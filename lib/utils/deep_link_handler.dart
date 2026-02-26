import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/item_details_screen.dart';
// import '../screens/provider_details_screen.dart'; // TODO: أنشئ هذه الشاشة
// import '../screens/booking_details_screen.dart'; // TODO: أنشئ هذه الشاشة

/// معالج الروابط العميقة (Deep Links Handler)
/// يتعامل مع الروابط من نوع zafa:// و https://zafaapp.com
class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  /// معالجة URI ومعرفة نوعه
  Future<void> handleDeepLink(BuildContext context, Uri uri) async {
    print('📱 Deep Link received: $uri');
    
    // مسار الرابط
    final path = uri.path;
    final segments = uri.pathSegments;

    if (segments.isEmpty) {
      print('⚠️ Empty URI segments');
      return;
    }

    // التعامل حسب نوع الرابط
    switch (segments[0]) {
      case 'item':
        if (segments.length >= 2) {
          final itemId = segments[1];
          await _navigateToItem(context, itemId);
        }
        break;

      case 'provider':
        if (segments.length >= 2) {
          final providerId = segments[1];
          await _navigateToProvider(context, providerId);
        }
        break;

      case 'booking':
        if (segments.length >= 2) {
          final bookingId = segments[1];
          await _navigateToBooking(context, bookingId);
        }
        break;

      default:
        print('⚠️ Unknown deep link path: $path');
        _showErrorSnackBar(context, 'رابط غير معروف');
    }
  }

  /// الانتقال إلى شاشة تفاصيل العنصر
  Future<void> _navigateToItem(BuildContext context, String itemId) async {
    print('🔗 Navigate to item: $itemId');
    
    try {
      // جلب بيانات العنصر من Firestore
      final itemDoc = await FirebaseFirestore.instance
          .collection('published_items')
          .doc(itemId)
          .get();

      if (!itemDoc.exists) {
        _showErrorSnackBar(context, 'العنصر غير موجود');
        return;
      }

      final itemData = itemDoc.data()!;
      itemData['id'] = itemDoc.id;

      // جلب اسم المزود
      String providerName = 'مزود الخدمة';
      if (itemData['providerId'] != null) {
        try {
          final providerDoc = await FirebaseFirestore.instance
              .collection('published_providers')
              .doc(itemData['providerId'])
              .get();
          if (providerDoc.exists) {
            providerName = providerDoc.data()?['name'] ?? 'مزود الخدمة';
          }
        } catch (e) {
          print('⚠️ Could not fetch provider name: $e');
        }
      }

      // الانتقال إلى شاشة التفاصيل
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailsScreen(
              item: itemData,
              providerName: providerName,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error navigating to item: $e');
      _showErrorSnackBar(context, 'حدث خطأ أثناء فتح العنصر');
    }
  }

  /// الانتقال إلى شاشة تفاصيل المزود
  Future<void> _navigateToProvider(BuildContext context, String providerId) async {
    print('🔗 Navigate to provider: $providerId');
    
    try {
      // جلب بيانات المزود من Firestore
      final providerDoc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(providerId)
          .get();

      if (!providerDoc.exists) {
        _showErrorSnackBar(context, 'مزود الخدمة غير موجود');
        return;
      }

      final providerData = providerDoc.data()!;
      providerData['id'] = providerDoc.id;

      // TODO: أنشئ ProviderDetailsScreen
      // if (context.mounted) {
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //       builder: (context) => ProviderDetailsScreen(
      //         provider: providerData,
      //       ),
      //     ),
      //   );
      // }

      // مؤقتاً: عرض رسالة
      _showInfoSnackBar(
        context, 
        'سيتم فتح صفحة المزود: ${providerData['name'] ?? 'مزود الخدمة'}'
      );
    } catch (e) {
      print('❌ Error navigating to provider: $e');
      _showErrorSnackBar(context, 'حدث خطأ أثناء فتح مزود الخدمة');
    }
  }

  /// الانتقال إلى شاشة تفاصيل الحجز
  Future<void> _navigateToBooking(BuildContext context, String bookingId) async {
    print('🔗 Navigate to booking: $bookingId');
    
    try {
      // جلب بيانات الحجز من Firestore
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        _showErrorSnackBar(context, 'الحجز غير موجود');
        return;
      }

      final bookingData = bookingDoc.data()!;
      bookingData['id'] = bookingDoc.id;

      // TODO: أنشئ BookingDetailsScreen
      // if (context.mounted) {
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //       builder: (context) => BookingDetailsScreen(
      //         booking: bookingData,
      //       ),
      //     ),
      //   );
      // }

      // مؤقتاً: عرض رسالة
      _showInfoSnackBar(
        context,
        'سيتم فتح تفاصيل الحجز: ${bookingData['itemName'] ?? 'حجز'}'
      );
    } catch (e) {
      print('❌ Error navigating to booking: $e');
      _showErrorSnackBar(context, 'حدث خطأ أثناء فتح الحجز');
    }
  }

  /// عرض رسالة خطأ
  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// عرض رسالة معلومات
  void _showInfoSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF667eea),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// التحقق من صحة URI
  static bool isValidDeepLink(Uri uri) {
    // التحقق من Scheme
    if (uri.scheme != 'zafa' && uri.scheme != 'https') {
      return false;
    }

    // التحقق من Host للروابط HTTPS
    if (uri.scheme == 'https' && uri.host != 'zafaapp.com') {
      return false;
    }

    // التحقق من وجود مسار
    if (uri.pathSegments.isEmpty) {
      return false;
    }

    // التحقق من نوع المسار المدعوم
    final validTypes = ['item', 'provider', 'booking'];
    return validTypes.contains(uri.pathSegments[0]);
  }

  /// استخراج معلومات من URI
  static Map<String, dynamic> parseDeepLink(Uri uri) {
    final segments = uri.pathSegments;
    
    if (segments.isEmpty) {
      return {'type': 'unknown', 'id': null};
    }

    return {
      'type': segments[0],
      'id': segments.length >= 2 ? segments[1] : null,
      'scheme': uri.scheme,
      'host': uri.host,
    };
  }
}
