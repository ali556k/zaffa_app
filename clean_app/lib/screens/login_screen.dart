
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ...existing code...
import 'main_screen.dart';
import 'register_screen.dart';

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

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final userRef = FirebaseFirestore.instance.collection('users').doc(phone);
    final userDoc = await userRef.get();
    if (!userDoc.exists) {
      await _logAttempt(phone, false, 'رقم الهاتف غير مسجل');
      setState(() { _error = 'رقم الهاتف غير مسجل'; _isLoading = false; });
      return;
    }

    final data = userDoc.data()!;
    final hashedPassword = data['password'];
    final failedAttempts = data['failedAttempts'] ?? 0;
    final lastFailedAttempt = data['lastFailedAttempt']?.toDate();

    // تحقق من الحظر المؤقت
    if (failedAttempts >= 5 && lastFailedAttempt != null) {
      final now = DateTime.now();
      if (now.difference(lastFailedAttempt).inMinutes < 15) {
        setState(() {
          _error = 'تم حظر الحساب مؤقتًا بسبب محاولات خاطئة. حاول بعد 15 دقيقة.';
          _isLoading = false;
        });
        return;
      } else {
        // إعادة تعيين العد بعد انتهاء الحظر
        await userRef.update({'failedAttempts': 0, 'lastFailedAttempt': null});
      }
    }

    if (!BCrypt.checkpw(password, hashedPassword)) {
      await userRef.update({
        'failedAttempts': failedAttempts + 1,
        'lastFailedAttempt': FieldValue.serverTimestamp(),
      });
      await _logAttempt(phone, false, 'كلمة المرور غير صحيحة');
      setState(() { _error = 'كلمة المرور غير صحيحة'; _isLoading = false; });
      return;
    }

    // نجاح الدخول: إعادة تعيين العد
    await userRef.update({'failedAttempts': 0, 'lastFailedAttempt': null});
    await _logAttempt(phone, true, 'نجاح الدخول');

    // حفظ الجلسة الجديدة في Firestore مع active=true
    await FirebaseFirestore.instance.collection('sessions').doc(phone).set({
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
    // تحديث آخر دخول في Firestore
    await userRef.update({'lastSession': FieldValue.serverTimestamp()});
    print('تم حفظ الجلسة بعد تسجيل الدخول في Firestore فقط: $phone');

    // حفظ رقم الهاتف محليًا
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', phone);

    setState(() { _isLoading = false; });
    if (mounted) {
      // بعد تسجيل الدخول، انتقل مباشرة للواجهة الرئيسية
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainScreen()),
        (route) => false,
      );
    }
  }

  // تسجيل محاولات الدخول
  Future<void> _logAttempt(String phone, bool success, String message) async {
    await FirebaseFirestore.instance.collection('login_attempts').add({
      'phone': phone,
      'success': success,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: const Text('دخول'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterScreen()),
                );
              },
              child: const Text('إنشاء حساب جديد'),
            ),
            TextButton(
              onPressed: () {
                // مثال: توجيه المستخدم للدعم الفني أو صفحة استعادة كلمة المرور
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('إعادة تعيين كلمة المرور'),
                    content: const Text('يرجى التواصل مع الدعم الفني لاستعادة كلمة المرور.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('حسنًا'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('نسيت كلمة المرور؟'),
            ),
          ],
        ),
      ),
    );
  }
}
