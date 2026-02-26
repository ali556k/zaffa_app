import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'splash_screen.dart';

import 'provider_items_registration_screen.dart';
import 'item_edit_screen.dart';
import 'dart:async';

class ProviderMainProfessional extends StatefulWidget {
  const ProviderMainProfessional({super.key});

  @override
  State<ProviderMainProfessional> createState() =>
      _ProviderMainProfessionalState();
}

class _ProviderMainProfessionalState extends State<ProviderMainProfessional>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _providerId;
  Map<String, dynamic>? _serviceData;
  Map<String, dynamic>? _providerData;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _pendingBookings = [];
  bool _isLoading = true;
  late Timer _refreshTimer;
  late TabController _homeTabController;
  late AnimationController _animationController;

  // إحصائيات احترافية
  int _totalBookings = 0;
  int _activeItems = 0;
  double _totalRevenue = 0;
  double _monthlyRevenue = 0;

  @override
  void initState() {
    super.initState();
    _homeTabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _loadProviderData();
    _animationController.forward();

    // تحديث الإحصائيات كل 30 ثانية
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadProviderData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _homeTabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // دالة لحفظ بيانات مزود الخدمة في SharedPreferences
  Future<void> _saveProviderLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserId', _providerId ?? '');
      await prefs.setString('providerName', _providerData?['name'] ?? '');
      await prefs.setString('user_phone', _providerData?['phone'] ?? '');
      await prefs.setString('account_type', 'provider');

      print('✅ تم حفظ بيانات مزود الخدمة: ${_providerData?['name']}');

      // حفظ الجلسة في Firestore أيضاً
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_providerId)
          .set({
            'userId': _providerId,
            'accountType': 'provider',
            'isActive': true,
            'lastLogin': FieldValue.serverTimestamp(),
            'name': _providerData?['name'],
            'phone': _providerData?['phone'],
          });

      print('✅ تم حفظ جلسة مزود الخدمة بمعرف: $_providerId');
    } catch (e) {
      print('خطأ في حفظ بيانات التسجيل: $e');
    }
  }

  Future<void> _loadProviderData() async {
    try {
      print('🔄 بدء تحميل بيانات مزود الخدمة...');
      final prefs = await SharedPreferences.getInstance();
      _providerId = prefs.getString('currentUserId');

      if (_providerId == null || _providerId!.isEmpty) {
        print('❌ معرف مزود الخدمة غير موجود، العودة للشاشة الرئيسية');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
        return;
      }

      print('📱 معرف مزود الخدمة: $_providerId');

      // تحميل بيانات مزود الخدمة
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(_providerId)
          .get();

      if (providerDoc.exists) {
        _providerData = providerDoc.data();
        print('👤 تم تحميل بيانات مزود الخدمة: ${_providerData?['name']}');

        // تحميل بيانات الخدمة
        final serviceDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(_providerId)
            .get();

        if (serviceDoc.exists) {
          _serviceData = serviceDoc.data();
          print('🏢 تم تحميل بيانات الخدمة: ${_serviceData?['serviceName']}');
        }

        // حفظ بيانات التسجيل
        await _saveProviderLoginData();

        // تحميل العناصر من جميع مجموعات الخدمات
        final serviceTypes = [
          'hall',
          'hotel',
          'cake',
          'restaurant',
          'bride_dress',
          'salon_care',
          'flowers',
          'groom_suit',
          'car',
          'car_decoration',
          'honeymoon',
          'عامة',
        ];

        List<Map<String, dynamic>> allItems = [];

        for (String serviceType in serviceTypes) {
          final snapshot = await FirebaseFirestore.instance
              .collection(serviceType)
              .where('providerId', isEqualTo: _providerId)
              .get();

          print(
            '🔍 البحث في مجموعة $serviceType: وجد ${snapshot.docs.length} عنصر',
          );

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            data['collectionName'] = serviceType;
            allItems.add(data);
            print('➕ تم إضافة عنصر: ${data['name'] ?? 'بدون اسم'}');
          }
        }

        // تحميل الحجوزات
        final bookingsSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('providerId', isEqualTo: _providerId)
            .get();

        List<Map<String, dynamic>> allBookings = [];
        for (var doc in bookingsSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          allBookings.add(data);
        }

        if (mounted) {
          setState(() {
            _items = allItems;
            _bookings = allBookings;
            _pendingBookings = allBookings
                .where((booking) => booking['status'] == 'pending')
                .toList();
            _isLoading = false;
          });

          print('🔍 تم تحميل ${_items.length} عنصر لمزود الخدمة $_providerId');

          // تحديث الإحصائيات
          _updateProfessionalStatistics();
        }
      } else {
        print('❌ مزود الخدمة غير موجود في قاعدة البيانات');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('خطأ في تحميل بيانات المزود: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateProfessionalStatistics() {
    // حساب العناصر النشطة (active أو approved أو بدون status)
    _activeItems = _items
        .where(
          (item) =>
              item['status'] == 'active' ||
              item['status'] == 'approved' ||
              item['status'] == null ||
              !item.containsKey('status'),
        )
        .length;

    print('📊 إحصائيات العناصر: المجموع ${_items.length}، النشط $_activeItems');

    // حساب إحصائيات الحجوزات
    _totalBookings = _bookings.length;

    // حساب الإيرادات (للشهر الحالي فقط)
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    _monthlyRevenue = _bookings
        .where(
          (booking) =>
              booking['status'] == 'confirmed' &&
              booking['createdAt'] != null &&
              (booking['createdAt'] as Timestamp).toDate().isAfter(
                currentMonth,
              ),
        )
        .fold(
          0.0,
          (sum, booking) =>
              sum +
              (double.tryParse(booking['totalPrice']?.toString() ?? '0') ??
                  0.0),
        );

    _totalRevenue = _bookings
        .where((booking) => booking['status'] == 'confirmed')
        .fold(
          0.0,
          (sum, booking) =>
              sum +
              (double.tryParse(booking['totalPrice']?.toString() ?? '0') ??
                  0.0),
        );

    print('💰 إيرادات الشهر: $_monthlyRevenue، الإجمالي: $_totalRevenue');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadProviderData,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildProfessionalHomeScreen(),
            _buildProfessionalBookingsScreen(),
            _buildProfessionalAccountScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildProfessionalBottomNav(),
    );
  }

  Widget _buildProfessionalBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF667eea),
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_online_rounded),
              label: 'الحجوزات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_rounded),
              label: 'الحساب',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalHomeScreen() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header الرئيسي
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      Icons.business_center_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، ${_providerData?['name'] ?? 'مزود الخدمة'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _serviceData?['serviceName'] ?? 'خدمة غير محددة',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadProviderData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // محتوى الصفحة الرئيسية
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Tab Bar احترافي
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _homeTabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey[600],
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        tabs: const [
                          Tab(text: 'العناصر'),
                          Tab(text: 'الحجوزات'),
                          Tab(text: 'الأنشطة'),
                        ],
                      ),
                    ),

                    // محتوى التبويبات
                    Expanded(
                      child: TabBarView(
                        controller: _homeTabController,
                        children: [
                          _buildItemsOverview(),
                          _buildBookingsOverview(),
                          _buildActivitiesOverview(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'العناصر الخاصة بك',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openItemEditor,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة عنصر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyItemsState()
                : RefreshIndicator(
                    onRefresh: _loadProviderData,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          _buildItemCard(_items[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد عناصر متاحة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بإضافة عناصر جديدة لخدماتك',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final isActive =
        item['status'] == 'approved' ||
        item['status'] == 'active' ||
        item['status'] == null;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showItemDetailsDialog(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.green : Colors.orange,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // صورة العنصر أو أيقونة افتراضية
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: item['imageUrl'] != null && item['imageUrl'].isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                          child: Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_rounded,
                          size: 40,
                          color: isActive ? Colors.green : Colors.orange,
                        ),
                ),
              ),

              // معلومات العنصر
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'عنصر بدون اسم',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['price'] ?? '0'} د.ع',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'نشط' : 'معلق',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الحجوزات الأخيرة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _pendingBookings.isEmpty
                ? _buildEmptyBookingsState()
                : ListView.builder(
                    itemCount: _pendingBookings.take(5).length,
                    itemBuilder: (context, index) =>
                        _buildBookingCard(_pendingBookings[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBookingsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد حجوزات معلقة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر الحجوزات الجديدة هنا',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF667eea),
          child: Text(
            booking['customerName']?.substring(0, 1).toUpperCase() ?? 'ع',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          booking['customerName'] ?? 'عميل غير محدد',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('التاريخ: ${booking['date'] ?? 'غير محدد'}'),
            Text('المبلغ: ${booking['totalPrice'] ?? '0'} د.ع'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _handleBookingAction('approve', booking),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _handleBookingAction('reject', booking),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'النشاطات الأخيرة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildActivityItem(
                  'تم إضافة عنصر جديد',
                  'منذ ساعتين',
                  Icons.add_circle_outline,
                ),
                _buildActivityItem(
                  'تم قبول حجز جديد',
                  'منذ 3 ساعات',
                  Icons.check_circle_outline,
                ),
                _buildActivityItem(
                  'تم تحديث السعر',
                  'منذ 5 ساعات',
                  Icons.edit_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon, [
    Color? color,
  ]) {
    final itemColor = color ?? const Color(0xFF667eea);
    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(title),
      subtitle: Text(time),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Widget _buildProfessionalBookingsScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.book_online_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'إدارة الحجوزات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_bookings.length} حجز',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // محتوى الحجوزات
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _bookings.isEmpty
                    ? _buildEmptyBookingsState()
                    : RefreshIndicator(
                        onRefresh: _loadProviderData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) =>
                              _buildBookingCard(_bookings[index]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalAccountScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header الملف الشخصي
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                ),
                child: Stack(
                  children: [
                    // خلفية منحنية
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                      ),
                    ),

                    // محتوى الهيدر
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // صورة المزود
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.business_center_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // اسم المزود
                            Text(
                              _providerData?['name'] ?? 'مزود الخدمة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // نوع الخدمة
                            Text(
                              _serviceData?['serviceName'] ?? 'خدمة غير محددة',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // معلومات الحساب
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // إحصائيات سريعة
                    Row(
                      children: [
                        Expanded(
                          child: _buildAccountStatCard(
                            'العناصر النشطة',
                            _activeItems.toString(),
                            Icons.inventory_2_rounded,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAccountStatCard(
                            'الحجوزات',
                            _totalBookings.toString(),
                            Icons.book_online_rounded,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // قائمة خيارات الحساب
                    _buildAccountItem(
                      'معلومات الحساب',
                      _providerData?['name'] ?? '',
                      Icons.person_rounded,
                      Colors.blue,
                    ),
                    _buildAccountItem(
                      'رقم الهاتف',
                      _providerData?['phone'] ?? '',
                      Icons.phone_rounded,
                      Colors.green,
                    ),
                    _buildAccountItem(
                      'إيرادات هذا الشهر',
                      '${NumberFormat('#,###').format(_monthlyRevenue)} د.ع',
                      Icons.trending_up,
                      Colors.blue,
                    ),
                    _buildAccountItem(
                      'إجمالي الإيرادات',
                      '${NumberFormat('#,###').format(_totalRevenue)} د.ع',
                      Icons.paid_rounded,
                      Colors.green,
                    ),
                    _buildAccountItem(
                      'عدد العناصر النشطة',
                      _activeItems.toString(),
                      Icons.inventory_2_rounded,
                      Colors.purple,
                    ),

                    const SizedBox(height: 20),

                    // زر تسجيل الخروج
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('تسجيل الخروج'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // دوال المساعدة والوظائف
  void _openItemEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProviderItemsRegistrationScreen(serviceData: _serviceData ?? {}),
      ),
    ).then((_) => _loadProviderData());
  }

  void _showItemDetailsDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name'] ?? 'عنصر بدون اسم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('السعر: ${item['price'] ?? '0'} د.ع'),
            const SizedBox(height: 8),
            Text('الوصف: ${item['description'] ?? 'لا يوجد وصف'}'),
            const SizedBox(height: 8),
            Text('الحالة: ${item['status'] ?? 'غير محدد'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editItem(item);
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  void _editItem(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemEditScreen(item: item)),
    ).then((_) => _loadProviderData());
  }

  void _handleBookingAction(String action, Map<String, dynamic> booking) async {
    try {
      String newStatus = action == 'approve' ? 'confirmed' : 'rejected';

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking['id'])
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'approve' ? 'تم قبول الحجز' : 'تم رفض الحجز'),
          backgroundColor: action == 'approve' ? Colors.green : Colors.red,
        ),
      );

      _loadProviderData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في معالجة الحجز: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // حذف الجلسة من Firestore
      if (_providerId != null) {
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_providerId)
            .delete();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تسجيل الخروج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
