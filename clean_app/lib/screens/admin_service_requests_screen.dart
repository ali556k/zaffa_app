import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminServiceRequestsScreen extends StatelessWidget {
  const AdminServiceRequestsScreen({super.key});

  Future<void> _updateStatus(String requestId, String status, BuildContext context) async {
    await FirebaseFirestore.instance.collection('service_requests').doc(requestId).update({'status': status});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحديث حالة الطلب!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلبات إنشاء الخدمات')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('لا توجد طلبات حالياً.'));
          }
          final requests = snapshot.data!.docs;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('اسم الخدمة: ${req['name'] ?? ''}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المزود: ${req['providerName'] ?? ''}'),
                      Text('الموقع: ${req['location'] ?? ''}'),
                      Text('تفاصيل: ${req['details'] ?? ''}'),
                      Text('السعر: ${req['price'] ?? ''}'),
                      Text('الحالة: ${req['status'] ?? ''}'),
                    ],
                  ),
                  trailing: req['status'] == 'بانتظار الموافقة'
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _updateStatus(req.id, 'تمت الموافقة', context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                              child: Text('موافقة'),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _updateStatus(req.id, 'مرفوض', context),
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
