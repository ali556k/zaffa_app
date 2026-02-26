import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة المشاركة الاجتماعية للخدمات والمزودين
class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  // رابط التطبيق الأساسي (Deep Link)
  static const String _appBaseUrl = 'https://zafaapp.com'; // استبدل بالرابط الفعلي
  static const String _appScheme = 'zafa://'; // Deep link scheme
  
  /// مشاركة خدمة معينة
  Future<void> shareItem({
    required String itemId,
    required String itemName,
    required String providerName,
    String? price,
    String? description,
  }) async {
    try {
      // إنشاء رابط ديناميكي يحفظ بيانات العنصر في Firestore
      final shareLink = await _createShareableLink('item', itemId, {
        'name': itemName,
        'providerName': providerName,
        'price': price,
        'description': description,
      });

      final priceText = price != null ? '\nالسعر: $price د.ع' : '';
      final descriptionText = description != null && description.isNotEmpty 
          ? '\n\n$description' 
          : '';

      final message = '''
🎉 اكتشف خدمة رائعة في تطبيق زفة!

📌 $itemName
👤 من: $providerName$priceText$descriptionText

🔗 عرض التفاصيل:
$shareLink

حمّل تطبيق زفة الآن واستمتع بأفضل خدمات الأعراس!
''';

      await Share.share(
        message,
        subject: 'مشاركة خدمة من تطبيق زفة',
      );

      // تسجيل عملية المشاركة في قاعدة البيانات
      await _logShare('item', itemId);
    } catch (e) {
      print('خطأ في مشاركة الخدمة: $e');
    }
  }

  /// مشاركة ملف مزود خدمة
  Future<void> shareProvider({
    required String providerId,
    required String providerName,
    String? bio,
    int? itemsCount,
    double? rating,
  }) async {
    try {
      final itemsText = itemsCount != null ? '\n📦 عدد الخدمات: $itemsCount' : '';
      final ratingText = rating != null ? '\n⭐ التقييم: ${rating.toStringAsFixed(1)}/5' : '';
      final bioText = bio != null && bio.isNotEmpty ? '\n\n📝 $bio' : '';

      // Deep Link للمزود
      final deepLink = '${_appScheme}provider/$providerId';
      final webLink = '$_appBaseUrl/provider/$providerId';

      final message = '''
👨‍💼 تعرف على مزود خدمات رائع في تطبيق زفة!

✨ $providerName$itemsText$ratingText$bioText

🔗 افتح في التطبيق:
$deepLink

أو عبر المتصفح:
$webLink

حمّل تطبيق زفة الآن لاستكشاف المزيد!
''';

      await Share.share(
        message,
        subject: 'مشاركة مزود خدمة من تطبيق زفة',
      );

      // تسجيل عملية المشاركة
      await _logShare('provider', providerId);
    } catch (e) {
      print('خطأ في مشاركة المزود: $e');
    }
  }

  /// مشاركة التطبيق نفسه
  Future<void> shareApp() async {
    try {
      // روابط التحميل
      const playStoreLink = 'https://play.google.com/store/apps/details?id=com.zafa.app'; // استبدل بالرابط الفعلي
      const appStoreLink = 'https://apps.apple.com/app/zafa/id123456789'; // استبدل بالرابط الفعلي
      
      final message = '''
💍 تطبيق زفة - كل ما تحتاجه لحفل زفاف أحلامك!

🎊 قاعات أفراح
🍰 كيك وحلويات
🌹 تنسيق زهور
🚗 سيارات زفاف
📸 تصوير وفيديو
والمزيد...

📱 حمّل التطبيق الآن:

🤖 Android:
$playStoreLink

🍎 iOS:
$appStoreLink

🌐 أو زُر موقعنا:
$_appBaseUrl
''';

      await Share.share(
        message,
        subject: 'تطبيق زفة - لتنظيم أعراس مميزة',
      );
    } catch (e) {
      print('خطأ في مشاركة التطبيق: $e');
    }
  }

  /// مشاركة حجز معين (للعملاء)
  Future<void> shareBooking({
    required String bookingId,
    required String itemName,
    required String providerName,
    required DateTime bookingDate,
    String? timeSlot,
  }) async {
    try {
      final dateText = '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
      final timeText = timeSlot != null ? '\n⏰ الوقت: $timeSlot' : '';

      // Deep Link للحجز
      final deepLink = '${_appScheme}booking/$bookingId';
      final webLink = '$_appBaseUrl/booking/$bookingId';

      final message = '''
✅ تم تأكيد حجزي في تطبيق زفة!

📌 $itemName
👤 من: $providerName
📅 التاريخ: $dateText$timeText

🔗 عرض الحجز:
$deepLink

أو عبر المتصفح:
$webLink

استخدم تطبيق زفة لحجز خدمات زفافك بسهولة!
''';

      await Share.share(
        message,
        subject: 'تأكيد حجز من تطبيق زفة',
      );
    } catch (e) {
      print('خطأ في مشاركة الحجز: $e');
    }
  }

  /// إنشاء رابط قابل للمشاركة يحفظ البيانات في Firestore
  Future<String> _createShareableLink(String type, String id, Map<String, dynamic> data) async {
    try {
      // إنشاء مستند في مجموعة shared_links
      final docRef = await FirebaseFirestore.instance
          .collection('shared_links')
          .add({
        'type': type,
        'targetId': id,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'clickCount': 0,
      });

      // إنشاء رابط قصير باستخدام معرف المستند
      final shortId = docRef.id;
      final shareableLink = '$_appBaseUrl/s/$shortId';
      
      print('✅ تم إنشاء رابط المشاركة: $shareableLink');
      return shareableLink;
    } catch (e) {
      print('❌ خطأ في إنشاء رابط المشاركة: $e');
      // في حالة الخطأ، نُرجع رابط افتراضي
      return '$_appBaseUrl/$type/$id';
    }
  }

  /// تسجيل عملية المشاركة في قاعدة البيانات للإحصائيات
  Future<void> _logShare(String type, String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('shares')
          .add({
        'type': type,
        'targetId': id,
        'sharedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('خطأ في تسجيل المشاركة: $e');
    }
  }

  /// الحصول على عدد المشاركات لعنصر معين
  Future<int> getShareCount(String itemId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shares')
          .where('type', isEqualTo: 'item')
          .where('targetId', isEqualTo: itemId)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('خطأ في الحصول على عدد المشاركات: $e');
      return 0;
    }
  }
}
