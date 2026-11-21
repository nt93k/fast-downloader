import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'download_storage.dart';
import 'download_task.dart';

class DownloadManager extends ChangeNotifier {
  final DownloadStorage _storage = createDownloadStorage();
  final List<DownloadTask> tasks = <DownloadTask>[];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _online = true;

  bool get isOnline => _online;

  Future<void> init() async {
    final connectivity = Connectivity();
    try {
      final results = await connectivity.checkConnectivity();
      _online = !results.contains(ConnectivityResult.none);
    } catch (_) {
      _online = true;
    }
    notifyListeners();

    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = !results.contains(ConnectivityResult.none);
      final wasOnline = _online;
      _online = nowOnline;

      if (!nowOnline) {
        for (final task in tasks) {
          task.onConnectivityLost();
        }
      } else if (nowOnline && !wasOnline) {
        // عودة الإنترنت: استئناف فوري لكل مهمة توقفت بسبب الانقطاع.
        for (final task in tasks) {
          if (task.status == DownloadStatus.error) task.resumeNow();
        }
      }
      notifyListeners();
    });
  }

  DownloadTask addDownload(String url) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: id,
      url: url.trim(),
      fileName: _nameFromUrl(url.trim()),
      storage: _storage,
      onChanged: (_) => notifyListeners(),
    );
    tasks.insert(0, task);
    notifyListeners();
    task.start();
    return task;
  }

  void pause(DownloadTask task) => task.pause();

  void resume(DownloadTask task) => task.resumeNow();

  void retry(DownloadTask task) => task.resumeNow();

  void remove(DownloadTask task) {
    task.cancel();
    tasks.remove(task);
    notifyListeners();
  }

  void clearFinished() {
    final finished = tasks
        .where((task) =>
            task.status == DownloadStatus.done ||
            task.status == DownloadStatus.canceled)
        .toList();
    for (final task in finished) {
      task.dispose();
      tasks.remove(task);
    }
    notifyListeners();
  }

  String _nameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      var name = uri.pathSegments.where((part) => part.isNotEmpty).lastOrNull ?? '';
      try {
        name = Uri.decodeComponent(name);
      } catch (_) {}
      name = name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_').trim();
      if (name.isNotEmpty) return name;
      final host = uri.host.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_');
      return '${host.isEmpty ? 'download' : host}_${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    for (final task in tasks) {
      task.dispose();
    }
    super.dispose();
  }
}
