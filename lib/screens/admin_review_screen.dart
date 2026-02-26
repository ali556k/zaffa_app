import 'package:flutter/material.dart';
import '../utils/price_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _reviewedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // تحميل العناصر المعلقة
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('provider_items')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      _pendingItems = pendingSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // تحميل العناصر المراجعة
      final reviewedSnapshot = await FirebaseFirestore.instance
          .collection('provider_items')
          .where('status', whereIn: ['approved', 'rejected'])
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _reviewedItems = reviewedSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print(
        'تم تحميل ${_pendingItems.length} عنصر معلق و ${_reviewedItems.length} عنصر مراجع',
      );
    } catch (e) {
      print('خطأ في تحميل العناصر: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات مزودي الخدمة المرسلة'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: 'قيد المراجعة (${_pendingItems.length})',
              icon: const Icon(Icons.hourglass_empty),
            ),
            Tab(
              text: 'مراجعة (${_reviewedItems.length})',
              icon: const Icon(Icons.history),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadItems,
        child: TabBarView(
          controller: _tabController,
          children: [_buildPendingItemsList(), _buildReviewedItemsList()],
        ),
      ),
    );
  }

  Widget _buildPendingItemsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد عناصر في انتظار المراجعة',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingItems.length,
      itemBuilder: (context, index) =>
          _buildPendingItemCard(_pendingItems[index], index),
    );
  }

  Widget _buildReviewedItemsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviewedItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد عناصر مراجعة بعد',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviewedItems.length,
      itemBuilder: (context, index) =>
          _buildReviewedItemCard(_reviewedItems[index]),
    );
  }

  Widget _buildPendingItemCard(Map<String, dynamic> item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات مزود الخدمة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'مزود الخدمة: ${item['providerId'] ?? 'غير محدد'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // معلومات العنصر
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory,
                    color: Color(0xFF1E88E5),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${PriceFormatter.formatString('${item['price'] ?? ''}')} دينار عراقي',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      if (item['details'] != null &&
                          item['details'].isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item['details'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5568),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // أزرار الموافقة والرفض
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(item, index),
                    icon: const Icon(Icons.check),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(item, index),
                    icon: const Icon(Icons.close),
                    label: const Text('رفض'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewedItemCard(Map<String, dynamic> item) {
    final bool isApproved = item['status'] == 'approved';
    final Color statusColor = isApproved ? const Color(0xFF10B981) : Colors.red;
    final IconData statusIcon = isApproved ? Icons.check_circle : Icons.cancel;
    final String statusText = isApproved ? 'معتمد' : 'مرفوض';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حالة المراجعة
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  'مزود الخدمة: ${item['providerId'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // معلومات العنصر
            Text(
              item['name'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${PriceFormatter.formatString('${item['price'] ?? ''}')} دينار عراقي',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),

            // عرض تعليقات الإدارة إذا كان مرفوض
            if (!isApproved &&
                item['adminComments'] != null &&
                item['adminComments'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'سبب الرفض:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['adminComments'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> item, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('موافقة على العنصر'),
        content: Text('هل أنت متأكد من الموافقة على "${item['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _approveItem(item, index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('موافقة'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> item, int index) {
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض العنصر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سبب رفض "${item['name']}"؟'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض',
                border: OutlineInputBorder(),
                hintText: 'اكتب السبب هنا...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.trim().isNotEmpty) {
                await _rejectItem(item, index, commentController.text.trim());
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى كتابة سبب الرفض')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveItem(Map<String, dynamic> item, int index) async {
    try {
      await FirebaseFirestore.instance
          .collection('provider_items')
          .doc(item['id'])
          .update({
            'status': 'active',
            'approvedAt': FieldValue.serverTimestamp(),
            'adminComments': '',
          });

      setState(() {
        _pendingItems.removeAt(index);
        item['status'] = 'active';
        _reviewedItems.insert(0, item);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت الموافقة على "${item['name']}" بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الموافقة: $e')));
    }
  }

  Future<void> _rejectItem(
    Map<String, dynamic> item,
    int index,
    String reason,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('provider_items')
          .doc(item['id'])
          .update({
            'status': 'rejected',
            'rejectedAt': FieldValue.serverTimestamp(),
            'adminComments': reason,
          });

      setState(() {
        _pendingItems.removeAt(index);
        item['status'] = 'rejected';
        item['adminComments'] = reason;
        _reviewedItems.insert(0, item);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم رفض "${item['name']}" بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الرفض: $e')));
    }
  }
}
