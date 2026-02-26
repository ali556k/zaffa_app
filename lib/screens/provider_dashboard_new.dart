import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderDashboardNew extends StatefulWidget {
  final String providerId;
  final String providerName;

  const ProviderDashboardNew({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<ProviderDashboardNew> createState() => _ProviderDashboardNewState();
}

class _ProviderDashboardNewState extends State<ProviderDashboardNew> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String _requestStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // تحميل حالة الطلب
      final requestQuery = await FirebaseFirestore.instance
          .collection('provider_requests')
          .where('providerId', isEqualTo: widget.providerId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();

      if (requestQuery.docs.isNotEmpty) {
        final requestData = requestQuery.docs.first.data();
        _requestStatus = requestData['status'] ?? 'pending';

        // إذا كان الطلب معتمد، نحمل العناصر من مجموعة الخدمات
        if (_requestStatus == 'approved') {
          await _loadApprovedItems(requestData);
        } else {
          // إذا كان الطلب معلق أو مرفوض، نحمل العناصر من الطلب
          _items = List<Map<String, dynamic>>.from(requestData['items'] ?? []);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadApprovedItems(Map<String, dynamic> requestData) async {
    try {
      final serviceType = requestData['serviceType'];
      final serviceCollection = _getServiceCollection(serviceType);

      if (serviceCollection != null) {
        final query = await FirebaseFirestore.instance
            .collection('services')
            .doc(serviceCollection)
            .collection('items')
            .where('providerId', isEqualTo: widget.providerId)
            .get();

        _items = query.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      }
    } catch (e) {
      print('خطأ في تحميل العناصر المعتمدة: $e');
    }
  }

  String? _getServiceCollection(String? serviceType) {
    final Map<String, String> serviceMapping = {
      'قاعات اعراس': 'hall',
      'فنادق': 'hotel',
      'كيك': 'cake',
      'طعام': 'restaurant',
      'فستان الزفاف': 'bride_dress',
      'صالون وعناية': 'salon_care',
      'ورد': 'flowers',
      'بدلة رجالي': 'groom_suit',
      'تاجير السيارات': 'car',
      'تزيين السيارة': 'car_decoration',
      'شهر العسل': 'honeymoon',
    };
    return serviceMapping[serviceType];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildBookingsPage();
      case 2:
        return _buildAccountPage();
      case 3:
        return _buildSupportPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header with welcome message
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.business,
                          size: 32,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'أهلاً وسهلاً',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              widget.providerName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                ],
              ),
            ),

            // Items List
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E88E5),
                        ),
                      )
                    : _buildItemsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_requestStatus) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'نشط';
        statusIcon = Icons.verified;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'مرفوض';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'معلق';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'العناصر',
            _items.length.toString(),
            Icons.inventory_2,
            Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'الحجوزات',
            '0', // TODO: implement bookings count
            Icons.book_online,
            Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'التقييم',
            '5.0', // TODO: implement rating
            Icons.star,
            Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1E88E5), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E88E5),
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد عناصر بعد',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'ستظهر عناصرك هنا بعد الموافقة عليها',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showItemDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildItemImage(item),
              ),
              const SizedBox(width: 16),

              // Item Details
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
                      item['details'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${item['price']} دينار',
                            style: const TextStyle(
                              color: Color(0xFF1E88E5),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildItemStatusBadge(item),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage(Map<String, dynamic> item) {
    final imageUrls = item['imageUrls'] as List<dynamic>?;

    if (imageUrls != null && imageUrls.isNotEmpty) {
      return Image.network(
        imageUrls.first,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.image, color: Colors.grey),
          );
        },
      );
    }

    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _buildItemStatusBadge(Map<String, dynamic> item) {
    Color statusColor;
    String statusText;

    if (_requestStatus == 'approved') {
      final isActive = item['isActive'] ?? true;
      statusColor = isActive ? Colors.green : Colors.orange;
      statusText = isActive ? 'نشط' : 'غير نشط';
    } else if (_requestStatus == 'rejected') {
      statusColor = Colors.red;
      statusText = 'مرفوض';
    } else {
      statusColor = Colors.orange;
      statusText = 'معلق';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemDetailsModal(item: item),
    );
  }

  Widget _buildBookingsPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: const Text(
                'حجوزاتي',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_online, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد حجوزات بعد',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'ستظهر حجوزات العملاء هنا',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.providerName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'مزود خدمة',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildAccountOption(
                      icon: Icons.edit,
                      title: 'تعديل الملف الشخصي',
                      onTap: () {
                        // TODO: implement profile edit
                      },
                    ),
                    _buildAccountOption(
                      icon: Icons.notifications,
                      title: 'الإشعارات',
                      onTap: () {
                        // TODO: implement notifications
                      },
                    ),
                    _buildAccountOption(
                      icon: Icons.settings,
                      title: 'الإعدادات',
                      onTap: () {
                        // TODO: implement settings
                      },
                    ),
                    _buildAccountOption(
                      icon: Icons.logout,
                      title: 'تسجيل الخروج',
                      onTap: () {
                        _showLogoutDialog();
                      },
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

  Widget _buildAccountOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1E88E5)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSupportPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: const Text(
                'الدعم الفني',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildSupportOption(
                      icon: Icons.chat,
                      title: 'المحادثة المباشرة',
                      subtitle: 'تحدث مع فريق الدعم',
                      onTap: () {
                        // TODO: implement chat
                      },
                    ),
                    _buildSupportOption(
                      icon: Icons.phone,
                      title: 'الاتصال بنا',
                      subtitle: '07XX XXX XXXX',
                      onTap: () {
                        // TODO: implement call
                      },
                    ),
                    _buildSupportOption(
                      icon: Icons.email,
                      title: 'البريد الإلكتروني',
                      subtitle: 'support@zafa.app',
                      onTap: () {
                        // TODO: implement email
                      },
                    ),
                    _buildSupportOption(
                      icon: Icons.help,
                      title: 'الأسئلة الشائعة',
                      subtitle: 'إجابات للأسئلة المتكررة',
                      onTap: () {
                        // TODO: implement FAQ
                      },
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

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF1E88E5)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'حجوزاتي',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الحساب'),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'الدعم الفني',
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('logout'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: implement logout
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('logout'),
          ),
        ],
      ),
    );
  }
}

// Widget تفاصيل العنصر
class ItemDetailsModal extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailsModal({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrls = item['imageUrls'] as List<dynamic>? ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item['name'] ?? 'تفاصيل العنصر',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // صور العنصر
                  if (imageUrls.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.image, size: 50),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // اسم العنصر
                  Text(
                    item['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // التفاصيل
                  const Text(
                    'التفاصيل',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['details'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // السعر والسعة
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'السعر',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E88E5),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item['price']} دينار',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E88E5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (item['capacity'] != null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'السعة/الكمية',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['capacity'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
