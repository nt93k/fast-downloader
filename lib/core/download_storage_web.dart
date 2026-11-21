// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'download_storage.dart';

/// تخزين في ذاكرة المتصفح حتى اكتمال التنزيل، ثم حفظه كملف عبر Blob.
class WebDownloadStorage implements DownloadStorage {
  final Map<String, BytesBuilder> _buffers = {};

  BytesBuilder _buffer(String key) =>
      _buffers.putIfAbsent(key, BytesBuilder.new);

  @override
  Future<int> length(String key) async => _buffer(key).length;

  @override
  Future<void> append(String key, List<int> bytes) async {
    _buffer(key).add(bytes);
  }

  @override
  Future<void> delete(String key) async {
    _buffers.remove(key);
  }

  @override
  Future<void> saveToDevice(String key, String fileName) async {
    final bytes = _buffer(key).takeBytes();
    final blob = html.Blob(<dynamic>[bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Future<String?> existingFilePath(String key) async => null;
}

DownloadStorage createDownloadStorage() => WebDownloadStorage();
