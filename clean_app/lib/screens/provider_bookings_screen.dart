import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // تم حذف الاعتماد على firebase_auth نهائياً
import 'package:flutter/material.dart';

class ProviderBookingsScreen extends StatelessWidget {
  const ProviderBookingsScreen({super.key});

  Future<void> _updateStatus(String bookingId, String status, BuildContext context) async {
    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({'status': status});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحديث حالة الحجز!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final user = FirebaseAuth.instance.currentUser; // تم تعطيله لإزالة الاعتماد على FirebaseAuth
    return Scaffold(
      appBar: AppBar(title: Text('حجوزات مزود الخدمة')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            // .where('providerId', isEqualTo: user?.uid) // تم حذف الاعتماد على user
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('لا توجد حجوزات حالياً.'));
          }
          final bookings = snapshot.data!.docs;
          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('الخدمة: ${booking['serviceName'] ?? ''}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('العميل: ${booking['userEmail'] ?? ''}'),
                      Text('التاريخ: ${booking['date']}'),
                      Text('الوقت: ${booking['time']}'),
                      Text('الحالة: ${booking['status'] ?? ''}'),
                      if (booking['receiptUrl'] != null && booking['receiptUrl'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Image.network(booking['receiptUrl'], width: 120, height: 120),
                        ),
                    ],
                  ),
                  trailing: booking['status'] == 'بانتظار التأكيد'
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _updateStatus(booking.id, 'تم التأكيد', context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                              child: Text('تأكيد'),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _updateStatus(booking.id, 'مرفوض', context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                              child: Text('رفض'),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
