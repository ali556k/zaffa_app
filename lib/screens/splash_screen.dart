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

      // طباعة جميع المفاتيح المحفوظة للتشخيص
      final allKeys = prefs.getKeys();
      print('🔑 جميع المفاتيح المحفوظة: $allKeys');

      final phone = prefs.getString('user_phone');

      print('🔍 التحقق من الجلسة المحفوظة...');
      print('🔍 رقم الهاتف المحفوظ: $phone');

      if (!mounted) return;

      if (phone != null && phone.isNotEmpty) {
        // السماح بدخول الضيف مباشرة
        if (phone == 'guest') {
          print('👤 ضيف يدخل التطبيق بنجاح');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const MainNavigationScreen(),
            ),
          );
          return;
        }

        // التحقق من وجود المستخدم في قاعدة البيانات أولاً
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(phone)
            .get();

        if (!userDoc.exists) {
          print('🧹 مستخدم غير موجود، تنظيف البيانات المحفوظة');
          // مسح بيانات الجلسة فقط، ليس كل SharedPreferences
          await prefs.remove('user_phone');
          await prefs.remove('account_type');
          await prefs.remove('currentUserId');
          await prefs.remove('providerName');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
          );
          return;
        }

        // التحقق من حالة الجلسة في Firestore
        final sessionDoc = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(phone)
            .get();

        print('🔍 فحص الجلسة لرقم: $phone');
        print('🔍 الجلسة موجودة: ${sessionDoc.exists}');
        if (sessionDoc.exists) {
          print('🔍 بيانات الجلسة: ${sessionDoc.data()}');
          print('🔍 الجلسة نشطة (active): ${sessionDoc.data()?['active']}');
          print('🔍 الجلسة نشطة (isActive): ${sessionDoc.data()?['isActive']}');
        }

        if (sessionDoc.exists &&
            (sessionDoc.data()?['active'] == true ||
                sessionDoc.data()?['isActive'] == true)) {
          // تهيئة خدمة الإشعارات فوراً
          if (mounted) {
            NotificationService().init(context);
            print('🔔 تم تهيئة خدمة الإشعارات');
          }

          // التحقق من نوع الحساب
          final accountType = prefs.getString('account_type');
          print('✅ جلسة نشطة موجودة: $phone - نوع الحساب: $accountType');

          if (accountType == 'provider') {
            print('🔍 مزود خدمة - فحص البيانات المحفوظة...');

            // التحقق من وجود بيانات مزود الخدمة في الواجهة الاحترافية أولاً
            final currentUserId = prefs.getString('currentUserId');
            final providerName = prefs.getString('providerName');

            if (currentUserId != null && currentUserId == phone) {
              // التحقق الإضافي من وجود مزود الخدمة في قاعدة البيانات
              final providerVerification = await FirebaseFirestore.instance
                  .collection('providers')
                  .doc(currentUserId)
                  .get();

              if (providerVerification.exists) {
                print(
                  '✅ تم العثور على بيانات الواجهة الاحترافية المحفوظة للمزود: $providerName',
                );
                // انتقل مباشرة لواجهة مزود الخدمة الاحترافية
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const ProviderMainProfessional(),
                  ),
                );
                return;
              } else {
                // بيانات محفوظة غير صحيحة - حذفها
                print('🧹 بيانات مزود خدمة محفوظة غير صحيحة، تنظيف البيانات');
                await prefs.remove('currentUserId');
                await prefs.remove('providerName');
              }
            }

            // إذا لم تكن البيانات محفوظة، تحقق من قاعدة البيانات
            final providerDoc = await FirebaseFirestore.instance
                .collection('providers')
                .doc(phone)
                .get();

            if (providerDoc.exists) {
              final providerData = providerDoc.data()!;
              print(
                '📱 مزود خدمة موجود في قاعدة البيانات: ${providerData['name']}',
              );

              // حفظ البيانات للمرة القادمة
              await prefs.setString('currentUserId', phone);
              await prefs.setString(
                'providerName',
                providerData['name'] ?? 'مزود الخدمة',
              );

              // انتقل لواجهة مزود الخدمة الاحترافية
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ProviderMainProfessional(),
                ),
              );
              return;
            }

            // التحقق من وجود بيانات الخدمة في النظام القديم
            final serviceDoc = await FirebaseFirestore.instance
                .collection('provider_services')
                .doc(phone)
                .get();

            if (serviceDoc.exists) {
              // مزود خدمة مسجل في النظام القديم - انتقل للشاشة الرئيسية
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
              );
            } else {
              // لا يوجد أي بيانات - انتقل للواجهة الاحترافية الجديدة
              print('📱 انتقال لواجهة مزود الخدمة الاحترافية الجديدة');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ProviderMainProfessional(),
                ),
              );
            }
          } else {
            // مستخدم عادي
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            );
          }
        } else {
          // الجلسة غير نشطة، امسح بيانات الجلسة فقط وانتقل لتسجيل الدخول
          print('! الجلسة غير نشطة أو منتهية الصلاحية');
          await prefs.remove('user_phone');
          await prefs.remove('account_type');
          await prefs.remove('currentUserId');
          await prefs.remove('providerName');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
          );
        }
      } else {
        // لا توجد جلسة محفوظة، انتقل لتسجيل الدخول
        print('ℹ️ لا توجد جلسة محفوظة');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
        );
      }
    } catch (e) {
      // في حالة حدوث خطأ، امسح بيانات الجلسة فقط وانتقل لتسجيل الدخول
      print('❌ خطأ في فحص تسجيل الدخول: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_phone');
      await prefs.remove('account_type');
      await prefs.remove('currentUserId');
      await prefs.remove('providerName');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const login_screen.LoginScreen()),
      );
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
