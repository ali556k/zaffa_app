// import 'package:firebase_auth/firebase_auth.dart'; // تم حذف الاعتماد على firebase_auth نهائياً
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderHomeScreen extends StatelessWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final user = FirebaseAuth.instance.currentUser; // تم تعطيله لإزالة الاعتماد على FirebaseAuth
    return Scaffold(
      appBar: AppBar(title: Text('لوحة مزود الخدمة')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.add_business),
              label: Text('طلب إنشاء خدمة جديدة'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProviderCreateServiceScreen()),
                );
              },
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.book_online),
              label: Text('عرض الحجوزات'),
              onPressed: () {
                Navigator.pushNamed(context, '/provider_bookings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderCreateServiceScreen extends StatefulWidget {
  const ProviderCreateServiceScreen({super.key});

  @override
  State<ProviderCreateServiceScreen> createState() => _ProviderCreateServiceScreenState();
}

class _ProviderCreateServiceScreenState extends State<ProviderCreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String location = '';
  String creditCard = '';
  String details = '';
  String price = '';
  bool isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    // final user = FirebaseAuth.instance.currentUser; // تم تعطيله لإزالة الاعتماد على FirebaseAuth
    await FirebaseFirestore.instance.collection('service_requests').add({
      // 'providerId': user?.uid, // تم حذف الاعتماد على user
      // 'providerName': user?.displayName ?? '', // تم حذف الاعتماد على user
      'name': name,
      'location': location,
      'creditCard': creditCard,
      'details': details,
      'price': price,
      'status': 'بانتظار الموافقة',
      'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال طلب إنشاء الخدمة!')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلب إنشاء خدمة')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'اسم الخدمة'),
                  onChanged: (v) => name = v,
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'موقع الخدمة'),
                  onChanged: (v) => location = v,
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'رقم بطاقة الائتمان'),
                  onChanged: (v) => creditCard = v,
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'تفاصيل الخدمة'),
                  onChanged: (v) => details = v,
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'سعر الخدمة'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => price = v,
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                SizedBox(height: 24),
                isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text('إرسال الطلب'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
