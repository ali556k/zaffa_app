import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/service_information_screen.dart';

class RegisterWithOtpPage extends StatefulWidget {
  final String name;
  final String phone;
  final String province;
  final String creditCard;
  final String password;
  final String? accountType;
  final String? area;
  final String? profileImagePath;

  const RegisterWithOtpPage({
    super.key,
    required this.name,
    required this.phone,
    required this.province,
    required this.creditCard,
    required this.password,
    this.accountType,
    this.area,
    this.profileImagePath,
  });

  @override
  State<RegisterWithOtpPage> createState() => _RegisterWithOtpPageState();
}

class _RegisterWithOtpPageState extends State<RegisterWithOtpPage> {
  final _otpController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _otpError;
  String? _registerError;
  String? _otpPhone;
  Timer? _otpTimer;
  int _secondsLeft = 0;

  static const otpUrl = 'https://sendotp-cuoayufz5a-uc.a.run.app';
  static const verifyUrl = 'https://verifyotp-cuoayufz5a-uc.a.run.app';
  static const otpTimeout = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.phone;
    print('🎯 صفحة OTP مفتوحة لرقم: ${widget.phone}');

    // إرسال OTP تلقائياً عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('⏰ بدء إرسال OTP تلقائياً...');
      _sendOtp();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _phoneController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _otpError = null;
      _registerError = null;
    });
    final phone = widget.phone;
    print('🔄 محاولة إرسال OTP لرقم: $phone');
    try {
      final res = await http.post(
        Uri.parse(otpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      print('📱 رد الخادم: ${res.statusCode} - ${res.body}');
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          _otpPhone = phone;
          _secondsLeft = otpTimeout;
        });
        _startOtpTimer();
        print(
          '✅ تم إرسال OTP بنجاح إلى رقم الهاتف، سيتم عرض نافذة إدخال الرمز',
        );
        _showOtpModal();
      } else {
        print('❌ فشل OTP: ${res.statusCode} - ${res.body}');
        setState(() {
          _otpError = data['error'] ?? 'فشل إرسال رمز التحقق';
        });
      }
    } catch (e) {
      print('💥 خطأ في الاتصال: $e');
      setState(() {
        _otpError = 'خطأ في الاتصال بالخادم: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtpAndRegister() async {
    setState(() {
      _isLoading = true;
      _registerError = null;
    });
    final phone = _otpPhone ?? _phoneController.text.trim();
    final otp = _otpController.text.trim();
    try {
      final res = await http.post(
        Uri.parse(verifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['verified'] == true) {
        await _createUser();
        if (mounted) {
          Navigator.of(context).pop();
          _showSuccessDialog();
        }
      } else {
        setState(() {
          _registerError = data['reason'] == 'expired'
              ? 'انتهت صلاحية الرمز. اطلب رمز جديد.'
              : 'رمز التحقق غير صحيح.';
        });
      }
    } catch (e) {
      setState(() {
        _registerError = 'خطأ في الاتصال بالخادم';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createUser() async {
    try {
      // رفع الصورة إذا وجدت
      String? imageUrl;
      if (widget.profileImagePath != null) {
        imageUrl = await _uploadProfileImage();
      }

      // تشفير كلمة المرور
      final hashedPassword = BCrypt.hashpw(widget.password, BCrypt.gensalt());

      // بيانات المستخدم
      final userData = {
        'name': widget.name,
        'phone': widget.phone,
        'city': widget.province,
        'governorate': widget.province,
        'area': widget.area ?? '',
        'password': hashedPassword,
        'profileImage': imageUrl,
        'accountType': widget.accountType ?? 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'failedAttempts': 0,
        'lastFailedAttempt': null,
        'lastSession': FieldValue.serverTimestamp(),
      };

      // إنشاء المستخدم في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.phone)
          .set(userData);

      // حفظ بيانات الجلسة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', widget.phone);
      await prefs.setString('account_type', widget.accountType ?? 'customer');

      if (widget.accountType != 'provider') {
        // إذا كان عميل عادي، إنشاء جلسة نشطة
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.phone)
            .set({
              'active': true,
              'accountType': widget.accountType ?? 'customer',
              'lastLogin': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      print('خطأ في إنشاء المستخدم: $e');
      rethrow;
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (widget.profileImagePath == null) return null;
    try {
      final file = File(widget.profileImagePath!);
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${widget.phone}.jpg');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      return null;
    }
  }

  void _showOtpModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'التحقق من رقم الهاتف',
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تم إرسال رمز التحقق إلى'),
                  const SizedBox(height: 8),
                  Text(
                    _otpPhone ?? 'رقم الهاتف',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'يرجى إدخال الرمز المرسل إلى هاتفك:',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رمز التحقق',
                      border: OutlineInputBorder(),
                      hintText: 'ادخل الرمز المكون من 6 أرقام',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_secondsLeft > 0)
                    Text(
                      'الوقت المتبقي: $_secondsLeft ثانية',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  if (_registerError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _registerError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtpAndRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('تحقق OTP'),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _secondsLeft == 0 && !_isLoading
                        ? _sendOtp
                        : null,
                    child: const Text('إعادة إرسال الرمز'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تم التسجيل بنجاح', textAlign: TextAlign.center),
        content: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.accountType == 'provider') {
                // إذا كان مزود خدمة، اتجه إلى شاشة معلومات الخدمة
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceInformationScreen(
                      userName: widget.name,
                      userPhone: widget.phone,
                      userGovernorate: widget.province,
                    ),
                  ),
                );
              } else {
                // إذا كان عميل عادي، اتجه إلى الشاشة الرئيسية
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainNavigationScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('التحقق من رقم الهاتف'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: width > 500 ? 400 : width * 0.95,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android, size: 64, color: Colors.teal),
                const SizedBox(height: 16),
                const Text(
                  'تم إرسال رمز التحقق',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'إلى رقم: ${widget.phone}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جاري إرسال الرمز...'),
                    ],
                  )
                else if (_otpError != null)
                  Column(
                    children: [
                      Text(
                        _otpError!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text('إعادة الإرسال'),
                      ),
                    ],
                  )
                else
                  const Text(
                    'يرجى انتظار وصول الرسالة',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
