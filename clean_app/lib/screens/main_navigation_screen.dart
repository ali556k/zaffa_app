import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'services_screen.dart';
import 'fazaa_screen.dart';
import 'wedding_day_screen.dart';
import '../widgets/custom_page_title.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'my_bookings_screen.dart';
import 'chat/chats_list_screen.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // تم حذف الاعتماد على firebase_auth نهائياً

// استورد الشاشات الأخرى عند الحاجة

class MainNavigationScreen extends StatefulWidget {
  final bool isAdmin;
  const MainNavigationScreen({super.key, this.isAdmin = false});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'الصفحة الرئيسية',
    if (true) '',
    '', // يوم الزفاف بدون عنوان
    '', // الحساب بدون عنوان
    '', // الحجوزات بدون عنوان
    '', // فزعة بدون عنوان
  ];

  List<Widget> get _pages => [
    ServicesScreen(),
    if (widget.isAdmin) AddServiceScreen(),
    WeddingDayScreen(),
    ProfileScreen(),
    MyBookingsScreen(),
    FazaaScreen(),
    // شاشة التواصل مع الدعم الفني
    ChatsListScreen(
      currentUserId: '', // ضع هنا uid أو رقم الهاتف للمستخدم الحالي
      userType: 'user', // أو 'admin' أو 'vendor' حسب نوع المستخدم
    ),
  ];


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color.fromARGB(255, 216, 208, 208),
        body: Stack(
          children: [
            // الصفحة الحالية
            Positioned.fill(child: _pages[_selectedIndex]),
            // تم إلغاء العنوان مؤقتًا لاختبار الخط الأبيض
            // if (_selectedIndex != 0)
            //   Positioned(
            //     top: 0,
            //     left: 0,
            //     right: 0,
            //     child: CustomPageTitle(_titles[_selectedIndex]),
            //   ),
          ],
        ),
        bottomNavigationBar: Directionality(
          textDirection: TextDirection.rtl,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: const Color(0xFFB46A6A),
            unselectedItemColor: Colors.grey,
            items: [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
              if (widget.isAdmin)
                BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'إضافة خدمة'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'يوم الزفاف'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الحساب'),
              BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'الحجوزات'),
              BottomNavigationBarItem(icon: Icon(Icons.flash_on), label: 'فزعة'),
              BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: 'الدعم الفني'),
            ],
          ),
        ),
      ),
    );
  }
}

// شاشة إضافة خدمة (فارغة مؤقتاً)
class AddServiceScreen extends StatelessWidget {
  const AddServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // لا يوجد AppBar ولا أي عبارة في الأعلى
      body: Center(child: Text('واجهة إضافة خدمة للمالك')), // عدلها حسب الحاجة
    );
  }
}

