import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PhonePasswordRegisterScreen extends StatefulWidget {
  const PhonePasswordRegisterScreen({super.key});

  @override
  State<PhonePasswordRegisterScreen> createState() => _PhonePasswordRegisterScreenState();
}

class _PhonePasswordRegisterScreenState extends State<PhonePasswordRegisterScreen> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
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

  Future<void> _register() async {
    setState(() { _isLoading = true; _error = null; });
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final province = _selectedProvince;

    if (username.isEmpty || phone.isEmpty || password.length < 6 || province == null) {
      setState(() { _error = 'يرجى إدخال جميع الحقول بشكل صحيح'; _isLoading = false; });
      return;
    }

    try {
      // تسجيل المستخدم في Firebase Auth (يفترض أن لديك طريقة تحقق OTP أو بريد إلكتروني)
      // هنا مثال باستخدام البريد (يمكنك تعديله حسب منطقك)
      final email = '$phone@zafa-app.com';
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      // رفع صورة افتراضية أو تركها فارغة
      String photoUrl = '';

      // حفظ بيانات المستخدم في Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': username,
        'phone': phone,
        'province': province,
        'photoUrl': photoUrl,
        'type': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() { _isLoading = false; });
      if (mounted) Navigator.pop(context); // أو انتقل لواجهة الدخول
    } catch (e) {
      setState(() { _error = 'حدث خطأ أثناء التسجيل: $e'; _isLoading = false; });
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
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
            ),
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
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'اسم المحافظة'),
              value: _selectedProvince,
              items: _provinces.map((prov) => DropdownMenuItem(
                value: prov,
                child: Text(prov),
              )).toList(),
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
                    onPressed: _register,
                    child: const Text('تسجيل'),
                  ),
          ],
        ),
      ),
    );
  }
}
