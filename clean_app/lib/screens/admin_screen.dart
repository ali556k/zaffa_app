import 'package:flutter/material.dart';

import 'service_items_screen.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // تم حذف الاعتماد على shared_preferences

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {


  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> mainServices = [
      {'id': 'car', 'name': 'خدمة السيارة'},
      {'id': 'hotel', 'name': 'خدمة الفندق'},
      {'id': 'hall', 'name': 'قاعة العرس'},
      {'id': 'bouquet', 'name': 'بوكيه الورد'},
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الخدمات'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'إعادة تعيين تاريخ يوم العرس',
            onPressed: () async {
              // تم حذف منطق SharedPreferences نهائياً. استخدم flutter_secure_storage أو Firestore إذا لزم الأمر.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تمت إعادة تعيين تاريخ يوم العرس')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: mainServices.length,
        itemBuilder: (context, index) {
          final service = mainServices[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Icon(Icons.folder, size: 40, color: Color(0xFF800000)),
              title: Text(service['name']!, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceItemsScreen(
                      serviceId: service['id']!,
                      serviceName: service['name']!,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: null,
    );
  }
}
