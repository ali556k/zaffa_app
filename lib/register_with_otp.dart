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
      await prefs.setBool('is_logged_in', true);

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

  String _fmtTimer() {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showOtpModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // مزامنة الثواني مع الـ StatefulBuilder
            void syncState() {
              if (ctx.mounted) setModalState(() {});
            }

            _otpTimer?.cancel();
            _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (_secondsLeft > 0) {
                setState(() => _secondsLeft--);
                syncState();
              } else {
                t.cancel();
                syncState();
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // أيقونة
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6E1229).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        color: Color(0xFF6E1229),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'أدخل رمز التحقق',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تم إرسال الرمز إلى\n${_otpPhone ?? widget.phone}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    // حقل إدخال الرمز
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 10,
                        color: Color(0xFF6E1229),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '----',
                        hintStyle: const TextStyle(
                          letterSpacing: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF6E1229).withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF6E1229),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // عداد
                    _secondsLeft > 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: _secondsLeft < 60
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'صلاحية الرمز: ${_fmtTimer()}',
                                style: TextStyle(
                                  color: _secondsLeft < 60
                                      ? Colors.red
                                      : Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : TextButton.icon(
                            onPressed: _isLoading ? null : _sendOtp,
                            icon: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Color(0xFF6E1229),
                            ),
                            label: const Text(
                              'إعادة إرسال الرمز',
                              style: TextStyle(color: Color(0xFF6E1229)),
                            ),
                          ),
                    // رسالة الخطأ
                    if (_registerError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _registerError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // زر التحقق
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _verifyOtpAndRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6E1229),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_outlined, size: 20),
                        label: Text(
                          _isLoading ? 'جاري التحقق...' : 'تحقق وأكمل التسجيل',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'التحقق من رقم الهاتف',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6E1229),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // أيقونة رئيسية
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6E1229), Color(0xFF9C1B3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6E1229).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'التحقق من رقم الهاتف',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم إرسال رمز التحقق إلى\n${widget.phone}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // بطاقة الحالة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Column(
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              color: Color(0xFF6E1229),
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'جاري إرسال رمز التحقق...',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6E1229),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : _otpError != null
                    ? Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _otpError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6E1229),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text(
                                'إعادة الإرسال',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'تم الإرسال! ستصل الرسالة خلال لحظات عبر WhatsApp أو SMS',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'سيظهر نافذة لإدخال الرمز تلقائياً',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
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
}
