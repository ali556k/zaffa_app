import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// دالة لتحويل نوع الخدمة إلى معرف الخدمة
String getServiceId(String serviceType) {
  switch (serviceType) {
    case 'قاعات اعراس':
      return 'hall';
    case 'فنادق':
      return 'hotel';
    case 'سيارات':
      return 'car';
    case 'مطاعم':
      return 'restaurant';
    case 'كيك':
      return 'cake';
    case 'ورد':
      return 'flowers';
    case 'عناية العروس':
      return 'salon_care';
    case 'فستان العروس':
      return 'bride_dress';
    case 'بدلة العريس':
      return 'groom_suit';
    case 'زينة سيارات':
      return 'car_decoration';
    case 'شهر عسل':
      return 'honeymoon';
    default:
      return 'other';
  }
}

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('provider_requests'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_requests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('خطأ في تحميل البيانات: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات جديدة'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildRequestCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final status = data['status'] ?? 'pending';
    final serviceType = data['serviceType'] ?? '';
    final providerName = data['providerName'] ?? 'غير محدد';
    final timestamp = data['timestamp'] as Timestamp?;

    Color statusColor;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'موافق';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'مرفوض';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'معلق';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'طلب من: $providerName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'نوع الخدمة: $serviceType',
              style: const TextStyle(fontSize: 16),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 8),
              Text(
                'تاريخ الطلب: ${_formatDate(timestamp.toDate())}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            if (status == 'pending') ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleRequest(docId, 'approved', data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('approve'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleRequest(docId, 'rejected', data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleRequest(
    String docId,
    String newStatus,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(docId)
          .update({'status': newStatus});

      if (newStatus == 'approved') {
        // إضافة مزود الخدمة إلى قاعدة البيانات
        await _addServiceProvider(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved' ? 'تم قبول الطلب' : 'تم رفض الطلب',
            ),
            backgroundColor: newStatus == 'approved'
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في معالجة الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addServiceProvider(Map<String, dynamic> data) async {
    final serviceId = getServiceId(data['serviceType'] ?? '');

    await FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .collection('providers')
        .add({
          'name': data['providerName'],
          'phone': data['providerPhone'],
          'location': data['location'],
          'services': data['services'] ?? [],
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
