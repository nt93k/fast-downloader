import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'download_storage.dart';

/// تخزين حقيقي على Android / iOS / Windows / macOS / Linux.
class NativeDownloadStorage implements DownloadStorage {
  Directory? _root;

  Future<Directory> _downloadsDir() async {
    final root = _root ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file(String key) async {
    final dir = await _downloadsDir();
    return File('${dir.path}${Platform.pathSeparator}$key');
  }

  @override
  Future<int> length(String key) async {
    final file = await _file(key);
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  @override
  Future<void> append(String key, List<int> bytes) async {
    final file = await _file(key);
    final sink = file.openWrite(mode: FileMode.append);
    sink.add(bytes);
    await sink.close();
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<void> saveToDevice(String key, String fileName) async {
    // الملف محفوظ بالفعل داخل مجلد التطبيق، لا إجراء إضافي مطلوب.
  }

  @override
  Future<String?> existingFilePath(String key) async {
    final file = await _file(key);
    return file.existsSync() ? file.path : null;
  }
}

DownloadStorage createDownloadStorage() => NativeDownloadStorage();
