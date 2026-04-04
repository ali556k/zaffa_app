import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/chat_helper.dart';
import '../models/booking_model.dart';
import 'booking_screen.dart';

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

  Future<void> _editBooking(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> bookingData,
  ) async {
    // تجهيز بيانات الخدمة من بيانات الحجز
    final serviceData = <String, dynamic>{
      'id': bookingData['itemId'] ?? '',
      'name': bookingData['itemName'] ?? '',
      'providerId': bookingData['providerId'] ?? '',
      'providerName': bookingData['providerName'] ?? '',
      'providerPhone': bookingData['providerPhone'] ?? '',
      'serviceType': bookingData['category'] ?? '',
      'category': bookingData['category'] ?? '',
      'price': bookingData['basePrice'] ?? bookingData['price'] ?? '',
    };

    // استخراج بيانات الحجز الحالية
    DateTime? existingDate;
    if (bookingData['bookingDate'] != null) {
      existingDate = (bookingData['bookingDate'] as Timestamp).toDate();
    }

    TimeSlot? existingTimeSlot;
    if (bookingData['timeSlot'] != null) {
      existingTimeSlot = TimeSlot.fromMap(
        bookingData['timeSlot'] as Map<String, dynamic>,
      );
    }

    // إيجاد orderId المرتبط بالحجز
    final orderId = bookingData['orderId']?.toString() ?? '';
    final editOrderId = orderId.isNotEmpty ? orderId : bookingId;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          serviceData: serviceData,
          existingItemPrice:
              (bookingData['basePrice'] ?? bookingData['price'] ?? '')
                  .toString()
                  .replaceAll(RegExp(r'[^\d.]'), ''),
          isEditMode: true,
          editOrderId: editOrderId,
          orderId: editOrderId,
          existingScheduledAt: existingDate,
          existingIsFullDayBooking: bookingData['timeSlot'] == null,
          existingTimeSlot: existingTimeSlot,
          existingNotes: bookingData['notes']?.toString(),
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {}); // تحديث القائمة
    }
  }

  Future<void> _launchMapsUrl(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
              // قسم التوصيل
              Builder(
                builder: (context) {
                  final deliveryAddress = bookingData['deliveryAddress']
                      ?.toString();
                  final deliveryLat = bookingData['deliveryLat'] is num
                      ? (bookingData['deliveryLat'] as num).toDouble()
                      : null;
                  final deliveryLng = bookingData['deliveryLng'] is num
                      ? (bookingData['deliveryLng'] as num).toDouble()
                      : null;
                  if ((deliveryAddress == null || deliveryAddress.isEmpty) &&
                      (deliveryLat == null || deliveryLng == null)) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B0606).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF2B0606).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.delivery_dining,
                                  color: Color(0xFF2B0606),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'موقع التوصيل',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B0606),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (deliveryAddress != null &&
                                      deliveryAddress.isNotEmpty)
                                  ? deliveryAddress
                                  : 'تم تحديد موقع التوصيل على الخريطة',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (deliveryLat != null && deliveryLng != null) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _launchMapsUrl(deliveryLat, deliveryLng),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2B0606),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.map_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'عرض موقع التوصيل في الخريطة',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

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

  Widget _buildStatusBadge(String? status, bool isCancelled) {
    Color color;
    String text;
    IconData icon;

    if (isCancelled) {
      color = Colors.red;
      text = 'ملغى';
      icon = Icons.cancel;
    } else {
      switch (status) {
        case 'تم التأكيد':
        case 'confirmed':
          color = Colors.green;
          text = 'مؤكد';
          icon = Icons.check_circle;
          break;
        case 'مرفوض':
        case 'rejected':
          color = Colors.red;
          text = 'مرفوض';
          icon = Icons.cancel;
          break;
        case 'modified':
          color = Colors.blue;
          text = 'معدَّل';
          icon = Icons.edit;
          break;
        case 'pending':
        case 'بانتظار التأكيد':
        default:
          color = Colors.orange;
          text = 'قيد الانتظار';
          icon = Icons.hourglass_empty;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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

                    // بيانات التوصيل
                    final deliveryAddress = bookingData['deliveryAddress']
                        ?.toString();
                    final deliveryLat = bookingData['deliveryLat'] is num
                        ? (bookingData['deliveryLat'] as num).toDouble()
                        : null;
                    final deliveryLng = bookingData['deliveryLng'] is num
                        ? (bookingData['deliveryLng'] as num).toDouble()
                        : null;
                    final hasDelivery =
                        (deliveryAddress != null &&
                            deliveryAddress.isNotEmpty) ||
                        (deliveryLat != null && deliveryLng != null);

                    // حساب نافذة التعديل (24 ساعة من الإنشاء)
                    DateTime? createdAtDate;
                    if (bookingData['createdAt'] != null) {
                      createdAtDate = (bookingData['createdAt'] as Timestamp)
                          .toDate();
                    }
                    final now = DateTime.now();
                    final canEdit =
                        !isCancelled &&
                        (bookingData['status'] == 'pending' ||
                            bookingData['status'] == 'بانتظار التأكيد' ||
                            bookingData['status'] == null) &&
                        (createdAtDate == null ||
                            now.difference(createdAtDate).inHours < 24);
                    final withinWindow =
                        createdAtDate != null &&
                        now.difference(createdAtDate).inHours < 24;
                    final hoursLeft = createdAtDate != null
                        ? 24 - now.difference(createdAtDate).inHours
                        : 0;

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
                                    _buildStatusBadge(
                                      bookingData['status']?.toString(),
                                      isCancelled,
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

                                // موقع التوصيل
                                if (hasDelivery) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.delivery_dining,
                                        size: 16,
                                        color: Color(0xFF2B0606),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (deliveryAddress != null &&
                                                  deliveryAddress.isNotEmpty)
                                              ? 'التوصيل إلى: $deliveryAddress'
                                              : 'تم تحديد موقع التوصيل على الخريطة',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF2B0606),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (deliveryLat != null &&
                                          deliveryLng != null)
                                        IconButton(
                                          onPressed: () async {
                                            final uri = Uri.parse(
                                              'https://www.google.com/maps/search/?api=1&query=$deliveryLat,$deliveryLng',
                                            );
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.map,
                                            size: 20,
                                            color: Color(0xFF2B0606),
                                          ),
                                          tooltip: 'عرض في الخريطة',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                ],

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

                                // تحذير نافذة التعديل
                                if (!isCancelled &&
                                    (bookingData['status'] == 'pending' ||
                                        bookingData['status'] ==
                                            'بانتظار التأكيد' ||
                                        bookingData['status'] == null)) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: canEdit
                                          ? Colors.orange.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: canEdit
                                            ? Colors.orange[300]!
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          canEdit
                                              ? Icons.timer_outlined
                                              : Icons.lock_outline,
                                          size: 16,
                                          color: canEdit
                                              ? Colors.orange[700]
                                              : Colors.grey[500],
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            canEdit
                                                ? 'يمكن تعديل الطلب خلال اول 24 ساعة من تثبيت الحجز'
                                                : 'انتهت نافذة التعديل (24 ساعة)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: canEdit
                                                  ? Colors.orange[800]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

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
                                    // زر تعديل الطلب (نافذة 24 ساعة)
                                    if (!isCancelled &&
                                        (bookingData['status'] == 'pending' ||
                                            bookingData['status'] ==
                                                'بانتظار التأكيد' ||
                                            bookingData['status'] == null)) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Tooltip(
                                          message: canEdit
                                              ? 'يمكنك التعديل خلال $hoursLeft ساعة متبقية'
                                              : 'انتهت نافذة التعديل (24 ساعة)',
                                          child: OutlinedButton.icon(
                                            onPressed: canEdit
                                                ? () => _editBooking(
                                                    context,
                                                    bookingDoc.id,
                                                    bookingData,
                                                  )
                                                : null,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: canEdit
                                                  ? Colors.orange[700]
                                                  : Colors.grey[400],
                                              side: BorderSide(
                                                color: canEdit
                                                    ? Colors.orange[700]!
                                                    : Colors.grey[300]!,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: Icon(
                                              canEdit
                                                  ? Icons.edit_outlined
                                                  : Icons.lock_outline,
                                              size: 18,
                                            ),
                                            label: Text(
                                              canEdit ? 'تعديل' : 'منتهي',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
