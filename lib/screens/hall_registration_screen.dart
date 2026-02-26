import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';

class HallRegistrationScreen extends StatefulWidget {
  final String userPhone;
  final String userName;
  final String governorate;
  final String area;
  final String location;
  final String serviceType;

  const HallRegistrationScreen({
    super.key,
    required this.userPhone,
    required this.userName,
    required this.governorate,
    required this.area,
    required this.location,
    required this.serviceType,
  });

  @override
  _HallRegistrationScreenState createState() => _HallRegistrationScreenState();
}

class _HallRegistrationScreenState extends State<HallRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hallNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();

  bool _isLoading = false;
  List<File> _hallImages = [];
  LatLng? _selectedLocation;
  final ImagePicker _picker = ImagePicker();

  // قائمة الخدمات الضمنية المتاحة
  final List<Map<String, dynamic>> _availableServices = [
    {'name': 'خدمة التصوير الفوتوغرافي', 'price': 0.0, 'selected': false},
    {'name': 'خدمة التصوير بالفيديو', 'price': 0.0, 'selected': false},
    {'name': 'خدمة الطعام والضيافة', 'price': 0.0, 'selected': false},
    {'name': 'خدمة تنسيق الورود والزينة', 'price': 0.0, 'selected': false},
    {'name': 'خدمة الموسيقى والدي جي', 'price': 0.0, 'selected': false},
    {'name': 'خدمة الإضاءة المتقدمة', 'price': 0.0, 'selected': false},
    {'name': 'خدمة التكييف والتهوية', 'price': 0.0, 'selected': false},
    {'name': 'خدمة مواقف السيارات', 'price': 0.0, 'selected': false},
    {'name': 'خدمة الأمن والحراسة', 'price': 0.0, 'selected': false},
    {'name': 'خدمة تنظيف ما بعد الحفل', 'price': 0.0, 'selected': false},
  ];

  @override
  void initState() {
    super.initState();
    _verifyHallService();
    // إذا كان الموقع محدد مسبقاً
    if (widget.location.isNotEmpty) {
      final coordinates = widget.location.split(',');
      if (coordinates.length == 2) {
        _selectedLocation = LatLng(
          double.tryParse(coordinates[0]) ?? 0.0,
          double.tryParse(coordinates[1]) ?? 0.0,
        );
      }
    }
  }

  // فحص أن الخدمة المحددة هي قاعات أعراس
  void _verifyHallService() {
    if (widget.serviceType != 'قاعة عرس' &&
        widget.serviceType != 'قاعات اعراس') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الصفحة مخصصة لتسجيل قاعات الأعراس فقط'),
          backgroundColor: Colors.red,
        ),
      );
      // العودة للصفحة السابقة
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _hallNameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // دالة اختيار الصور
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _hallImages = images.map((image) => File(image.path)).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم اختيار ${images.length} صورة')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('خطأ في اختيار الصور')));
    }
  }

  // دالة رفع الصور إلى Firebase Storage
  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];

    for (int i = 0; i < _hallImages.length; i++) {
      try {
        String fileName = 'hall_images/${widget.userPhone}/image_$i.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(_hallImages[i]);
        String downloadUrl = await storageRef.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        print('خطأ في رفع الصورة $i: $e');
      }
    }

    return imageUrls;
  }

  // دالة اختيار الموقع

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من الحقول المطلوبة
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد موقع القاعة على الخريطة')),
      );
      return;
    }

    if (_hallImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار صور للقاعة (الحد الأدنى 5 صور)'),
        ),
      );
      return;
    }

    if (_hallImages.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى اختيار 5 صور على الأقل للقاعة (تم اختيار ${_hallImages.length} صور فقط)',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // رفع الصور أولاً
      List<String> imageUrls = await _uploadImages();

      // جمع الخدمات الضمنية المختارة
      List<Map<String, dynamic>> selectedServices = _availableServices
          .where((service) => service['selected'] == true)
          .map(
            (service) => {'name': service['name'], 'price': service['price']},
          )
          .toList();

      // إعداد بيانات القاعة الكاملة
      Map<String, dynamic> hallData = {
        'requestId': FirebaseFirestore.instance
            .collection('provider_requests')
            .doc()
            .id,
        'providerId': widget.userPhone,
        'providerName': widget.userName,
        'providerPhone': widget.userPhone,
        'serviceType': 'قاعات اعراس',
        'serviceName': 'قاعات اعراس',
        'userGovernorate': widget.governorate,
        'area': widget.area,
        'location': _selectedLocation != null
            ? '${_selectedLocation!.latitude},${_selectedLocation!.longitude}'
            : widget.location,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),

        // بيانات القاعة المخصصة
        'hallName': _hallNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'capacity': _capacityController.text.trim(),
        'basePrice': double.tryParse(_priceController.text) ?? 0.0,
        'includedServices': selectedServices,
        'hallImages': imageUrls,
        'isHallProvider': true,

        // بيانات إضافية
        'totalServices': selectedServices.length,
        'totalIncludedPrice': selectedServices.fold<double>(
          0.0,
          (sum, service) => sum + (service['price'] as double),
        ),
      };

      // حفظ البيانات في provider_requests للموافقة من الإدارة
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(hallData['requestId'])
          .set(hallData);

      // حفظ البيانات في provider_services مع حالة معلق
      await FirebaseFirestore.instance
          .collection('provider_services')
          .doc(widget.userPhone)
          .set({
            'serviceName': 'قاعات اعراس',
            'serviceType': 'قاعات اعراس',
            'providerId': widget.userPhone,
            'providerName': widget.userName,
            'providerPhone': widget.userPhone,
            'location': widget.location,
            'area': widget.area,
            'governorate': widget.governorate,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'hallData': hallData,
            'isHallProvider': true,
          });

      // حفظ البيانات في providers
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.userPhone)
          .set({
            'providerId': widget.userPhone,
            'providerName': widget.userName,
            'phone': widget.userPhone,
            'serviceType': 'قاعات اعراس',
            'governorate': widget.governorate,
            'area': widget.area,
            'location': widget.location,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'hallData': hallData,
            'isHallProvider': true,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم تسجيل قاعة الأعراس بنجاح! سيتم مراجعة الطلب من قبل الإدارة',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop(true); // العودة مع إشارة النجاح
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التسجيل: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'تسجيل_قاعة_أعراس',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF530405),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات القاعة الأساسية
              _buildSectionCard(
                title: 'معلومات القاعة الأساسية',
                icon: Icons.home_work,
                children: [
                  _buildTextField(
                    controller: _hallNameController,
                    label: 'اسم القاعة',
                    hint: 'أدخل اسم قاعة الأعراس',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'اسم القاعة مطلوب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'وصف القاعة',
                    hint: 'أدخل وصف مفصل للقاعة ومميزاتها',
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'وصف القاعة مطلوب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _capacityController,
                          label: 'سعة القاعة',
                          hint: 'عدد الأشخاص',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'سعة القاعة مطلوبة';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'السعر الأساسي (دينار)',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'السعر الأساسي مطلوب';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // تم حذف قسم موقع القاعة حسب الطلب
              const SizedBox(height: 0),

              // صور القاعة
              _buildSectionCard(
                title: 'صور القاعة',
                icon: Icons.photo_library,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF530405).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF530405).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF530405),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يجب إضافة 5 صور على الأقل للقاعة لتوضيح جميع التفاصيل للعملاء',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF530405),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _hallImages.isEmpty
                              ? Icons.add_photo_alternate
                              : Icons.photo_library,
                          size: 48,
                          color: _hallImages.isEmpty
                              ? Colors.grey
                              : Color(0xFF530405),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hallImages.isEmpty
                              ? 'لم يتم اختيار صور بعد'
                              : 'تم اختيار ${_hallImages.length} صورة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _hallImages.isEmpty
                                ? Colors.grey
                                : Color(0xFF530405),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الحد الأدنى: 5 صور',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hallImages.length >= 5
                                ? Color(0xFF530405)
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_hallImages.isNotEmpty && _hallImages.length < 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'تحتاج إلى ${5 - _hallImages.length} صورة إضافية',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text(
                            _hallImages.isEmpty ? 'اختيار صور' : 'تغيير الصور',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF530405),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (_hallImages.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _hallImages.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _hallImages[index],
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
                ],
              ),

              const SizedBox(height: 24),

              // الخدمات الضمنية
              _buildSectionCard(
                title: 'الخدمات الضمنية المتاحة',
                icon: Icons.list_alt,
                children: [
                  const Text(
                    'اختر الخدمات الضمنية التي تقدمها القاعة وحدد أسعارها:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildServicesList(),
                ],
              ),

              const SizedBox(height: 32),

              // زر التسجيل
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF530405),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'تسجيل_قاعة_الأعراس',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ملاحظة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Color(0xFF530405)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'سيتم مراجعة طلبك من قبل الإدارة وستصلك رسالة عند الموافقة على تسجيل القاعة',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF530405), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF530405),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF530405)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  List<Widget> _buildServicesList() {
    return _availableServices.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> service = entry.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: service['selected']
              ? const Color(0xFF530405).withOpacity(0.1)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: service['selected']
                ? const Color(0xFF530405)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: service['selected'],
                  onChanged: (bool? value) {
                    setState(() {
                      _availableServices[index]['selected'] = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF530405),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: service['selected']
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: service['selected']
                          ? const Color(0xFF530405)
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (service['selected']) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 40), // المحاذاة مع النص
                  const Text(
                    'السعر: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF530405),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: service['price'].toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0.00 دينار',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _availableServices[index]['price'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'دينار_3',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }).toList();
  }
}

// شاشة اختيار الموقع
class _LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const _LocationPickerScreen({required this.initialLocation});

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _updateMarker();
  }

  void _updateMarker() {
    if (_selectedLocation != null) {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          infoWindow: const InfoWindow(
            title: 'موقع القاعة',
            snippet: 'الموقع المختار',
          ),
        ),
      };
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _updateMarker();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'اختيار_موقع_القاعة',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _selectedLocation != null
                ? () => Navigator.pop(context, _selectedLocation)
                : null,
            child: Text(
              'save',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 15.0,
            ),
            onTap: _onMapTapped,
            markers: _markers,
            mapType: MapType.normal,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'اضغط_على_الخريطة_لاختيار_موقع',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedLocation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'الموقع المختار: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
