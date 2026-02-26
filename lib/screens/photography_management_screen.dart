import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/image_viewer.dart';

class PhotographyManagementScreen extends StatefulWidget {
  final String providerId;

  const PhotographyManagementScreen({super.key, required this.providerId});

  @override
  _PhotographyManagementScreenState createState() =>
      _PhotographyManagementScreenState();
}

class _PhotographyManagementScreenState
    extends State<PhotographyManagementScreen> {
  Map<String, dynamic>? _photographyData;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  bool _isEditing = false;

  // Controllers للتعديل
  final _serviceNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pricePerHourController = TextEditingController();
  final _cameraTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verifyPhotographyProvider();
  }

  // فحص أن المزود هو مزود تصوير
  Future<void> _verifyPhotographyProvider() async {
    try {
      // البحث في published_providers أولاً
      var providerDoc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(widget.providerId)
          .get();

      // إذا لم يكن موجوداً، ابحث في provider_requests
      if (!providerDoc.exists) {
        providerDoc = await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(widget.providerId)
            .get();
      }

      if (!providerDoc.exists) {
        _showError('مزود الخدمة غير موجود');
        return;
      }

      final category = providerDoc.data()?['category'] ?? '';
      final serviceType = providerDoc.data()?['serviceType'] ?? '';
      if (category != 'photography' &&
          serviceType != 'التصوير' &&
          serviceType != 'جلسات تصوير') {
        _showError('هذه الخدمة مخصصة لمزودي خدمات التصوير فقط');
        Navigator.of(context).pop();
        return;
      }

      // إذا كان التحقق ناجحاً، قم بتحميل البيانات
      _loadPhotographyData();
    } catch (e) {
      print('خطأ في التحقق: $e');
      _showError('خطأ في التحقق من صحة المزود');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _loadPhotographyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // جلب بيانات التصوير من published_providers أولاً
      var photographyDoc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(widget.providerId)
          .get();

      // إذا لم يكن موجوداً، ابحث في provider_requests
      if (!photographyDoc.exists) {
        photographyDoc = await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(widget.providerId)
            .get();
      }

      if (photographyDoc.exists) {
        _photographyData = photographyDoc.data();
        _populateControllers();
      }

      // جلب الحجوزات
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: widget.providerId)
          .orderBy('eventDate', descending: false)
          .get();

      _bookings = bookingsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('خطأ في جلب بيانات التصوير: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _populateControllers() {
    if (_photographyData != null) {
      _serviceNameController.text = _photographyData!['serviceName'] ?? '';
      _descriptionController.text = _photographyData!['description'] ?? '';
      _pricePerHourController.text =
          _photographyData!['pricePerHour']?.toString() ??
          _photographyData!['price']?.toString() ??
          '';
      _cameraTypeController.text = _photographyData!['cameraType'] ?? '';
    }
  }

  Future<void> _updatePhotographyData() async {
    if (_photographyData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final pricePerHour = double.tryParse(_pricePerHourController.text) ?? 0.0;

      final updatedData = {
        'serviceName': _serviceNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'pricePerHour': pricePerHour,
        'price': pricePerHour, // للتوافق
        'basePrice': pricePerHour,
        'cameraType': _cameraTypeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // تحديث البيانات في published_providers إذا كان موجوداً
      final publishedDoc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(widget.providerId)
          .get();

      if (publishedDoc.exists) {
        await FirebaseFirestore.instance
            .collection('published_providers')
            .doc(widget.providerId)
            .update(updatedData);
      }

      // تحديث البيانات في provider_requests إذا كان موجوداً
      final requestDoc = await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(widget.providerId)
          .get();

      if (requestDoc.exists) {
        await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(widget.providerId)
            .update(updatedData);
      }

      setState(() {
        _photographyData = {..._photographyData!, ...updatedData};
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تحديث بيانات خدمة التصوير بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      _loadPhotographyData(); // إعادة تحميل البيانات
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث البيانات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _blockDate(DateTime date, {String? timeSlot}) async {
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(date);

      // تحديد المجموعة الصحيحة للتحديث
      String collection = 'published_providers';

      // التحقق من وجود المستند في published_providers
      var doc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(widget.providerId)
          .get();

      // إذا لم يكن موجوداً، استخدم provider_requests
      if (!doc.exists) {
        collection = 'provider_requests';
        doc = await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(widget.providerId)
            .get();
      }

      // التحقق من وجود المستند
      if (!doc.exists) {
        throw Exception('لم يتم العثور على بيانات الخدمة');
      }

      if (timeSlot != null) {
        // حجب فترة زمنية محددة فقط
        final slotKey = '$dateString:$timeSlot';
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(widget.providerId)
            .update({
              'blockedTimeSlots': FieldValue.arrayUnion([slotKey]),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حجب الفترة $timeSlot في ${DateFormat('dd/MM/yyyy').format(date)}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // حجب اليوم كاملاً
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(widget.providerId)
            .update({
              'blockedDates': FieldValue.arrayUnion([dateString]),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حجب تاريخ ${DateFormat('dd/MM/yyyy').format(date)} بالكامل',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadPhotographyData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حجب التاريخ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unblockDate(String dateString) async {
    try {
      // تحديد المجموعة الصحيحة للتحديث
      String collection = 'published_providers';

      // التحقق من وجود المستند في published_providers
      var doc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(widget.providerId)
          .get();

      // إذا لم يكن موجوداً، استخدم provider_requests
      if (!doc.exists) {
        collection = 'provider_requests';
        doc = await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(widget.providerId)
            .get();
      }

      // التحقق من وجود المستند
      if (!doc.exists) {
        throw Exception('لم يتم العثور على بيانات الخدمة');
      }

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.providerId)
          .update({
            'blockedDates': FieldValue.arrayRemove([dateString]),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إلغاء حجب التاريخ $dateString'),
          backgroundColor: Colors.green,
        ),
      );

      _loadPhotographyData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إلغاء حجب التاريخ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _descriptionController.dispose();
    _pricePerHourController.dispose();
    _cameraTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('إدارة خدمة التصوير'),
          backgroundColor: const Color(0xFF7B1FA2),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_photographyData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('إدارة خدمة التصوير'),
          backgroundColor: const Color(0xFF7B1FA2),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'لم يتم العثور على بيانات خدمة التصوير',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_photographyData!['serviceName'] ?? 'إدارة خدمة التصوير'),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing
                ? _updatePhotographyData
                : () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _populateControllers();
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الخدمة الأساسية
            _buildPhotographyInfoCard(),

            const SizedBox(height: 16),

            // معرض الصور
            _buildImageGalleryCard(),

            const SizedBox(height: 16),

            // إدارة التواريخ المحجوزة
            _buildDateManagementCard(),

            const SizedBox(height: 16),

            // الحجوزات الحالية
            _buildBookingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotographyInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt, color: Color(0xFF7B1FA2)),
                const SizedBox(width: 8),
                const Text(
                  'معلومات الخدمة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isEditing) ...[
              _buildEditableField('اسم الخدمة', _serviceNameController),
              const SizedBox(height: 12),
              _buildEditableField('الوصف', _descriptionController, maxLines: 3),
              const SizedBox(height: 12),
              _buildEditableField(
                'السعر للساعة الواحدة',
                _pricePerHourController,
              ),
              const SizedBox(height: 12),
              _buildEditableField(
                'نوع الكاميرا والمعدات',
                _cameraTypeController,
              ),
            ] else ...[
              _buildInfoRow(
                'اسم الخدمة',
                _photographyData!['serviceName'] ?? '',
              ),
              _buildInfoRow('الوصف', _photographyData!['description'] ?? ''),
              _buildInfoRow(
                'السعر للساعة',
                '${_photographyData!['pricePerHour'] ?? _photographyData!['price'] ?? 0} دينار',
              ),
              _buildInfoRow(
                'نوع الكاميرا',
                _photographyData!['cameraType'] ?? 'غير محدد',
              ),
              _buildInfoRow('المحافظة', _photographyData!['governorate'] ?? ''),
              _buildInfoRow('المنطقة', _photographyData!['area'] ?? ''),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageGalleryCard() {
    final images =
        _photographyData!['images'] as List<dynamic>? ??
        _photographyData!['imageUrls'] as List<dynamic>? ??
        [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, color: Color(0xFF7B1FA2)),
                const SizedBox(width: 8),
                Text(
                  'معرض الصور (${images.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (images.isEmpty)
              const Text('لا توجد صور', style: TextStyle(color: Colors.grey))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      openImageViewer(
                        context,
                        imageUrls: images.map((e) => e.toString()).toList(),
                        initialIndex: index,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateManagementCard() {
    final blockedDates =
        _photographyData!['blockedDates'] as List<dynamic>? ?? [];
    final blockedTimeSlots =
        _photographyData!['blockedTimeSlots'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range, color: Color(0xFF7B1FA2)),
                const SizedBox(width: 8),
                const Text(
                  'إدارة التواريخ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showDatePicker(),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('حجب تاريخ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // التواريخ المحجوبة بالكامل
            if (blockedDates.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.event_busy, size: 16, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    'أيام محجوبة بالكامل:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: blockedDates
                    .map(
                      (dateString) => Chip(
                        avatar: Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.red[700],
                        ),
                        label: Text(dateString),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _unblockDate(dateString),
                        backgroundColor: Colors.red.withOpacity(0.1),
                        deleteIconColor: Colors.red,
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 16),
            ],

            // الفترات الزمنية المحجوبة جزئياً
            if (blockedTimeSlots.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'فترات محجوبة جزئياً:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: blockedTimeSlots.map((slotKey) {
                  final parts = slotKey.toString().split(':');
                  final date = parts[0];
                  final time = parts.length > 1
                      ? parts.sublist(1).join(':')
                      : '';
                  return Chip(
                    avatar: Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    label: Text('$date | $time'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _unblockTimeSlot(slotKey),
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    deleteIconColor: Colors.orange,
                  );
                }).toList(),
              ),
            ],

            if (blockedDates.isEmpty && blockedTimeSlots.isEmpty)
              const Text(
                'لا توجد تواريخ أو فترات محجوبة',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: Color(0xFF7B1FA2)),
                const SizedBox(width: 8),
                Text(
                  'الحجوزات (${_bookings.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_bookings.isEmpty)
              const Text(
                'لا توجد حجوزات حالياً',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...(_bookings
                  .take(5)
                  .map(
                    (booking) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B1FA2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF7B1FA2).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                booking['customerName'] ?? 'عميل',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    booking['status'] ?? 'pending',
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getStatusText(
                                    booking['status'] ?? 'pending',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'التاريخ: ${booking['eventDate'] ?? ''}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (booking['hoursBooked'] != null)
                            Text(
                              'عدد الساعات: ${booking['hoursBooked']} ساعة',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          Text(
                            'الهاتف: ${booking['customerPhone'] ?? ''}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )),

            if (_bookings.length > 5)
              TextButton(
                onPressed: () {
                  // عرض جميع الحجوزات
                },
                child: const Text('عرض جميع الحجوزات'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      // عرض خيار: حجب كامل أو حجب فترة محددة
      _showBlockTypeDialog(picked);
    }
  }

  void _showBlockTypeDialog(DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('نوع الحجب', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'التاريخ: ${DateFormat('dd/MM/yyyy').format(date)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 20),

            // خيار حجب اليوم كاملاً
            ListTile(
              leading: Icon(Icons.event_busy, color: Colors.red),
              title: Text('حجب اليوم كاملاً'),
              subtitle: Text('لن يتمكن أي عميل من الحجز في هذا اليوم'),
              onTap: () {
                Navigator.pop(context);
                _blockDate(date);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            SizedBox(height: 12),

            // خيار حجب فترة محددة
            ListTile(
              leading: Icon(Icons.access_time, color: Colors.orange),
              title: Text('حجب فترة محددة'),
              subtitle: Text('حجب ساعات معينة من اليوم فقط'),
              onTap: () {
                Navigator.pop(context);
                _showTimeSlotPicker(date);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showTimeSlotPicker(DateTime date) async {
    TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'اختر وقت البداية',
    );

    if (startTime == null) return;

    TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (startTime.hour + 1) % 24,
        minute: startTime.minute,
      ),
      helpText: 'اختر وقت النهاية',
    );

    if (endTime == null) return;

    // تنسيق الفترة الزمنية
    final timeSlot =
        '${startTime.format(context)} - ${endTime.format(context)}';
    _blockDate(date, timeSlot: timeSlot);
  }

  Future<void> _unblockTimeSlot(String slotKey) async {
    try {
      // تحديد المجموعة الصحيحة للتحديث
      String collection = 'published_providers';

      var doc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(widget.providerId)
          .get();

      if (!doc.exists) {
        collection = 'provider_requests';
        doc = await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(widget.providerId)
            .get();
      }

      if (!doc.exists) {
        throw Exception('لم يتم العثور على بيانات الخدمة');
      }

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.providerId)
          .update({
            'blockedTimeSlots': FieldValue.arrayRemove([slotKey]),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إلغاء حجب الفترة'),
          backgroundColor: Colors.green,
        ),
      );

      _loadPhotographyData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إلغاء حجب الفترة: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكد';
      case 'pending':
        return 'معلق';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير محدد';
    }
  }
}
