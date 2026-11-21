import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'download_storage.dart';

enum DownloadStatus { downloading, paused, error, done, canceled }

/// مهمة تنزيل واحدة. تعتمد على طلبات HTTP Range لاستئناف التنزيل
/// من آخر بايت تم حفظه بدلاً من البدء من الصفر بعد انقطاع الاتصال.
class DownloadTask {
  final String id;
  final String url;
  final String storageKey;
  String fileName;
  final DownloadStorage _storage;
  final void Function(DownloadTask task) onChanged;

  int downloaded = 0;
  int? totalBytes;
  double speedBytesPerSecond = 0;
  DownloadStatus status = DownloadStatus.downloading;
  String? errorMessage;
  int retryCount = 0;
  String? savedPath;
  DateTime? startedAt;

  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;
  Timer? _retryTimer;
  Timer? _stallTimer;
  Future<void> _pendingWrite = Future.value();
  int _streamGeneration = 0;
  bool _disposed = false;

  int _lastSampleBytes = 0;
  DateTime _lastSampleTime = DateTime.now();

  static const Duration _stallTimeout = Duration(seconds: 20);
  static const int _maxBackoffSeconds = 30;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this._storage,
    required this.onChanged,
  }) : storageKey = '${id}_${_safeName(fileName)}';

  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_').trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  double get progress {
    if (totalBytes == null || totalBytes! <= 0) return 0;
    return (downloaded / totalBytes!).clamp(0.0, 1.0).toDouble();
  }

  bool get isActive => status == DownloadStatus.downloading;

  bool get canPause => status == DownloadStatus.downloading;

  bool get canResume =>
      status == DownloadStatus.paused || status == DownloadStatus.error;

  Duration? get remaining {
    if (totalBytes == null || speedBytesPerSecond <= 0) return null;
    final left = totalBytes! - downloaded;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / speedBytesPerSecond).round());
  }

  Future<void> start() async {
    if (_disposed) return;
    _retryTimer?.cancel();
    await _begin();
  }

  void resumeNow() {
    if (_disposed || status == DownloadStatus.downloading || status == DownloadStatus.done) {
      return;
    }
    _retryTimer?.cancel();
    _begin();
  }

  void pause() {
    if (_disposed || status != DownloadStatus.downloading) return;
    _retryTimer?.cancel();
    _stopStream();
    status = DownloadStatus.paused;
    speedBytesPerSecond = 0;
    _notify();
  }

  void onConnectivityLost() {
    if (status == DownloadStatus.downloading) {
      _fail('انقطع الاتصال بالإنترنت');
    }
  }

  void cancel() {
    _disposed = true;
    _retryTimer?.cancel();
    _stopStream();
    status = DownloadStatus.canceled;
    speedBytesPerSecond = 0;
    _storage.delete(storageKey).catchError((Object _) {});
    _notify();
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _stopStream();
  }

  Future<void> _begin() async {
    if (_disposed) return;
    _stopStream();
    _streamGeneration++;
    _pendingWrite = Future.value();
    status = DownloadStatus.downloading;
    errorMessage = null;
    speedBytesPerSecond = 0;
    startedAt ??= DateTime.now();
    _notify();

    try {
      downloaded = await _storage.length(storageKey);
      totalBytes ??= await _probeLength();
      _lastSampleBytes = downloaded;
      _lastSampleTime = DateTime.now();

      http.StreamedResponse? response;
      var accepted = false;

      for (var attempt = 0; attempt < 3; attempt++) {
        _client?.close();
        final client = http.Client();
        _client = client;
        final request = http.Request('GET', Uri.parse(url));
        request.headers['Accept-Encoding'] = 'identity';
        request.headers['User-Agent'] = 'FastDownloader/1.0';
        if (downloaded > 0) {
          request.headers['Range'] = 'bytes=$downloaded-';
        }
        final result = await client.send(request);

        if (result.statusCode == 416) {
          await result.stream.drain<void>();
          if (totalBytes != null && downloaded >= totalBytes!) {
            await _finish();
            return;
          }
          await _resetFile();
          continue;
        }

        if (result.statusCode == 200 && downloaded > 0) {
          // الخادم تجاهل Range؛ نعيد البناء من الصفر لضمان سلامة الملف.
          await result.stream.drain<void>();
          await _resetFile();
          continue;
        }

        if (result.statusCode == 206) {
          final contentRange = result.headers['content-range'];
          final start = _rangePart(contentRange, 0);
          if (start != null && start != downloaded) {
            await result.stream.drain<void>();
            await _resetFile();
            continue;
          }
          final total = _rangePart(contentRange, 2);
          if (total != null) totalBytes = total;
        } else if (result.statusCode != 200) {
          final body = await result.stream.bytesToString();
          final short = body.length > 160 ? body.substring(0, 160) : body;
          throw http.ClientException(
              'HTTP ${result.statusCode}: $short', Uri.parse(url));
        } else {
          final length = int.tryParse(result.headers['content-length'] ?? '');
          if (length != null && totalBytes == null) totalBytes = length;
        }

        response = result;
        accepted = true;
        break;
      }

      if (!accepted || response == null) {
        throw http.ClientException('تعذر فتح رابط التنزيل');
      }

      _armStallTimer();
      _subscription = response.stream.listen(
        _onData,
        onError: (Object error, StackTrace stack) =>
            _fail(_friendlyError(error)),
        onDone: _onDone,
        cancelOnError: true,
      );
    } catch (error) {
      _fail(_friendlyError(error));
    }
  }

  Future<int?> _probeLength() async {
    final client = http.Client();
    try {
      final response = await client
          .head(Uri.parse(url), headers: {'Accept-Encoding': 'identity'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return int.tryParse(response.headers['content-length'] ?? '');
      }
    } catch (_) {
      // بعض الخوادم لا تدعم HEAD؛ سنعتمد على رأس الاستجابة في GET.
    } finally {
      client.close();
    }
    return null;
  }

  static int? _rangePart(String? contentRange, int index) {
    if (contentRange == null) return null;
    final match = RegExp(r'bytes\s+(\d+)-(\d+)/(\d+|\*)').firstMatch(contentRange);
    if (match == null) return null;
    return int.tryParse(match.group(index + 1) ?? '');
  }

  void _onData(List<int> chunk) {
    if (_disposed || status != DownloadStatus.downloading) return;
    final generation = _streamGeneration;
    _pendingWrite = _pendingWrite
        .then((_) => _storeChunk(chunk, generation))
        .catchError((Object error) {
      _fail('تعذر حفظ البيانات: ${_friendlyError(error)}');
    });
  }

  Future<void> _storeChunk(List<int> chunk, int generation) async {
    if (_disposed ||
        status != DownloadStatus.downloading ||
        generation != _streamGeneration) {
      return;
    }
    await _storage.append(storageKey, chunk);
    downloaded += chunk.length;
    _armStallTimer();

    final now = DateTime.now();
    final elapsed = now.difference(_lastSampleTime).inMilliseconds;
    if (elapsed >= 500) {
      speedBytesPerSecond =
          (downloaded - _lastSampleBytes) * 1000.0 / elapsed;
      _lastSampleBytes = downloaded;
      _lastSampleTime = now;
      _notify();
    }
  }

  Future<void> _onDone() async {
    if (_disposed || status != DownloadStatus.downloading) return;
    try {
      await _pendingWrite;
      if (_disposed || status != DownloadStatus.downloading) return;
      if (totalBytes != null && downloaded < totalBytes!) {
        _fail('اكتمل التدفق قبل اكتمال الملف');
        return;
      }
      await _finish();
    } catch (error) {
      _fail(_friendlyError(error));
    }
  }

  Future<void> _finish() async {
    _stopStream();
    status = DownloadStatus.done;
    speedBytesPerSecond = 0;
    retryCount = 0;
    try {
      await _storage.saveToDevice(storageKey, fileName);
    } catch (_) {
      // فشل الحفظ على الويب لا يُلغي اكتمال التنزيل.
    }
    savedPath = await _storage.existingFilePath(storageKey);
    _notify();
  }

  void _fail(String message) {
    if (_disposed || status != DownloadStatus.downloading) return;
    _stopStream();
    status = DownloadStatus.error;
    errorMessage = message;
    speedBytesPerSecond = 0;
    _notify();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    retryCount++;
    final seconds = min(_maxBackoffSeconds, pow(2, min(retryCount, 5)).toInt());
    _retryTimer = Timer(Duration(seconds: seconds), () {
      if (!_disposed && status == DownloadStatus.error) _begin();
    });
  }

  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallTimeout, () {
      if (status == DownloadStatus.downloading) {
        _fail('لا توجد بيانات قادمة - قد يكون الاتصال مقطوعاً');
      }
    });
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _stallTimer?.cancel();
    _stallTimer = null;
    _client?.close();
    _client = null;
  }

  Future<void> _resetFile() async {
    await _storage.delete(storageKey);
    downloaded = 0;
    totalBytes = null;
    _lastSampleBytes = 0;
    _lastSampleTime = DateTime.now();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'تعذر الوصول للخادم';
    }
    if (text.contains('TimeoutException')) return 'انتهت مهلة الاتصال';
    if (text.startsWith('ClientException: ')) {
      return text.substring('ClientException: '.length);
    }
    return text.length > 160 ? text.substring(0, 160) : text;
  }

  void _notify() {
    if (!_disposed) onChanged(this);
  }
}
