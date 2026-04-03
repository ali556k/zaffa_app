import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'provider_dashboard.dart';
import 'provider_bookings_management_screen.dart';
import 'dart:async';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class ProviderMainScreen extends StatefulWidget {
  const ProviderMainScreen({super.key});

  @override
  State<ProviderMainScreen> createState() => _ProviderMainScreenState();
}

class _ProviderMainScreenState extends State<ProviderMainScreen>
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
  StreamSubscription<QuerySnapshot>? _bookingsSub;
  late TabController _tabController;
  final BookingService _bookingService = BookingService();

  // إحصائيات لوحة التحكم
  int _totalBookings = 0;
  int _pendingBookingsCount = 0;
  int _approvedBookings = 0;
  int _activeItems = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProviderData();
    // تحديث تلقائي كل 30 ثانية للحجوزات الجديدة
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadProviderData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _bookingsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProviderData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _providerId = prefs.getString('user_phone');

      if (_providerId != null) {
        // تحميل بيانات مزود الخدمة الشخصية
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(_providerId)
            .get();

        if (providerDoc.exists) {
          _providerData = providerDoc.data();
          print('تم تحميل بيانات مزود الخدمة: ${_providerData?['name']}');
        }

        // تحميل بيانات الخدمة
        final serviceDoc = await FirebaseFirestore.instance
            .collection('provider_services')
            .doc(_providerId)
            .get();

        if (serviceDoc.exists) {
          _serviceData = serviceDoc.data();
          print('تم تحميل بيانات الخدمة: ${_serviceData?['serviceName']}');
        } else {
          print('لا توجد بيانات خدمة لمزود الخدمة: $_providerId');
        }

        // تحميل العناصر
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('provider_items')
            .where('providerId', isEqualTo: _providerId)
            .get();

        _items = itemsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        // الاشتراك في التحديثات الحية للحجوزات
        _subscribeToBookings();

        print('تم تحميل ${_items.length} عنصر و ${_bookings.length} حجز');
      } else {
        print('لا يوجد رقم هاتف محفوظ');
        // إذا لم يكن هناك providerId، انتقل لصفحة تسجيل الدخول
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
        return;
      }
    } catch (e) {
      print('خطأ في تحميل بيانات المزود: $e');
      // في حالة الخطأ، اعرض رسالة للمستخدم
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToBookings() {
    _bookingsSub?.cancel();
    if (_providerId == null) return;

    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: _providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final newBookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _bookings = newBookings;
        _updateStatistics();
      });
    });
  }

  void _updateStatistics() {
    // حساب العناصر النشطة
    _activeItems = _items.where((item) => item['status'] == 'active').length;

    // حساب إحصائيات الحجوزات
    _totalBookings = _bookings.length;
    _pendingBookingsCount = _bookings
        .where((booking) => booking['status'] == 'pending')
        .length;
    _approvedBookings = _bookings
        .where((booking) => booking['status'] == 'confirmed')
        .length;

    // تصفية الحجوزات المعلقة
    _pendingBookings = _bookings
        .where((booking) => booking['status'] == 'pending')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadProviderData,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeScreen(),
            _buildItemsScreen(),
            _buildBookingsScreen(),
            _buildReportsScreen(),
            _buildAccountScreen(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey,
        iconSize: 24,
        selectedFontSize: 12,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'عناصري'),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'الحجوزات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'التقارير',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'الحساب',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E88E5), Color(0xFFF8FAFC)],
            stops: [0.0, 0.3],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'جاري تحميل البيانات...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFFF8FAFC)],
          stops: [0.0, 0.3],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مرحباً بك',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _providerData?['name'] ?? 'مزود الخدمة',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // إحصائيات سريعة
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              'العناصر',
                              _items.length.toString(),
                              Icons.inventory,
                            ),
                            _buildStatCard(
                              'الحجوزات',
                              _totalBookings.toString(),
                              Icons.book_online,
                            ),
                            _buildStatCard(
                              'معلقة',
                              _pendingBookingsCount.toString(),
                              Icons.pending,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              'مؤكدة',
                              _approvedBookings.toString(),
                              Icons.check_circle,
                            ),
                            _buildStatCard(
                              'نشطة',
                              _activeItems.toString(),
                              Icons.verified,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // أزرار سريعة
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProviderDashboard(),
                              ),
                            );
                            // إعادة تحميل البيانات عند العودة من صفحة إضافة العناصر
                            _loadProviderData();
                          },
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('إضافة عنصر'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _selectedIndex = 2),
                          icon: const Icon(Icons.book_online, size: 20),
                          label: const Text('الحجوزات'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // زر إدارة الحجوزات الجديد
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ProviderBookingsManagementScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.event_note, size: 20),
                      label: const Text('إدارة الحجوزات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // قائمة العناصر
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'عناصر الخدمة',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showAddItemDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة عنصر'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (context, index) =>
                                  _buildItemCard(_items[index], index),
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

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildColoredStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد عناصر بعد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابدأ بإضافة عناصر لخدمتك',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddItemDialog,
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول عنصر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showItemDetails(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory,
                      color: Color(0xFF1E88E5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['price'] ?? ''} دينار عراقي',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // عرض حالة العنصر
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (item['status'] == 'active')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (item['status'] == 'active')
                                    ? Icons.check_circle
                                    : Icons.hourglass_empty,
                                size: 16,
                                color: (item['status'] == 'active')
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (item['status'] == 'active') ? 'نشط' : 'معلق',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (item['status'] == 'active')
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: const Color(0xFF1E88E5)),
                            SizedBox(width: 8),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditItemDialog(item, index);
                      } else if (value == 'delete') {
                        _deleteItem(item, index);
                      }
                    },
                  ),
                ],
              ),
              if (item['details'] != null && item['details'].isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.description,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['details'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5568),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // زر التوفر (للخدمات غير القابلة للحجز فقط)
              if (!isBookableCategory(item['serviceType'] ?? '')) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                StreamBuilder<bool>(
                  stream: _bookingService.getItemAvailability(item['id'] ?? ''),
                  builder: (context, snapshot) {
                    final isAvailable = snapshot.data ?? true;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.withOpacity(0.05)
                            : Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAvailable
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAvailable ? Icons.check_circle : Icons.cancel,
                            color: isAvailable ? Colors.green : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'حالة التوفر',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isAvailable ? 'متوفر' : 'غير متوفر',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isAvailable,
                            onChanged: (value) async {
                              try {
                                await _bookingService.updateItemAvailability(
                                  item['id'] ?? '',
                                  value,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value
                                            ? '✅ تم تحديث الحالة إلى متوفر'
                                            : '❌ تم تحديث الحالة إلى غير متوفر',
                                      ),
                                      backgroundColor: value
                                          ? Colors.green
                                          : Colors.orange,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('خطأ في تحديث الحالة: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['details'] != null && item['details'].isNotEmpty) ...[
              const Text(
                'التفاصيل:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(item['details']),
              const SizedBox(height: 16),
            ],
            const Text('السعر:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${item['price']} دينار عراقي',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final detailsController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة عنصر جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العنصر',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل العنصر',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر (دينار عراقي)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                await _addItem({
                  'name': nameController.text.trim(),
                  'details': detailsController.text.trim(),
                  'price': priceController.text.trim(),
                });
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(Map<String, dynamic> item, int index) {
    final nameController = TextEditingController(text: item['name']);
    final detailsController = TextEditingController(text: item['details']);
    final priceController = TextEditingController(text: item['price']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل العنصر'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العنصر',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل العنصر',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر (دينار عراقي)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                await _editItem(item['id'], {
                  'name': nameController.text.trim(),
                  'details': detailsController.text.trim(),
                  'price': priceController.text.trim(),
                }, index);
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(Map<String, dynamic> itemData) async {
    try {
      itemData['providerId'] = _providerId;
      itemData['serviceId'] = _providerId;
      itemData['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await FirebaseFirestore.instance
          .collection('provider_items')
          .add(itemData);

      itemData['id'] = docRef.id;

      setState(() {
        _items.add(itemData);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة العنصر بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  Future<void> _editItem(
    String itemId,
    Map<String, dynamic> itemData,
    int index,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('provider_items')
          .doc(itemId)
          .update(itemData);

      setState(() {
        _items[index] = {..._items[index], ...itemData};
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعديل العنصر بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  void _deleteItem(Map<String, dynamic> item, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العنصر'),
        content: Text('هل أنت متأكد من حذف "${item['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _performDeleteItem(item['id'], index);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteItem(String itemId, int index) async {
    try {
      await FirebaseFirestore.instance
          .collection('provider_items')
          .doc(itemId)
          .delete();

      setState(() {
        _items.removeAt(index);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العنصر بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  Widget _buildAccountScreen() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            height: 200,
            decoration: BoxDecoration(color: const Color(0xFF1E88E5)),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: const Color(0xFF1E88E5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _providerData?['name'] ?? 'مزود الخدمة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _providerId ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // معلومات الحساب
          Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  'الاسم',
                  _providerData?['name'] ?? '',
                  Icons.person,
                ),
                _buildInfoTile(
                  'البريد الإلكتروني',
                  _providerData?['email'] ?? '',
                  Icons.email,
                ),
                _buildInfoTile('رقم الهاتف', _providerId ?? '', Icons.phone),
                _buildInfoTile(
                  'اسم الخدمة',
                  _serviceData?['serviceName'] ?? '',
                  Icons.business,
                ),
                _buildInfoTile(
                  'نوع الخدمة',
                  _serviceData?['serviceType'] ?? '',
                  Icons.category,
                ),
                _buildInfoTile(
                  'المنطقة',
                  _serviceData?['area'] ?? '',
                  Icons.location_on,
                ),
                _buildInfoTile(
                  'عدد العناصر',
                  _items.length.toString(),
                  Icons.inventory,
                ),
              ],
            ),
          ),

          // كشف الحساب
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color:
                            Theme.of(context).appBarTheme.backgroundColor ??
                            const Color(0xFF530405),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'كشف الحساب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي العناصر'),
                          Text(_items.length.toString()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الحجوزات'),
                          const Text('0'), // سيتم تحديثه لاحقاً
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('حالة الحساب'),
                          Text(
                            'نشط',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // زر تسجيل الخروج
          Container(
            margin: const EdgeInsets.all(24),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).appBarTheme.backgroundColor ??
                    const Color(0xFF530405),
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
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E88E5), size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsScreen() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Row(
            children: [
              Icon(Icons.book_online, size: 28),
              SizedBox(width: 12),
              Text(
                'إدارة الحجوزات',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // تبويبات الحجوزات
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Color(0xFF530405),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pending, size: 16),
                            const SizedBox(width: 4),
                            Text('معلقة ($_pendingBookingsCount)'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 16),
                            const SizedBox(width: 4),
                            Text('مؤكدة ($_approvedBookings)'),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 16),
                            SizedBox(width: 4),
                            Text('جميع الحجوزات'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      // الحجوزات المعلقة
                      _buildBookingsTab(_pendingBookings),

                      // الحجوزات المؤكدة
                      _buildBookingsTab(
                        _bookings
                            .where((b) => b['status'] == 'confirmed')
                            .toList(),
                      ),

                      // جميع الحجوزات
                      _buildBookingsTab(_bookings),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_online, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد حجوزات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        return _buildEnhancedBookingCard(bookings[index]);
      },
    );
  }

  Widget _buildEnhancedBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF10B981);
        statusText = 'مؤكد';
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ملغي';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'معلق';
        statusIcon = Icons.pending;
    }

    // استخراج التاريخ والوقت
    String displayDate = 'غير محدد';
    String displayTime = '';

    if (booking['bookingDate'] != null) {
      try {
        if (booking['bookingDate'] is Timestamp) {
          final dateTime = (booking['bookingDate'] as Timestamp).toDate();
          displayDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
        } else {
          displayDate = booking['bookingDate'].toString();
        }
      } catch (e) {
        displayDate = booking['bookingDate'].toString();
      }
    }

    // استخراج الوقت من timeSlot
    if (booking['timeSlot'] != null) {
      final timeSlot = booking['timeSlot'];
      if (timeSlot is Map) {
        final startTime = timeSlot['startTime'] ?? '';
        final endTime = timeSlot['endTime'] ?? '';
        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          displayTime = '$startTime - $endTime';
        }
      }
    } else if (booking['dayStatus'] == 'fullyBooked') {
      displayTime = 'اليوم كامل';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBookingDetails(booking),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: statusColor, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['itemName'] ?? 'عنصر غير محدد',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (booking['category'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              booking['category'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking['customerName'] ?? 'غير محدد',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(displayDate, style: const TextStyle(fontSize: 14)),
                    if (displayTime.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(displayTime, style: const TextStyle(fontSize: 14)),
                    ],
                  ],
                ),

                if (booking['notes'] != null &&
                    booking['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking['notes'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showBookingDetails(booking),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('عرض التفاصيل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    if (status == 'pending') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _updateBookingStatus(booking['id'], 'confirmed'),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('قبول'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // void _contactCustomer(Map<String, dynamic> booking) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('تواصل مع العميل'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text('العميل: ${booking['customerName'] ?? 'غير محدد'}'),
  //           Text('رقم الهاتف: ${booking['customerPhone'] ?? 'غير محدد'}'),
  //           const SizedBox(height: 16),
  //           const Text('يمكنك التواصل مع العميل عبر:'),
  //         ],
  //       ),
  //       actions: [
  //         TextButton.icon(
  //           onPressed: () {
  //             // هنا يمكنك إضافة منطق الاتصال الهاتفي
  //             Navigator.pop(context);
  //           },
  //           icon: const Icon(Icons.phone),
  //           label: const Text('اتصال'),
  //         ),
  //         TextButton.icon(
  //           onPressed: () {
  //             // هنا يمكنك إضافة منطق إرسال رسالة
  //             Navigator.pop(context);
  //           },
  //           icon: const Icon(Icons.message),
  //           label: const Text('رسالة'),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('إغلاق'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildItemsScreen() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Row(
            children: [
              Icon(Icons.inventory, size: 28, color: const Color(0xFF530405)),
              const SizedBox(width: 12),
              const Text(
                'إدارة العناصر',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _addNewItem(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('إضافة عنصر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // إحصائيات العناصر
          Row(
            children: [
              Expanded(
                child: _buildColoredStatCard(
                  'إجمالي العناصر',
                  _items.length.toString(),
                  Icons.inventory,
                  const Color(0xFF530405),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildColoredStatCard(
                  'العناصر النشطة',
                  _activeItems.toString(),
                  Icons.check_circle,
                  const Color(0xFF530405),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildColoredStatCard(
                  'قيد المراجعة',
                  (_items.length - _activeItems).toString(),
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // قائمة العناصر
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد عناصر حالياً',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'اضغط على زر "إضافة عنصر" لبدء إضافة العناصر',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProviderData,
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          _buildItemCard(_items[index], index),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsScreen() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Row(
            children: [
              Icon(Icons.analytics, size: 28, color: Color(0xFF530405)),
              SizedBox(width: 12),
              Text(
                'التقارير والإحصائيات',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // إحصائيات الحجوزات
          Row(
            children: [
              Expanded(
                child: _buildColoredStatCard(
                  'إجمالي الحجوزات',
                  _totalBookings.toString(),
                  Icons.book_online,
                  const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildColoredStatCard(
                  'حجوزات معلقة',
                  _pendingBookingsCount.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildColoredStatCard(
                  'حجوزات مؤكدة',
                  _approvedBookings.toString(),
                  Icons.check_circle,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // الحجوزات الأخيرة
          const Text(
            'الحجوزات الأخيرة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _bookings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_online, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد حجوزات حالياً',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _bookings.take(10).length, // عرض آخر 10 حجوزات
                    itemBuilder: (context, index) {
                      final booking = _bookings[index];
                      return _buildBookingCard(booking);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'pending';
    Color statusColor;
    String statusText;

    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF10B981);
        statusText = 'مؤكد';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ملغي';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'معلق';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.book_online, color: statusColor),
        ),
        title: Text(
          booking['itemName'] ?? 'عنصر غير محدد',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العميل: ${booking['customerName'] ?? 'غير محدد'}'),
            Text('التاريخ: ${booking['bookingDate'] ?? 'غير محدد'}'),
            if (booking['totalPrice'] != null)
              Text('المبلغ: ${booking['totalPrice']} د.ع'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _showBookingDetails(booking),
      ),
    );
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    // استخراج التاريخ والوقت
    String displayDate = 'غير محدد';
    String displayTime = '';

    if (booking['bookingDate'] != null) {
      try {
        if (booking['bookingDate'] is Timestamp) {
          final dateTime = (booking['bookingDate'] as Timestamp).toDate();
          displayDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
        } else {
          displayDate = booking['bookingDate'].toString();
        }
      } catch (e) {
        displayDate = booking['bookingDate'].toString();
      }
    }

    // استخراج الوقت من timeSlot
    if (booking['timeSlot'] != null) {
      final timeSlot = booking['timeSlot'];
      if (timeSlot is Map) {
        final startTime = timeSlot['startTime'] ?? '';
        final endTime = timeSlot['endTime'] ?? '';
        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          displayTime = '$startTime - $endTime';
        }
      }
    } else if (booking['dayStatus'] == 'fullyBooked') {
      displayTime = 'اليوم كامل';
    }

    final status = booking['status'] ?? 'pending';
    Color statusColor;
    String statusText;

    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF10B981);
        statusText = 'مؤكد';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ملغي';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'معلق';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // رأس النافذة
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'تفاصيل الحجز',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // المحتوى
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // معلومات العنصر
                      _buildDetailSection(
                        title: 'معلومات العنصر',
                        icon: Icons.inventory_2,
                        color:
                            Theme.of(context).appBarTheme.backgroundColor ??
                            const Color(0xFF530405),
                        children: [
                          _buildDetailRow(
                            'اسم العنصر',
                            booking['itemName'] ?? 'غير محدد',
                          ),
                          if (booking['category'] != null)
                            _buildDetailRow('الفئة', booking['category']),
                          if (booking['price'] != null)
                            _buildDetailRow('السعر', '${booking['price']} د.ع'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // معلومات الزبون
                      _buildDetailSection(
                        title: 'معلومات الزبون',
                        icon: Icons.person,
                        color: const Color(0xFF10B981),
                        children: [
                          _buildDetailRow(
                            'الاسم',
                            booking['customerName'] ?? 'غير محدد',
                          ),
                          _buildDetailRow(
                            'رقم الهاتف',
                            booking['customerPhone'] ?? 'غير محدد',
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // معلومات التاريخ والوقت
                      _buildDetailSection(
                        title: 'التاريخ والوقت',
                        icon: Icons.calendar_today,
                        color: const Color(0xFFF59E0B),
                        children: [
                          _buildDetailRow('التاريخ', displayDate),
                          if (displayTime.isNotEmpty)
                            _buildDetailRow('الوقت', displayTime),
                          if (booking['createdAt'] != null)
                            _buildDetailRow(
                              'تاريخ الإنشاء',
                              _formatTimestamp(booking['createdAt']),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // الملاحظات
                      if (booking['notes'] != null &&
                          booking['notes'].toString().isNotEmpty)
                        _buildDetailSection(
                          title: 'الملاحظات',
                          icon: Icons.notes,
                          color: const Color(0xFF8B5CF6),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                booking['notes'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // صورة الإيصال
                      if (booking['receiptUrl'] != null &&
                          booking['receiptUrl'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          title: 'إيصال الدفع',
                          icon: Icons.receipt,
                          color: Colors.red,
                          children: [
                            GestureDetector(
                              onTap: () {
                                // فتح الصورة بحجم كامل
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: InteractiveViewer(
                                            child: Image.network(
                                              booking['receiptUrl'],
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value:
                                                        loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Center(
                                                      child: Icon(
                                                        Icons.error_outline,
                                                        color: Colors.red,
                                                        size: 48,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 40,
                                          right: 20,
                                          child: IconButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.black
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    booking['receiptUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 48,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'فشل تحميل الصورة',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'اضغط على الصورة للتكبير',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // الأزرار
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    if (status == 'pending') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateBookingStatus(booking['id'], 'confirmed');
                          },
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('قبول الحجز'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateBookingStatus(booking['id'], 'cancelled');
                          },
                          icon: const Icon(Icons.cancel, size: 20),
                          label: const Text('رفض الحجز'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 20),
                          label: const Text('إغلاق'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final dateTime = timestamp.toDate();
        return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
      return timestamp.toString();
    } catch (e) {
      return 'غير محدد';
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الحجز إلى: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );

      // إعادة تحميل البيانات
      _loadProviderData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث الحجز: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addNewItem() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProviderDashboard()),
    );
    // إعادة تحميل البيانات عند العودة من صفحة إضافة العناصر
    _loadProviderData();
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
