import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'deposit_receipt_screen.dart';

// ─────────────────────────────────────────
//  المستوى 1 — قائمة الفئات
// ─────────────────────────────────────────
class AdminBookingsScreen extends StatelessWidget {
  const AdminBookingsScreen({super.key});

  static const List<Map<String, dynamic>> _categories = [
    {'id': 'hall', 'name': 'قاعات أعراس', 'icon': Icons.celebration},
    {'id': 'hotel', 'name': 'فنادق', 'icon': Icons.hotel},
    {'id': 'restaurant', 'name': 'مطاعم', 'icon': Icons.restaurant},
    {'id': 'salon_care', 'name': 'صالونات', 'icon': Icons.spa},
    {'id': 'car', 'name': 'تأجير سيارات', 'icon': Icons.directions_car},
    {'id': 'photography', 'name': 'تصوير', 'icon': Icons.camera_alt},
    {'id': 'bride_dress', 'name': 'فساتين عروس', 'icon': Icons.checkroom},
    {'id': 'groom_suit', 'name': 'بدلات رجالية', 'icon': Icons.dry_cleaning},
    {
      'id': 'car_decoration',
      'name': 'تزيين سيارات',
      'icon': Icons.workspace_premium,
    },
    {'id': 'cake', 'name': 'كيك', 'icon': Icons.cake},
    {'id': 'flowers', 'name': 'ورود', 'icon': Icons.local_florist},
    {'id': 'honeymoon', 'name': 'شهر العسل', 'icon': Icons.flight_takeoff},
    {'id': 'bouquet', 'name': 'بوكيه الورد', 'icon': Icons.spa},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'الحجوزات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2B0606),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // إجمالي الحجوزات
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .snapshots(),
            builder: (context, snap) {
              final total = snap.data?.docs.length ?? 0;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B0606), Color(0xFF6E1229)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2B0606).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.book_online,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إجمالي الحجوزات',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '$total حجز',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // قائمة الفئات
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('category', isEqualTo: cat['id'])
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B0606).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            cat['icon'] as IconData,
                            color: const Color(0xFF2B0606),
                            size: 26,
                          ),
                        ),
                        title: Text(
                          cat['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          count == 0 ? 'لا توجد حجوزات' : '$count حجز',
                          style: TextStyle(
                            color: count == 0
                                ? Colors.grey
                                : const Color(0xFF6E1229),
                            fontWeight: count == 0
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: count > 0
                            ? const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(0xFF2B0606),
                              )
                            : null,
                        onTap: count == 0
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _AdminCategoryBookingsScreen(
                                    categoryId: cat['id'] as String,
                                    categoryName: cat['name'] as String,
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

// ─────────────────────────────────────────
//  المستوى 2 — مزودو الخدمة داخل الفئة
// ─────────────────────────────────────────
class _AdminCategoryBookingsScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const _AdminCategoryBookingsScreen({
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2B0606),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('category', isEqualTo: categoryId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد حجوزات في هذه الفئة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // ترتيب من الأحدث في Dart (لتجنب Composite Index في Firestore)
          final sortedDocs = List.of(docs)
            ..sort((a, b) {
              final ta = (a.data() as Map)['createdAt'];
              final tb = (b.data() as Map)['createdAt'];
              if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
              return 0;
            });

          // تجميع الحجوزات حسب اسم الخدمة (itemName)
          final Map<String, Map<String, dynamic>> providers = {};
          for (final doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final itemName = (data['itemName']?.toString().isNotEmpty == true)
                ? data['itemName']!.toString()
                : data['providerName']?.toString() ?? 'خدمة';
            final pid = itemName; // مفتاح التجميع = اسم الخدمة
            if (!providers.containsKey(pid)) {
              providers[pid] = {
                'id': data['providerId']?.toString() ?? '',
                'name': itemName,
                'providerName': data['providerName']?.toString() ?? '',
                'phone': data['providerPhone']?.toString() ?? '',
                'bookings': <Map<String, dynamic>>[],
              };
            }
            (providers[pid]!['bookings'] as List<Map<String, dynamic>>).add({
              ...data,
              'docId': doc.id,
            });
          }

          final providerList = providers.values.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: providerList.length,
            itemBuilder: (context, i) {
              final p = providerList[i];
              final bookings = p['bookings'] as List<Map<String, dynamic>>;
              final counts = _countByStatus(bookings);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AdminProviderBookingsScreen(
                        providerName: p['name'] as String,
                        providerPhone: p['phone'] as String,
                        bookings: bookings,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2B0606,
                                ).withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.store,
                                color: Color(0xFF2B0606),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if ((p['providerName'] as String? ?? '')
                                          .isNotEmpty &&
                                      p['providerName'] != p['name'])
                                    Text(
                                      'المزود: ${p['providerName']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if ((p['phone'] as String).isNotEmpty)
                                    Text(
                                      p['phone'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${bookings.length} حجز',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B0606),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (counts.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: counts.entries
                                .map(
                                  (e) =>
                                      _StatusChip(label: e.key, count: e.value),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, int> _countByStatus(List<Map<String, dynamic>> bookings) {
    final Map<String, int> result = {};
    for (final b in bookings) {
      final label = _statusLabel(b['status']?.toString() ?? '');
      result[label] = (result[label] ?? 0) + 1;
    }
    return result;
  }
}

// ─────────────────────────────────────────
//  المستوى 3 — تفاصيل حجوزات مزود معين
// ─────────────────────────────────────────
class _AdminProviderBookingsScreen extends StatefulWidget {
  final String providerName;
  final String providerPhone;
  final List<Map<String, dynamic>> bookings;

  const _AdminProviderBookingsScreen({
    required this.providerName,
    required this.providerPhone,
    required this.bookings,
  });

  @override
  State<_AdminProviderBookingsScreen> createState() =>
      _AdminProviderBookingsScreenState();
}

class _AdminProviderBookingsScreenState
    extends State<_AdminProviderBookingsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    // فلترة الحجوزات
    final filtered = _filter == 'all'
        ? widget.bookings
        : widget.bookings
              .where((b) => b['status']?.toString() == _filter)
              .toList();

    // ترتيب من الأحدث
    filtered.sort((a, b) {
      final ta = a['createdAt'];
      final tb = b['createdAt'];
      if (ta is Timestamp && tb is Timestamp) {
        return tb.compareTo(ta);
      }
      return 0;
    });

    // قائمة الحالات الفريدة للفلترة
    final statuses = {
      'all',
      ...widget.bookings.map((b) => b['status']?.toString() ?? ''),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.providerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2B0606),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _FilterChip(
                  label: 'الكل (${widget.bookings.length})',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                ...statuses.where((s) => s != 'all').map((s) {
                  final cnt = widget.bookings
                      .where((b) => b['status'] == s)
                      .length;
                  return _FilterChip(
                    label: '${_statusLabel(s)} ($cnt)',
                    selected: _filter == s,
                    onTap: () => setState(() => _filter = s),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Text(
                'لا توجد حجوزات بهذه الحالة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _BookingCard(booking: filtered[i]),
            ),
    );
  }
}

// ─────────────────────────────────────────
//  بطاقة الحجز التفصيلية
// ─────────────────────────────────────────
class _BookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final status = b['status']?.toString() ?? '';
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    String? dateStr;
    if (b['bookingDate'] is Timestamp) {
      dateStr = DateFormat(
        'yyyy/MM/dd',
        'ar',
      ).format((b['bookingDate'] as Timestamp).toDate());
    }
    String? createdStr;
    if (b['createdAt'] is Timestamp) {
      createdStr = DateFormat(
        'yyyy/MM/dd – HH:mm',
      ).format((b['createdAt'] as Timestamp).toDate());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // رأس البطاقة
          InkWell(
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // أيقونة الحالة
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _statusIcon(status),
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['itemName']?.toString() ??
                              b['customerName']?.toString() ??
                              'خدمة',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if ((b['customerName']?.toString() ?? '').isNotEmpty)
                          Text(
                            b['customerName']!.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            if (dateStr != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          // التفاصيل القابلة للطي
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // معلومات الزبون
                  _Section(
                    title: 'معلومات الزبون',
                    icon: Icons.person,
                    color: Colors.blue[700]!,
                    rows: [
                      _Row('الاسم', b['customerName']?.toString()),
                      _Row('الهاتف', b['customerPhone']?.toString()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // معلومات الحجز
                  _Section(
                    title: 'تفاصيل الحجز',
                    icon: Icons.event_note,
                    color: const Color(0xFF2B0606),
                    rows: [
                      _Row('اسم الخدمة', b['itemName']?.toString()),
                      _Row(
                        'رقم الحجز',
                        b['serialNumber']?.toString() ?? b['docId']?.toString(),
                      ),
                      _Row(
                        'السعر الأساسي',
                        _price(b['basePrice'] ?? b['price']),
                      ),
                      _Row('تاريخ الحجز', dateStr),
                      _Row('تاريخ الإنشاء', createdStr),
                      if ((b['notes']?.toString() ?? '').isNotEmpty)
                        _Row('ملاحظات', b['notes']?.toString()),
                      if ((b['deliveryAddress']?.toString() ?? '').isNotEmpty)
                        _Row('موقع التوصيل', b['deliveryAddress']?.toString()),
                    ],
                  ),
                  // معلومات العربون إن وجدت
                  if (_hasDepositInfo(b)) ...[
                    const SizedBox(height: 10),
                    _Section(
                      title: 'العربون',
                      icon: Icons.payments,
                      color: Colors.green[700]!,
                      rows: [
                        _Row('مبلغ العربون', _price(b['depositAmount'])),
                        if (b['depositDetails'] is Map) ...[
                          _Row(
                            'آخر 5 أرقام',
                            (b['depositDetails'] as Map)['last5Digits']
                                ?.toString(),
                          ),
                          _Row(
                            'اسم المرسل',
                            (b['depositDetails'] as Map)['senderName']
                                ?.toString(),
                          ),
                          _Row(
                            'تاريخ التحويل',
                            (b['depositDetails'] as Map)['date']?.toString(),
                          ),
                        ],
                        if (b['depositConfirmedAt'] is Timestamp)
                          _Row(
                            'تاريخ التأكيد',
                            DateFormat('yyyy/MM/dd – HH:mm').format(
                              (b['depositConfirmedAt'] as Timestamp).toDate(),
                            ),
                          ),
                      ],
                    ),
                  ],
                  // سبب الرفض / الإلغاء إن وجد
                  if ((b['rejectionReason']?.toString() ?? '').isNotEmpty ||
                      (b['cancellationReason']?.toString() ?? '')
                          .isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _Section(
                      title: 'سبب الرفض / الإلغاء',
                      icon: Icons.cancel,
                      color: Colors.red[700]!,
                      rows: [
                        _Row(
                          'السبب',
                          b['rejectionReason']?.toString() ??
                              b['cancellationReason']?.toString(),
                        ),
                      ],
                    ),
                  ],
                  // زر عرض الإيصال عند اكتمال الحجز
                  if (b['status'] == 'deposit_confirmed') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DepositReceiptScreen(
                                bookingId: b['docId']?.toString() ?? '',
                                customerName:
                                    b['customerName']?.toString() ?? 'الزبون',
                                basePrice:
                                    b['basePrice']?.toString() ??
                                    b['price']?.toString() ??
                                    '0',
                                depositAmount: (b['depositAmount'] is num)
                                    ? (b['depositAmount'] as num).toDouble()
                                    : double.tryParse(
                                            b['depositAmount']?.toString() ??
                                                '0',
                                          ) ??
                                          0,
                                serialNumber: b['serialNumber']?.toString(),
                                itemName: b['itemName']?.toString(),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text(
                          'عرض الإيصال',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _hasDepositInfo(Map<String, dynamic> b) {
    return (b['depositAmount'] != null) ||
        (b['depositDetails'] != null) ||
        (b['depositConfirmedAt'] != null);
  }

  String _price(dynamic val) {
    if (val == null) return 'غير محدد';
    final d = double.tryParse(val.toString());
    if (d == null) return val.toString();
    return NumberFormat('#,###', 'ar').format(d) + ' د.ع';
  }
}

// ─────────────────────────────────────────
//  Widgets مساعدة
// ─────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> rows;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final validRows = rows.whereType<_InfoRow>().toList();
    if (validRows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 10),
          ...validRows,
        ],
      ),
    );
  }
}

// دالة توليد صف معلومات (ترجع null إذا كانت القيمة فارغة)
Widget _Row(String label, String? value) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();
  return _InfoRow(label: label, value: value);
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  const _StatusChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = _statusColorByLabel(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : Colors.white54),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? const Color(0xFF2B0606) : Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  دوال مساعدة للحالات
// ─────────────────────────────────────────
String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'بانتظار الموافقة';
    case 'modified':
      return 'معدَّل من الزبون';
    case 'awaiting_deposit':
      return 'بانتظار العربون';
    case 'deposit_submitted':
      return 'عربون مرسل';
    case 'deposit_confirmed':
      return 'تم استلام العربون';
    case 'confirmed':
      return 'مؤكد';
    case 'approved':
      return 'مقبول';
    case 'rejected':
      return 'مرفوض';
    case 'cancelled':
      return 'ملغى من الزبون';
    case 'auto_cancelled':
      return 'ملغى تلقائياً';
    default:
      return status.isNotEmpty ? status : 'غير محدد';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.orange;
    case 'modified':
      return Colors.amber[700]!;
    case 'awaiting_deposit':
      return Colors.blue;
    case 'deposit_submitted':
      return Colors.indigo;
    case 'deposit_confirmed':
      return Colors.green[700]!;
    case 'confirmed':
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    case 'cancelled':
      return Colors.red[300]!;
    case 'auto_cancelled':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

Color _statusColorByLabel(String label) {
  if (label.contains('بانتظار الموافقة')) return Colors.orange;
  if (label.contains('معدَّل')) return Colors.amber[700]!;
  if (label.contains('بانتظار العربون')) return Colors.blue;
  if (label.contains('عربون مرسل')) return Colors.indigo;
  if (label.contains('استلام العربون')) return Colors.green[700]!;
  if (label.contains('مؤكد') || label.contains('مقبول')) return Colors.green;
  if (label.contains('مرفوض')) return Colors.red;
  if (label.contains('ملغى')) return Colors.red[300]!;
  return Colors.grey;
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.hourglass_empty;
    case 'modified':
      return Icons.edit_note;
    case 'awaiting_deposit':
      return Icons.account_balance_wallet;
    case 'deposit_submitted':
      return Icons.send;
    case 'deposit_confirmed':
      return Icons.verified;
    case 'confirmed':
    case 'approved':
      return Icons.check_circle;
    case 'rejected':
      return Icons.cancel;
    case 'cancelled':
    case 'auto_cancelled':
      return Icons.block;
    default:
      return Icons.info_outline;
  }
}
