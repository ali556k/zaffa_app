import 'package:firebase_storage/firebase_storage.dart';

class StorageHelper {
  /// الحصول على رابط صورة صالح من Firebase Storage
  /// يستخرج اسم الملف من الرابط القديم ويولد رابط جديد
  static Future<String> getValidImageUrl(String oldUrl) async {
    try {
      // إذا كان الرابط يعمل، استخدمه مباشرة
      if (!oldUrl.contains('firebasestorage.googleapis.com')) {
        return oldUrl;
      }

      // استخراج المسار من الرابط القديم
      final uri = Uri.parse(oldUrl);
      final pathSegments = uri.pathSegments;
      
      // البحث عن /o/ في المسار
      final oIndex = pathSegments.indexOf('o');
      if (oIndex == -1 || oIndex >= pathSegments.length - 1) {
        print('⚠️ مسار غير صحيح: $oldUrl');
        return oldUrl;
      }

      // المسار بعد /o/ هو مسار الملف في Storage
      final filePath = Uri.decodeComponent(pathSegments[oIndex + 1]);
      print('📁 مسار الملف المستخرج: $filePath');

      // الحصول على رابط تحميل جديد من Firebase Storage
      final ref = FirebaseStorage.instance.ref().child(filePath);
      final downloadUrl = await ref.getDownloadURL();
      
      print('✅ تم توليد رابط جديد: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('❌ خطأ في توليد رابط الصورة: $e');
      print('   الرابط القديم: $oldUrl');
      // إرجاع الرابط القديم في حالة الفشل
      return oldUrl;
    }
  }

  /// تحويل قائمة روابط قديمة إلى روابط جديدة صالحة
  static Future<List<String>> getValidImageUrls(List<String> oldUrls) async {
    final validUrls = <String>[];
    
    for (final url in oldUrls) {
      try {
        final validUrl = await getValidImageUrl(url);
        validUrls.add(validUrl);
      } catch (e) {
        print('⚠️ تخطي صورة معطوبة: $url');
        // الاستمرار مع الصور الأخرى
      }
    }
    
    return validUrls;
  }
}
