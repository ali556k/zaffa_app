import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:clean_app/screens/provider_items_registration_screen.dart';

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

class _ProviderDashboardNewState extends State<ProviderDashboardNew>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProviderItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProviderItems() async {
    print('🔄 بدء تحميل عناصر مزود الخدمة...');
    setState(() {
      _isLoading = true;
    });

    try {
      // البحث في جميع مجموعات الخدمات
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
        final query = await FirebaseFirestore.instance
            .collection(serviceType)
            .where('providerId', isEqualTo: widget.providerId)
            .get();

        print('🔍 البحث في مجموعة $serviceType: وجد ${query.docs.length} عنصر');

        for (var doc in query.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['collectionName'] = serviceType;
          allItems.add(data);
          print('➕ تم إضافة عنصر: ${data['name'] ?? 'بدون اسم'}');
        }
      }

      print('🔍 تم تحميل ${allItems.length} عنصر إجمالي');

      setState(() {
        _items = allItems;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل العناصر: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة للحصول على لون حالة العنصر
  Color _getStatusColor(Map<String, dynamic> item) {
    final status = item['status']?.toString().toLowerCase() ?? '';

    // التحقق من حقل status أولاً
    if (status == 'active') {
      return Colors.green; // نشط
    } else if (status == 'pending') {
      return Colors.orange; // معلق
    } else if (status == 'rejected') {
      return Colors.red; // مرفوض
    }

    // الرجوع للطريقة القديمة كخيار احتياطي
    final isApproved = item['isApproved'] ?? false;
    final isActive = item['isActive'] ?? false;

    if (isApproved && isActive) {
      return Colors.green;
    } else if (isApproved && !isActive) {
      return Colors.blue;
    } else {
      return Colors.orange;
    }
  }

  // دالة للحصول على نص حالة العنصر
  String _getStatusText(Map<String, dynamic> item) {
    final status = item['status']?.toString().toLowerCase() ?? '';

    // التحقق من حقل status أولاً
    if (status == 'active') {
      return '🟢 نشط';
    } else if (status == 'pending') {
      return '🟠 معلق';
    } else if (status == 'rejected') {
      return '🔴 مرفوض';
    }

    // الرجوع للطريقة القديمة كخيار احتياطي
    final isApproved = item['isApproved'] ?? false;
    final isActive = item['isActive'] ?? false;

    if (isApproved && isActive) {
      return '🟢 نشط';
    } else if (isApproved && !isActive) {
      return '🔵 غير نشط';
    } else {
      return '🟠 في انتظار الموافقة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.providerName.isNotEmpty
                            ? widget.providerName[0]
                            : 'م',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً، ${widget.providerName}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'لوحة تحكم مزود الخدمة',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  labelColor: const Color(0xFF1E88E5),
                  unselectedLabelColor: Colors.white,
                  tabs: const [
                    Tab(icon: Icon(Icons.inventory_2), text: 'العناصر'),
                    Tab(icon: Icon(Icons.calendar_today), text: 'الحجوزات'),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildItemsPage(), _buildBookingsPage()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsPage() {
    return Column(
      children: [
        // Header with Add Button
        Container(
          padding: EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عناصري (${_items.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addNewItem,
                icon: Icon(Icons.add, size: 20),
                label: Text('add_item'),
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

        // Items List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
                )
              : _items.isEmpty
              ? _buildEmptyState()
              : _buildItemsList(),
        ),
      ],
    );
  }

  Widget _buildBookingsPage() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'تقويم الحجوزات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Text(
                'سيتم إضافة تقويم الحجوزات قريباً',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
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
          Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'لا توجد عناصر مضافة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ابدأ بإضافة عناصر لخدماتك',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _addNewItem,
            icon: Icon(Icons.add),
            label: Text('add_first_item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return RefreshIndicator(
      onRefresh: _loadProviderItems,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _buildItemCard(item);
        },
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl'] ?? '';
    final name = item['name'] ?? 'بدون اسم';
    final description = item['description'] ?? 'بدون وصف';
    final price = item['price']?.toString() ?? '0';
    final location = item['location'] ?? 'بدون موقع';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  )
                : Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(item),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Price and Location
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                    Text(
                      '$price ريال',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editItem(item),
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).appBarTheme.backgroundColor,
                          side: BorderSide(
                            color:
                                Theme.of(context).appBarTheme.backgroundColor ??
                                Colors.black,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteItem(item),
                        icon: Icon(Icons.delete, size: 16),
                        label: Text('delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewItem() async {
    // جلب البيانات الحقيقية للمزود من قاعدة البيانات
    Map<String, dynamic> serviceData = {
      'providerId': widget.providerId,
      'providerName': widget.providerName,
      'providerPhone': widget.providerId,
      'serviceType': 'عامة',
      'serviceName': widget.providerName, // استخدام اسم المزود كقيمة افتراضية
      'area': 'غير محدد',
    };

    try {
      // محاولة جلب البيانات من providers collection
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();

      if (providerDoc.exists) {
        final providerData = providerDoc.data()!;
        print('📋 تم جلب بيانات المزود: $providerData');

        // تحديث البيانات بالقيم الحقيقية
        serviceData = {
          'providerId': widget.providerId,
          'providerName': providerData['name'] ?? widget.providerName,
          'providerPhone': providerData['phone'] ?? widget.providerId,
          'serviceType': providerData['serviceType'] ?? 'عامة',
          'serviceName':
              providerData['serviceName'] ??
              providerData['name'] ??
              widget.providerName,
          'area': providerData['area'] ?? providerData['address'] ?? 'غير محدد',
        };
        print('✅ تم تحديث بيانات الخدمة: $serviceData');
      } else {
        // محاولة جلب من provider_services
        final serviceDoc = await FirebaseFirestore.instance
            .collection('provider_services')
            .doc(widget.providerId)
            .get();

        if (serviceDoc.exists) {
          final serviceDocData = serviceDoc.data()!;
          print('📋 تم جلب بيانات الخدمة: $serviceDocData');

          serviceData = {
            'providerId': widget.providerId,
            'providerName':
                serviceDocData['providerName'] ?? widget.providerName,
            'providerPhone':
                serviceDocData['providerPhone'] ?? widget.providerId,
            'serviceType': serviceDocData['serviceType'] ?? 'عامة',
            'serviceName': serviceDocData['serviceName'] ?? widget.providerName,
            'area': serviceDocData['area'] ?? 'غير محدد',
          };
          print('✅ تم تحديث بيانات الخدمة من provider_services: $serviceData');
        } else {
          print(
            '⚠️ لم يتم العثور على بيانات المزود، سيتم استخدام القيم الافتراضية',
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في جلب بيانات المزود: $e');
      print('⚠️ سيتم استخدام القيم الافتراضية');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProviderItemsRegistrationScreen(serviceData: serviceData),
      ),
    ).then((_) {
      // إعادة تحميل العناصر عند العودة
      _loadProviderItems();
    });
  }

  void _editItem(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderItemsRegistrationScreen(
          serviceData: {
            'providerId': widget.providerId,
            'providerName': widget.providerName,
            'item': item,
          },
        ),
      ),
    ).then((_) {
      // إعادة تحميل العناصر عند العودة
      _loadProviderItems();
    });
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_delete'),
        content: Text('هل أنت متأكد من حذف "${item['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // حذف العنصر من قاعدة البيانات
        await FirebaseFirestore.instance
            .collection('services')
            .doc(item['serviceType'])
            .collection('items')
            .doc(item['id'])
            .delete();

        // حذف الصورة من التخزين إذا كانت موجودة
        if (item['imageUrl'] != null && item['imageUrl'].isNotEmpty) {
          try {
            await FirebaseStorage.instance
                .refFromURL(item['imageUrl'])
                .delete();
          } catch (e) {
            print('خطأ في حذف الصورة: $e');
          }
        }

        // إعادة تحميل العناصر
        _loadProviderItems();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('item_deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف العنصر: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
