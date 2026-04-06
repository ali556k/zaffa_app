import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'provider_main_professional.dart';
import 'hall_registration_screen.dart';

class ProviderServiceRegistrationScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String providerPhone;

  const ProviderServiceRegistrationScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
  });

  @override
  State<ProviderServiceRegistrationScreen> createState() => _ProviderServiceRegistrationScreenState();
}

class _ProviderServiceRegistrationScreenState extends State<ProviderServiceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceNameController = TextEditingController();
  final _creditCardController = TextEditingController();
  final _areaController = TextEditingController();
  
  String? _selectedServiceType;
  File? _serviceImage;
  LatLng? _selectedLocation;
  bool _isLoading = false;

  final List<String> _serviceTypes = [
    'قاعة عرس',
    'فنادق',
    'كيك',
    'طعام',
    'فستان الزفاف',
    'صالون وعناية',
    'ورد',
    'بدلة رجالي',
    'تاجير السيارات',
    'تزيين السيارة',
    'شهر العسل',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
          return;
        }
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        if (mounted) {
          setState(() {
            _selectedLocation = LatLng(position.latitude, position.longitude);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الحصول على الموقع. حاول مجدداً.')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _serviceImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الصورة: $e')),
      );
    }
  }

  Future<String?> _uploadServiceImage() async {
    if (_serviceImage == null) return null;
    
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('service_images/${widget.providerId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await ref.putFile(_serviceImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      return null;
    }
  }

  Future<void> _submitServiceInfo() async {
    // ====== نقطة الدخول - يجب أن تظهر هذه الرسالة دائماً ======
    print('');
    print('🚨🚨� ENTER _submitServiceInfo 🚨🚨🚨');
    print('�🔍 ═══════════════════════════════════════');
    print('🔍 بدء _submitServiceInfo');
    print('📝 نوع الخدمة المختار: "$_selectedServiceType"');
    print('🔍 ═══════════════════════════════════════');
    
    // ====== الفحص الأولي للنموذج ======
    if (!_formKey.currentState!.validate()) {
      print('❌ فشل التحقق من النموذج');
      return;
    }
    
    // ====== الفحص: هل تم اختيار نوع الخدمة؟ ======
    if (_selectedServiceType == null || _selectedServiceType!.isEmpty) {
      print('❌ نوع الخدمة غير محدد');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار نوع الخدمة')),
      );
      return;
    }

    // ====== هل نوع الخدمة هو قاعة عرس؟ ======
    print('🔍 ═══════════════════════════════════════');
    print('🔍 التحقق من نوع الخدمة...');
    print('   نوع الخدمة: "$_selectedServiceType"');
    
    final isHallService = _selectedServiceType == 'قاعة عرس';
    print('   🎯 هل هو قاعة عرس؟ $isHallService');
    
    // ====== المسار الخاص بقاعات العرس ======
    if (isHallService) {
      print('🏰 ═══════════════════════════════════════');
      print('🏰 تم اختيار قاعة عرس - مسار القاعات');
      print('🏰 ═══════════════════════════════════════');
      
      // التحقق من المنطقة
      if (_areaController.text.trim().isEmpty) {
        print('❌ المنطقة فارغة');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال منطقة القاعة')),
        );
        return;
      }
      
      // التحقق من الموقع
      if (_selectedLocation == null) {
        print('❌ الموقع غير محدد');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تحديد موقع القاعة على الخريطة')),
        );
        return;
      }

      print('✅ جميع البيانات متوفرة - الانتقال للصفحة المتخصصة');
      
      // عرض رسالة
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🏰 سيتم فتح نموذج تسجيل تفاصيل القاعة...'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      
      print('🚀 فتح HallRegistrationScreen...');
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HallRegistrationScreen(
            userPhone: widget.providerId,
            userName: widget.providerName,
            governorate: _areaController.text.trim(),
            area: _areaController.text.trim(),
            location: '${_selectedLocation!.latitude},${_selectedLocation!.longitude}',
            serviceType: 'قاعة عرس',
          ),
        ),
      );
      
      print('🔙 عودة من HallRegistrationScreen - النتيجة: $result');

      if (result == true && mounted) {
        print('✅ التسجيل ناجح - تحديث البيانات والانتقال للرئيسية');
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_hall_provider', true);
        await prefs.setString('provider_type', 'hall');
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ProviderMainProfessional(),
          ),
          (route) => false,
        );
      }
      
      return; // ⚠️ مهم جداً - إيقاف التنفيذ هنا
    }

    // ====== المسار العادي للخدمات الأخرى ======
    print('📦 ═══════════════════════════════════════');
    print('📦 خدمة عادية - المسار التقليدي');
    print('📦 ═══════════════════════════════════════');
    if (_serviceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار صورة للخدمة')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد موقع الخدمة على الخريطة')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // رفع صورة الخدمة
      final imageUrl = await _uploadServiceImage();
      
      // إنشاء بيانات الخدمة
      final serviceData = {
        'serviceName': _serviceNameController.text.trim(),
        'serviceType': _selectedServiceType,
        'serviceImageUrl': imageUrl,
        'location': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
        'area': _areaController.text.trim(),
        'creditCard': _creditCardController.text.trim(),
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'providerPhone': widget.providerPhone,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // جميع الخدمات تبدأ كمعلقة
      };

      print('💾 حفظ بيانات الخدمة: $serviceData');

      // حفظ معلومات الخدمة في Firestore
      await FirebaseFirestore.instance
          .collection('provider_services')
          .doc(widget.providerId)
          .set(serviceData);

      // إرسال طلب للمالك لجميع الخدمات
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .add({
        ...serviceData,
        'requestType': 'new_provider',
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'notes': null,
        // بيانات إضافية لقاعات الأعراس
        'isHallProvider': (_selectedServiceType == 'قاعة عرس' || _selectedServiceType == 'قاعات اعراس'),
        'expectedCapacity': _selectedServiceType == 'قاعة عرس' || _selectedServiceType == 'قاعات اعراس' ? '300 شخص' : null,
        'hallFeatures': _selectedServiceType == 'قاعة عرس' || _selectedServiceType == 'قاعات اعراس' 
            ? ['نظام صوت متطور', 'إضاءة احترافية', 'تكييف مركزي', 'مواقف سيارات'] 
            : null,
      });

      print('📤 تم إرسال الطلب للمالك بنجاح');

      // حفظ بيانات مزود الخدمة للتذكر
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', widget.providerId);
      await prefs.setString('providerName', widget.providerName);
      await prefs.setString('user_phone', widget.providerId);
      await prefs.setString('account_type', 'provider');

      // حفظ الجلسة في Firestore
      await FirebaseFirestore.instance.collection('sessions').doc(widget.providerId).set({
        'active': true,
        'lastLogin': FieldValue.serverTimestamp(),
        'accountType': 'provider',
      });

      // إنشاء مزود في مجموعة providers إذا لم يكن موجوداً
      final providerRef = FirebaseFirestore.instance.collection('providers').doc(widget.providerId);
      final providerDoc = await providerRef.get();
      
      if (!providerDoc.exists) {
        final providerData = {
          'name': widget.providerName,
          'phone': widget.providerPhone,
          'serviceType': _selectedServiceType,
          'serviceName': _serviceNameController.text.trim(),
          'area': _areaController.text.trim(),
          'creditCard': _creditCardController.text.trim(),
          'status': 'pending', // تغيير من 'approved' إلى 'pending'
          'createdAt': FieldValue.serverTimestamp(),
        };
        print('💾 حفظ بيانات مزود جديد: $providerData');
        await providerRef.set(providerData);
      } else {
        // تحديث بيانات المزود الموجود بنوع الخدمة الجديد
        final updateData = {
          'serviceType': _selectedServiceType,
          'serviceName': _serviceNameController.text.trim(),
          'area': _areaController.text.trim(),
          'creditCard': _creditCardController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        print('🔄 تحديث بيانات مزود موجود: $updateData');
        await providerRef.update(updateData);
      }

      // عرض رسالة نجاح موحدة لجميع الخدمات
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال طلب ${(_selectedServiceType == 'قاعة عرس' || _selectedServiceType == 'قاعات اعراس') ? 'قاعة الأعراس' : 'مزود الخدمة'} بنجاح!\n'
            'سيتم مراجعته من قبل الإدارة وستصلك رسالة تأكيد عند الموافقة.',
          ),
          backgroundColor: const Color(0xFFB46A6A),
          duration: const Duration(seconds: 4),
        ),
      );

      // الانتقال إلى واجهة مزود الخدمة الاحترافية
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const ProviderMainProfessional(),
        ),
        (route) => false, // إزالة جميع الشاشات السابقة
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building ProviderServiceRegistrationScreen');
    print('📝 Current Service Type in build: "$_selectedServiceType"');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.business,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تسجيل معلومات الخدمة',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مرحباً ${widget.providerName}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Form Container
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF1E88E5)),
                              SizedBox(height: 16),
                              Text('جاري حفظ معلومات الخدمة...'),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // صورة الخدمة
                                _buildImagePicker(),
                                const SizedBox(height: 24),
                                
                                // اسم الخدمة
                                _buildTextField(
                                  controller: _serviceNameController,
                                  label: 'اسم الخدمة',
                                  icon: Icons.store,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'يرجى إدخال اسم الخدمة';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // نوع الخدمة
                                _buildServiceTypeDropdown(),
                                const SizedBox(height: 20),
                                
                                // المنطقة
                                _buildTextField(
                                  controller: _areaController,
                                  label: 'المنطقة',
                                  icon: Icons.location_city,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'يرجى إدخال المنطقة';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // رقم بطاقة الائتمان
                                _buildTextField(
                                  controller: _creditCardController,
                                  label: 'رقم بطاقة الائتمان',
                                  icon: Icons.credit_card,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'يرجى إدخال رقم بطاقة الائتمان';
                                    }
                                    if (value.length < 16) {
                                      return 'رقم بطاقة الائتمان غير صحيح';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                
                                // خريطة تحديد الموقع
                                _buildLocationPicker(),
                                const SizedBox(height: 32),
                                
                                // زر التالي
                                _buildNextButton(),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'صورة الخدمة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        
        // Container محسن للصورة والزر
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // زر إضافة صورة
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _serviceImage != null 
                          ? [const Color(0xFF4CAF50), const Color(0xFF45A049)]
                          : [const Color(0xFF1E88E5), const Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_serviceImage != null ? const Color(0xFF4CAF50) : const Color(0xFF1E88E5)).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _serviceImage != null ? Icons.check_circle : Icons.add_photo_alternate,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _serviceImage != null ? 'تم الاختيار' : 'إضافة صورة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // عرض الصورة المختارة
              Expanded(
                child: _serviceImage != null
                    ? Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _serviceImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'معاينة الصورة',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF1E88E5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع الخدمة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedServiceType,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.category, color: Color(0xFF1E88E5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          hint: const Text('اختر نوع الخدمة'),
          items: _serviceTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (String? newValue) {
            print('📝 تم اختيار نوع الخدمة: "$newValue"');
            setState(() {
              _selectedServiceType = newValue;
            });
            print('✅ تم حفظ نوع الخدمة: "$_selectedServiceType"');
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى اختيار نوع الخدمة';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'موقع الخدمة على الخريطة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        
        // زر تحديد الموقع
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _openLocationPicker(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLocation != null ? const Color(0xFF10B981) : const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            icon: Icon(_selectedLocation != null ? Icons.check_circle : Icons.location_on),
            label: Text(
              _selectedLocation != null ? 'تم تحديد الموقع' : 'تحديد الموقع على الخريطة',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        if (_selectedLocation != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الموقع المحدد:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'خط الطول: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'خط العرض: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openLocationPicker(),
                  icon: const Icon(Icons.edit, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPickerModal(
        initialLocation: _selectedLocation ?? const LatLng(33.3152, 44.3661), // بغداد
        onLocationSelected: (LatLng location) {
          setState(() {
            _selectedLocation = location;
          });
        },
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          print('🔴🔴🔴 BUTTON PRESSED!!! 🔴🔴🔴');
          print('📝 Service Type when button pressed: "$_selectedServiceType"');
          _submitServiceInfo();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'إنشاء حساب مزود الخدمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.check),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _creditCardController.dispose();
    _areaController.dispose();
    super.dispose();
  }
}

// Widget منفصل لاختيار الموقع على الخريطة
class LocationPickerModal extends StatefulWidget {
  final LatLng initialLocation;
  final Function(LatLng) onLocationSelected;

  const LocationPickerModal({
    super.key,
    required this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'تحديد الموقع على الخريطة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // تعليمات
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.info, color: Color(0xFF1E88E5)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اضغط على المكان المطلوب على الخريطة لتحديد موقع خدمتك',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // الخريطة
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation!,
                zoom: 15,
              ),
              onMapCreated: (GoogleMapController controller) {
                // يمكن حفظ controller إذا كان مطلوباً
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
                        infoWindow: const InfoWindow(title: 'الموقع المحدد'),
                      ),
                    }
                  : {},
            ),
          ),
          
          // معلومات الموقع المحدد وزر التأكيد
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_selectedLocation != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF1E88E5)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الموقع المحدد:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'خط الطول: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'خط العرض: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // زر التأكيد
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _selectedLocation != null
                        ? () {
                            widget.onLocationSelected(_selectedLocation!);
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text(
                      'تأكيد الموقع',
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
        ],
      ),
    );
  }
}
