import 'download_storage_io.dart' if (dart.library.html) 'download_storage_web.dart' as impl;

/// واجهة تخزين مستقلة عن المنصة.
///
/// على الهاتف وسطح المكتب تُكتب البيانات مباشرة في ملف،
/// وعلى الويب تُجمع في الذاكرة ثم تُحفظ عبر المتصفح عند الاكتمال.
abstract class DownloadStorage {
  /// عدد البايتات المحفوظة حتى الآن (نقطة الاستئناف).
  Future<int> length(String key);

  /// إضافة جزء جديد إلى نهاية الملف/المخزن.
  Future<void> append(String key, List<int> bytes);

  /// حذف البيانات غير المكتملة.
  Future<void> delete(String key);

  /// تسليم الملف النهائي للمستخدم (لا شيء على المنصات الأصلية).
  Future<void> saveToDevice(String key, String fileName);

  /// مسار الملف على المنصات الأصلية، وnull على الويب.
  Future<String?> existingFilePath(String key);
}

DownloadStorage createDownloadStorage() => impl.createDownloadStorage();
