import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // تم حذف الاعتماد على firebase_auth نهائياً
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;
  const BookingScreen({super.key, required this.serviceData});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool isLoading = false;
  File? receiptImage;
  String? receiptUrl;
  final picker = ImagePicker();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  Future<void> _pickReceiptImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        receiptImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadReceiptImage() async {
    if (receiptImage == null) return null;
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('receipts/$fileName');
    await ref.putFile(receiptImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _bookService() async {
    if (selectedDate == null || selectedTime == null || receiptImage == null) return;
    setState(() => isLoading = true);
    // final user = FirebaseAuth.instance.currentUser; // تم حذف الاعتماد على FirebaseAuth
    final receiptUrl = await _uploadReceiptImage();
    await FirebaseFirestore.instance.collection('bookings').add({
      'serviceId': widget.serviceData['id'],
      'serviceName': widget.serviceData['name'],
      'providerId': widget.serviceData['providerId'] ?? '',
      // 'userId': user?.uid, // تم حذف الاعتماد على user
      // 'userEmail': user?.email, // تم حذف الاعتماد على user
      'date': selectedDate!.toIso8601String(),
      'time': selectedTime!.format(context),
      'receiptUrl': receiptUrl,
      'status': 'بانتظار التأكيد',
      'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إرسال الحجز بانتظار التأكيد!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تثبيت الحجز')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخدمة: ${widget.serviceData['name']}', style: TextStyle(fontSize: 20)),
            SizedBox(height: 16),
            Text('اختر التاريخ:'),
            Row(
              children: [
                Text(selectedDate == null ? 'لم يتم التحديد' : '${selectedDate!.toLocal()}'.split(' ')[0]),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: Text('اختيار التاريخ'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('اختر الوقت:'),
            Row(
              children: [
                Text(selectedTime == null ? 'لم يتم التحديد' : selectedTime!.format(context)),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _selectTime(context),
                  child: Text('اختيار الوقت'),
                ),
              ],
            ),
            SizedBox(height: 24),
            Text('معلومات الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('رقم البطاقة/المحفظة: 0770xxxxxxx'), // عدل الرقم حسب مزود الخدمة
            Text('يرجى الدفع عبر التطبيق الخارجي ثم رفع صورة الإيصال'),
            SizedBox(height: 16),
            Text('إيصال الدفع:'),
            Row(
              children: [
                receiptImage != null
                    ? Image.file(receiptImage!, width: 80, height: 80)
                    : Text('لم يتم اختيار صورة'),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _pickReceiptImage,
                  child: Text('رفع الإيصال'),
                ),
              ],
            ),
            SizedBox(height: 32),
            Center(
              child: isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _bookService,
                      child: Text('تثبيت الحجز ورفع الإيصال'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
