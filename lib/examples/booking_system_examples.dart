import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/calendar_service.dart';

/// مثال على كيفية استخدام CalendarService
class CalendarServiceExample {
  final CalendarService _calendarService = CalendarService();

  /// مثال 1: الحصول على حالة الأيام في شهر معين
  void exampleGetMonthlyStatus(String itemId) {
    final now = DateTime.now();

    _calendarService.getMonthlyBookingStatus(itemId: itemId, month: now).listen(
      (statusMap) {
        print('📅 حالة الأيام في ${now.month}/${now.year}:');

        statusMap.forEach((date, status) {
          String emoji;
          String text;

          switch (status) {
            case DayStatus.available:
              emoji = '🟢';
              text = 'متاح';
              break;
            case DayStatus.partiallyBooked:
              emoji = '🟠';
              text = 'محجوز جزئياً';
              break;
            case DayStatus.fullyBooked:
              emoji = '🔴';
              text = 'محجوز كاملاً';
              break;
          }

          print('$emoji ${date.day}/${date.month}: $text');
        });
      },
    );
  }

  /// مثال 2: الحصول على الأوقات المحجوزة في يوم معين
  void exampleGetBookedSlots(String itemId, DateTime date) {
    _calendarService
        .getBookedTimeSlotsForDay(itemId: itemId, date: date)
        .listen((slots) {
          print('⏰ الأوقات المحجوزة في ${date.day}/${date.month}:');

          if (slots.isEmpty) {
            print('✅ لا توجد أوقات محجوزة');
          } else {
            for (var slot in slots) {
              print('🕐 من ${slot.startTime} إلى ${slot.endTime}');
            }
          }
        });
  }

  /// مثال 3: التحقق من إمكانية الحجز
  Future<void> exampleCanBook(
    String itemId,
    DateTime date, {
    TimeSlot? timeSlot,
  }) async {
    final canBook = await _calendarService.canBook(
      itemId: itemId,
      date: date,
      timeSlot: timeSlot,
    );

    if (canBook) {
      print('✅ يمكن الحجز في ${date.day}/${date.month}');
      if (timeSlot != null) {
        print('   الوقت: ${timeSlot.startTime} - ${timeSlot.endTime}');
      } else {
        print('   اليوم كامل');
      }
    } else {
      print('❌ لا يمكن الحجز - يوجد تعارض');
    }
  }

  /// مثال 4: الحصول على حالة يوم واحد
  Future<void> exampleGetDayStatus(String itemId, DateTime date) async {
    final status = await _calendarService.getDayStatusOnce(
      itemId: itemId,
      date: date,
    );

    String emoji;
    String text;

    switch (status) {
      case DayStatus.available:
        emoji = '🟢';
        text = 'متاح';
        break;
      case DayStatus.partiallyBooked:
        emoji = '🟠';
        text = 'محجوز جزئياً';
        break;
      case DayStatus.fullyBooked:
        emoji = '🔴';
        text = 'محجوز كاملاً';
        break;
    }

    print('$emoji حالة ${date.day}/${date.month}: $text');
  }
}

/// أمثلة على إنشاء نماذج الحجز
class BookingModelExamples {
  /// مثال 1: حجز يوم كامل
  BookingModel createFullDayBooking() {
    return BookingModel(
      itemId: 'hall_123',
      itemName: 'قاعة الأمل الكبرى',
      providerId: '077777',
      providerName: 'أحمد محمد',
      customerId: '0781234567',
      customerName: 'خالد علي',
      customerPhone: '0781234567',
      category: 'hall',
      bookingDate: DateTime(2025, 12, 25),
      dayStatus: DayStatus.fullyBooked, // حجز كامل اليوم
      timeSlot: null, // لا يوجد وقت محدد لأنه حجز كامل
      notes: 'حفل زفاف - عدد المدعوين: 300',
    );
  }

  /// مثال 2: حجز فترة محددة
  BookingModel createPartialBooking() {
    return BookingModel(
      itemId: 'car_456',
      itemName: 'سيارة مرسيدس S Class',
      providerId: '077888',
      providerName: 'محمد أحمد',
      customerId: '0789876543',
      customerName: 'سارة خالد',
      customerPhone: '0789876543',
      category: 'car',
      bookingDate: DateTime(2025, 12, 20),
      dayStatus: DayStatus.partiallyBooked, // حجز جزئي
      timeSlot: TimeSlot(startTime: '14:00', endTime: '18:00'),
      notes: 'استلام من المطار',
    );
  }

