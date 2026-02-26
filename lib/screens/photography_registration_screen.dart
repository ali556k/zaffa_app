import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PhotographyRegistrationScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String governorate;
  final String area;
  final String? profileImage;

  const PhotographyRegistrationScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.governorate,
    required this.area,
    this.profileImage,
  });

  @override
  State<PhotographyRegistrationScreen> createState() =>
      _PhotographyRegistrationScreenState();
}

class _PhotographyRegistrationScreenState
    extends State<PhotographyRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _pricePerHourController = TextEditingController();
  final TextEditingController _cameraTypeController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  // Data
  List<XFile> _selectedImages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _pricePerHourController.dispose();
    _cameraTypeController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images;
        });
      }
    } catch (e) {
      _showErrorDialog('خطأ في اختيار الصور', 'حدث خطأ أثناء اختيار الصور: $e');
    }
  }

  Future<void> _submitPhotographyService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImages.length < 5) {
      _showErrorDialog(
        'صور غير كافية',
        'يجب إضافة 5 صور على الأقل لخدمة التصوير',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // رفع الصور إلى Firebase Storage
      List<String> imageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final ref = FirebaseStorage.instance.ref().child(
          'photography_services/${widget.providerId}/image_$i.jpg',
        );

        await ref.putFile(File(_selectedImages[i].path));
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // إنشاء بيانات طلب التصوير للإرسال للمالك
      final requestData = {
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'providerPhone': widget.providerPhone,
        'category': 'photography',
        'serviceType': 'جلسات تصوير',
        'serviceName': 'خدمة التصوير - ${widget.providerName}',
        'governorate': widget.governorate,
        'area': widget.area,
        'pricePerHour': double.parse(_pricePerHourController.text),
        'price': double.parse(_pricePerHourController.text),
        'basePrice': double.parse(_pricePerHourController.text),
        'cameraType': _cameraTypeController.text,
        'description': _detailsController.text,
        'images': imageUrls,
        'imageUrls': imageUrls,
        'profileImage': widget.profileImage ?? imageUrls.first,
        'serviceImage': imageUrls.first,
        'status': 'pending',
        'requestType': 'photography',
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 0.0,
        'reviewCount': 0,
      };

      // إرسال الطلب إلى مجموعة provider_requests
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(widget.providerId)
          .set(requestData);

      // تحديث بيانات المزود في مجموعة providers
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .set({
            'providerId': widget.providerId,
            'name': widget.providerName,
            'phone': widget.providerPhone,
            'governorate': widget.governorate,
            'area': widget.area,
            'category': 'photography',
            'status': 'pending',
            'hasSubmittedService': true,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      setState(() => _isLoading = false);

      // إظهار رسالة النجاح
      _showSuccessDialog();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('خطأ في التسجيل', 'حدث خطأ أثناء حفظ البيانات: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'تم التسجيل بنجاح!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'تم تسجيل خدمة التصوير بنجاح. سيتمكن العملاء الآن من رؤية خدمتك والحجز بعد موافقة المالك.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق النافذة
              Navigator.pop(
                context,
                true,
              ); // العودة مع نتيجة true لفتح حساب المزود
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('تم', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تسجيل خدمة التصوير',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2B0606),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2B0606)),
                  SizedBox(height: 16),
                  Text(
                    'جاري حفظ البيانات...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // معلومات المزود
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2B0606,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF2B0606),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'معلومات المزود',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              'الاسم',
                              widget.providerName,
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'الهاتف',
                              widget.providerPhone,
                              Icons.phone,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'المحافظة',
                              widget.governorate,
                              Icons.location_city,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'المنطقة',
                              widget.area,
                              Icons.location_on,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // صور الخدمة
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.photo_library,
                                    color: Colors.blue,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'صور الخدمة',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '5 صور على الأقل',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // زر اختيار الصور
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: Text(
                                  _selectedImages.isEmpty
                                      ? 'اختيار الصور'
                                      : 'تغيير الصور (${_selectedImages.length})',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),

                            // عرض الصور المختارة
                            if (_selectedImages.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _selectedImages.length >= 5
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedImages.length >= 5
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedImages.length >= 5
                                          ? Icons.check_circle
                                          : Icons.warning_amber,
                                      color: _selectedImages.length >= 5
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedImages.length >= 5
                                            ? 'تم اختيار ${_selectedImages.length} صورة ✓'
                                            : 'يجب اختيار ${5 - _selectedImages.length} صور إضافية',
                                        style: TextStyle(
                                          color: _selectedImages.length >= 5
                                              ? Colors.green
                                              : Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: const EdgeInsets.only(left: 12),
                                      width: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          File(_selectedImages[index].path),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // السعر للساعة
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.attach_money,
                                    color: Colors.green,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'السعر للساعة الواحدة',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _pricePerHourController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'السعر بالدينار العراقي',
                                hintText: 'مثال: 50000',
                                prefixIcon: const Icon(Icons.payments),
                                suffixText: 'د.ع',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال السعر';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'يرجى إدخال رقم صحيح';
                                }
                                if (double.parse(value) <= 0) {
                                  return 'السعر يجب أن يكون أكبر من صفر';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // نوع الكاميرا
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.purple,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'نوع الكاميرا',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cameraTypeController,
                              decoration: InputDecoration(
                                labelText: 'نوع الكاميرا والمعدات',
                                hintText: 'مثال: Canon EOS R5, Sony A7III',
                                prefixIcon: const Icon(Icons.videocam),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.purple,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال نوع الكاميرا';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // التفاصيل
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.description,
                                    color: Colors.orange,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'تفاصيل الخدمة',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _detailsController,
                              maxLines: 6,
                              decoration: InputDecoration(
                                labelText: 'وصف تفصيلي للخدمة',
                                hintText:
                                    'اكتب وصفاً شاملاً للخدمات التي تقدمها...\n\nمثال:\n- تصوير فوتوغرافي احترافي\n- تصوير فيديو سينمائي 4K\n- مونتاج احترافي\n- ألبوم رقمي\n- طباعة الصور',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.orange,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إضافة وصف للخدمة';
                                }
                                if (value.length < 50) {
                                  return 'الوصف يجب أن يكون 50 حرف على الأقل';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // زر التسجيل
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitPhotographyService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B0606),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'تسجيل الخدمة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
