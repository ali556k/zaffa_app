import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart' as login_screen;
import 'register_screen.dart';
import 'provider_main_professional.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      print('🔍 user_phone=$phone | is_logged_in=$isLoggedIn');

      if (!mounted) return;

      // ── لا توجد جلسة محفوظة ──
      if (phone == null || phone.isEmpty || !isLoggedIn) {
        print('ℹ️ لا توجد جلسة صالحة');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
        );
        return;
      }

      // ── ضيف ──
      if (phone == 'guest') {
        print('👤 ضيف');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
        return;
      }

      // ── تهيئة الإشعارات ──
      NotificationService().init(context);

      // ── توجيه فوري بدون انتظار Firestore ──
      final accountType = prefs.getString('account_type') ?? 'customer';
      print('✅ جلسة صالحة: $phone | نوع: $accountType');

      if (accountType == 'provider') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProviderMainProfessional()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }

      // ── تحقق في الخلفية من وجود المستخدم في Firestore (لا يحجب التنقل) ──
      _verifyUserInBackground(phone, prefs);
    } catch (e) {
      print('❌ خطأ في _checkLogin: $e');
      if (!mounted) return;
      // حتى عند الخطأ: إذا كان هناك phone محفوظ → فتح التطبيق
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (phone != null && phone.isNotEmpty && isLoggedIn && phone != 'guest') {
        final accountType = prefs.getString('account_type') ?? 'customer';
        if (!mounted) return;
        if (accountType == 'provider') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProviderMainProfessional()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        }
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
        );
      }
    }
  }

  /// تحقق في الخلفية — يُسجّل الخروج فقط إذا حُذف المستخدم نهائياً من Firestore
  Future<void> _verifyUserInBackground(
    String phone,
    SharedPreferences prefs,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(phone)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!userDoc.exists) {
        print('⚠️ المستخدم $phone محذوف من Firestore — سيُسجَّل خروجه');
        await prefs.remove('user_phone');
        await prefs.remove('is_logged_in');
        await prefs.remove('account_type');
        await prefs.remove('currentUserId');
        await prefs.remove('providerName');
        // لا نُنقّل هنا لأن المستخدم ربما فتح صفحة داخلية بالفعل
      }
    } catch (_) {
      // تجاهل أخطاء الشبكة — الجلسة تبقى صالحة
      print('⚠️ تعذّر التحقق من Firestore في الخلفية (شبكة) — تجاهل');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class LoginOrRegisterScreen extends StatelessWidget {
  const LoginOrRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'يرجى تسجيل الدخول أولاً',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const login_screen.LoginScreen(),
                  ),
                );
              },
              child: const Text('تسجيل الدخول'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text('create_account_new'),
            ),
          ],
        ),
      ),
    );
  }
}
