import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_navigation_screen.dart';
import 'register_screen.dart';
import 'provider_main_professional.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clearInvalidSession();
  }

  // تنظيف أي جلسة غير صحيحة محفوظة
  Future<void> _clearInvalidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('currentUserId');

    if (currentUserId != null) {
      // التحقق من صحة البيانات المحفوظة
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();

        if (!userDoc.exists) {
          print('🧹 تنظيف بيانات جلسة غير صحيحة: $currentUserId');
          await prefs.clear();
        }
      } catch (e) {
        print('🧹 خطأ في التحقق من الجلسة، تنظيف البيانات: $e');
        await prefs.clear();
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(phone);
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        await _logAttempt(phone, false, 'رقم الهاتف غير مسجل');
        setState(() {
          _error = 'رقم الهاتف غير مسجل';
          _isLoading = false;
        });
        return;
      }

      final data = userDoc.data()!;
      final hashedPassword = data['password'];
      final failedAttempts = data['failedAttempts'] ?? 0;
      final lastFailedAttempt = data['lastFailedAttempt']?.toDate();
      final accountType = data['accountType'] ?? 'customer';

      // تحقق من الحظر المؤقت
      if (failedAttempts >= 5 && lastFailedAttempt != null) {
        final now = DateTime.now();
        if (now.difference(lastFailedAttempt).inMinutes < 15) {
          setState(() {
            _error =
                'تم حظر الحساب مؤقتًا بسبب محاولات خاطئة. حاول بعد 15 دقيقة.';
            _isLoading = false;
          });
          return;
        } else {
          // إعادة تعيين العد بعد انتهاء الحظر
          try {
            await userRef.update({
              'failedAttempts': 0,
              'lastFailedAttempt': null,
            });
          } catch (e) {
            print('خطأ في إعادة تعيين محاولات فاشلة: $e');
          }
        }
      }

      if (!BCrypt.checkpw(password, hashedPassword)) {
        try {
          await userRef.update({
            'failedAttempts': failedAttempts + 1,
            'lastFailedAttempt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('خطأ في تحديث محاولات فاشلة: $e');
        }
        await _logAttempt(phone, false, 'كلمة المرور غير صحيحة');
        setState(() {
          _error = 'كلمة المرور غير صحيحة';
          _isLoading = false;
        });
        return;
      }

      // نجاح الدخول: إعادة تعيين العد
      try {
        await userRef.update({'failedAttempts': 0, 'lastFailedAttempt': null});
      } catch (e) {
        print('خطأ في إعادة تعيين العد: $e');
      }
      await _logAttempt(phone, true, 'نجاح الدخول');

      // حفظ الجلسة الجديدة في Firestore مع active=true
      try {
        await FirebaseFirestore.instance.collection('sessions').doc(phone).set({
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
          'active': true,
        });
        // تحديث آخر دخول في Firestore
        await userRef.update({'lastSession': FieldValue.serverTimestamp()});
        print('تم حفظ الجلسة بعد تسجيل الدخول في Firestore فقط: $phone');
      } catch (e) {
        print('خطأ في حفظ الجلسة: $e');
      }

      // حفظ رقم الهاتف ونوع الحساب محليًا
      final prefs = await SharedPreferences.getInstance();

      // طباعة المفاتيح الموجودة قبل الحفظ
      print('🔑 المفاتيح قبل الحفظ: ${prefs.getKeys()}');

      await prefs.setString('user_phone', phone);
      await prefs.setString('account_type', accountType);

      // إجبار حفظ البيانات فوراً
      await prefs.commit();

      // التحقق من حفظ البيانات فوراً
      final savedPhone = prefs.getString('user_phone');
      final savedAccountType = prefs.getString('account_type');
      print('✅ تم حفظ بيانات تسجيل الدخول محلياً: $phone - $accountType');
      print('🔍 التحقق من الحفظ: $savedPhone - $savedAccountType');
      print('🔑 المفاتيح بعد الحفظ: ${prefs.getKeys()}');

      // حفظ توكن الجهاز للإشعارات
      try {
        await NotificationService().saveDeviceToken();
      } catch (e) {
        print('خطأ في حفظ توكن الجهاز: $e');
      }

      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        // بعد تسجيل الدخول، انتقل مباشرة للواجهة المناسبة
        if (accountType == 'provider') {
          // حفظ بيانات تسجيل الدخول لمزود الخدمة
          try {
            // التحقق من وجود بيانات مزود الخدمة وحفظها
            final providerDoc = await FirebaseFirestore.instance
                .collection('providers')
                .doc(phone)
                .get();

            if (providerDoc.exists) {
              final providerData = providerDoc.data()!;
              await _saveProviderLoginState(
                phone,
                accountType,
                providerData['name'] ?? 'مزود الخدمة',
              );

              // انتقل مباشرة لواجهة مزود الخدمة الاحترافية
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProviderMainProfessional(),
                ),
                (route) => false,
              );
            } else {
              // مزود الخدمة غير موجود في قاعدة البيانات
              print('❌ مزود الخدمة غير مسجل في النظام');
              setState(() {
                _error =
                    'هذا الرقم غير مسجل كمزود خدمة. يرجى التواصل مع الإدارة.';
                _isLoading = false;
              });
              return;
            }
          } catch (e) {
            print('خطأ في حفظ بيانات مزود الخدمة: $e');
            // في حالة الخطأ، لا تحفظ بيانات خاطئة
            setState(() {
              _error =
                  'حدث خطأ في التحقق من بيانات مزود الخدمة. يرجى المحاولة مرة أخرى.';
              _isLoading = false;
            });
            return;
          }
        } else {
          _saveLoginState(phone, accountType);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('خطأ عام في تسجيل الدخول: $e');
      setState(() {
        _error = 'حدث خطأ في تسجيل الدخول. يرجى المحاولة مرة أخرى.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLoginState(String userPhone, String accountType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'user_phone',
      userPhone,
    ); // إضافة هذا للتوافق مع ProviderMainScreen
    await prefs.setString('account_type', accountType);

    // حفظ الجلسة في Firestore
    await FirebaseFirestore.instance.collection('sessions').doc(userPhone).set({
      'active': true,
      'lastLogin': FieldValue.serverTimestamp(),
      'accountType': accountType,
    });
  }

  // دالة حفظ بيانات مزود الخدمة مع خاصية التذكر
  Future<void> _saveProviderLoginState(
    String userPhone,
    String accountType,
    String providerName,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // طباعة المفاتيح الموجودة قبل الحفظ
    print('🔑 المفاتيح قبل حفظ مزود الخدمة: ${prefs.getKeys()}');

    await prefs.setString('user_phone', userPhone);
    await prefs.setString('account_type', accountType);
    await prefs.setString('currentUserId', userPhone);
    await prefs.setString('providerName', providerName);

    // إجبار حفظ البيانات فوراً
    await prefs.commit();

    // التحقق من حفظ البيانات فوراً
    final savedPhone = prefs.getString('user_phone');
    final savedAccountType = prefs.getString('account_type');
    final savedUserId = prefs.getString('currentUserId');

    // حفظ الجلسة في Firestore
    await FirebaseFirestore.instance.collection('sessions').doc(userPhone).set({
      'active': true,
      'lastLogin': FieldValue.serverTimestamp(),
      'accountType': accountType,
    });

    print('✅ تم حفظ بيانات مزود الخدمة والجلسة للتذكر: $providerName');
    print(
      '🔍 التحقق من الحفظ: هاتف=$savedPhone، نوع=$savedAccountType، معرف=$savedUserId',
    );
    print('🔑 المفاتيح بعد حفظ مزود الخدمة: ${prefs.getKeys()}');
  }

  // تسجيل محاولات الدخول
  Future<void> _logAttempt(String phone, bool success, String message) async {
    try {
      await FirebaseFirestore.instance.collection('login_attempts').add({
        'phone': phone,
        'success': success,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('خطأ في تسجيل محاولة الدخول: $e');
      // تجاهل الخطأ - هذا ليس مهماً للوظيفة الأساسية
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6E1229),
              const Color(0xFF6E1229).withOpacity(0.9),
              const Color(0xFF6E1229),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // شعار التطبيق
                  ClipOval(
                    child: Image.asset(
                      'assets/app_icon_new.png',
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 130,
                          height: 130,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.celebration,
                            size: 80,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),

                  // عنوان الترحيب
                  const Text(
                    'أهلاً بك في زفة',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'سجل الدخول للمتابعة',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // حقل رقم الهاتف
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      decoration: InputDecoration(
                        hintText: 'رقم الهاتف',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.phone_android,
                          color: const Color(0xFF6E1229),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // حقل كلمة المرور
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      decoration: InputDecoration(
                        hintText: 'كلمة المرور',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: const Color(0xFF6E1229),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),

                  // رسالة الخطأ
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // زر تسجيل الدخول
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF530405),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // زر إنشاء حساب جديد
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RegisterScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ليس لديك حساب؟ ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'سجل الآن',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,

                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // زر نسيت كلمة المرور
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text(
                            'إعادة تعيين كلمة المرور',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF530405),
                            ),
                          ),
                          content: const Text(
                            'يرجى التواصل مع الدعم الفني لاستعادة كلمة المرور.',
                            style: TextStyle(fontSize: 15),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF530405),
                              ),
                              child: const Text(
                                'حسنًا',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  // رابط سياسة الخصوصية
                  TextButton(
                    onPressed: () async {
                      final Uri url = Uri.parse(
                        'https://sites.google.com/view/zaffa-iq/%D8%A7%D9%84%D8%B5%D9%81%D8%AD%D8%A9-%D8%A7%D9%84%D8%B1%D8%A6%D9%8A%D8%B3%D9%8A%D8%A9',
                      );
                      if (!await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      )) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('لم يتمكن من فتح الرابط'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      'شروط الأحكام وسياسة الخصوصية',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
