import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/price_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/calendar_service.dart';
import '../services/booking_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;
  final bool isEditMode;
  final String? editOrderId;
  final String? orderId;
  final DateTime? existingScheduledAt;
  final bool? existingIsFullDayBooking;
  final TimeSlot? existingTimeSlot;
  final String? existingNotes;
  final String? existingItemPrice;

  const BookingScreen({
    super.key,
    required this.serviceData,
    this.isEditMode = false,
    this.editOrderId,
    this.orderId,
    this.existingScheduledAt,
    this.existingIsFullDayBooking,
    this.existingTimeSlot,
    this.existingNotes,
    this.existingItemPrice,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  bool isLoading = false;
  File? receiptImage;
  String? receiptUrl;
  final picker = ImagePicker();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  double? _deliveryLat;
  double? _deliveryLng;

  // بيانات المزود والعنصر
  String providerName = '';
  String itemName = '';
  String itemPrice = '';
  String userCreditCard = '';
  String userGovernorate = '';
  String userArea = '';
  String userDisplayName = '';
  String providerCreditCard = '';

  // التقويم والحجوزات
  final CalendarService _calendarService = CalendarService();
  final BookingService _bookingService = BookingService();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, DayStatus> _dayStatusMap = {};
  List<TimeSlot> _bookedTimeSlotsForSelectedDay = [];
  bool _isFullDayBooking = true;
  bool isDateTimeConflict = false;

  // معرف الحجز المرتبط (في وضع التعديل) - يُستثنى من فحص التضارب
  String? _linkedBookingId;

  // subscriptions لإدارتها وإلغائها بشكل صحيح
  StreamSubscription? _calendarSub;
  StreamSubscription? _slotsSub;

  // حساب السعر النهائي للتصوير بناءً على عدد الساعات
  double _calculateFinalPrice() {
    // التحقق من نوع الخدمة
    final category = widget.serviceData['category'] ?? '';

    // فقط للتصوير نحسب حسب الساعات
    if (category != 'photography') {
      // للخدمات الأخرى، نرجع السعر الأساسي
      return _extractPriceValue(itemPrice);
    }

    // للتصوير: إذا كان حجز كامل اليوم، السعر الأساسي
    if (_isFullDayBooking) {
      return _extractPriceValue(itemPrice);
    }

    // إذا كان حجز جزئي، احسب عدد الساعات
    if (selectedStartTime != null && selectedEndTime != null) {
      final startMinutes =
          selectedStartTime!.hour * 60 + selectedStartTime!.minute;
      final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;
      final durationMinutes = endMinutes - startMinutes;
      final hours = durationMinutes / 60.0;

      // السعر الأساسي للساعة الواحدة
      final pricePerHour = _extractPriceValue(itemPrice);

      // السعر النهائي = عدد الساعات × سعر الساعة
      return hours * pricePerHour;
    }

    return _extractPriceValue(itemPrice);
  }

  // استخراج القيمة العددية من السعر
  double _extractPriceValue(String priceString) {
    if (priceString.isEmpty) return 0.0;

    // إزالة "د.ع" والمسافات
    String cleanPrice = priceString
        .replaceAll('د.ع', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    // محاولة التحويل إلى رقم
    try {
      return double.parse(cleanPrice);
    } catch (e) {
      return 0.0;
    }
  }

  // تنسيق السعر للعرض
  String _formatPrice(double price) {
    // تنسيق بالألوف مع فواصل
    return PriceFormatter.formatNum(price);
  }

  // الحصول على عدد الساعات المحجوزة
  double _getBookedHours() {
    if (selectedStartTime == null || selectedEndTime == null) return 0.0;

    final startMinutes =
        selectedStartTime!.hour * 60 + selectedStartTime!.minute;
    final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;
    final durationMinutes = endMinutes - startMinutes;

    return durationMinutes / 60.0;
  }

  // التحقق من نوع الخدمة
  bool get _isBookableService {
    final candidates =
        [
              widget.serviceData['serviceType'],
              widget.serviceData['category'],
              widget.serviceData['serviceName'],
              widget.serviceData['categoryArabic'],
            ]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .map((e) => e.toString().trim())
            .toList();

    for (final c in candidates) {
      final canonical = _canonicalServiceType(c);
      if (isBookableCategory(canonical)) return true;
    }
    return false;
  }

  // تطبيع نوع الخدمة إلى قيمة قياسية تستخدمها قائمة الحجز
  String _canonicalServiceType(String value) {
    final v = value.toLowerCase();
    if (v.isEmpty) return v;
    if (v.contains('قاع') || v.contains('hall')) return 'hall';
    if (v.contains('فند') || v.contains('فناد') || v.contains('hotel')) {
      return 'hotel';
    }
    if (v.contains('صال') ||
        v.contains('عناي') ||
        v.contains('تجميل') ||
        v.contains('مكياج') ||
        v.contains('salon') ||
        v.contains('care')) {
      return 'salon_care';
    }
    if ((v.contains('سيار') ||
            v.contains('تأجير') ||
            v.contains('تاجير') ||
            v.contains('car')) &&
        !v.contains('تزيين') &&
        !v.contains('decoration')) {
      return 'car';
    }
    if (v.contains('تصوير') ||
        v.contains('فيديو') ||
        v.contains('photo') ||
        v.contains('كام')) {
      return 'photography';
    }
    if (v.contains('مطع') || v.contains('rest')) return 'restaurant';
    if (v.contains('فست') || v.contains('dress')) return 'bride_dress';
    if (v.contains('بدل') || v.contains('suit')) return 'groom_suit';
    if (v.contains('تزيين') || v.contains('decoration')) {
      return 'car_decoration';
    }
    if (v.contains('كيك') || v.contains('cake')) return 'cake';
    if (v.contains('ورد') ||
        v.contains('flower') ||
        v.contains('bouq') ||
        v.contains('بوكيه')) {
      return 'flowers';
    }
    if (v.contains('شهر') || v.contains('honeymoon') || v.contains('عسل')) {
      return 'honeymoon';
    }
    return value; // إرجاع الأصل إذا لم يتم التطابق
  }

  @override
  void initState() {
    super.initState();

    _loadUserData();
    _loadProviderData();

    if (widget.isEditMode) {
      selectedDate = widget.existingScheduledAt;
      _isFullDayBooking = widget.existingIsFullDayBooking ?? true;
      if (widget.existingTimeSlot != null) {
        final partsStart = widget.existingTimeSlot!.startTime.split(':');
        final partsEnd = widget.existingTimeSlot!.endTime.split(':');
        selectedStartTime = TimeOfDay(
          hour: int.tryParse(partsStart[0]) ?? 0,
          minute: int.tryParse(partsStart[1]) ?? 0,
        );
        selectedEndTime = TimeOfDay(
          hour: int.tryParse(partsEnd[0]) ?? 0,
          minute: int.tryParse(partsEnd[1]) ?? 0,
        );
      }
      if (widget.existingNotes != null) {
        _detailsController.text = widget.existingNotes!;
      }
      // تحميل bookingId المرتبط لاستثنائه من فحص التضارب
      if (widget.editOrderId != null) {
        _loadLinkedBookingId(widget.editOrderId!);
      }
    }

    // الاستماع لتحديثات الحجوزات فقط للخدمات القابلة للحجز
    if (_isBookableService) {
      _listenToBookingUpdates();
    }
  }

  @override
  void dispose() {
    _calendarSub?.cancel();
    _slotsSub?.cancel();
    _detailsController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  /// تحميل معرف الحجز المرتبط بالطلب (في وضع التعديل)
  Future<void> _loadLinkedBookingId(String orderId) async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      final data = orderDoc.data();
      String? bookingId = data?['bookingId']?.toString();

      if (bookingId == null || bookingId.isEmpty) {
        // Fallback: البحث في bookings عبر orderId
        final q = await FirebaseFirestore.instance
            .collection('bookings')
            .where('orderId', isEqualTo: orderId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) bookingId = q.docs.first.id;
      }

      if (bookingId != null && mounted) {
        setState(() => _linkedBookingId = bookingId);
        // إعادة تهيئة الـ stream بعد معرفة الـ bookingId
        if (_isBookableService) _listenToBookingUpdates();
      }
    } catch (e) {
      print('⚠️ لم يتم تحميل linkedBookingId: $e');
    }
  }

  /// الاستماع لتحديثات الحجوزات في الوقت الفعلي
  void _listenToBookingUpdates() {
    final itemId = widget.serviceData['id'] ?? '';
    if (itemId.isEmpty) return;

    // إلغاء الاستماعات السابقة
    _calendarSub?.cancel();
    _slotsSub?.cancel();

    // الاستماع لحالة الأيام في الشهر الحالي
    _calendarSub = _calendarService
        .getMonthlyBookingStatus(
          itemId: itemId,
          month: _focusedDay,
          excludeBookingId: _linkedBookingId,
        )
        .handleError((e) => print('❌ خطأ في stream التقويم: $e'))
        .listen((statusMap) {
          if (mounted) setState(() => _dayStatusMap = statusMap);
        });

    // الاستماع للأوقات المحجوزة في اليوم المحدد
    if (selectedDate != null) {
      _slotsSub = _calendarService
          .getBookedTimeSlotsForDay(
            itemId: itemId,
            date: selectedDate!,
            excludeBookingId: _linkedBookingId,
          )
          .handleError((e) => print('❌ خطأ في stream الأوقات: $e'))
          .listen((slots) {
            if (mounted) setState(() => _bookedTimeSlotsForSelectedDay = slots);
          });
    }
  }

  /// تحديث الاستماع عند تغيير الشهر
  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
    });
    _listenToBookingUpdates();
  }

  /// تحديث الاستماع عند اختيار يوم
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(selectedDate, selectedDay)) {
      setState(() {
        selectedDate = selectedDay;
        _focusedDay = focusedDay;
        selectedStartTime = null;
        selectedEndTime = null;
      });

      // الاستماع للأوقات المحجوزة في اليوم الجديد
      final itemId = widget.serviceData['id'] ?? '';
      _slotsSub?.cancel();
      _slotsSub = _calendarService
          .getBookedTimeSlotsForDay(
            itemId: itemId,
            date: selectedDay,
            excludeBookingId: _linkedBookingId,
          )
          .listen((slots) {
            if (mounted) setState(() => _bookedTimeSlotsForSelectedDay = slots);
          });

      // عرض الأوقات المحجوزة إذا كان اليوم محجوز جزئياً
      final dayStatus =
          _dayStatusMap[DateTime(
            selectedDay.year,
            selectedDay.month,
            selectedDay.day,
          )];
      if (dayStatus == DayStatus.partiallyBooked) {
        _showBookedTimeSlotsDialog(selectedDay);
      } else if (dayStatus == DayStatus.fullyBooked) {
        _showFullyBookedDialog();
      }
    }
  }

  /// عرض نافذة الأوقات المحجوزة
  void _showBookedTimeSlotsDialog(DateTime day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'حجز جزئي',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy', 'ar').format(day),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الأوقات المحجوزة:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            if (_bookedTimeSlotsForSelectedDay.isEmpty)
              const Text('لا توجد أوقات محجوزة')
            else
              ..._bookedTimeSlotsForSelectedDay.map((slot) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'من ${slot.startTime} إلى ${slot.endTime}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'يمكنك اختيار وقت آخر لا يتعارض مع الأوقات المحجوزة',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض نافذة اليوم محجوز بالكامل
  void _showFullyBookedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.block, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text(
              'محجوز بالكامل',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: const Text(
          'هذا اليوم محجوز بالكامل. يرجى اختيار تاريخ آخر.',
          style: TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// إعادة تحميل بيانات التقويم بعد الحجز
  Future<void> _refreshCalendarData() async {
    final itemId = widget.serviceData['id'] ?? '';
    if (itemId.isEmpty) return;

    try {
      setState(() => _dayStatusMap = {});
      _listenToBookingUpdates();
      print('✅ تم تحديث بيانات التقويم بعد الحجز');
    } catch (e) {
      print('❌ خطأ في تحديث بيانات التقويم: $e');
    }
  }

  /// إعادة ضبط نموذج الحجز للحجز التالي
  void _resetBookingForm() {
    setState(() {
      selectedDate = null;
      selectedStartTime = null;
      selectedEndTime = null;
      receiptImage = null;
      _isFullDayBooking = true;
      isDateTimeConflict = false;
      _detailsController.clear();
      itemPrice = '';
    });

    print('✅ تم إعادة ضبط نموذج الحجز');
  }

  // تحميل بيانات المستخدم
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPhone = prefs.getString('user_phone') ?? '';

      if (userPhone.isNotEmpty) {
        // البحث في users أولاً باستخدام document ID
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userPhone)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            userCreditCard = userData['creditCard'] ?? 'غير محدد';
            userGovernorate = userData['governorate']?.toString() ?? '';
            userArea = userData['area']?.toString() ?? '';
            userDisplayName = userData['name']?.toString() ?? '';
          });
          return;
        }

        // إذا لم يوجد في users، ابحث باستخدام phone field
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: userPhone)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          setState(() {
            userCreditCard = userData['creditCard'] ?? 'غير محدد';
            userGovernorate = userData['governorate']?.toString() ?? '';
            userArea = userData['area']?.toString() ?? '';
            userDisplayName = userData['name']?.toString() ?? '';
          });
          return;
        }

        // البحث في customers كبديل
        final customerQuery = await FirebaseFirestore.instance
            .collection('customers')
            .where('phone', isEqualTo: userPhone)
            .limit(1)
            .get();

        if (customerQuery.docs.isNotEmpty) {
          final customerData = customerQuery.docs.first.data();
          setState(() {
            userCreditCard = customerData['creditCard'] ?? 'غير محدد';
            userGovernorate = customerData['governorate']?.toString() ?? '';
            userArea = customerData['area']?.toString() ?? '';
            userDisplayName = customerData['name']?.toString() ?? '';
          });
          return;
        }

        // إذا لم يوجد في أي مكان
        setState(() {
          userCreditCard = 'غير متوفر';
        });
      }
    } catch (e) {
      print('خطأ في تحميل بيانات المستخدم: $e');
      setState(() {
        userCreditCard = 'خطأ في التحميل';
        userGovernorate = '';
        userArea = '';
        userDisplayName = '';
      });
    }
  }

  // تحميل بيانات مزود الخدمة
  Future<void> _loadProviderData() async {
    try {
      setState(() {
        // استخراج اسم العنصر
        itemName =
            widget.serviceData['name'] ??
            widget.serviceData['itemName'] ??
            widget.serviceData['serviceName'] ??
            'العنصر';

        // استخراج السعر
        var priceValue =
            widget.serviceData['price'] ??
            widget.serviceData['basePrice'] ??
            widget.serviceData['hallData']?['basePrice'] ??
            widget.serviceData['hallData']?['price'] ??
            widget.existingItemPrice;

        if (priceValue != null) {
          itemPrice = priceValue.toString();
          // إضافة العملة إذا لم تكن موجودة
          if (!itemPrice.contains('د.ع')) {
            itemPrice += ' د.ع';
          }
        } else {
          itemPrice = 'يحدد لاحقاً';
        }
      });

      // تحميل اسم المزود الحقيقي من قاعدة البيانات
      await _loadRealProviderName();

      // تحميل رقم بطاقة الائتمان لمزود الخدمة
      await _loadProviderCreditCard();
    } catch (e) {
      print('خطأ في تحميل بيانات المزود: $e');
      setState(() {
        providerName = 'مزود الخدمة';
        itemName = 'العنصر';
        itemPrice = 'غير محدد';
      });
    }
  }

  // تحميل اسم المزود الحقيقي من قاعدة البيانات
  Future<void> _loadRealProviderName() async {
    try {
      final providerId =
          widget.serviceData['providerId'] ??
          widget.serviceData['providerPhone'] ??
          widget.serviceData['provider_id'];

      if (providerId != null) {
        // البحث في users أولاً
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId.toString())
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            providerName =
                userData['name'] ?? userData['fullName'] ?? 'مزود الخدمة';
          });
          return;
        }

        // البحث باستخدام phone field
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: providerId.toString())
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          setState(() {
            providerName =
                userData['name'] ?? userData['fullName'] ?? 'مزود الخدمة';
          });
          return;
        }

        // البحث في providers
        final providerQuery = await FirebaseFirestore.instance
            .collection('providers')
            .where('phone', isEqualTo: providerId.toString())
            .limit(1)
            .get();

        if (providerQuery.docs.isNotEmpty) {
          final providerData = providerQuery.docs.first.data();
          setState(() {
            providerName =
                providerData['name'] ??
                providerData['fullName'] ??
                'مزود الخدمة';
          });
          return;
        }
      }

      // إذا لم نجد اسم المزود، استخدم القيمة الافتراضية
      setState(() {
        providerName =
            widget.serviceData['providerName'] ??
            widget.serviceData['provider_name'] ??
            'مزود الخدمة';
      });
    } catch (e) {
      print('خطأ في تحميل اسم المزود: $e');
      setState(() {
        providerName = 'مزود الخدمة';
      });
    }
  }

  // تحميل رقم بطاقة الائتمان لمزود الخدمة
  Future<void> _loadProviderCreditCard() async {
    try {
      final providerId =
          widget.serviceData['providerId'] ??
          widget.serviceData['providerPhone'] ??
          widget.serviceData['provider_id'];

      if (providerId != null) {
        // البحث في users أولاً
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId.toString())
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final creditCard = userData['creditCard'];
          if (creditCard != null &&
              creditCard.toString().isNotEmpty &&
              creditCard != 'غير محدد') {
            setState(() {
              providerCreditCard = creditCard.toString();
            });
            return;
          }
        }

        // البحث باستخدام phone field
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: providerId.toString())
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          final creditCard = userData['creditCard'];
          if (creditCard != null &&
              creditCard.toString().isNotEmpty &&
              creditCard != 'غير محدد') {
            setState(() {
              providerCreditCard = creditCard.toString();
            });
            return;
          }
        }

        // البحث في providers
        final providerQuery = await FirebaseFirestore.instance
            .collection('providers')
            .where('phone', isEqualTo: providerId.toString())
            .limit(1)
            .get();

        if (providerQuery.docs.isNotEmpty) {
          final providerData = providerQuery.docs.first.data();
          final creditCard = providerData['creditCard'];
          if (creditCard != null &&
              creditCard.toString().isNotEmpty &&
              creditCard != 'غير محدد') {
            setState(() {
              providerCreditCard = creditCard.toString();
            });
            return;
          }
        }

        // البحث في provider_requests كمحاولة أخيرة
        final requestQuery = await FirebaseFirestore.instance
            .collection('provider_requests')
            .where('providerId', isEqualTo: providerId.toString())
            .limit(1)
            .get();

        if (requestQuery.docs.isNotEmpty) {
          final requestData = requestQuery.docs.first.data();
          final creditCard = requestData['creditCard'];
          if (creditCard != null &&
              creditCard.toString().isNotEmpty &&
              creditCard != 'غير محدد') {
            setState(() {
              providerCreditCard = creditCard.toString();
            });
            return;
          }
        }

        // البحث بالهاتف في provider_requests
        final phoneQuery = await FirebaseFirestore.instance
            .collection('provider_requests')
            .where('providerPhone', isEqualTo: providerId.toString())
            .limit(1)
            .get();

        if (phoneQuery.docs.isNotEmpty) {
          final phoneData = phoneQuery.docs.first.data();
          final creditCard = phoneData['creditCard'];
          if (creditCard != null &&
              creditCard.toString().isNotEmpty &&
              creditCard != 'غير محدد') {
            setState(() {
              providerCreditCard = creditCard.toString();
            });
            return;
          }
        }

        // محاولة خاصة للمزود 077777
        if (providerId.toString() == '077777') {
          // البحث في كامل مجموعة provider_requests
          final allRequestsQuery = await FirebaseFirestore.instance
              .collection('provider_requests')
              .get();

          for (var doc in allRequestsQuery.docs) {
            final data = doc.data();
            if (data['providerId'] == '077777' ||
                data['providerPhone'] == '077777') {
              setState(() {
                providerCreditCard = data['creditCard'] ?? 'غير محدد';
              });
              return;
            }
          }
        }

        // إذا لم يوجد في أي مكان
        setState(() {
          providerCreditCard = 'غير متوفر';
        });
      }
    } catch (e) {
      print('خطأ في تحميل رقم بطاقة المزود: $e');
      setState(() {
        providerCreditCard = 'خطأ في التحميل';
      });
    }
  }

  /// اختيار وقت البدء
  Future<void> _selectStartTime(BuildContext context) async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار التاريخ أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime ?? TimeOfDay.now(),
      helpText: 'اختر وقت البدء',
    );

    if (picked != null) {
      setState(() {
        selectedStartTime = picked;
        // إعادة تعيين وقت النهاية إذا كان أقل من وقت البدء
        if (selectedEndTime != null) {
          final startMinutes = picked.hour * 60 + picked.minute;
          final endMinutes =
              selectedEndTime!.hour * 60 + selectedEndTime!.minute;
          if (endMinutes <= startMinutes) {
            selectedEndTime = null;
          }
        }
      });
      _checkTimeConflict();
    }
  }

  /// اختيار وقت النهاية
  Future<void> _selectEndTime(BuildContext context) async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار التاريخ أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار وقت البدء أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          selectedEndTime ??
          TimeOfDay(
            hour: (selectedStartTime!.hour + 1) % 24,
            minute: selectedStartTime!.minute,
          ),
      helpText: 'اختر وقت النهاية',
    );

    if (picked != null) {
      // التحقق من أن وقت النهاية بعد وقت البدء
      final startMinutes =
          selectedStartTime!.hour * 60 + selectedStartTime!.minute;
      final endMinutes = picked.hour * 60 + picked.minute;

      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('وقت النهاية يجب أن يكون بعد وقت البدء'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        selectedEndTime = picked;
      });
      _checkTimeConflict();
    }
  }

  /// التحقق من تضارب الأوقات
  Future<void> _checkTimeConflict() async {
    if (selectedDate == null || _isFullDayBooking) {
      setState(() {
        isDateTimeConflict = false;
      });
      return;
    }

    if (selectedStartTime == null || selectedEndTime == null) {
      setState(() {
        isDateTimeConflict = false;
      });
      return;
    }

    // التحقق من itemId
    final itemId = widget.serviceData['id'] ?? '';
    if (itemId.isEmpty) {
      print('⚠️ لا يوجد itemId في serviceData');
      setState(() {
        isDateTimeConflict = true; // منع الحجز للأمان
      });
      return;
    }

    print('🔍 التحقق من التضارب للعنصر: $itemId');

    // التحقق من أن وقت البدء < وقت النهاية
    final startMinutes =
        selectedStartTime!.hour * 60 + selectedStartTime!.minute;
    final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;

    if (startMinutes >= endMinutes) {
      print('❌ وقت البدء >= وقت النهاية');
      setState(() {
        isDateTimeConflict = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('وقت البدء يجب أن يكون أقل من وقت النهاية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newSlot = TimeSlot(
      startTime:
          '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}',
      endTime:
          '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}',
    );

    print('🕐 الوقت المطلوب: ${newSlot.startTime} - ${newSlot.endTime}');

    final canBookResult = await _calendarService.canBook(
      itemId: itemId,
      date: selectedDate!,
      timeSlot: newSlot,
      excludeBookingId: _linkedBookingId,
    );

    print('📋 نتيجة التحقق: $canBookResult');

    setState(() {
      isDateTimeConflict = !canBookResult;
    });

    if (!canBookResult) {
      print('❌ تم اكتشاف تضارب في الوقت');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الوقت يتعارض مع حجز موجود'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      print('✅ لا يوجد تضارب، يمكن الحجز');
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null) {
        setState(() {
          receiptImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في اختيار الصورة: $e')));
    }
  }

  Future<String?> _uploadReceiptImage() async {
    if (receiptImage == null) return null;
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child('receipts/$fileName');
      final uploadTask = ref.putFile(receiptImage!);
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      // تحرير الملف المؤقت بعد الرفع
      try {
        await receiptImage!.delete();
      } catch (e) {
        print('لا يمكن حذف الملف المؤقت: $e');
      }

      return url;
    } catch (e) {
      throw Exception('فشل في رفع صورة الإيصال: $e');
    }
  }

  Future<void> _bookService() async {
    // التحقق مما إذا كان المستخدم ضيفاً
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user_phone');
    if (userPhone == 'guest') {
      _showErrorDialog(
        'عملية غير متاحة للضيوف',
        'لا يمكن تثبيت حجز بدون تسجيل حساب.\n\nيرجى إنشاء حساب للمتابعة.',
      );
      return;
    }

    // التحقق من وجود itemId
    final itemId = widget.serviceData['id'] ?? '';
    if (itemId.isEmpty) {
      _showErrorDialog(
        'خطأ في البيانات',
        'معرف الخدمة غير صحيح. يرجى المحاولة مرة أخرى.',
      );
      return;
    }

    // التحقق من الحقول المطلوبة
    // للخدمات القابلة للحجز فقط (التي لديها تقويم): يجب اختيار تاريخ
    // للخدمات الأخرى: نستخدم التاريخ الحالي تلقائياً
    if (_isBookableService && selectedDate == null) {
      _showErrorDialog('بيانات ناقصة', 'يرجى اختيار التاريخ للحجز');
      return;
    }

    // إذا كانت الخدمة غير قابلة للحجز وليس هناك تاريخ محدد، نستخدم التاريخ الحالي
    final DateTime bookingDate;
    if (!_isBookableService && selectedDate == null) {
      bookingDate = DateTime.now();
    } else {
      bookingDate = selectedDate!;
    }

    // التحقق من عدم الحجز في الماضي (للخدمات القابلة للحجز فقط)
    if (_isBookableService) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final selectedDateOnly = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
      );

      if (selectedDateOnly.isBefore(todayDate)) {
        _showErrorDialog(
          'تاريخ غير صالح',
          'لا يمكن الحجز في تاريخ سابق. يرجى اختيار تاريخ اليوم أو تاريخ مستقبلي.',
        );
        return;
      }
    }

    // التحقق من الأوقات في حالة الحجز الجزئي
    if (!_isFullDayBooking &&
        (selectedStartTime == null || selectedEndTime == null)) {
      _showErrorDialog(
        'بيانات ناقصة',
        'يرجى اختيار وقت البدء والنهاية للحجز الجزئي',
      );
      return;
    }

    // التحقق من أن وقت البدء أقل من وقت النهاية
    if (!_isFullDayBooking &&
        selectedStartTime != null &&
        selectedEndTime != null) {
      final startMinutes =
          selectedStartTime!.hour * 60 + selectedStartTime!.minute;
      final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;

      if (startMinutes >= endMinutes) {
        _showErrorDialog(
          'خطأ في الأوقات',
          'وقت البدء يجب أن يكون أقل من وقت النهاية',
        );
        return;
      }
    }

    // في وضع التعديل لا نشترط رفع إيصال جديد (الإيصال الأصلي محفوظ مسبقاً)
    if (receiptImage == null && !widget.isEditMode) {
      _showErrorDialog(
        'إيصال الدفع مطلوب',
        'يرجى رفع صورة إيصال الدفع لتأكيد الحجز',
      );
      return;
    }

    // التحقق من التضارب في الوقت
    if (isDateTimeConflict) {
      _showErrorDialog(
        'تضارب في الموعد',
        'هذا التاريخ أو الوقت محجوز مسبقاً. يرجى اختيار موعد آخر.',
      );
      return;
    }

    // إعداد timeSlot و dayStatus للاستخدام في كلا الوضعين
    TimeSlot? timeSlot;
    DayStatus dayStatus = DayStatus.fullyBooked;
    if (!_isFullDayBooking &&
        selectedStartTime != null &&
        selectedEndTime != null) {
      timeSlot = TimeSlot(
        startTime:
            '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}',
        endTime:
            '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}',
      );
      dayStatus = DayStatus.partiallyBooked;
    }

    // في وضع التعديل: تحديث الطلب الحالي بدون إنشاء حجز جديد
    if (widget.isEditMode && widget.editOrderId != null) {
      setState(() => isLoading = true);
      try {
        String orderId = widget.editOrderId!;

        // نحتفظ بتاريخ الحجز الأصلي إذا كان موجودًا من التعديل السابق، وإلا نستخدم قيم الحجز الحالية
        final existingOrderDoc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();
        final existingData = existingOrderDoc.data() as Map<String, dynamic>?;
        final originalDateTimestamp =
            existingData?['originalDate'] as Timestamp?;
        final originalTimeSlotMap =
            existingData?['originalTimeSlot'] as Map<String, dynamic>?;

        final originalDate = originalDateTimestamp != null
            ? originalDateTimestamp.toDate()
            : widget.existingScheduledAt;
        final originalTimeSlot = originalTimeSlotMap != null
            ? TimeSlot.fromMap(originalTimeSlotMap)
            : widget.existingTimeSlot;

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .update({
              'scheduledAt': Timestamp.fromDate(bookingDate),
              'isFullDayBooking': _isFullDayBooking,
              'timeSlot': (_isFullDayBooking || timeSlot == null)
                  ? null
                  : timeSlot.toMap(),
              'notes': _detailsController.text.trim(),
              'status': 'modified',
              'isModified': true,
              'originalDate': originalDate != null
                  ? Timestamp.fromDate(originalDate)
                  : null,
              'originalTimeSlot': originalTimeSlot?.toMap(),
              'modifiedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        String? linkedBookingId = existingData?['bookingId']?.toString();

        if (linkedBookingId == null || linkedBookingId.isEmpty) {
          // لو لم يوجد bookingId في الطلب، نجرب إيجاد الحجز المرتبط عبر orderId في مجموعة bookings
          final fallbackQuery = await FirebaseFirestore.instance
              .collection('bookings')
              .where('orderId', isEqualTo: orderId)
              .limit(1)
              .get();

          if (fallbackQuery.docs.isNotEmpty) {
            linkedBookingId = fallbackQuery.docs.first.id;
          }
        }

        if (linkedBookingId != null && linkedBookingId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(linkedBookingId)
              .update({
                'bookingDate': Timestamp.fromDate(bookingDate),
                'dayStatus': dayStatus.toString().split('.').last,
                'timeSlot': (_isFullDayBooking || timeSlot == null)
                    ? null
                    : timeSlot.toMap(),
                'notes': _detailsController.text.trim(),
                'status': 'modified',
                'isModified': true,
                'originalDate': originalDate != null
                    ? Timestamp.fromDate(originalDate)
                    : null,
                'originalTimeSlot': originalTimeSlot?.toMap(),
                'modifiedAt': FieldValue.serverTimestamp(),
                'orderId': orderId,
              });
        }

        setState(() => isLoading = false);
        _showSuccessDialog(isEditMode: true);
      } catch (e) {
        setState(() => isLoading = false);
        _showErrorDialog(
          'خطأ في تعديل الحجز',
          'حدث خطأ أثناء تعديل الحجز. حاول ثانية.\nالخطأ: $e',
        );
      }
      return;
    }

    setState(() => isLoading = true);

    try {
      // الحصول على رقم هاتف المستخدم الحالي
      final prefs = await SharedPreferences.getInstance();
      final currentUserPhone = prefs.getString('user_phone') ?? '';
      final currentUserName = (userDisplayName.isNotEmpty)
          ? userDisplayName
          : (prefs.getString('user_name') ?? 'مستخدم');

      // رفع صورة الإيصال
      final receiptUrl = await _uploadReceiptImage();

      // إنشاء نموذج الحجز
      final booking = BookingModel(
        itemId: widget.serviceData['id'] ?? '',
        itemName: itemName,
        providerId:
            widget.serviceData['providerId'] ??
            widget.serviceData['providerPhone'] ??
            '',
        providerName: providerName,
        customerId: currentUserPhone,
        customerName: currentUserName,
        customerPhone: currentUserPhone,
        category: widget.serviceData['serviceType'] ?? '',
        bookingDate: bookingDate,
        dayStatus: dayStatus,
        timeSlot: timeSlot,
        notes: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
      );

      // تحقق نهائي من إمكانية الحجز قبل الحجز (لمنع race conditions)
      // فقط للخدمات القابلة للحجز
      if (_isBookableService) {
        final canBookCheck = await _calendarService.canBook(
          itemId: widget.serviceData['id'] ?? '',
          date: bookingDate,
          timeSlot: timeSlot,
          excludeBookingId: _linkedBookingId,
        );

        if (!canBookCheck) {
          setState(() => isLoading = false);
          if (mounted) {
            _showErrorDialog(
              'تعذر إتمام الحجز',
              'عذراً، هذا التاريخ/الوقت تم حجزه من مستخدم آخر. يرجى اختيار تاريخ آخر.',
            );
            // تحديث حالة التقويم
            await _refreshCalendarData();
          }
          return;
        }
      }

      // استخدام BookingService للحجز مع التحقق من التعارض
      // للخدمات غير القابلة للحجز: نتخطى فحص التعارض لأن عدة زبائن يمكنهم حجز نفس العنصر
      final bookingId = await _bookingService.createBooking(
        booking,
        skipConflictCheck: !_isBookableService,
      );

      // حساب السعر النهائي
      final finalPrice = _calculateFinalPrice();
      final finalPriceString = '${_formatPrice(finalPrice)} د.ع';

      // إضافة receiptUrl وstatus وprice للحجز
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'receiptUrl': receiptUrl,
            'status': 'pending',
            'price': finalPriceString,
            'basePrice': itemPrice, // السعر الأساسي
            'hoursBooked':
                widget.serviceData['category'] == 'photography' &&
                    !_isFullDayBooking
                ? _getBookedHours()
                : null, // عدد الساعات للتصوير فقط
            // معلومات موقع الزبون لعرضها للمزود
            'customerGovernorate': userGovernorate,
            'customerArea': userArea,
            'orderId': widget.orderId ?? '',
            // حفظ providerPhone لتسهيل الفلترة في شاشة المزود
            'providerPhone':
                widget.serviceData['providerPhone'] ??
                widget.serviceData['providerId'] ??
                '',
            // معلومات التوصيل
            'deliveryAddress': _deliveryAddressController.text.trim().isEmpty
                ? null
                : _deliveryAddressController.text.trim(),
            'deliveryLat': _deliveryLat,
            'deliveryLng': _deliveryLng,
          });

      // ربط الحجز بالطلب (إذا كان هناك طلب مرتبط)
      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .update({'bookingId': bookingId});
      }

      setState(() => isLoading = false);

      // تحديث التقويم فوراً (فقط للخدمات القابلة للحجز)
      if (_isBookableService) {
        await _refreshCalendarData();

        // تحديث فوري لحالة اليوم المحجوز
        final normalizedDate = DateTime(
          bookingDate.year,
          bookingDate.month,
          bookingDate.day,
        );
        setState(() {
          if (_isFullDayBooking) {
            _dayStatusMap[normalizedDate] = DayStatus.fullyBooked;
          } else {
            // إذا كان هناك حجوزات أخرى، جعله جزئي، وإلا جزئي أيضاً
            _dayStatusMap[normalizedDate] = DayStatus.partiallyBooked;
          }
        });
      }

      // إظهار رسالة النجاح
      _showSuccessDialog();
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog(
        'خطأ في الحجز',
        'حدث خطأ أثناء تثبيت الحجز. يرجى المحاولة مرة أخرى.\nالخطأ: $e',
      );
    }
  }

  // إظهار رسالة خطأ
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // إظهار رسالة النجاح
  void _showSuccessDialog({bool isEditMode = false}) {
    final title = isEditMode
        ? 'تم تعديل الحجز بنجاح!'
        : 'تم تثبيت الحجز بنجاح!';
    final message = isEditMode
        ? 'تم تحديث بيانات الطلب وسيتم مراجعتها من قبل المزود.'
        : 'تم إرسال حجزك إلى مزود الخدمة وسيتم التواصل معك قريباً لتأكيد التفاصيل.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!isEditMode) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // إغلاق النافذة فقط
                    // إعادة ضبط النموذج للحجز التالي
                    _resetBookingForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'حجز آخر',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context); // إغلاق النافذة
                  if (isEditMode) {
                    Navigator.pop(
                      context,
                      true,
                    ); // إرجاع نتيجة التعديل للشاشة السابقة
                  }
                },
                child: const Text(
                  'العودة',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'تعديل الحجز' : 'تثبيت الحجز',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isBookableService
          ? _buildBookableServiceBody()
          : _buildNonBookableServiceBody(),
    );
  }

  /// بناء خلية التقويم مع النقطة أسفل الرقم
  Widget _buildDayCell(
    DateTime day, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final status = _dayStatusMap[normalizedDay];
    Color? dotColor;
    if (status == DayStatus.fullyBooked) {
      dotColor = Colors.red;
    } else if (status == DayStatus.partiallyBooked) {
      dotColor = Colors.orange;
    }

    BoxDecoration? circleDecoration;
    Color textColor = const Color(0xFF1F2937);

    if (isSelected) {
      circleDecoration = const BoxDecoration(
        color: Color(0xFF10B981),
        shape: BoxShape.circle,
      );
      textColor = Colors.white;
    } else if (isToday) {
      circleDecoration = BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.3),
        shape: BoxShape.circle,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: circleDecoration,
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        if (dotColor != null)
          Positioned(
            bottom: 2,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          ),
      ],
    );
  }

  // واجهة الخدمات القابلة للحجز (التقويم والمواعيد)
  Widget _buildBookableServiceBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات مزود الخدمة والعنصر
          _buildServiceInfoCard(),
          const SizedBox(height: 20),

          // اختيار التاريخ والوقت
          _buildDateTimeSelectionCard(),
          const SizedBox(height: 20),

          // معلومات الدفع
          _buildPaymentInfoCard(),
          const SizedBox(height: 20),

          // رفع إيصال الدفع
          _buildReceiptUploadCard(),
          const SizedBox(height: 20),

          // حقل تفاصيل الحجز (اختياري)
          _buildBookingDetailsCard(),
          const SizedBox(height: 30),

          // زر تثبيت الحجز
          _buildBookingButton(),
        ],
      ),
    );
  }

  // واجهة الخدمات غير القابلة للحجز (متوفر/غير متوفر)
  Widget _buildNonBookableServiceBody() {
    return StreamBuilder<bool>(
      stream: _bookingService.getItemAvailability(
        widget.serviceData['id'] ?? '',
      ),
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? true;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات مزود الخدمة والعنصر
              _buildServiceInfoCard(),
              const SizedBox(height: 20),

              // حالة التوفر
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAvailable
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAvailable ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAvailable ? 'متوفر للحجز' : 'غير متوفر حالياً',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAvailable
                                ? 'يمكنك التواصل مع مزود الخدمة لإتمام الحجز'
                                : 'هذا العنصر غير متوفر في الوقت الحالي. يرجى التحقق لاحقاً أو التواصل مع مزود الخدمة',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // معلومات الدفع
              _buildPaymentInfoCard(),
              const SizedBox(height: 20),

              if (isAvailable) ...[
                // حقل التوصيل إلى (قبل الإيصال ليراه الزبون أولاً)
                _buildDeliveryCard(),
                const SizedBox(height: 20),

                // رفع إيصال الدفع
                _buildReceiptUploadCard(),
                const SizedBox(height: 20),

                // حقل تفاصيل الحجز
                _buildBookingDetailsCard(),
                const SizedBox(height: 30),

                // زر تثبيت الحجز (نفس الزر للخدمات القابلة وغير القابلة للحجز)
                _buildBookingButton(),

                const SizedBox(height: 16),

                // زر التواصل مع المزود (اختياري)
                _buildContactProviderButton(),
              ] else ...[
                // رسالة توضيحية
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'لا يمكن حجز هذا العنصر في الوقت الحالي. يمكنك تصفح عناصر أخرى أو التواصل مع مزود الخدمة للاستفسار.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // زر التواصل مع مزود الخدمة
  Widget _buildContactProviderButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _contactProvider,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.chat, size: 24),
        label: const Text(
          'التواصل مع مزود الخدمة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // دالة التواصل مع المزود
  Future<void> _contactProvider() async {
    // هنا يمكن فتح المحادثة مع المزود أو رقم الهاتف
    final providerPhone =
        widget.serviceData['providerPhone'] ??
        widget.serviceData['providerId'] ??
        '';

    if (providerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن العثور على معلومات الاتصال بمزود الخدمة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // يمكن هنا فتح المحادثة أو الاتصال
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('التواصل مع مزود الخدمة'),
        content: Text('رقم الهاتف: $providerPhone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // كارت معلومات الخدمة
  Widget _buildServiceInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business,
                  color: Color(0xFF1E88E5),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات الخدمة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تفاصيل مزود الخدمة والعنصر',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('اسم العنصر', itemName, Icons.inventory_2),
          const SizedBox(height: 12),

          // عرض السعر مع تفاصيل الحساب للتصوير
          if (widget.serviceData['category'] == 'photography' &&
              !_isFullDayBooking &&
              selectedStartTime != null &&
              selectedEndTime != null) ...[
            // للتصوير: عرض تفصيلي للحساب
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calculate,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'تفاصيل السعر',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سعر الساعة الواحدة:',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      Text(
                        itemPrice,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'عدد الساعات المحجوزة:',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      Text(
                        '${_formatPrice(_getBookedHours())} ساعة',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'المبلغ الإجمالي:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        '${_formatPrice(_calculateFinalPrice())} د.ع',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // للخدمات الأخرى أو الحجز الكامل: عرض السعر العادي
            _buildInfoRow('السعر', itemPrice, Icons.attach_money),
          ],
        ],
      ),
    );
  }

  // كارت اختيار التاريخ والوقت
  Widget _buildDateTimeSelectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختيار التاريخ والوقت',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'حدد الوقت المناسب للحجز',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // حالة التعديل: عرض بيانات الحجز السابق مع التاريخ/الوقت/النوع
          if (widget.isEditMode && widget.existingScheduledAt != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEAC5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEBB447), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تفاصيل الحجز الأصلي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'التاريخ الأصلي: ${DateFormat('dd/MM/yyyy').format(widget.existingScheduledAt!)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'النوع الأصلي: ${widget.existingIsFullDayBooking == true ? 'يوم كامل' : 'فترة محددة'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (widget.existingIsFullDayBooking == false &&
                      widget.existingTimeSlot != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'الوقت الأصلي: ${widget.existingTimeSlot!.startTime} - ${widget.existingTimeSlot!.endTime}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'السعر الأساسي: ${widget.existingItemPrice ?? itemPrice}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // التقويم الملون
          TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDate, day),
            onDaySelected: _onDaySelected,
            onPageChanged: _onPageChanged,
            calendarFormat: CalendarFormat.month,
            locale: 'ar',
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: Color(0xFF10B981),
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: Color(0xFF10B981),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              todayTextStyle: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.bold,
              ),
              defaultTextStyle: const TextStyle(color: Color(0xFF1F2937)),
              weekendTextStyle: const TextStyle(color: Color(0xFF1F2937)),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, _) => _buildDayCell(day),
              todayBuilder: (ctx, day, _) => _buildDayCell(day, isToday: true),
              selectedBuilder: (ctx, day, _) =>
                  _buildDayCell(day, isSelected: true),
              outsideBuilder: (ctx, day, _) => _buildDayCell(day),
            ),
          ),

          const SizedBox(height: 20),

          // مفتاح الألوان
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('حجز جزئي', Colors.orange),
                _buildLegendItem('يوم كامل محجوز', Colors.red),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // نوع الحجز (كامل/جزئي)
          if (selectedDate != null) ...[
            const Text(
              'نوع الحجز:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildBookingTypeButton(
                    title: 'اليوم كامل',
                    icon: Icons.calendar_month,
                    isSelected: _isFullDayBooking,
                    onTap: () {
                      setState(() {
                        _isFullDayBooking = true;
                        selectedStartTime = null;
                        selectedEndTime = null;
                        isDateTimeConflict = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBookingTypeButton(
                    title: 'فترة محددة',
                    icon: Icons.access_time,
                    isSelected: !_isFullDayBooking,
                    onTap: () {
                      setState(() {
                        _isFullDayBooking = false;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // اختيار الأوقات (إذا كان الحجز جزئي)
          if (selectedDate != null && !_isFullDayBooking) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    title: 'وقت البدء',
                    value: selectedStartTime == null
                        ? 'اختر الوقت'
                        : '${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}',
                    icon: Icons.access_time,
                    onTap: () => _selectStartTime(context),
                    isSelected: selectedStartTime != null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeSelector(
                    title: 'وقت النهاية',
                    value: selectedEndTime == null
                        ? 'اختر الوقت'
                        : '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}',
                    icon: Icons.access_time_filled,
                    onTap: selectedStartTime == null
                        ? null
                        : () => _selectEndTime(context),
                    isSelected: selectedEndTime != null,
                    isDisabled: selectedStartTime == null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // تحذير التضارب
          if (isDateTimeConflict) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تضارب في الموعد',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'هذا الوقت يتعارض مع حجز موجود. يرجى اختيار وقت آخر.',
                          style: TextStyle(fontSize: 14, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// عنصر مفتاح الألوان
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  /// زر نوع الحجز
  Widget _buildBookingTypeButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withOpacity(0.1)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF10B981) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF10B981) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// محدد الوقت
  Widget _buildTimeSelector({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isSelected,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withOpacity(0.1)
              : isSelected
              ? const Color(0xFF10B981).withOpacity(0.1)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.3)
                : isSelected
                ? const Color(0xFF10B981)
                : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isDisabled
                      ? Colors.grey
                      : isSelected
                      ? const Color(0xFF10B981)
                      : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDisabled ? Colors.grey : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDisabled
                    ? Colors.grey
                    : isSelected
                    ? const Color(0xFF1F2937)
                    : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // كارت معلومات الدفع
  Widget _buildPaymentInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.credit_card,
                  color: Color(0xFF8B5CF6),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معلومات الدفع',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'بيانات الدفع المسجلة في حسابك',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            'رقم بطاقة الائتمان (مزود الخدمة)',
            providerCreditCard,
            Icons.credit_card,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'يرجى دفع العربون بواسطة تطبيق دفع خارجي',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // كارت رفع الإيصال
  Widget _buildReceiptUploadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B46C1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt,
                  color: Color(0xFF6B46C1),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إيصال الدفع',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ارفع صورة إيصال الدفع',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // عرض الصورة أو زر الاختيار
          if (receiptImage != null) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6B46C1).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(receiptImage!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // زر اختيار/تغيير الصورة
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _pickReceiptImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: receiptImage == null
                    ? const Color(0xFF6B46C1)
                    : Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: Icon(
                receiptImage == null ? Icons.upload_file : Icons.edit,
                size: 24,
              ),
              label: Text(
                receiptImage == null ? 'اختيار صورة الإيصال' : 'تغيير الصورة',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // كارت تفاصيل الحجز (اختياري)
  Widget _buildBookingDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notes,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفاصيل الحجز',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'أضف أي تفاصيل إضافية (اختياري)',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // حقل النص للتفاصيل
          TextField(
            controller: _detailsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'أضف أي ملاحظات أو تفاصيل إضافية للحجز...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  // كارت التوصيل إلى (للخدمات غير القابلة للحجز فقط)
  Widget _buildDeliveryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF6E1229).withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6E1229).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6E1229).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF6E1229),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التوصيل إلى',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'حدد مكان التوصيل (اختياري)',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _deliveryAddressController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'اكتب عنوان التوصيل أو الحي أو المنطقة...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF6E1229),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF6E1229),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final LatLng? picked = await Navigator.push<LatLng?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _DeliveryLocationPickerScreen(
                      initialLocation:
                          _deliveryLat != null && _deliveryLng != null
                          ? LatLng(_deliveryLat!, _deliveryLng!)
                          : const LatLng(33.3152, 44.3661),
                    ),
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _deliveryLat = picked.latitude;
                    _deliveryLng = picked.longitude;
                  });
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6E1229),
                side: const BorderSide(color: Color(0xFF6E1229)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _deliveryLat != null
                    ? Icons.edit_location_alt
                    : Icons.add_location_alt_outlined,
                size: 22,
              ),
              label: Text(
                _deliveryLat != null
                    ? 'تغيير موقع التوصيل على الخريطة'
                    : 'تحديد موقع التوصيل على الخريطة',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_deliveryLat != null && _deliveryLng != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'تم تحديد موقع التوصيل على الخريطة',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _deliveryLat = null;
                      _deliveryLng = null;
                    }),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // زر تثبيت الحجز
  Widget _buildBookingButton() {
    // للخدمات القابلة للحجز: يجب اختيار تاريخ
    // للخدمات غير القابلة للحجز: التاريخ اختياري (سيُستخدم التاريخ الحالي تلقائياً)
    bool canBook;
    if (_isBookableService) {
      // الخدمات القابلة للحجز تحتاج تاريخ محدد
      canBook =
          selectedDate != null && receiptImage != null && !isDateTimeConflict;
    } else {
      // الخدمات غير القابلة للحجز لا تحتاج تاريخ
      canBook = receiptImage != null;
    }

    // إذا كان الحجز جزئي، يجب تحديد الأوقات
    if (!_isFullDayBooking) {
      canBook = canBook && selectedStartTime != null && selectedEndTime != null;
    }

    // تحديد الرسائل التحذيرية
    List<String> warnings = [];

    // فقط الخدمات القابلة للحجز تحتاج تحذير التاريخ
    if (_isBookableService && selectedDate == null) {
      warnings.add('⚠️ يرجى اختيار تاريخ');
    }

    if (!_isFullDayBooking && selectedStartTime == null) {
      warnings.add('⚠️ يرجى اختيار وقت البدء');
    }
    if (!_isFullDayBooking && selectedEndTime == null) {
      warnings.add('⚠️ يرجى اختيار وقت النهاية');
    }
    if (receiptImage == null) warnings.add('⚠️ يرجى رفع إيصال الدفع');
    if (isDateTimeConflict) warnings.add('⚠️ يوجد تضارب في التاريخ/الوقت');
    if (itemPrice == '0 د.ع' || itemPrice == 'يحدد لاحقاً') {
      warnings.add('⚠️ السعر غير محدد، تواصل مع مزود الخدمة');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عرض التحذيرات إذا وجدت
        if (warnings.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'يرجى إكمال المتطلبات التالية:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // زر الحجز
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: canBook ? _bookService : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canBook ? const Color(0xFF10B981) : Colors.grey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: canBook ? 4 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(Icons.check_circle, size: 28),
                  const SizedBox(width: 12),
                ],
                Text(
                  isLoading
                      ? (widget.isEditMode
                            ? 'جارٍ حفظ التعديل...'
                            : 'جاري التثبيت...')
                      : (widget.isEditMode ? 'حفظ التعديل' : 'تثبيت الحجز'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // عنصر مساعد لعرض المعلومات
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// شاشة اختيار موقع التوصيل
class _DeliveryLocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const _DeliveryLocationPickerScreen({required this.initialLocation});

  @override
  State<_DeliveryLocationPickerScreen> createState() =>
      _DeliveryLocationPickerScreenState();
}

class _DeliveryLocationPickerScreenState
    extends State<_DeliveryLocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم رفض إذن الموقع نهائياً. افتح الإعدادات وامنح الإذن يدوياً.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
          await Geolocator.openAppSettings();
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('صلاحية الموقع مطلوبة')),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final newLocation = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _selectedLocation = newLocation);
        _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحصول على الموقع. حاول مجدداً.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تحديد موقع التوصيل',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6E1229),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.my_location),
            tooltip: 'موقعي الحالي',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (location) => setState(() => _selectedLocation = location),
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('delivery_location'),
                      position: _selectedLocation!,
                      infoWindow: const InfoWindow(title: 'موقع التوصيل'),
                    ),
                  }
                : {},
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'اضغط على الخريطة لتحديد موقع التوصيل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (_selectedLocation != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('استخدام موقعي الحالي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedLocation != null
                        ? () => Navigator.pop(context, _selectedLocation)
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد موقع التوصيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6E1229),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
