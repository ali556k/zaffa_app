import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../screens/chat_room_screen.dart';
import '../utils/chat_utils.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/booking_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static BuildContext? _appContext;

  Future<void> init(BuildContext context) async {
    _appContext = context;

    // طلب صلاحية الإشعارات
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // حفظ توكن الجهاز
    await _saveDeviceToken();

    // إنشاء قنوات الإشعارات
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'zafa_main_channel',
            'إشعارات زفة',
            description: 'إشعارات الحجوزات والرسائل',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

    // إعداد local notifications
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // استقبال الإشعار أثناء عمل التطبيق
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        'تم استقبال رسالة أثناء عمل التطبيق: ${message.notification?.title}',
      );
      _showNotification(message);
    });

    // استقبال الإشعار عند فتح التطبيق من الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('تم فتح التطبيق من الإشعار: ${message.data}');
      _handleNotificationTap(message);
    });

    // التحقق من إشعار عند فتح التطبيق
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('تم فتح التطبيق من إشعار أولي: ${message.data}');
        _handleNotificationTap(message);
      }
    });
  }

  // حفظ توكن الجهاز في قاعدة البيانات
  Future<void> _saveDeviceToken() async {
    try {
      String? token = await _fcm.getToken();
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('user_phone');

      if (userPhone != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userPhone)
            .update({'fcmToken': token});
        print('تم حفظ توكن الجهاز: $token');
      }
    } catch (e) {
      print('خطأ في حفظ توكن الجهاز: $e');
    }
  }

  // دالة عامة لحفظ توكن الجهاز
  Future<void> saveDeviceToken() async {
    await _saveDeviceToken();
  }

  // دالة لحفظ FCM Token للمزود في providers collection
  Future<void> saveProviderToken(String providerId) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .update({'fcmToken': token});
        print('✅ تم حفظ FCM Token للمزود في providers: $providerId');
      }
    } catch (e) {
      print('⚠️ خطأ في حفظ FCM Token للمزود: $e');
    }
  }

  // معالجة الضغط على الإشعار المحلي
  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final parts = payload.split('|');
      if (parts.isEmpty) return;
      final type = parts[0];
      if (type == 'message' && parts.length >= 3) {
        _navigateToChat(parts[1], parts[2]);
      } else if ((type == 'booking_status' || type == 'new_booking') &&
          parts.length >= 2) {
        _navigateToMyBookings();
      }
    } catch (e) {
      print('خطأ في تحليل payload: $e');
    }
  }

  // معالجة الضغط على الإشعار من Firebase
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    print('بيانات الإشعار: $data');
    final type = data['type'] ?? '';
    if (type == 'message' && data['chatId'] != null) {
      _navigateToChat(data['chatId']!, data['currentUserId'] ?? '');
    } else if (type == 'booking_status' || type == 'new_booking') {
      _navigateToMyBookings();
    }
  }

  // التنقل لصفحة حجوزاتي
  void _navigateToMyBookings() {
    if (_appContext != null) {
      Navigator.of(
        _appContext!,
      ).pushNamedAndRemoveUntil('/bookings', (route) => route.isFirst);
    }
  }

  // التنقل إلى شاشة المحادثة
  void _navigateToChat(String chatId, String currentUserId) async {
    if (_appContext != null && currentUserId.isNotEmpty) {
      // التحقق من صحة معرف المحادثة
      if (ChatUtils.isValidChatId(chatId)) {
        // استخراج معرف المستخدم الآخر من chatId
        List<String> ids = chatId.split('-');
        String otherUserId = ids.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        // تحديد اسم المستخدم الآخر
        String otherUserName = 'مستخدم';
        if (otherUserId == '07721874360' || chatId.startsWith('support-')) {
          otherUserName = 'الدعم الفني';
        }

        await Navigator.of(_appContext!).push(
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              chatId: chatId,
              currentUserId: currentUserId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
            ),
          ),
        );
      } else {
        print('معرف المحادثة غير صحيح: $chatId');
      }
    } else {
      print('لا يمكن التنقل - السياق أو معرف المستخدم غير متوفر');
    }
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // الحصول على معرف المستخدم الحالي للتنقل
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_phone') ?? '';

    // تحديد نوع الإشعار وبناء payload
    final type = message.data['type'] ?? 'message';
    final chatId = message.data['chatId'] ?? '';
    String payload;
    if (type == 'message') {
      payload = 'message|$chatId|$currentUserId';
    } else {
      final bookingId = message.data['bookingId'] ?? '';
      payload = '$type|$bookingId';
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'zafa_main_channel',
          'إشعارات زفة',
          channelDescription: 'إشعارات الحجوزات والرسائل',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          playSound: true,
          enableVibration: true,
          showWhen: true,
          color: const Color(0xFF800000),
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            htmlFormatBigText: false,
            contentTitle: notification.title,
            htmlFormatContentTitle: false,
          ),
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: payload,
    );
  }

  Future<String?> getDeviceToken() async {
    return await _fcm.getToken();
  }

  // ===== إشعارات الحجوزات الذكية =====

  /// جدولة إشعار تذكير قبل الحجز بـ 24 ساعة
  Future<void> scheduleBookingReminder({
    required String bookingId,
    required DateTime bookingDate,
    required String itemName,
    required String customerName,
  }) async {
    try {
      // تهيئة timezone
      tz.initializeTimeZones();

      // حساب وقت الإشعار (24 ساعة قبل الحجز)
      final reminderTime = bookingDate.subtract(const Duration(hours: 24));

      // التحقق من أن الوقت المجدول في المستقبل
      if (reminderTime.isBefore(DateTime.now())) {
        print('وقت التذكير قد مضى، لن يتم جدولة الإشعار');
        return;
      }

      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'booking_reminders',
            'تذكيرات الحجوزات',
            channelDescription: 'إشعارات تذكير بالحجوزات القادمة',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF8B0000),
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        bookingId.hashCode,
        '⏰ تذكير بحجز قادم',
        'لديك حجز غداً: $itemName\nيرجى الاستعداد والتأكد من التفاصيل',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'booking_reminder|$bookingId',
      );
    } catch (e) {
      print('خطأ في جدولة تذكير الحجز: $e');
    }
  }

  /// إلغاء إشعار تذكير محدد
  Future<void> cancelBookingReminder(String bookingId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(bookingId.hashCode);
    } catch (e) {
      print('خطأ في إلغاء تذكير الحجز: $e');
    }
  }

  /// إشعار المزود عند وصول الحجوزات لـ 3+ في يوم واحد
  Future<void> notifyProviderHighBookings({
    required String providerId,
    required DateTime date,
    required int bookingsCount,
  }) async {
    try {
      // جلب معلومات المزود
      final providerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .get();

      if (!providerDoc.exists) return;

      final providerData = providerDoc.data();
      final fcmToken = providerData?['fcmToken'];

      if (fcmToken == null) {
        print('لا يوجد FCM token للمزود');
        return;
      }

      // إرسال إشعار FCM للمزود
      await _sendNotificationToToken(
        token: fcmToken,
        title: '📊 تنبيه: يوم مزدحم!',
        body:
            'لديك $bookingsCount حجوزات في ${_formatDate(date)}. يرجى التحضير جيداً.',
        data: {
          'type': 'high_bookings_alert',
          'date': date.toIso8601String(),
          'count': bookingsCount.toString(),
        },
      );
    } catch (e) {
      print('خطأ في إرسال تنبيه الحجوزات: $e');
    }
  }

  /// التحقق من عدد الحجوزات اليومية وإرسال تنبيه إذا لزم الأمر
  Future<void> checkDailyBookingsAndNotify({
    required String providerId,
    required DateTime date,
  }) async {
    try {
      // الحصول على بداية ونهاية اليوم
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // عد الحجوزات في هذا اليوم
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where(
            'bookingDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('bookingDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('isCancelled', isEqualTo: false)
          .get();

      final bookingsCount = bookingsSnapshot.docs.length;

      // إرسال تنبيه إذا كان العدد 3 أو أكثر
      if (bookingsCount >= 3) {
        await notifyProviderHighBookings(
          providerId: providerId,
          date: date,
          bookingsCount: bookingsCount,
        );
      }
    } catch (e) {
      print('خطأ في التحقق من الحجوزات اليومية: $e');
    }
  }

  /// إرسال إشعار عبر FCM Token
  Future<void> _sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // في الإنتاج، يجب استخدام Cloud Functions أو خادم خلفي
      // هنا نستخدم local notification كبديل
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'booking_alerts',
            'تنبيهات الحجوزات',
            channelDescription: 'إشعارات حول الحجوزات والتنبيهات',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF8B0000),
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
        payload: data?.toString(),
      );
    } catch (e) {
      print('خطأ في إرسال الإشعار: $e');
    }
  }

  /// إرسال إشعار للمزود عند تعديل الحجز من قبل العميل
  Future<void> sendBookingModificationNotification({
    required String providerId,
    required String bookingId,
    required String customerName,
    required String itemName,
    required DateTime newDate,
    TimeSlot? newTimeSlot,
  }) async {
    try {
      print('📢 إرسال إشعار تعديل الحجز للمزود: $providerId');

      // جلب معلومات المزود للحصول على FCM Token
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      if (!providerDoc.exists) {
        print('⚠️ المزود غير موجود');
        return;
      }

      final providerData = providerDoc.data();
      final fcmToken = providerData?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ لا يوجد FCM Token للمزود');
        return;
      }

      // تنسيق معلومات التعديل
      final dateString = _formatDate(newDate);
      final timeString = newTimeSlot != null
          ? 'من ${newTimeSlot.startTime} إلى ${newTimeSlot.endTime}'
          : 'اليوم كامل';

      // إرسال الإشعار
      await _sendNotificationToToken(
        token: fcmToken,
        title: '✏️ تم تعديل حجز',
        body:
            'قام $customerName بتعديل حجز $itemName\nالموعد الجديد: $dateString\nالوقت: $timeString',
        data: {
          'type': 'booking_modified',
          'bookingId': bookingId,
          'providerId': providerId,
          'customerId': customerName,
        },
      );

      print('✅ تم إرسال إشعار التعديل للمزود');
    } catch (e) {
      print('❌ خطأ في إرسال إشعار التعديل: $e');
    }
  }

  /// إرسال إشعار إلى مستخدم (عميل) وفق userId
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // جلب fcmToken من users
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      String? token = userDoc.data()?['fcmToken'] as String?;

      // في بعض الحالات يُخزن المستخدم بمعرف الهاتف
      if (token == null || token.isEmpty) {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: userId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          token = q.docs.first.data()['fcmToken'] as String?;
        }
      }

      if (token != null && token.isNotEmpty) {
        await _sendNotificationToToken(
          token: token,
          title: title,
          body: body,
          data: data,
        );
      } else {
        // لا يوجد توكن؛ عرض إشعار محلي كحل بديل إن كان التطبيق مفتوحاً
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
              'user_notifications',
              'إشعارات المستخدم',
              channelDescription: 'إشعارات للحالات والتحديثات',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            );
        const NotificationDetails details = NotificationDetails(
          android: androidDetails,
        );
        await _flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch % 100000,
          title,
          body,
          details,
          payload: data?.toString(),
        );
      }
    } catch (e) {
      print('❌ خطأ في إرسال إشعار للمستخدم: $e');
    }
  }

  /// تنسيق التاريخ بالعربية
  String _formatDate(DateTime date) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'إبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
