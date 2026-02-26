import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/chat_helper.dart';
import '../models/booking_model.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with AutomaticKeepAliveClientMixin {
  String? _currentUserPhone;
  bool _hasLoadedData = false;

  @override
  bool get wantKeepAlive => true; // للحفاظ على حالة الشاشة

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserPhone = prefs.getString('user_phone');
      if (_currentUserPhone != null && !_hasLoadedData) {
        _hasLoadedData = true;
      }
    });
  }

  void _openChat(BookingModel booking, BuildContext context) {
    // فتح المحادثة مع المزود باستخدام ChatHelper
    ChatHelper.startChatWithUser(
      context: context,
      otherUserId: booking.providerId,
      otherUserName: booking.providerName,
      otherUserRole: 'provider',
      serviceName: booking.itemName, // اسم الخدمة من الحجز
    );
  }

  void _showBookingDetailsFromData(
    String bookingId,
    Map<String, dynamic> bookingData,
  ) {
    final itemName = bookingData['itemName'] ?? 'خدمة';
    final providerName = bookingData['providerName'] ?? 'مزود الخدمة';
    final providerId = bookingData['providerId'] ?? '';
    // ignore: unused_local_variable
    final itemId = bookingData['itemId'] ?? '';
    final category = bookingData['category'] ?? '';
    final isCancelled = bookingData['isCancelled'] == true;
    final notes = bookingData['notes'];
    final price = bookingData['price'] ?? '';

    DateTime? bookingDate;
    if (bookingData['bookingDate'] != null) {
      bookingDate = (bookingData['bookingDate'] as Timestamp).toDate();
    }

    DateTime? createdAt;
    if (bookingData['createdAt'] != null) {
      createdAt = (bookingData['createdAt'] as Timestamp).toDate();
    }

    DateTime? cancelledAt;
    if (bookingData['cancelledAt'] != null) {
      cancelledAt = (bookingData['cancelledAt'] as Timestamp).toDate();
    }

    String? timeSlotText;
    if (bookingData['timeSlot'] != null) {
      final timeSlot = bookingData['timeSlot'] as Map<String, dynamic>;
      timeSlotText = '${timeSlot['startTime']} - ${timeSlot['endTime']}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF2B0606)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تفاصيل الحجز',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B0606),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('اسم الخدمة', itemName),
              SizedBox(height: 12),
              _buildDetailRow('مزود الخدمة', providerName),
              SizedBox(height: 12),
              _buildDetailRow('نوع الخدمة', _getCategoryName(category)),
              if (price.isNotEmpty) ...[
                SizedBox(height: 12),
                _buildDetailRow('السعر', price),
              ],
              Divider(height: 24),
              if (bookingDate != null) ...[
                _buildDetailRow(
                  'تاريخ الحجز',
                  DateFormat('EEEE، dd MMMM yyyy', 'ar').format(bookingDate),
                ),
                SizedBox(height: 12),
              ],
              if (timeSlotText != null) ...[
                _buildDetailRow('الوقت', timeSlotText),
                SizedBox(height: 12),
                _buildDetailRow('نوع الحجز', 'حجز جزئي'),
              ] else ...[
                _buildDetailRow('نوع الحجز', 'حجز يوم كامل'),
              ],
              if (createdAt != null) ...[
                SizedBox(height: 12),
                _buildDetailRow(
                  'تاريخ الإنشاء',
                  DateFormat('dd/MM/yyyy - HH:mm', 'ar').format(createdAt),
                ),
              ],
              if (notes != null && notes.toString().isNotEmpty) ...[
                Divider(height: 24),
                Text(
                  'ملاحظات:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  notes.toString(),
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ],
              if (isCancelled) ...[
                Divider(height: 24),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'حجز ملغى',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (cancelledAt != null) ...[
                        SizedBox(height: 8),
                        Text(
                          'تاريخ الإلغاء: ${DateFormat('dd/MM/yyyy - HH:mm', 'ar').format(cancelledAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: TextStyle(fontSize: 16)),
          ),
          if (!isCancelled && providerId.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final booking = BookingModel.fromMap(bookingData, bookingId);
                _openChat(booking, context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2B0606),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: Icon(Icons.chat, size: 18),
              label: Text('تواصل مع المزود'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  String _getCategoryName(String category) {
    final categoryNames = {
      'hall': 'قاعات أعراس',
      'hotel': 'فنادق',
      'salon_care': 'صالونات',
      'car': 'تأجير سيارات',
      'photography': 'تصوير',
      'restaurant': 'مطاعم',
      'bride_dress': 'فستان عروس',
      'groom_suit': 'بدلات رجالية',
      'car_decoration': 'تزيين سيارات',
      'cake': 'كيك',
      'flowers': 'ورود',
      'honeymoon': 'شهر العسل',
    };
    return categoryNames[category] ?? category;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب لـ AutomaticKeepAliveClientMixin

    if (_currentUserPhone == null) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 216, 208, 208),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 216, 208, 208),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: Text('حجوزاتي', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('customerId', isEqualTo: _currentUserPhone)
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2B0606),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'حدث خطأ في تحميل الحجوزات',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الخطأ: ${snapshot.error}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[300],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد حجوزات حالياً',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'ابدأ بحجز خدمة من الصفحة',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allBookings = snapshot.data!.docs;

                // فصل الحجوزات النشطة والملغاة
                final activeBookings = allBookings
                    .where(
                      (doc) =>
                          (doc.data() as Map<String, dynamic>)['isCancelled'] !=
                          true,
                    )
                    .toList();
                final cancelledBookings = allBookings
                    .where(
                      (doc) =>
                          (doc.data() as Map<String, dynamic>)['isCancelled'] ==
                          true,
                    )
                    .toList();

                final displayBookings = [
                  ...activeBookings,
                  ...cancelledBookings,
                ];

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: displayBookings.length,
                  itemBuilder: (context, index) {
                    final bookingDoc = displayBookings[index];
                    final bookingData =
                        bookingDoc.data() as Map<String, dynamic>;

                    final itemName = bookingData['itemName'] ?? 'خدمة';
                    final providerName =
                        bookingData['providerName'] ?? 'مزود الخدمة';
                    final category = bookingData['category'] ?? '';
                    final isCancelled = bookingData['isCancelled'] == true;
                    final price = bookingData['price'] ?? '';

                    // تحويل التاريخ
                    DateTime? bookingDate;
                    if (bookingData['bookingDate'] != null) {
                      bookingDate = (bookingData['bookingDate'] as Timestamp)
                          .toDate();
                    }

                    // الوقت
                    String? timeSlotText;
                    if (bookingData['timeSlot'] != null) {
                      final timeSlot =
                          bookingData['timeSlot'] as Map<String, dynamic>;
                      timeSlotText =
                          '${timeSlot['startTime']} - ${timeSlot['endTime']}';
                    }

                    // تحديد حالة الحجز ولونه
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      elevation: isCancelled ? 1 : 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _showBookingDetailsFromData(
                          bookingDoc.id,
                          bookingData,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Opacity(
                          opacity: isCancelled ? 0.6 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // العنوان والحالة
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            itemName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2B0606),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getCategoryName(category),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCancelled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.red,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.cancel,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'ملغى',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const Divider(height: 20),

                                // اسم المزود
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'المزود: $providerName',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // التاريخ
                                if (bookingDate != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'التاريخ: ${DateFormat('dd/MM/yyyy', 'ar').format(bookingDate)}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 6),

                                // الوقت (إذا كان حجز جزئي)
                                if (timeSlotText != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'الوقت: $timeSlotText',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.event,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'النوع: حجز يوم كامل',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),

                                // السعر
                                if (price.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.payments,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'السعر: $price',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2B0606),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // أزرار الإجراءات
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _showBookingDetailsFromData(
                                              bookingDoc.id,
                                              bookingData,
                                            ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Color(0xFF2B0606),
                                          side: BorderSide(
                                            color: Color(0xFF2B0606),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.info_outline,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'التفاصيل',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    if (!isCancelled) ...[
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            final booking =
                                                BookingModel.fromMap(
                                                  bookingData,
                                                  bookingDoc.id,
                                                );
                                            _openChat(booking, context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF2B0606,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: Icon(Icons.chat, size: 18),
                                          label: Text(
                                            'تواصل',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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
