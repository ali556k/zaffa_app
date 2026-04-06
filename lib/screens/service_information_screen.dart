import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'provider_main_professional.dart';
import 'hall_registration_screen.dart';
import 'photography_registration_screen.dart';
import 'provider_items_registration_screen.dart';

class ServiceInformationScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userGovernorate;

  const ServiceInformationScreen({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userGovernorate,
  });

  @override
  State<ServiceInformationScreen> createState() =>
      _ServiceInformationScreenState();
}

class _ServiceInformationScreenState extends State<ServiceInformationScreen> {
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _creditCardController = TextEditingController();

  String? _selectedServiceType;
  String? _serviceImagePath;
  LatLng? _selectedLocation;
  bool _isLoading = false;

  final List<String> _weddingServices = [
    'قاعة عرس',
    'فنادق',
    'مطعم',
    'كيك',
    'تأجير سيارات',
    'تزيين السيارة',
    'بدلات رجالي',
    'فستان العروس',
    'صالون وعناية',
    'التصوير',
    'جلسات تصوير',
    'شركة سياحة',
    'ورد',
  ];

  Future<void> _pickServiceImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _serviceImagePath = picked.path;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض إذن الموقع نهائياً. افتح الإعدادات وامنح الإذن يدوياً.'),
              duration: Duration(seconds: 4),
            ),
          );
          await Geolocator.openAppSettings();
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('صلاحية الموقع مطلوبة')),
            );
          }
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الحصول على الموقع. حاول مجدداً.')),
        );
      }
    }
  }

  Future<void> _openLocationPicker() async {
    final LatLng? pickedLocation = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(
        builder: (context) => _LocationPickerScreen(
          initialLocation: _selectedLocation ?? const LatLng(33.3152, 44.3661),
        ),
      ),
    );

    if (pickedLocation != null) {
      setState(() {
        _selectedLocation = pickedLocation;
      });
    }
  }

  Future<String?> _uploadServiceImage() async {
    if (_serviceImagePath == null) return null;

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'service_images/${widget.userPhone}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await ref.putFile(File(_serviceImagePath!));
      return await ref.getDownloadURL();
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      return null;
    }
  }

  Future<void> _proceedToItemsRegistration() async {
    // Debug entry
    // ignore: avoid_print
    print('🚪 ENTER _proceedToItemsRegistration in ServiceInformationScreen');

    if (_serviceNameController.text.isEmpty ||
        _selectedServiceType == null ||
        _areaController.text.isEmpty ||
        _creditCardController.text.isEmpty ||
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إكمال جميع الحقول المطلوبة')),
      );
      return;
    }

    // If the selected service is Photography, route to the specialized photography registration
    if (_selectedServiceType == 'التصوير' ||
        _selectedServiceType == 'جلسات تصوير') {
      print(
        '📷 Photography service selected in ServiceInformationScreen. Preparing to open PhotographyRegistrationScreen...',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📷 سيتم فتح نموذج تسجيل تفاصيل خدمة التصوير...'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      final gov = widget.userGovernorate;
      final area = _areaController.text.trim();

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotographyRegistrationScreen(
            providerId: widget.userPhone,
            providerName: widget.userName,
            providerPhone: widget.userPhone,
            governorate: gov,
            area: area,
          ),
        ),
      );

      print(
        '🔙 Returned from PhotographyRegistrationScreen with result: $result',
      );

      if (result == true && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_photography_provider', true);
        await prefs.setString('provider_type', 'photography');
        await prefs.setString('currentUserId', widget.userPhone);
        await prefs.setString('providerName', widget.userName);
        await prefs.setString('user_phone', widget.userPhone);
        await prefs.setString('account_type', 'provider');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ProviderMainProfessional(),
          ),
          (route) => false,
        );
      }

      return;
    }

    // If the selected service is a Wedding Hall, route to the specialized hall registration
    if (_selectedServiceType == 'قاعة عرس') {
      // ignore: avoid_print
      print(
        '🏰 Hall service selected in ServiceInformationScreen. Preparing to open HallRegistrationScreen...',
      );

      // Optional UX hint
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🏰 سيتم فتح نموذج تسجيل تفاصيل قاعة العرس...'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      final gov = widget.userGovernorate;
      final area = _areaController.text.trim();
      final locationStr =
          '${_selectedLocation!.latitude},${_selectedLocation!.longitude}';

      // Navigate to the specialized hall registration screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HallRegistrationScreen(
            userPhone: widget.userPhone,
            userName: widget.userName,
            governorate: gov,
            area: area,
            location: locationStr,
            serviceType: 'قاعة عرس',
            creditCard: _creditCardController.text.trim(),
          ),
        ),
      );

      // ignore: avoid_print
      print('🔙 Returned from HallRegistrationScreen with result: $result');

      if (result == true && mounted) {
        // Mark as hall provider locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_hall_provider', true);
        await prefs.setString('provider_type', 'hall');
        await prefs.setString('currentUserId', widget.userPhone);
        await prefs.setString('providerName', widget.userName);
        await prefs.setString('user_phone', widget.userPhone);
        await prefs.setString('account_type', 'provider');

        // Go to provider main screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ProviderMainProfessional(),
          ),
          (route) => false,
        );
      }

      // Critical: stop here to avoid executing the normal provider_services save path
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // رفع صورة الخدمة
      String? serviceImageUrl = await _uploadServiceImage();

      // إنشاء معرف فريد لمزود الخدمة
      String providerId = widget.userPhone;

      // جلب معلومات المستخدم من users لدمجها مع معلومات الخدمة
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .get();

      final userData = userDoc.data() ?? {};

      // إنشاء بيانات الخدمة الكاملة (معلومات المستخدم + معلومات الخدمة)
      final serviceData = {
        // معلومات المستخدم الأساسية (من جدول users فقط)
        'userName': userData['name'] ?? 'مستخدم',
        'providerName': providerId, // رقم الهاتف كمعرف
        'phone': widget.userPhone,
        'userPhone': widget.userPhone,
        'governorate': userData['governorate'] ?? widget.userGovernorate,
        'userGovernorate': userData['governorate'] ?? widget.userGovernorate,
        'area': _areaController.text.trim(),
        'userArea': _areaController.text.trim(),
        'accountType': userData['accountType'] ?? 'provider',
        'profileImage': userData['profileImage'],

        // معلومات الخدمة (اسم الخدمة التجاري المدخل من المزود)
        'serviceName': _serviceNameController.text.trim(),
        'name': _serviceNameController.text.trim(),
        'serviceType': _selectedServiceType,
        'services': [_selectedServiceType],
        'serviceImage': serviceImageUrl,
        'serviceImageUrl': serviceImageUrl,
        'imageUrl': serviceImageUrl,
        'location': GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'creditCard': _creditCardController.text.trim(),

        // معلومات إضافية
        'providerId': providerId,
        'providerPhone': widget.userPhone,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
      };

      // حفظ معلومات الخدمة الكاملة في Firestore
      await FirebaseFirestore.instance
          .collection('provider_services')
          .doc(providerId)
          .set(serviceData, SetOptions(merge: true));

      // حفظ بيانات مزود الخدمة للتذكر
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', providerId);
      await prefs.setString('providerName', widget.userName);
      await prefs.setString('user_phone', widget.userPhone);
      await prefs.setString('account_type', 'provider');

      // حفظ الجلسة في Firestore
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(providerId)
          .set({
            'active': true,
            'lastLogin': FieldValue.serverTimestamp(),
            'accountType': 'provider',
          });

      // حفظ/تحديث مزود في مجموعة providers مع جميع المعلومات
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .set(serviceData, SetOptions(merge: true));

      // ملاحظة مهمة: لا نرسل طلب للمالك هنا!
      // سيتم إرسال طلب واحد فقط من add_service_items_screen بعد إضافة العناصر
      // هذا يضمن أن الطلب يحتوي على جميع المعلومات + العناصر معاً

      setState(() {
        _isLoading = false;
      });

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ معلومات الخدمة بنجاح! الآن أضف عناصر خدمتك'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // الانتقال مباشرة لشاشة إضافة العناصر (التصميم القديم)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ProviderItemsRegistrationScreen(serviceData: serviceData),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'معلومات الخدمة',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF530405),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات المستخدم
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'معلومات المستخدم',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF530405),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Color(0xFF530405),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'الاسم: ${widget.userName}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.phone, color: Color(0xFF530405)),
                              const SizedBox(width: 8),
                              Text(
                                'الهاتف: ${widget.userPhone}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_city,
                                color: Color(0xFF530405),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'المحافظة: ${widget.userGovernorate}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // معلومات الخدمة
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تفاصيل الخدمة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF530405),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // اسم الخدمة
                          TextField(
                            controller: _serviceNameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الخدمة',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.business,
                                color: Color(0xFF530405),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // نوع الخدمة
                          DropdownButtonFormField<String>(
                            value: _selectedServiceType,
                            decoration: const InputDecoration(
                              labelText: 'نوع الخدمة ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.category,
                                color: Color(0xFF530405),
                              ),
                            ),
                            items: _weddingServices
                                .map(
                                  (service) => DropdownMenuItem(
                                    value: service,
                                    child: Text(service),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedServiceType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // المنطقة
                          TextField(
                            controller: _areaController,
                            decoration: const InputDecoration(
                              labelText: 'المنطقة ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.location_on,
                                color: Color(0xFF530405),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // رقم بطاقة الائتمان
                          TextField(
                            controller: _creditCardController,
                            decoration: const InputDecoration(
                              labelText: 'رقم بطاقة الائتمان ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.credit_card,
                                color: Color(0xFF530405),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),

                          // صورة الخدمة
                          const Text(
                            'صورة الخدمة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickServiceImage,
                            child: Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _serviceImagePath == null
                                  ? const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 50,
                                        ),
                                        Text('اختر صورة الخدمة'),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_serviceImagePath!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // تحديد الموقع على الخريطة
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'موقع الخدمة على الخريطة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // عرض الموقع المحدد
                          if (_selectedLocation != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFF530405).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color(0xFF530405).withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF530405),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'تم تحديد الموقع بنجاح',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF530405),
                                          ),
                                        ),
                                        Text(
                                          'خط العرض: ${_selectedLocation!.latitude.toStringAsFixed(4)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          'خط الطول: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // أزرار تحديد الموقع
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _openLocationPicker,
                                  icon: const Icon(Icons.map, size: 20),
                                  label: const Text('تحديد موقع الخدمة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF530405),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _getCurrentLocation,
                                icon: const Icon(Icons.my_location, size: 20),
                                label: const Text('موقعي'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF530405),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_selectedLocation == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'يجب تحديد موقع الخدمة على الخريطة',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // زر إنشاء الحساب
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _proceedToItemsRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF530405),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'إنشاء حساب مزود الخدمة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _areaController.dispose();
    _creditCardController.dispose();
    super.dispose();
  }
}

// شاشة اختيار الموقع داخلية
class _LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const _LocationPickerScreen({required this.initialLocation});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض إذن الموقع نهائياً. افتح الإعدادات وامنح الإذن يدوياً.'),
              duration: Duration(seconds: 4),
            ),
          );
          await Geolocator.openAppSettings();
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('صلاحية الموقع مطلوبة')),
            );
          }
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedLocation = newLocation;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الحصول على الموقع. حاول مجدداً.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تحديد موقع الخدمة',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF530405),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.my_location),
            tooltip: 'موقعي الحالي',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // الخريطة
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onTap: (LatLng location) {
              setState(() {
                _selectedLocation = location;
              });
            },
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedLocation!,
                      infoWindow: const InfoWindow(title: 'موقع الخدمة المحدد'),
                    ),
                  }
                : {},
          ),

          // معلومات الموقع في الأعلى
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'اضغط على الخريطة لتحديد موقع خدمتك',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (_selectedLocation != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'خط العرض: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        'خط الطول: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // زر التأكيد في الأسفل
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // زر موقعي الحالي
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('استخدام موقعي الحالي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // زر تأكيد الموقع
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedLocation != null
                        ? () {
                            Navigator.pop(context, _selectedLocation);
                          }
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد الموقع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
