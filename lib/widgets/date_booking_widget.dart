import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ويدجت حجز التواريخ لمزودي الخدمة
class DateBookingWidget extends StatefulWidget {
  final String serviceId;
  final String providerId;
  final String itemId;
  final Map<String, dynamic> itemData;

  const DateBookingWidget({
    super.key,
    required this.serviceId,
    required this.providerId,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<DateBookingWidget> createState() => _DateBookingWidgetState();
}

class _DateBookingWidgetState extends State<DateBookingWidget> {
  DateTime selectedDate = DateTime.now();
  Set<DateTime> bookedDates = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
  }

  // تحميل التواريخ المحجوزة
  Future<void> _loadBookedDates() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('items')
          .doc(widget.itemId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final bookedList = data?['bookedDates'] as List<dynamic>? ?? [];
        setState(() {
          bookedDates = bookedList
              .map((timestamp) => (timestamp as Timestamp).toDate())
              .map((date) => DateTime(date.year, date.month, date.day))
              .toSet();
        });
        print('التواريخ المحجوزة: $bookedDates');
      }
    } catch (e) {
      print('خطأ في تحميل التواريخ المحجوزة: $e');
    }
  }

  // إضافة أو إزالة تاريخ محجوز
  Future<void> _toggleDateBooking(DateTime date) async {
    setState(() {
      isLoading = true;
    });

    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final isBooked = bookedDates.contains(normalizedDate);

      Set<DateTime> newBookedDates = Set.from(bookedDates);
      if (isBooked) {
        newBookedDates.remove(normalizedDate);
      } else {
        newBookedDates.add(normalizedDate);
      }

      // تحويل التواريخ إلى Timestamps
      final timestampList = newBookedDates
          .map((date) => Timestamp.fromDate(date))
          .toList();

      // حفظ في Firebase
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('items')
          .doc(widget.itemId)
          .update({
        'bookedDates': timestampList,
      });

      setState(() {
        bookedDates = newBookedDates;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBooked ? 'تم إلغاء حجز التاريخ' : 'تم حجز التاريخ',
          ),
          backgroundColor: isBooked ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      print('خطأ في تحديث التاريخ: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في تحديث التاريخ'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // عنوان العنصر
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.itemData['name'] ?? 'عنصر غير محدد',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E88E5),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),

        // تقويم لاختيار التاريخ
        Expanded(
          child: CalendarDatePicker(
            initialDate: selectedDate,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            onDateChanged: (date) {
              setState(() {
                selectedDate = date;
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        // معلومات التاريخ المختار
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                'التاريخ المختار: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bookedDates.contains(DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                    ? 'هذا التاريخ محجوز حالياً'
                    : 'هذا التاريخ متاح حالياً',
                style: TextStyle(
                  fontSize: 12,
                  color: bookedDates.contains(DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // أزرار العمل
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _toggleDateBooking(selectedDate),
                icon: Icon(
                  bookedDates.contains(DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                      ? Icons.event_available
                      : Icons.event_busy,
                ),
                label: Text(
                  bookedDates.contains(DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                      ? 'إلغاء الحجز'
                      : 'حجز التاريخ',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bookedDates.contains(DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
                      ? Colors.orange
                      : const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // عداد التواريخ المحجوزة
        Text(
          'إجمالي التواريخ المحجوزة: ${bookedDates.length}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
