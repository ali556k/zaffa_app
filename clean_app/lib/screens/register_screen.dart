import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // تحقق من قوة كلمة المرور
  bool _isPasswordStrong(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$');
    return regex.hasMatch(password);
  }

  final _storage = const FlutterSecureStorage();

  Future<void> _register() async {
    setState(() { _isLoading = true; _error = null; });
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() { _error = 'يرجى إدخال جميع الحقول'; _isLoading = false; });
      return;
    }
    if (!_isPasswordStrong(password)) {
      setState(() {
        _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي على حرف كبير وصغير ورقم ورمز.';
        _isLoading = false;
      });
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(phone).get();
    if (userDoc.exists) {
      setState(() { _error = 'رقم الهاتف مسجل مسبقًا'; _isLoading = false; });
      return;
    }

    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
    await FirebaseFirestore.instance.collection('users').doc(phone).set({
      'phone': phone,
      'password': hashedPassword,
      'createdAt': FieldValue.serverTimestamp(),
      'failedAttempts': 0,
      'lastFailedAttempt': null,
      'lastSession': FieldValue.serverTimestamp(),
    });

    // حفظ الجلسة بعد التسجيل
    await _storage.write(key: 'user_phone', value: phone);
    print('تم حفظ الجلسة بعد التسجيل: $phone');

    setState(() { _isLoading = false; });
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل حساب جديد')),
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
            const SizedBox(height: 8),
            Text(
              'اختر كلمة مرور قوية ولا تشاركها مع أي شخص.',
              style: TextStyle(color: Colors.blueGrey, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: const Text('إنشاء حساب'),
                  ),
          ],
        ),
      ),
    );
  }
}
