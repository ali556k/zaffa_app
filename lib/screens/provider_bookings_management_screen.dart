import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

/// شاشة إدارة الحجوزات لمزود الخدمة
class ProviderBookingsManagementScreen extends StatefulWidget {
  const ProviderBookingsManagementScreen({super.key});

  @override
  State<ProviderBookingsManagementScreen> createState() =>
      _ProviderBookingsManagementScreenState();
}

class _ProviderBookingsManagementScreenState
    extends State<ProviderBookingsManagementScreen> {
  final BookingService _bookingService = BookingService();
  String _providerId = '';
  bool _isLoading = true;

  Stream<QuerySnapshot> get _bookingsStream {
    // يبحث بـ providerId (قد يكون رقم هاتف أو معرف آخر)
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: _providerId)
        .orderBy('bookingDate', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> get _bookingsByPhoneStream {
    // يبحث بـ providerPhone كـ fallback
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('providerPhone', isEqualTo: _providerId)
        .orderBy('bookingDate', descending: true)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _loadProviderId();
  }

  /// تحميل معرف المزود
  Future<void> _loadProviderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      setState(() {
        _providerId = phone;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل معرف المزود: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'إدارة الحجوزات',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6E1229),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _bookingsStream,
        builder: (context, snap1) {
          return StreamBuilder<QuerySnapshot>(
            stream: _bookingsByPhoneStream,
            builder: (context, snap2) {
              final loading = snap1.connectionState == ConnectionState.waiting ||
                  snap2.connectionState == ConnectionState.waiting;
              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap1.hasError || snap2.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ: ${snap1.error ?? snap2.error}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                );
              }
              // دمج النتائج مع إزالة التكرار بالـ doc id
              final seen = <String>{};
              final docs = [
                ...?(snap1.data?.docs),
                ...?(snap2.data?.docs),
              ].where((d) => seen.add(d.id)).toList();

              // ترتيب تنازلي حسب bookingDate
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aDate = (aData['bookingDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
                final bDate = (bData['bookingDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
                return bDate.compareTo(aDate);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد حجوزات حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ستظهر الحجوزات الجديدة هنا',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final rawData = doc.data() as Map<String, dynamic>;
                  final booking = BookingModel.fromMap(rawData, doc.id);
                  return _buildBookingCard(booking, rawData);
                },
              );
            },
          );
        },
      ),
    );
  }

  /// بطاقة الحجز
  Widget _buildBookingCard(BookingModel booking, Map<String, dynamic> rawData) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'ar');
    final formattedDate = dateFormat.format(booking.bookingDate);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (booking.isCancelled) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'ملغي';
    } else if (booking.status == 'modified' || booking.isModified) {
      statusColor = Colors.blue;
      statusIcon = Icons.edit;
      statusText = 'معدل';
    } else if (booking.status == 'confirmed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'مؤكد';
    } else if (booking.dayStatus == DayStatus.fullyBooked) {
      statusColor = Colors.red;
      statusIcon = Icons.event_busy;
      statusText = 'محجوز كامل';
    } else if (booking.dayStatus == DayStatus.partiallyBooked) {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
      statusText = 'محجوز جزئي';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.event_available;
      statusText = 'متاح';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.itemName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // محتوى البطاقة
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات الزبون
                _buildInfoRow(
                  icon: Icons.person,
                  label: 'الزبون',
                  value: booking.customerName,
                  iconColor: const Color(0xFF1E88E5),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.phone,
                  label: 'الهاتف',
                  value: booking.customerPhone,
                  iconColor: const Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'التاريخ',
                  value: formattedDate,
                  iconColor: const Color(0xFFF59E0B),
                ),

                // حالة التعديل الأخيرة
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.info_outline,
                  label: 'الحالة',
                  value: booking.status == 'modified' || booking.isModified
                      ? 'معدل' : booking.status == 'confirmed'
                      ? 'مؤكد' : (booking.isCancelled ? 'ملغي' : 'قيد الانتظار'),
                  iconColor: booking.status == 'modified' || booking.isModified
                      ? Colors.blue : booking.status == 'confirmed'
                      ? Colors.green : booking.isCancelled
                      ? Colors.red : Colors.grey,
                ),

                // الوقت (إذا كان حجز جزئي)
                if (booking.timeSlot != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.access_time,
                    label: 'الوقت',
                    value:
                        '${booking.timeSlot!.startTime} - ${booking.timeSlot!.endTime}',
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                ],

                // الملاحظات
                if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: TextButton.icon(
                      onPressed: booking.isModified || booking.status == 'modified'
                          ? () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('عرض التعديلات'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('الحالة الحالية: ${booking.status == 'modified' || booking.isModified ? 'معدل' : booking.status}'),
                                      if (booking.originalDate != null)
                                        Text('التاريخ السابق: ${DateFormat('dd/MM/yyyy').format(booking.originalDate!)}'),
                                      if (booking.originalTimeSlot != null)
                                        Text('الوقت السابق: ${booking.originalTimeSlot!.startTime} - ${booking.originalTimeSlot!.endTime}'),
                                      const SizedBox(height: 8),
                                      Text('التاريخ الحالي: ${formattedDate}'),
                                      if (booking.timeSlot != null)
                                        Text('الوقت الحالي: ${booking.timeSlot!.startTime} - ${booking.timeSlot!.endTime}'),
                                      if (booking.notes != null)
                                        Text('ملاحظات: ${booking.notes}'),
                                      if (booking.modifiedAt != null)
                                        Text('آخر تعديل: ${DateFormat('dd/MM/yyyy HH:mm').format(booking.modifiedAt!)}'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إغلاق'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.history),
                      label: const Text('عرض التعديلات'),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notes,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ملاحظات:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          booking.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // حقل التوصيل إلى (يظهر فقط إذا أدخله الزبون)
                if ((rawData['deliveryAddress'] != null &&
                        rawData['deliveryAddress'].toString().isNotEmpty) ||
                    (rawData['deliveryLat'] != null &&
                        rawData['deliveryLng'] != null)) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6E1229).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6E1229).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 18,
                              color: const Color(0xFF6E1229),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'التوصيل إلى:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6E1229),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (rawData['deliveryAddress'] != null &&
                                  rawData['deliveryAddress']
                                      .toString()
                                      .isNotEmpty)
                              ? rawData['deliveryAddress']
                              : 'تم تحديد موقع التوصيل على الخريطة',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (rawData['deliveryLat'] != null &&
                            rawData['deliveryLng'] != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 160,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    (rawData['deliveryLat'] as num).toDouble(),
                                    (rawData['deliveryLng'] as num).toDouble(),
                                  ),
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('delivery'),
                                    position: LatLng(
                                      (rawData['deliveryLat'] as num)
                                          .toDouble(),
                                      (rawData['deliveryLng'] as num)
                                          .toDouble(),
                                    ),
                                    infoWindow: const InfoWindow(
                                      title: 'موقع التوصيل',
                                    ),
                                  ),
                                },
                                zoomControlsEnabled: false,
                                myLocationButtonEnabled: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final lat = (rawData['deliveryLat'] as num)
                                    .toDouble();
                                final lng = (rawData['deliveryLng'] as num)
                                    .toDouble();
                                final uri = Uri.parse(
                                  'https://www.google.com/maps?q=$lat,$lng',
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('فتح في خرائط جوجل'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6E1229),
                                side: const BorderSide(
                                  color: Color(0xFF6E1229),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // أزرار الإجراءات
                Row(
                  children: [
                    // زر إلغاء الحجز
                    if (!booking.isCancelled) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmCancelBooking(booking),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cancel, size: 20),
                          label: const Text(
                            'إلغاء الحجز',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'الحجز ملغي',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// صف المعلومات
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// تأكيد إلغاء الحجز
  void _confirmCancelBooking(BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'تأكيد الإلغاء',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل أنت متأكد من إلغاء هذا الحجز؟',
              style: TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'العنصر: ${booking.itemName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الزبون: ${booking.customerName}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  Text(
                    'التاريخ: ${DateFormat('dd/MM/yyyy', 'ar').format(booking.bookingDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'سيتم إرجاع هذا التاريخ إلى حالة "متاح" وسيتمكن الزبائن الآخرون من حجزه.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'رجوع',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking(booking);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'إلغاء الحجز',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// إلغاء الحجز
  Future<void> _cancelBooking(BookingModel booking) async {
    try {
      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _bookingService.cancelBooking(booking.id!, 'provider');

      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      // عرض رسالة النجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('booking_cancelled'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      // عرض رسالة الخطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
