import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

/// خدمة التقويم للحصول على حالة الأيام في الوقت الفعلي
class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _bookingsCollection = 'bookings';

  /// الحصول على حالة جميع الأيام المحجوزة لعنصر معين (استماع مباشر مبسط)
  Stream<Map<DateTime, DayStatus>> getMonthlyBookingStatus({
    required String itemId,
    required DateTime month,
  }) {
    return _firestore
        .collection(_bookingsCollection)
        .where('itemId', isEqualTo: itemId)
        .where('isCancelled', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final Map<DateTime, List<BookingModel>> bookingsByDay = {};
          final startOfMonth = DateTime(month.year, month.month, 1);
          final endOfMonth = DateTime(
            month.year,
            month.month + 1,
            0,
            23,
            59,
            59,
          );

          // تجميع الحجوزات حسب اليوم مع فلترة التاريخ
          for (var doc in snapshot.docs) {
            final booking = BookingModel.fromMap(doc.data(), doc.id);

            // فلترة الشهر المطلوب
            if (booking.bookingDate.isBefore(startOfMonth) ||
                booking.bookingDate.isAfter(endOfMonth)) {
              continue;
            }

            final day = DateTime(
              booking.bookingDate.year,
              booking.bookingDate.month,
              booking.bookingDate.day,
            );

            if (!bookingsByDay.containsKey(day)) {
              bookingsByDay[day] = [];
            }
            bookingsByDay[day]!.add(booking);
          }

          // حساب حالة كل يوم
          final Map<DateTime, DayStatus> dayStatusMap = {};
          for (var entry in bookingsByDay.entries) {
            dayStatusMap[entry.key] = _calculateDayStatus(entry.value);
          }

          return dayStatusMap;
        });
  }

  /// حساب حالة اليوم بناءً على الحجوزات
  DayStatus _calculateDayStatus(List<BookingModel> bookings) {
    if (bookings.isEmpty) {
      return DayStatus.available;
    }

    // إذا كان هناك أي حجز كامل، اليوم محجوز بالكامل
    for (var booking in bookings) {
      if (booking.dayStatus == DayStatus.fullyBooked) {
        return DayStatus.fullyBooked;
      }
    }

    // إذا وصلنا هنا، معناه كل الحجوزات جزئية
    return DayStatus.partiallyBooked;
  }

  /// الحصول على الأوقات المحجوزة في يوم معين (استماع مباشر مبسط)
  Stream<List<TimeSlot>> getBookedTimeSlotsForDay({
    required String itemId,
    required DateTime date,
  }) {
    return _firestore
        .collection(_bookingsCollection)
        .where('itemId', isEqualTo: itemId)
        .where('isCancelled', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final bookedSlots = <TimeSlot>[];
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = DateTime(
            date.year,
            date.month,
            date.day,
            23,
            59,
            59,
          );

          for (var doc in snapshot.docs) {
            final booking = BookingModel.fromMap(doc.data(), doc.id);

            // فلترة اليوم المطلوب
            if (booking.bookingDate.isBefore(startOfDay) ||
                booking.bookingDate.isAfter(endOfDay)) {
              continue;
            }

            if (booking.timeSlot != null) {
              bookedSlots.add(booking.timeSlot!);
            }
          }

          return bookedSlots;
        });
  }

  /// التحقق من إمكانية الحجز في تاريخ ووقت محدد (مبسط لتجنب الفهرسة)
  Future<bool> canBook({
    required String itemId,
    required DateTime date,
    TimeSlot? timeSlot,
  }) async {
    try {
      print('🔎 CalendarService.canBook() - itemId: $itemId');
      print('📅 التاريخ: ${date.day}/${date.month}/${date.year}');
      if (timeSlot != null) {
        print('🕐 الوقت: ${timeSlot.startTime} - ${timeSlot.endTime}');
      }

      // استعلام مبسط بدون فهرسة مركبة
      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('itemId', isEqualTo: itemId)
          .where('isCancelled', isEqualTo: false)
          .get();

      print('📊 عدد الحجوزات الكلية للعنصر: ${existingBookings.docs.length}');

      if (existingBookings.docs.isEmpty) {
        print('✅ لا توجد حجوزات، يمكن الحجز');
        return true;
      }

      // فلترة الحجوزات للتاريخ المحدد
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final dayBookings = existingBookings.docs.where((doc) {
        final data = doc.data();
        final bookingDate = (data['bookingDate'] as Timestamp).toDate();
        return bookingDate.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            ) &&
            bookingDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).toList();

      print('📊 عدد الحجوزات في هذا التاريخ: ${dayBookings.length}');

      if (dayBookings.isEmpty) {
        print('✅ لا توجد حجوزات في هذا التاريخ، يمكن الحجز');
        return true;
      }

      // التحقق من التفاصيل
      for (var doc in dayBookings) {
        final booking = BookingModel.fromMap(doc.data(), doc.id);
        print(
          '📋 حجز موجود: ${booking.dayStatus}, timeSlot: ${booking.timeSlot?.startTime ?? 'null'}-${booking.timeSlot?.endTime ?? 'null'}',
        );

        // إذا كان اليوم محجوز بالكامل
        if (booking.dayStatus == DayStatus.fullyBooked) {
          print('❌ اليوم محجوز بالكامل');
          return false;
        }

        // إذا كان الحجز الجديد لليوم كامل
        if (timeSlot == null) {
          print('❌ يوجد حجوزات جزئية، لا يمكن حجز اليوم كامل');
          return false; // يوجد حجوزات جزئية، لا يمكن حجز اليوم كامل
        }

        // التحقق من تعارض الأوقات
        if (booking.timeSlot != null) {
          final overlap = _doTimeSlotsOverlap(booking.timeSlot!, timeSlot);
          print(
            '🔄 التحقق من التداخل مع ${booking.timeSlot!.startTime}-${booking.timeSlot!.endTime}: $overlap',
          );
          if (overlap) {
            print('❌ يوجد تداخل في الأوقات');
            return false;
          }
        }
      }

      print('✅ لا يوجد تضارب، يمكن الحجز');
      return true;
    } catch (e) {
      print('❌ خطأ في التحقق من إمكانية الحجز: $e');
      return false; // في حالة الخطأ، منع الحجز للأمان
    }
  }

  /// التحقق من تداخل الأوقات
  bool _doTimeSlotsOverlap(TimeSlot slot1, TimeSlot slot2) {
    final start1 = _timeStringToMinutes(slot1.startTime);
    final end1 = _timeStringToMinutes(slot1.endTime);
    final start2 = _timeStringToMinutes(slot2.startTime);
    final end2 = _timeStringToMinutes(slot2.endTime);

    // التداخل يحدث إذا كان هناك وقت مشترك
    // مثال: 10:00-12:00 و 12:00-14:00 = لا تداخل (متجاورة) ✓
    // مثال: 10:00-12:00 و 11:00-13:00 = تداخل (يوجد وقت مشترك) ✓
    return start1 < end2 && start2 < end1;
  }

  /// تحويل وقت نصي (HH:mm) إلى دقائق
  int _timeStringToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// الحصول على حالة يوم معين مرة واحدة
  Future<DayStatus> getDayStatusOnce({
    required String itemId,
    required DateTime date,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final bookings = await _firestore
          .collection(_bookingsCollection)
          .where('itemId', isEqualTo: itemId)
          .where('isCancelled', isEqualTo: false)
          .where(
            'bookingDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'bookingDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .get();

      if (bookings.docs.isEmpty) {
        return DayStatus.available;
      }

      final bookingModels = bookings.docs
          .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
          .toList();

      return _calculateDayStatus(bookingModels);
    } catch (e) {
      print('❌ خطأ في الحصول على حالة اليوم: $e');
      return DayStatus.available;
    }
  }
}
