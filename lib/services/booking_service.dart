import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Collection names
  static const String _bookingsCollection = 'bookings';
  static const String _itemsAvailabilityCollection = 'items_availability';

  /// إنشاء حجز جديد
  Future<String> createBooking(BookingModel booking, {bool skipConflictCheck = false}) async {
    try {
      // التحقق من عدم وجود تعارض في الحجز
      // يُتخطى للخدمات غير القابلة للحجز (كيك، ورود، فساتين...)
      if (!skipConflictCheck) {
        final conflict = await _checkBookingConflict(
          booking.itemId,
          booking.bookingDate,
          booking.timeSlot,
        );

        if (conflict) {
          throw Exception('هذا اليوم أو الوقت محجوز مسبقاً');
        }
      }

      // حفظ الحجز
      final docRef = await _firestore
          .collection(_bookingsCollection)
          .add(booking.toMap());

      // جدولة تذكير قبل 24 ساعة من الحجز
      await _notificationService.scheduleBookingReminder(
        bookingId: docRef.id,
        bookingDate: booking.bookingDate,
        itemName: booking.itemName,
        customerName: booking.customerName,
      );

      // التحقق من عدد الحجوزات وإرسال تنبيه للمزود إذا لزم
      await _notificationService.checkDailyBookingsAndNotify(
        providerId: booking.providerId,
        date: booking.bookingDate,
      );

      return docRef.id;
    } catch (e) {
      print('❌ خطأ في إنشاء الحجز: $e');
      rethrow;
    }
  }

  /// التحقق من وجود تعارض في الحجز
  Future<bool> _checkBookingConflict(
    String itemId,
    DateTime date,
    TimeSlot? timeSlot, {
    String? excludeBookingId,
  }) async {
    try {
      print('🔍 BookingService._checkBookingConflict()');
      print('   itemId: $itemId');
      print('   date: ${date.day}/${date.month}/${date.year}');
      print(
        '   timeSlot: ${timeSlot?.startTime ?? 'null'} - ${timeSlot?.endTime ?? 'null'}',
      );

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // استعلام محسّن: نجلب كل حجوزات العنصر غير الملغاة ونفلترها في الكود
      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('itemId', isEqualTo: itemId)
          .where('isCancelled', isEqualTo: false)
          .get();

      // فلترة الحجوزات حسب التاريخ
      final dayBookings = existingBookings.docs.where((doc) {
        final data = doc.data();
        if (data['bookingDate'] == null) return false;
        final bookingDate = (data['bookingDate'] as Timestamp).toDate();
        return bookingDate.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            ) &&
            bookingDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).toList();

      print('📊 عدد الحجوزات الموجودة في هذا التاريخ: ${dayBookings.length}');

      if (dayBookings.isEmpty) {
        print('✅ لا توجد حجوزات، يمكن الحجز');
        return false; // لا يوجد تعارض
      }

      // التحقق من التفاصيل
      for (var doc in dayBookings) {
        // استثناء الحجز المراد تعديله
        if (excludeBookingId != null && doc.id == excludeBookingId) {
          print('⏭️ تخطي الحجز الحالي: $excludeBookingId');
          continue;
        }

        final booking = BookingModel.fromMap(doc.data(), doc.id);
        print('📋 حجز موجود:');
        print('   ID: ${doc.id}');
        print('   dayStatus: ${booking.dayStatus}');
        print(
          '   timeSlot: ${booking.timeSlot?.startTime ?? 'null'} - ${booking.timeSlot?.endTime ?? 'null'}',
        );
        print('   isCancelled: ${booking.isCancelled}');

        // إذا كان اليوم محجوز بالكامل
        if (booking.dayStatus == DayStatus.fullyBooked) {
          print('❌ اليوم محجوز بالكامل');
          return true;
        }

        // إذا كان الحجز الجديد لليوم كامل
        if (timeSlot == null) {
          print('❌ يوجد حجوزات جزئية، لا يمكن حجز اليوم كامل');
          return true;
        }

        // التحقق من تعارض الأوقات
        if (booking.timeSlot != null) {
          final overlap = _doTimeSlotsOverlap(booking.timeSlot!, timeSlot);
          print('🔄 التحقق من التداخل: $overlap');
          if (overlap) {
            print('❌ يوجد تداخل في الأوقات');
            return true;
          }
        }
      }

      print('✅ لا يوجد تعارض، يمكن الحجز');
      return false;
    } catch (e) {
      print('❌ خطأ في التحقق من التعارض: $e');
      print('📍 Stack trace للتشخيص:');
      print(StackTrace.current);
      return true; // في حالة الخطأ، نعتبر أن هناك تعارض للأمان
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

  /// الحصول على حجوزات عنصر معين
  Stream<List<BookingModel>> getItemBookings(String itemId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('itemId', isEqualTo: itemId)
        .where('isCancelled', isEqualTo: false)
        .orderBy('bookingDate', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// الحصول على حجوزات الزبون
  Stream<List<BookingModel>> getCustomerBookings(String customerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// الحصول على حجوزات مزود الخدمة
  Stream<List<BookingModel>> getProviderBookings(String providerId) {
    return _firestore
        .collection(_bookingsCollection)
        .where('providerId', isEqualTo: providerId)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// إلغاء حجز
  Future<void> cancelBooking(String bookingId, String cancelledBy) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'isCancelled': true,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': cancelledBy,
      });

      // إلغاء تذكير الحجز
      await _notificationService.cancelBookingReminder(bookingId);
    } catch (e) {
      print('❌ خطأ في إلغاء الحجز: $e');
      rethrow;
    }
  }

  /// تعديل حجز موجود
  Future<void> updateBooking({
    required String bookingId,
    required DateTime newDate,
    TimeSlot? newTimeSlot,
    required String itemId,
    required String customerId,
  }) async {
    try {
      // التحقق من عدم وجود تعديل سابق
      final bookingDoc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('الحجز غير موجود');
      }

      final bookingData = bookingDoc.data()!;
      if (bookingData['isModified'] == true) {
        throw Exception(
          'تم تعديل هذا الحجز مسبقاً. يُسمح بتعديل واحد فقط لكل حجز',
        );
      }

      // التحقق من عدم وجود تعارض في التاريخ الجديد
      final conflict = await _checkBookingConflict(
        itemId,
        newDate,
        newTimeSlot,
        excludeBookingId: bookingId,
      );

      if (conflict) {
        throw Exception('التاريخ أو الوقت الجديد محجوز مسبقاً');
      }

      // تحديث الحجز
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'bookingDate': Timestamp.fromDate(newDate),
        'timeSlot': newTimeSlot?.toMap(),
        'isModified': true,
        'modifiedAt': FieldValue.serverTimestamp(),
        'originalDate': bookingData['bookingDate'],
        'originalTimeSlot': bookingData['timeSlot'],
      });

      // إرسال إشعار للمزود بأن الحجز تم تعديله
      try {
        await _notificationService.sendBookingModificationNotification(
          providerId: bookingData['providerId'],
          bookingId: bookingId,
          customerName: bookingData['customerName'],
          itemName: bookingData['itemName'],
          newDate: newDate,
          newTimeSlot: newTimeSlot,
        );
      } catch (e) {
        print('⚠️ خطأ في إرسال إشعار التعديل للمزود: $e');
      }

      // إلغاء التذكير القديم وجدولة واحد جديد
      await _notificationService.cancelBookingReminder(bookingId);
      await _notificationService.scheduleBookingReminder(
        bookingId: bookingId,
        bookingDate: newDate,
        itemName: bookingData['itemName'],
        customerName: bookingData['customerName'],
      );

      print('✅ تم تعديل الحجز بنجاح');
    } catch (e) {
      print('❌ خطأ في تعديل الحجز: $e');
      rethrow;
    }
  }

  /// الحصول على حالة اليوم لعنصر معين (مبسط لتجنب الفهرسة)
  Future<DayStatus> getDayStatus(String itemId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // استعلام مبسط لتجنب الفهرسة المركبة
      final bookings = await _firestore
          .collection(_bookingsCollection)
          .where('itemId', isEqualTo: itemId)
          .where('isCancelled', isEqualTo: false)
          .get();

      // فلترة النتائج محلياً
      final dayBookings = bookings.docs.where((doc) {
        final data = doc.data();
        final bookingDate = (data['bookingDate'] as Timestamp).toDate();
        return bookingDate.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            ) &&
            bookingDate.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).toList();

      if (dayBookings.isEmpty) {
        return DayStatus.available;
      }

      // التحقق من وجود حجز كامل
      for (var doc in dayBookings) {
        final booking = BookingModel.fromMap(doc.data(), doc.id);
        if (booking.dayStatus == DayStatus.fullyBooked) {
          return DayStatus.fullyBooked;
        }
      }

      // إذا وصلنا هنا، معناه فيه حجوزات جزئية فقط
      return DayStatus.partiallyBooked;
    } catch (e) {
      print('❌ خطأ في الحصول على حالة اليوم: $e');
      return DayStatus.available;
    }
  }

  /// تحديث حالة توفر عنصر (للخدمات غير القابلة للحجز)
  Future<void> updateItemAvailability(String itemId, bool isAvailable) async {
    try {
      await _firestore
          .collection(_itemsAvailabilityCollection)
          .doc(itemId)
          .set({
            'itemId': itemId,
            'isAvailable': isAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // تحديث أيضاً في مجموعة العناصر المنشورة
      await _firestore.collection('published_items').doc(itemId).update({
        'isAvailable': isAvailable,
        'availabilityUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ خطأ في تحديث حالة التوفر: $e');
      rethrow;
    }
  }

  /// الحصول على حالة توفر عنصر
  Stream<bool> getItemAvailability(String itemId) {
    return _firestore.collection('published_items').doc(itemId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return true;
        final data = snapshot.data();
        return data?['isAvailable'] ?? true;
      },
    );
  }

  /// حذف حجز (للإدارة فقط)
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection(_bookingsCollection).doc(bookingId).delete();
    } catch (e) {
      print('❌ خطأ في حذف الحجز: $e');
      rethrow;
    }
  }

  /// الحصول على الأوقات المحجوزة في يوم معين
  Future<List<TimeSlot>> getBookedTimeSlotsForDay(
    String itemId,
    DateTime date,
  ) async {
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

      final bookedSlots = <TimeSlot>[];

      for (var doc in bookings.docs) {
        final booking = BookingModel.fromMap(doc.data(), doc.id);
        if (booking.timeSlot != null) {
          bookedSlots.add(booking.timeSlot!);
        }
      }

      return bookedSlots;
    } catch (e) {
      print('❌ خطأ في الحصول على الأوقات المحجوزة: $e');
      return [];
    }
  }

  /// الحصول على حالة توفر العنصر مرة واحدة (للخدمات غير القابلة للحجز)
  Future<bool> getItemAvailabilityOnce(String itemId) async {
    try {
      final doc = await _firestore
          .collection('published_items')
          .doc(itemId)
          .get();

      if (!doc.exists) {
        return true; // افتراضياً متوفر إذا لم يتم تعيين حالة
      }

      final data = doc.data();
      return data?['isAvailable'] ?? true;
    } catch (e) {
      print('❌ خطأ في الحصول على حالة التوفر: $e');
      return true; // افتراضياً متوفر في حالة الخطأ
    }
  }
}
