import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageUtils {
  /// تنظيف رابط الصورة من Firebase Storage
  /// إزالة التوكن القديم واستخدام الرابط المباشر
  static String cleanImageUrl(String url) {
    if (!url.contains('firebasestorage.googleapis.com')) {
      return url; // ليس رابط Firebase
    }

    // إزالة التوكن من الرابط
    final uri = Uri.parse(url);
    final newUri = uri.replace(queryParameters: {'alt': 'media'});
    return newUri.toString();
  }

  /// بناء صورة محسّنة مع caching
  static Widget buildCachedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultErrorWidget(width, height);
    }

    // التحقق من أن القيم ليست infinity قبل التحويل لـ int
    // تقليل الجودة للهواتف الضعيفة
    final memWidth = (width != null && width.isFinite && width < 400)
        ? width.toInt()
        : 400;
    final memHeight = (height != null && height.isFinite && height < 400)
        ? height.toInt()
        : 400;

    return CachedNetworkImage(
      imageUrl: cleanImageUrl(imageUrl),
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ?? _defaultPlaceholder(width, height),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(width, height),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 50),
      memCacheWidth: memWidth,
      memCacheHeight: memHeight,
      maxWidthDiskCache: 500,
      maxHeightDiskCache: 500,
    );
  }

  static Widget _defaultPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const SizedBox.shrink(),
    );
  }

  static Widget _defaultErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 40),
    );
  }

  static List<String> getImages(Map<String, dynamic> map) {
    // طباعة للتشخيص
    print('🖼️ محاولة جلب الصور من: ${map.keys.toList()}');

    List<String> result = [];

    // 1. حقل hallImages (للقاعات - مصفوفة)
    if (map['hallImages'] is List && (map['hallImages'] as List).isNotEmpty) {
      result = List<String>.from(
        map['hallImages'].map((e) => cleanImageUrl(e.toString())),
      );
      print('✅ وجدت صور في حقل hallImages: ${result.length}');
      print('   أول صورة: ${result.first}');
      return result;
    }

    // 2. حقل hallData.hallImages (بيانات القاعة المُفصلة)
    if (map['hallData'] is Map) {
      final hallData = map['hallData'] as Map<String, dynamic>;
      if (hallData['hallImages'] is List &&
          (hallData['hallImages'] as List).isNotEmpty) {
        result = List<String>.from(
          hallData['hallImages'].map((e) => cleanImageUrl(e.toString())),
        );
        print('✅ وجدت صور في hallData.hallImages: ${result.length}');
        print('   أول صورة: ${result.first}');
        return result;
      }
    }

    // 3. حقل images (مصفوفة)
    if (map['images'] is List && (map['images'] as List).isNotEmpty) {
      result = List<String>.from(
        map['images'].map((e) => cleanImageUrl(e.toString())),
      );
      print('✅ وجدت صور في حقل images: ${result.length}');
      print('   أول صورة: ${result.first}');
      return result;
    }

    // 4. حقل imageUrls (مصفوفة)
    if (map['imageUrls'] is List && (map['imageUrls'] as List).isNotEmpty) {
      result = List<String>.from(
        map['imageUrls'].map((e) => cleanImageUrl(e.toString())),
      );
      print('✅ وجدت صور في حقل imageUrls: ${result.length}');
      print('   أول صورة: ${result.first}');
      return result;
    }

    // 3. حقل serviceImage (صورة واحدة - تستخدم في published_providers)
    if (map['serviceImage'] != null &&
        map['serviceImage'].toString().isNotEmpty) {
      result = [cleanImageUrl(map['serviceImage'].toString())];
      print('✅ وجدت صورة في حقل serviceImage');
      print('   الصورة: ${result.first}');
      return result;
    }

    // 4. حقل profileImage (صورة واحدة - تستخدم في published_providers)
    if (map['profileImage'] != null &&
        map['profileImage'].toString().isNotEmpty) {
      result = [cleanImageUrl(map['profileImage'].toString())];
      print('✅ وجدت صورة في حقل profileImage');
      print('   الصورة: ${result.first}');
      return result;
    }

    // 5. حقل imageUrl (صورة واحدة)
    if (map['imageUrl'] != null && map['imageUrl'].toString().isNotEmpty) {
      result = [cleanImageUrl(map['imageUrl'].toString())];
      print('✅ وجدت صورة في حقل imageUrl');
      print('   الصورة: ${result.first}');
      return result;
    }

    // 6. حقل image (صورة واحدة)
    if (map['image'] != null && map['image'].toString().isNotEmpty) {
      result = [cleanImageUrl(map['image'].toString())];
      print('✅ وجدت صورة في حقل image');
      print('   الصورة: ${result.first}');
      return result;
    }

    print('❌ لم يتم العثور على صور');
    // لا توجد صور - إرجاع قائمة فارغة
    return [];
  }
}
