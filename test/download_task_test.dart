import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fast_downloader/core/download_storage.dart';
import 'package:fast_downloader/core/download_task.dart';

class _MemoryStorage implements DownloadStorage {
  final Map<String, BytesBuilder> _buffers = {};

  BytesBuilder _buffer(String key) =>
      _buffers.putIfAbsent(key, BytesBuilder.new);

  @override
  Future<int> length(String key) async => _buffer(key).length;

  @override
  Future<void> append(String key, List<int> bytes) async =>
      _buffer(key).add(bytes);

  @override
  Future<void> delete(String key) async => _buffers.remove(key);

  @override
  Future<void> saveToDevice(String key, String fileName) async {}

  @override
  Future<String?> existingFilePath(String key) async => null;

  Uint8List bytes(String key) => Uint8List.fromList(_buffer(key).takeBytes());
}

void main() {
  HttpServer? server;
  final fileBytes = Uint8List.fromList(
    List<int>.generate(2048, (i) => i % 251),
  );
  String? lastRange;

  setUp(() async {
    lastRange = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((request) {
      final requestedRange = request.headers.value('range');
      if (requestedRange != null) lastRange = requestedRange;

      var start = 0;
      if (requestedRange != null) {
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(requestedRange)!.group(1)!);
      }
      final remaining = fileBytes.length - start;

      if (request.method == 'HEAD') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.set('content-length', remaining)
          ..close();
        return;
      }

      if (start > 0) {
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            'content-range',
            'bytes $start-${fileBytes.length - 1}/${fileBytes.length}',
          )
          ..headers.set('content-length', remaining)
          ..add(fileBytes.sublist(start))
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.set('content-length', fileBytes.length)
          ..add(fileBytes)
          ..close();
      }
    });
  });

  tearDown(() async {
    await server!.close(force: true);
  });

  DownloadTask createTask(DownloadStorage storage) => DownloadTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        url: 'http://127.0.0.1:${server!.port}/file.bin',
        fileName: 'file.bin',
        storage: storage,
        onChanged: (_) {},
      );

  Future<void> waitForDone(DownloadTask task) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (task.status != DownloadStatus.done &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('downloads a full file', () async {
    final storage = _MemoryStorage();
    final task = createTask(storage);
    await task.start();
    await waitForDone(task);

    expect(task.status, DownloadStatus.done);
    expect(task.downloaded, fileBytes.length);
    expect(storage.bytes(task.storageKey), fileBytes);
    expect(lastRange, isNull);
    task.dispose();
  });

  test('resumes from saved offset using Range', () async {
    final storage = _MemoryStorage();
    final task = createTask(storage);
    await storage.append(task.storageKey, fileBytes.sublist(0, 500));

    await task.start();
    await waitForDone(task);

    expect(task.status, DownloadStatus.done);
    expect(lastRange, 'bytes=500-');
    expect(task.downloaded, fileBytes.length);
    expect(storage.bytes(task.storageKey), fileBytes);
    task.dispose();
  });
}
