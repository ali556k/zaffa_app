// تجربة إرسال طلب اختبار لضمان وصول الطلبات للمدير

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestRequestSender extends StatelessWidget {
  const TestRequestSender({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار إرسال الطلبات')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              // إرسال طلب اختبار
              await FirebaseFirestore.instance
                  .collection('provider_requests')
                  .add({
                'serviceName': 'خدمة تجريبية',
                'userPhone': '07700000000',
                'userName': 'مزود تجريبي',
                'governorate': 'بغداد',
                'description': 'هذا طلب اختبار للتأكد من وصول الطلبات',
                'submittedAt': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
                'status': 'pending',
                'type': 'test_request',
                'items': [
                  {
                    'name': 'عنصر تجريبي',
                    'details': 'وصف العنصر التجريبي',
                    'price': '100000',
                    'imageUrls': ['https://via.placeholder.com/300'],
                    'capacity': '100 شخص',
                  }
                ],
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال الطلب التجريبي بنجاح!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطأ في الإرسال: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('إرسال طلب تجريبي'),
        ),
      ),
    );
  }
}
