import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // تم حذف الاعتماد على firebase_auth نهائياً
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final user = FirebaseAuth.instance.currentUser; // تم حذف الاعتماد على FirebaseAuth
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 216, 208, 208),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // CustomPageTitle('حجوزاتي'),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  // .where('userId', isEqualTo: user?.uid) // تم حذف الاعتماد على user
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
                        subtitle: Text('التاريخ: ${booking['date']}\nالوقت: ${booking['time']}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