  /// مثال 3: طباعة تفاصيل الحجز
  void printBookingDetails(BookingModel booking) {
    print('📋 تفاصيل الحجز:');
    print('━━━━━━━━━━━━━━━━━━━━');
    print('🏷️  العنصر: ${booking.itemName}');
    print('👤 الزبون: ${booking.customerName}');
    print('📞 الهاتف: ${booking.customerPhone}');
    print(
      '📅 التاريخ: ${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}',
    );

    if (booking.timeSlot != null) {
      print(
        '⏰ الوقت: ${booking.timeSlot!.startTime} - ${booking.timeSlot!.endTime}',
      );
      print('📊 الحالة: محجوز جزئياً 🟠');
    } else {
      print('📊 الحالة: محجوز كاملاً 🔴');
    }

    if (booking.notes != null && booking.notes!.isNotEmpty) {
      print('📝 ملاحظات: ${booking.notes}');
    }

    print('━━━━━━━━━━━━━━━━━━━━');
  }

  /// مثال 4: تحويل الحجز إلى Map لحفظه في Firestore
  void exampleSaveToFirestore(BookingModel booking) {
    final data = booking.toMap();
    print('💾 البيانات المحفوظة:');
    print(data);

    // في التطبيق الفعلي:
    // await FirebaseFirestore.instance.collection('bookings').add(data);
  }
}

/// أمثلة على استخدام واجهة المستخدم
class UIExamples {
  /// مثال: كيفية عرض علامة ملونة في التقويم
  Widget buildDayMarker(DayStatus status) {
    Color color;
    String tooltip;

    switch (status) {
      case DayStatus.fullyBooked:
        color = Colors.red;
        tooltip = 'محجوز بالكامل';
        break;
      case DayStatus.partiallyBooked:
        color = Colors.orange;
        tooltip = 'محجوز جزئياً';
        break;
      case DayStatus.available:
        color = Colors.green;
        tooltip = 'متاح';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  /// مثال: نافذة عرض الأوقات المحجوزة
  void showBookedSlotsDialog(BuildContext context, List<TimeSlot> slots) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الأوقات المحجوزة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: slots.map((slot) {
            return ListTile(
              leading: const Icon(Icons.access_time, color: Colors.orange),
              title: Text('${slot.startTime} - ${slot.endTime}'),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  /// مثال: بطاقة حجز
  Widget buildBookingCard(BookingModel booking) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Text(
              booking.itemName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // الزبون
            Row(
              children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 4),
                Text(booking.customerName),
              ],
            ),

            // التاريخ
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text('${booking.bookingDate.day}/${booking.bookingDate.month}'),
              ],
            ),

            // الوقت (إذا وجد)
            if (booking.timeSlot != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${booking.timeSlot!.startTime} - ${booking.timeSlot!.endTime}',
                  ),
                ],
              ),

            // الحالة
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: booking.dayStatus == DayStatus.fullyBooked
                    ? Colors.red.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                booking.dayStatus == DayStatus.fullyBooked
                    ? 'محجوز كاملاً'
                    : 'محجوز جزئياً',
                style: TextStyle(
                  color: booking.dayStatus == DayStatus.fullyBooked
                      ? Colors.red
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تشغيل الأمثلة
void runExamples() {
  print('🚀 بدء تشغيل الأمثلة...\n');

  // 1. أمثلة CalendarService
  print('═══════════════════════════════');
  print('📅 أمثلة CalendarService');
  print('═══════════════════════════════\n');

  // final calendarExample = CalendarServiceExample();
  // calendarExample.exampleGetMonthlyStatus('hall_123');
  // calendarExample.exampleGetBookedSlots('hall_123', DateTime(2025, 12, 25));

  // 2. أمثلة BookingModel
  print('\n═══════════════════════════════');
  print('📋 أمثلة BookingModel');
  print('═══════════════════════════════\n');

  final bookingExample = BookingModelExamples();

  print('▶️ حجز يوم كامل:');
  final fullDayBooking = bookingExample.createFullDayBooking();
  bookingExample.printBookingDetails(fullDayBooking);

  print('\n▶️ حجز فترة محددة:');
  final partialBooking = bookingExample.createPartialBooking();
  bookingExample.printBookingDetails(partialBooking);

  print('\n✅ الأمثلة انتهت بنجاح!');
}
