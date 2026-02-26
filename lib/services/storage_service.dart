import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

/// خدمة تخزين الملفات
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// رفع صورة
  Future<String?> uploadImage({
    required File imageFile,
    required String chatId,
    required String senderId,
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final ref = _storage.ref().child('chat_images/$chatId/$senderId/$fileName');
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ تم رفع الصورة: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      return null;
    }
  }

  /// رفع ملف
  Future<String?> uploadFile({
    required File file,
    required String chatId,
    required String senderId,
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final ref = _storage.ref().child('chat_files/$chatId/$senderId/$fileName');
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ تم رفع الملف: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ خطأ في رفع الملف: $e');
      return null;
    }
  }

  /// رفع تسجيل صوتي
  Future<String?> uploadAudio({
    required File audioFile,
    required String chatId,
    required String senderId,
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_audio.m4a';
      final ref = _storage.ref().child('chat_audio/$chatId/$senderId/$fileName');
      
      final uploadTask = ref.putFile(audioFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ تم رفع التسجيل الصوتي: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ خطأ في رفع التسجيل الصوتي: $e');
      return null;
    }
  }

  /// اختيار صورة من المعرض
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  /// التقاط صورة بالكاميرا
  Future<File?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (photo != null) {
        return File(photo.path);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في التقاط الصورة: $e');
      return null;
    }
  }

  /// اختيار ملف
  Future<File?> pickFile() async {
    try {
      // ملاحظة: قد تحتاج إلى إضافة package file_picker
      // للتبسيط، نستخدم image picker فقط في هذا المثال
      return await pickImageFromGallery();
    } catch (e) {
      print('❌ خطأ في اختيار الملف: $e');
      return null;
    }
  }
}
