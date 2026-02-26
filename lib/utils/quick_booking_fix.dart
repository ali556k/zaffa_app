import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// حذف سريع للحجوزات المزيفة
class QuickBookingFix {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// حذف جميع الحجوزات المزيفة (استخدم بحذر!)
  static Future<void> clearAllFakeBookings(BuildContext context) async {
    try {
      // عرض تحذير
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ تحذير'),
          content: const Text(
            'هل تريد حذف جميع الحجوزات المزيفة من النظام؟\n\n'
            'هذا سيحل مشكلة ظهور نفس الحجوزات لجميع العناصر.\n\n'
            'هذا الإجراء لا يمكن التراجع عنه!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف الكل'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // إظهار مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري حذف البيانات المزيفة...'),
            ],
          ),
        ),
      );

      // حذف جميع الحجوزات
      final bookingsSnapshot = await _firestore.collection('bookings').get();
      
      print('🔍 وجدت ${bookingsSnapshot.docs.length} حجز للحذف');

      if (bookingsSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        
        for (var doc in bookingsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        print('✅ تم حذف ${bookingsSnapshot.docs.length} حجز');
      }

      // إغلاق مؤشر التحميل
      Navigator.of(context).pop();

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف ${bookingsSnapshot.docs.length} حجز بنجاح!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      print('🎉 تم تنظيف قاعدة البيانات بنجاح!');
      
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حذف البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      print('❌ خطأ في تنظيف البيانات: $e');
    }
  }

  /// حذف سريع للبيانات المزيفة (بدون واجهة مستخدم)
  static Future<void> clearFakeBookingsQuiet() async {
    try {
      print('🧹 بدء تنظيف البيانات المزيفة...');
      
      final bookingsSnapshot = await _firestore.collection('bookings').get();
      
      if (bookingsSnapshot.docs.isEmpty) {
        print('✅ لا توجد حجوزات للحذف');
        return;
      }

      final batch = _firestore.batch();
      
      for (var doc in bookingsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('🎉 تم حذف ${bookingsSnapshot.docs.length} حجز مزيف بنجاح!');
      
    } catch (e) {
      print('❌ خطأ في تنظيف البيانات: $e');
    }
  }

  /// زر سريع للإضافة إلى أي شاشة
  static Widget buildQuickFixButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => clearAllFakeBookings(context),
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.cleaning_services),
      label: const Text('حذف البيانات المزيفة'),
    );
  }

  /// إضافة زر في AppBar
  static Widget buildAppBarAction(BuildContext context) {
    return IconButton(
      onPressed: () => clearAllFakeBookings(context),
      icon: const Icon(Icons.cleaning_services),
      tooltip: 'حذف البيانات المزيفة',
    );
  }
}