// شاشة الحساب (فارغة مؤقتاً)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 216, 208, 208),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CustomPageTitle('الحساب'),
              const SizedBox(height: 24),
              Text('معلومات الحساب', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFB46A6A),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('طلب إنشاء خدمة', style: TextStyle(fontSize: 18)),
                onPressed: () async {
                  // نافذة بيانات مزود الخدمة
                  final providerData = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (context) {
                      final List<String> serviceTypes = [
                        'قاعات الاعراس',
                        'الفنادق',
                        'المطعم',
                        'تأجير السيارات',
                        'زروقة',
                        'بدلات رجالي',
                        'فستان الزفاف',
                        'صالون وعناية',
                        'شهر عسل',
                        'ورد',
                        'كيك',
                      ];
                      String? selectedServiceType;
                      final nameController = TextEditingController();
                      final phoneController = TextEditingController();
                      final creditController = TextEditingController();
                      return AlertDialog(
                        title: Text('بيانات مزود الخدمة'),
                        content: SingleChildScrollView(
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(labelText: 'نوع الخدمة'),
                                value: selectedServiceType,
                                items: serviceTypes.map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                )).toList(),
                                onChanged: (v) => selectedServiceType = v,
                              ),
                              TextField(
                                controller: nameController,
                                decoration: InputDecoration(labelText: 'اسم المستخدم'),
                              ),
                              TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(labelText: 'رقم الهاتف'),
                              ),
                              TextField(
                                controller: creditController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: 'رقم بطاقة الائتمان'),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text('إلغاء'),
                            onPressed: () => Navigator.pop(context),
                          ),
                          ElevatedButton(
                            child: Text('تسجيل'),
                            onPressed: () {
                              if (selectedServiceType == null ||
                                  nameController.text.isEmpty ||
                                  phoneController.text.isEmpty ||
                                  creditController.text.isEmpty) {
                                // تحقق من ملء جميع الحقول
                                return;
                              }
                              Navigator.pop(context, {
                                'serviceType': selectedServiceType!,
                                'name': nameController.text,
                                'phone': phoneController.text,
                                'credit': creditController.text,
                              });
                            },
                          ),
                        ],
                      );
                    },
                  );
                  if (providerData == null) return;

                  // نافذة بيانات الخدمة
                  final serviceData = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (context) {
                      final serviceNameController = TextEditingController();
                      final servicePriceController = TextEditingController();
                      final serviceDetailsController = TextEditingController();
                      return AlertDialog(
                        title: Text('معلومات الخدمة'),
                        content: SingleChildScrollView(
                          child: Column(
                            children: [
                              TextField(
                                controller: serviceNameController,
                                decoration: InputDecoration(labelText: 'اسم الخدمة'),
                              ),
                              TextField(
                                controller: servicePriceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: 'السعر'),
                              ),
                              TextField(
                                controller: serviceDetailsController,
                                decoration: InputDecoration(labelText: 'تفاصيل الخدمة'),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text('إلغاء'),
                            onPressed: () => Navigator.pop(context),
                          ),
                          ElevatedButton(
                            child: Text('طلب إنشاء الخدمة'),
                            onPressed: () {
                              if (serviceNameController.text.isEmpty ||
                                  servicePriceController.text.isEmpty ||
                                  serviceDetailsController.text.isEmpty) {
                                // تحقق من ملء جميع الحقول
                                return;
                              }
                              Navigator.pop(context, {
                                'serviceName': serviceNameController.text,
                                'servicePrice': servicePriceController.text,
                                'serviceDetails': serviceDetailsController.text,
                              });
                            },
                          ),
                        ],
                      );
                    },
                  );
                  if (serviceData == null) return;

                  // إرسال الطلب إلى المالك (Firestore)
                  // يمكنك تخصيص اسم المجموعة حسب الحاجة
                  // هنا مثال للإرسال
                  try {
                    await FirebaseFirestore.instance.collection('service_requests').add({
                      ...providerData,
                      ...serviceData,
                      'createdAt': DateTime.now(),
                    });
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('تم إرسال الطلب'),
                        content: Text('تم إرسال طلبك بنجاح وسيتم مراجعته من قبل الإدارة.'),
                        actions: [
                          TextButton(
                            child: Text('حسناً'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                    // العودة للصفحة الرئيسية بعد الإرسال
                    // يمكنك تعديل السلوك حسب الحاجة
                  } catch (e) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('خطأ'),
                        content: Text('حدث خطأ أثناء إرسال الطلب: $e'),
                        actions: [
                          TextButton(
                            child: Text('إغلاق'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFFB46A6A),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Color(0xFFB46A6A)),
                ),
                icon: Icon(Icons.logout),
                label: Text('تسجيل الخروج', style: TextStyle(fontSize: 18)),
                onPressed: () async {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final phone = prefs.getString('user_phone');
                    if (phone != null && phone.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('sessions').doc(phone).update({'active': false});
                      await prefs.remove('user_phone');
                    }
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ أثناء تسجيل الخروج: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// شاشة الحجوزات (فارغة مؤقتاً)
class MyBookingsTabScreen extends StatelessWidget {
  const MyBookingsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 216, 208, 208),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CustomPageTitle('حجوزاتي'),
            Expanded(
              child: Center(child: Text('قائمة الحجوزات')),
            ),
          ],
        ),
      ),
    );
  }
}
