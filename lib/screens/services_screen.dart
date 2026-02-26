import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_page_title.dart';
import 'published_providers_screen.dart';
import 'favorites_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  _ServicesScreenState createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime? weddingDate;
  Duration remaining = Duration();
  Timer? _timer;
  Map<String, int> serviceCounts = {};
  bool isLoading = true;
  bool _hasLoadedData = false;

  @override
  bool get wantKeepAlive => true; // للحفاظ على حالة الشاشة

  // قائمة معرفات الخدمات
  static const List<String> _serviceIds = [
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
    'photography',
    'honeymoon',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedData) {
        _hasLoadedData = true;
        _loadWeddingDate();
        _loadServiceCounts();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (weddingDate != null) {
      _updateCountdown();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateCountdown(),
      );
    }
  }

  void _updateCountdown() {
    setState(() {
      remaining = weddingDate!.difference(DateTime.now());
    });
  }

  Future<void> _loadWeddingDate() async {
    setState(() {
      if (weddingDate != null) {
        remaining = weddingDate!.difference(DateTime.now());
      }
    });
    _startCountdown();
  }

  // تحميل عدد مزودي الخدمة لكل نوع خدمة (محسّن)
  Future<void> _loadServiceCounts() async {
    try {
      print('⚡ بدء تحميل أعداد الخدمات بطريقة محسّنة...');
      final startTime = DateTime.now();

      // استعلام واحد لجميع المزودين النشطين
      final snapshot = await FirebaseFirestore.instance
          .collection('published_providers')
          .where('isActive', isEqualTo: true)
          .get();

      print('📊 تم جلب ${snapshot.docs.length} مزود نشط');

      // حساب العدد لكل فئة محلياً (بدون استعلامات إضافية)
      final Map<String, int> counts = {
        'hall': 0,
        'hotel': 0,
        'cake': 0,
        'restaurant': 0,
        'bride_dress': 0,
        'salon_care': 0,
        'flowers': 0,
        'groom_suit': 0,
        'car': 0,
        'car_decoration': 0,
        'honeymoon': 0,
        'photography': 0,
      };

      for (var doc in snapshot.docs) {
        final category = doc.data()['category'];
        if (counts.containsKey(category)) {
          counts[category] = (counts[category] ?? 0) + 1;
        }
      }

      final duration = DateTime.now().difference(startTime);
      print('✅ تم تحميل الأعداد في ${duration.inMilliseconds}ms');
      print('💡 تحسين: استعلام واحد بدلاً من 12 استعلام!');

      if (mounted) {
        setState(() {
          serviceCounts = counts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل أعداد الخدمات: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب لـ AutomaticKeepAliveClientMixin

    return Container(
      color: const Color.fromARGB(255, 216, 208, 208),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CustomPageTitle('الصفحة الرئيسية'),
            // زر المفضلات
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20, top: 8, bottom: 16),
              child: GestureDetector(
                onTap: () {
                  print('🔥 تم الضغط على زر المفضلات');
                  try {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) => const FavoritesScreen(),
                          ),
                        )
                        .then((value) {
                          print('🔙 تم الرجوع من شاشة المفضلات');
                        });
                  } catch (e) {
                    print('❌ خطأ في الانتقال للمفضلات: $e');
                  }
                },
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFB22222)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(50.0),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  itemCount: _serviceIds.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  cacheExtent: 200,
                  itemBuilder: (context, index) {
                    return _serviceImageButton(_serviceIds[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // دالة لتحويل معرف الخدمة إلى اسم الخدمة
  String _getServiceName(String serviceId) {
    switch (serviceId) {
      case 'hall':
        return 'قاعات اعراس';
      case 'hotel':
        return 'فنادق';
      case 'cake':
        return 'كيك';
      case 'restaurant':
        return 'طعام';
      case 'bride_dress':
        return 'فستان الزفاف';
      case 'salon_care':
        return 'صالون وعناية';
      case 'flowers':
        return 'ورد';
      case 'groom_suit':
        return 'بدلة رجالي';
      case 'car':
        return 'تاجير السيارات';
      case 'car_decoration':
        return 'تزيين السيارة';
      case 'honeymoon':
        return 'سياحة';
      case 'photography':
        return 'التصوير';
      default:
        return 'خدمة غير معروفة';
    }
  }

  // تحويل معرف الخدمة إلى مسار Firestore (يجب أن يكون نفس الاسم)
  String _getFirestorePath(String serviceId) {
    return serviceId; // استخدام نفس الاسم مباشرة
  }

  Widget _serviceImageButton(String id) {
    final firestorePath = _getFirestorePath(id);
    final count = serviceCounts[firestorePath] ?? 0;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: GestureDetector(
          onTap: () {
            // الانتقال إلى شاشة مزودي الخدمة المنشورين
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublishedProvidersScreen(
                  category: id,
                  categoryTitle: _getServiceName(id),
                ),
              ),
            );
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 2.0,
                  child: Container(
                    color: Colors.grey[900],
                    child: Image.asset(
                      'assets/$id.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      cacheWidth: 800,
                      cacheHeight: 400,
                    ),
                  ),
                ),
              ),
              // عرض عدد مزودي الخدمة
              if (count > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count مزود',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// شاشة فئات الخدمة - عرض مزودي الخدمة المعتمدين
class ServiceCategoriesScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;

  const ServiceCategoriesScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });

  @override
  State<ServiceCategoriesScreen> createState() =>
      _ServiceCategoriesScreenState();
}

class _ServiceCategoriesScreenState extends State<ServiceCategoriesScreen> {
  // جلب مزودي الخدمة المعتمدين لنوع خدمة معين
  Future<List<Map<String, dynamic>>> _getApprovedProviders() async {
    try {
      print('🔍 جاري البحث عن مزودي الخدمة للخدمة: ${widget.serviceId}');

      // البحث في مجموعة services عن الخدمات المعتمدة لهذا النوع
      final servicesQuery = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('items')
          .where('isActive', isEqualTo: true)
          .where('isApproved', isEqualTo: true) // فقط العناصر المعتمدة
          .get();

      print('📊 عدد العناصر الموجودة: ${servicesQuery.docs.length}');

      // جمع معرفات مزودي الخدمة الفريدة
      Set<String> providerIds = {};
      Map<String, Map<String, dynamic>> providersData = {};

      for (var doc in servicesQuery.docs) {
        final data = doc.data();
        print('📄 بيانات العنصر: $data');

        final providerId = data['providerId'] as String?;
        if (providerId != null && providerId.isNotEmpty) {
          providerIds.add(providerId);

          // حفظ بيانات المزود الأساسية من العنصر
          if (!providersData.containsKey(providerId)) {
            providersData[providerId] = {
              'providerId': providerId,
              'providerName': data['providerName'] ?? 'مزود خدمة',
              'hallName': data['hallName'], // اسم القاعة للقاعات
              'serviceName': data['serviceName'], // اسم الخدمة
              'location': data['location'] ?? 'غير محدد',
              'itemsCount': 1,
              'serviceType': widget.serviceId,
              'isHallProvider': data['isHallProvider'] ?? false,
            };
            print(
              '✅ تم إضافة مزود جديد: ${data['providerName']} ($providerId)',
            );
          } else {
            // زيادة عدد العناصر للمزود
            providersData[providerId]!['itemsCount'] =
                (providersData[providerId]!['itemsCount'] as int) + 1;
            print('📈 زيادة عدد العناصر للمزود: ${data['providerName']}');
          }
        } else {
          print('❌ عنصر بدون providerId أو providerId فارغ: $data');
        }
      }

      print('🎯 عدد مزودي الخدمة النهائي: ${providersData.length}');
      return providersData.values.toList();
    } catch (e) {
      print('❌ خطأ في جلب مزودي الخدمة: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '🏗️ بناء ServiceCategoriesScreen للخدمة: ${widget.serviceId} - ${widget.serviceName}',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'مزودو خدمة ${widget.serviceName}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Color(0xFFF5F7FA),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getApprovedProviders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في تحميل البيانات',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text('retry'),
                  ),
                ],
              ),
            );
          }

          final providers = snapshot.data ?? [];

          if (providers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد مزودو خدمة متاحون حالياً',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيظهر مزودو الخدمة عند إضافة عناصر معتمدة',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              // عرض اسم القاعة للقاعات، أو اسم المزود للخدمات الأخرى
              final isHallProvider = provider['isHallProvider'] == true;
              final providerName = isHallProvider
                  ? (provider['hallName'] as String? ??
                        provider['providerName'] as String)
                  : (provider['providerName'] as String);
              final location = provider['location'] as String;
              final itemsCount = provider['itemsCount'] as int;
              final providerId = provider['providerId'] as String;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // الانتقال إلى صفحة عرض عناصر هذا المزود
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProviderItemsScreen(
                          serviceId: widget.serviceId,
                          providerId: providerId,
                          providerName: providerName,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // أيقونة المتجر
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF1E88E5).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.store,
                            color: Color(0xFF1E88E5),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // بيانات المزود
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                providerName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$itemsCount عنصر متاح',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // سهم للانتقال
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF1E88E5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// شاشة عرض عناصر مزود خدمة معين
class ProviderItemsScreen extends StatelessWidget {
  final String serviceId;
  final String providerId;
  final String providerName;

  const ProviderItemsScreen({
    super.key,
    required this.serviceId,
    required this.providerId,
    required this.providerName,
  });

  // دالة لعرض نافذة حجز التواريخ
  void _showDateBookingDialog(
    BuildContext context,
    Map<String, dynamic> itemData,
    String itemId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('days', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Center(
              child: Text(
                'وظيفة الحجز غير متوفرة حالياً',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'عناصر $providerName',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .doc(serviceId)
            .collection('items')
            .where('providerId', isEqualTo: providerId)
            .where('isActive', isEqualTo: true)
            .where('isApproved', isEqualTo: true) // فقط العناصر المعتمدة
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد عناصر متاحة',
                style: TextStyle(fontSize: 18, color: Color(0xFF90A4AE)),
              ),
            );
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final data = item.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'غير محدد';
              final details = data['details'] ?? '';
              final price = data['price'] ?? 'غير محدد';
              final imageUrls = data['imageUrls'] as List<dynamic>? ?? [];
              final location = data['location'] ?? 'غير محدد';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // التنقل إلى صفحة تفاصيل العنصر
                    final itemData = data;
                    itemData['id'] = item.id;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: Text(itemData['name'] ?? 'تفاصيل العنصر'),
                          ),
                          body: Center(
                            child: Text(
                              'تفاصيل العنصر: ${itemData['name'] ?? 'غير محدد'}',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صورة العنصر
                      if (imageUrls.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Image.network(
                            imageUrls[0],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // تفاصيل العنصر
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (details.isNotEmpty) ...[
                              Text(
                                details,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$price ريال',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E88E5),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // نظام حجز التواريخ لمزودي الخدمة
                                    _showDateBookingDialog(
                                      context,
                                      data,
                                      item.id,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('حجز الأيام'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
