import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation_screen.dart';
import '../register_with_otp.dart';

class PhonePasswordRegisterScreen extends StatefulWidget {
  const PhonePasswordRegisterScreen({super.key});

  @override
  State<PhonePasswordRegisterScreen> createState() =>
      _PhonePasswordRegisterScreenState();
}

class _PhonePasswordRegisterScreenState
    extends State<PhonePasswordRegisterScreen> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _creditCardController = TextEditingController();
  String? _selectedProvince;
  bool _isLoading = false;
  String? _error;

  final List<String> _provinces = [
    'بغداد',
    'كركوك',
    'ميسان',
    'البصرة',
    'النجف',
    'كربلاء',
    'الديوانية',
    'بابل',
    'ذي قار',
    'المثنى',
    'واسط',
    'ديالى',
    'الانبار',
    'صلاح الدين',
    'نينوى',
    'دهوك',
    'اربيل',
    'سليمانية',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تسجيل حساب جديد',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF530405),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: Icon(Icons.person, color: Color(0xFF530405)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone, color: Color(0xFF530405)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF530405)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _creditCardController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رقم بطاقة الائتمان',
                  helperText: '16 رقم للدفع الإلكتروني',
                  prefixIcon: Icon(Icons.credit_card, color: Color(0xFF530405)),
                ),
                maxLength: 16,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'اسم المحافظة',
                  prefixIcon: Icon(
                    Icons.location_city,
                    color: Color(0xFF530405),
                  ),
                ),
                value: _selectedProvince,
                items: _provinces
                    .map(
                      (prov) =>
                          DropdownMenuItem(value: prov, child: Text(prov)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedProvince = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        final username = _usernameController.text.trim();
                        final phone = _phoneController.text.trim();
                        final password = _passwordController.text.trim();
                        final creditCard = _creditCardController.text.trim();
                        final province = _selectedProvince ?? '';
                        if (username.isEmpty ||
                            phone.isEmpty ||
                            password.length < 6 ||
                            province.isEmpty ||
                            creditCard.isEmpty ||
                            creditCard.length < 16) {
                          setState(() {
                            _error =
                                'يرجى إدخال جميع الحقول بشكل صحيح\nكلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          });
                          return;
                        }

                        // التحقق من الهاتف غير مسجل ثم الانتقال لـ OTP
                        setState(() => _isLoading = true);
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(phone)
                            .get()
                            .then((doc) {
                              setState(() => _isLoading = false);
                              if (doc.exists) {
                                setState(
                                  () => _error = 'رقم الهاتف مسجل مسبقاً',
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterWithOtpPage(
                                    name: username,
                                    phone: phone,
                                    province: province,
                                    creditCard: creditCard,
                                    password: password,
                                    accountType: 'customer',
                                  ),
                                ),
                              );
                            })
                            .catchError((e) {
                              setState(() {
                                _isLoading = false;
                                _error = 'حدث خطأ: $e';
                              });
                            });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF530405),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('تسجيل'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registerDirectly(
    String name,
    String phone,
    String password,
    String province,
    String creditCard,
  ) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔐 بدء إنشاء الحساب مباشرة بدون OTP...');

      // التحقق من وجود الرقم مسبقاً
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(phone)
          .get();

      if (existingUser.exists) {
        setState(() {
          _error = 'رقم الهاتف مسجل مسبقاً';
          _isLoading = false;
        });
        return;
      }

      // تشفير كلمة المرور
      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      // إنشاء الحساب
      await FirebaseFirestore.instance.collection('users').doc(phone).set({
        'name': name,
        'phone': phone,
        'password': hashedPassword,
        'governorate': province,
        'city': province,
        'creditCard': creditCard,
        'accountType': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      print('✅ تم إنشاء الحساب بنجاح');

      // حفظ بيانات تسجيل الدخول
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_name', name);
      await prefs.setString('account_type', 'customer');
      await prefs.setString('currentUserId', phone);
      await prefs.setBool('is_logged_in', true);

      if (mounted) {
        // الانتقال للصفحة الرئيسية
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ خطأ في إنشاء الحساب: $e');
      setState(() {
        _error = 'حدث خطأ أثناء التسجيل: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}
