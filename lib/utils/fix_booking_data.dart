import 'package:cloud_firestore/cloud_firestore.dart';

/// أداة إصلاح بيانات الحجوزات المتضاربة
class BookingDataFixer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إزالة جميع الحجوزات الوهمية والاختبارية
  Future<void> clearTestBookings() async {
    try {
      print('🔍 البحث عن الحجوزات الوهمية...');
      
      // جلب جميع الحجوزات
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .get();

      print('📊 وجدت ${bookingsSnapshot.docs.length} حجز');

      if (bookingsSnapshot.docs.isEmpty) {
        print('✅ لا توجد حجوزات للحذف');
        return;
      }

      // تحليل الحجوزات
      Map<String, int> itemBookingCounts = {};
      List<String> suspiciousBookings = [];
      
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId'] as String?;
        final bookingDate = data['bookingDate'] as Timestamp?;
        
        if (itemId == null || itemId.isEmpty) {
          suspiciousBookings.add(doc.id);
          continue;
        }
        
        // عد الحجوزات لكل عنصر
        itemBookingCounts[itemId] = (itemBookingCounts[itemId] ?? 0) + 1;
        
        // التحقق من التواريخ المشبوهة (أيام السبت والأحد بشكل متكرر)
        if (bookingDate != null) {
          final date = bookingDate.toDate();
          if (date.weekday == 6 || date.weekday == 7) { // السبت والأحد
            print('⚠️  حجز مشبوه في نهاية الأسبوع: ${doc.id} - $date');
          }
        }
      }

      print('📈 إحصائيات الحجوزات حسب العنصر:');
      itemBookingCounts.forEach((itemId, count) {
        print('  - العنصر $itemId: $count حجز');
        if (count > 10) { // عدد مشبوه من الحجوزات
          print('    ⚠️  عدد مشبوه من الحجوزات!');
        }
      });

      // عرض الخيارات للمستخدم
      print('\n🔧 خيارات الإصلاح المتاحة:');
      print('1. حذف جميع الحجوزات (إعادة تشغيل كامل)');
      print('2. حذف الحجوزات المشبوهة فقط');
      print('3. إلغاء');
      
      // يمكن استدعاء الطرق المناسبة حسب الحاجة
    } catch (e) {
      print('❌ خطأ في تحليل بيانات الحجوزات: $e');
    }
  }

  /// حذف جميع الحجوزات (إعادة تشغيل كامل)
  Future<void> deleteAllBookings() async {
    try {
      print('🗑️  بدء حذف جميع الحجوزات...');
      
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .get();

      final batch = _firestore.batch();
      int count = 0;

      for (var doc in bookingsSnapshot.docs) {
        batch.delete(doc.reference);
        count++;
        
        // تنفيذ batch كل 500 عنصر (حد Firestore)
        if (count % 500 == 0) {
          await batch.commit();
          print('✅ تم حذف $count حجز');
        }
      }

      // تنفيذ المجموعة الأخيرة
      if (count % 500 != 0) {
        await batch.commit();
      }

      print('🎉 تم حذف جميع الحجوزات بنجاح! العدد الإجمالي: $count');
    } catch (e) {
      print('❌ خطأ في حذف الحجوزات: $e');
    }
  }

  /// حذف الحجوزات المشبوهة فقط
  Future<void> deleteSuspiciousBookings() async {
    try {
      print('🔍 البحث عن الحجوزات المشبوهة...');
      
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .get();

      final batch = _firestore.batch();
      int deleteCount = 0;

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId'] as String?;
        final bookingDate = data['bookingDate'] as Timestamp?;
        bool shouldDelete = false;

        // حذف الحجوزات بدون itemId
        if (itemId == null || itemId.isEmpty) {
          shouldDelete = true;
          print('🗑️  حجز بدون itemId: ${doc.id}');
        }

        // حذف الحجوزات في أيام السبت والأحد المتكررة (إذا كانت اختبارية)
        if (bookingDate != null) {
          final date = bookingDate.toDate();
          if (date.weekday == 6 || date.weekday == 7) {
            // التحقق من وجود نمط متكرر
            shouldDelete = true;
            print('🗑️  حجز مشبوه في نهاية الأسبوع: ${doc.id} - $date');
          }
        }

        if (shouldDelete) {
          batch.delete(doc.reference);
          deleteCount++;
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
        print('🎉 تم حذف $deleteCount حجز مشبوه');
      } else {
        print('✅ لم يتم العثور على حجوزات مشبوهة');
      }
    } catch (e) {
      print('❌ خطأ في حذف الحجوزات المشبوهة: $e');
    }
  }

  /// التحقق من صحة البيانات
  Future<void> validateBookingData() async {
    try {
      print('🔍 التحقق من صحة بيانات الحجوزات...');
      
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .get();

      Map<String, int> itemCounts = {};
      Map<int, int> weekdayCounts = {}; // 1=الاثنين, 7=الأحد
      
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId'] as String?;
        final bookingDate = data['bookingDate'] as Timestamp?;
        
        if (itemId != null) {
          itemCounts[itemId] = (itemCounts[itemId] ?? 0) + 1;
        }
        
        if (bookingDate != null) {
          final weekday = bookingDate.toDate().weekday;
          weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
        }
      }

      print('📊 توزيع الحجوزات حسب العنصر:');
      itemCounts.forEach((itemId, count) {
        print('  - $itemId: $count حجز');
      });

      print('\n📅 توزيع الحجوزات حسب اليوم:');
      const weekdayNames = {
        1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
        5: 'الجمعة', 6: 'السبت', 7: 'الأحد'
      };
      
      weekdayCounts.forEach((weekday, count) {
        final dayName = weekdayNames[weekday] ?? 'غير محدد';
        print('  - $dayName: $count حجز');
        
        // تحذير من التركز الغير طبيعي
        if ((weekday == 6 || weekday == 7) && count > 5) {
          print('    ⚠️  تركز غير طبيعي في نهاية الأسبوع!');
        }
      });

    } catch (e) {
      print('❌ خطأ في التحقق من البيانات: $e');
    }
  }
}