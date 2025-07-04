import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'main_navigation_screen.dart';

class PhonePasswordLoginScreen extends StatefulWidget {
  const PhonePasswordLoginScreen({super.key});

  @override
  State<PhonePasswordLoginScreen> createState() => _PhonePasswordLoginScreenState();
}

class _PhonePasswordLoginScreenState extends State<PhonePasswordLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // جلب بيانات المستخدم من Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(phone).get();
      if (!userDoc.exists) {
        setState(() { _error = 'رقم الهاتف غير مسجل'; _isLoading = false; });
        return;
      }

      final hashedPassword = userDoc['password'];
      if (!BCrypt.checkpw(password, hashedPassword)) {
        setState(() { _error = 'كلمة المرور غير صحيحة'; _isLoading = false; });
        return;
      }

      // حفظ الجلسة محليًا
      // تم حذف SharedPreferences نهائياً. إذا كنت بحاجة لتخزين بيانات استخدم flutter_secure_storage أو Firestore.
      // تم حذف تخزين رقم الهاتف محلياً. إذا كنت بحاجة للوظيفة استخدم flutter_secure_storage.

      setState(() { _isLoading = false; });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainNavigationScreen()),
        );
      }
    } catch (e) {
      setState(() { _error = 'حدث خطأ أثناء تسجيل الدخول.'; _isLoading = false; });
    }
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
          ],
        ),
      ),
    );
  }
}
