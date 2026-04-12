import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_model.dart';
import '../screens/booking_screen.dart';
import '../utils/image_utils.dart';
import '../widgets/image_viewer.dart';
import '../services/favorite_service.dart';
import '../utils/chat_helper.dart';

class OrderModel {
  final String id;
  final String userId;
  final String providerId;
  final DateTime createdAt;
  final bool isAccepted;
  final bool isCancelled;
  final bool isDeleted;
  final String status;
  final Map<String, dynamic> data;

  OrderModel({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.createdAt,
    required this.isAccepted,
    required this.isCancelled,
    required this.isDeleted,
    required this.status,
    required this.data,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      providerId: d['providerId'] ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      isAccepted: d['isAccepted'] ?? false,
      isCancelled: d['isCancelled'] ?? false,
      isDeleted: d['isDeleted'] ?? false,
      status: d['status'] ?? 'pending',
      data: d,
    );
  }

  bool get canEdit {
    if (isAccepted || isCancelled || isDeleted) return false;
    final elapsed = DateTime.now().difference(createdAt);
    return elapsed.inHours < 24;
  }

  bool get canDelete => canEdit;
}

class HallDetailsScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final Map<String, dynamic> providerData;

  const HallDetailsScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.providerData,
  });

  @override
  State<HallDetailsScreen> createState() => _HallDetailsScreenState();
}

class _HallDetailsScreenState extends State<HallDetailsScreen>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  Map<String, dynamic> fullProviderData = {};
  String? hallDocumentId; // معرف الوثيقة من Firestore
  String? _userId;
  OrderModel? currentOrder;
  StreamSubscription<OrderModel?>? _orderSub;
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  bool isPhotography = false; // للتفريق بين القاعات والتصوير

  Duration _remainingEditDuration = Duration.zero;
  Timer? _countdownTimer;
  final Set<int> _deselectedServiceIndexes = {};

  @override
  bool get wantKeepAlive => true; // للحفاظ على حالة الشاشة

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadFullProviderData();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (currentOrder != null) {
        final end = currentOrder!.createdAt.add(const Duration(hours: 24));
        final remaining = end.difference(DateTime.now());
        setState(() {
          _remainingEditDuration = remaining.isNegative
              ? Duration.zero
              : remaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _countdownTimer?.cancel();
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user_phone');
    setState(() {
      _userId = userPhone;
    });
    _subscribeToOrder();
  }

  void _subscribeToOrder() {
    if (_userId == null || _userId!.isEmpty) return;
    _orderSub?.cancel();
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: _userId)
        .where('providerId', isEqualTo: widget.providerId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return OrderModel.fromFirestore(snapshot.docs.first);
        })
        .listen((order) {
          setState(() {
            currentOrder = order;
          });
          _startCountdownTimer();
        });
  }

  Future<void> _loadFullProviderData() async {
    try {
      // تحميل البيانات الكاملة للمزود من published_providers
      final doc = await FirebaseFirestore.instance
          .collection('published_providers')
          .where('providerId', isEqualTo: widget.providerId)
          .limit(1)
          .get();

      if (doc.docs.isNotEmpty) {
        final docId = doc.docs.first.id;
        final data = doc.docs.first.data();
        setState(() {
          fullProviderData = data;
          // استخدام document ID الفريد من Firestore - هذا هو المعرف الحقيقي للعنصر
          hallDocumentId = docId;
          // تحديد نوع الخدمة
          isPhotography = data['category'] == 'photography';
          isLoading = false;
        });
      } else {
        // إذا لم توجد في published_providers، استخدم البيانات المرسلة
        setState(() {
          fullProviderData = widget.providerData;
          hallDocumentId =
              null; // لا تستخدم providerId - اجبر على استخدام معرف فريد
          isPhotography = widget.providerData['category'] == 'photography';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل بيانات القاعة: $e');
      setState(() {
        fullProviderData = widget.providerData;
        isPhotography = widget.providerData['category'] == 'photography';
        isLoading = false;
      });
    }
  }

  String displayedHallName() {
    final hallDataName =
        fullProviderData['hallData']?['hallName']?.toString().trim() ?? '';
    final topHallName = fullProviderData['hallName']?.toString().trim() ?? '';
    final serviceName =
        fullProviderData['serviceName']?.toString().trim() ?? '';

    if (hallDataName.isNotEmpty) {
      return hallDataName;
    }

    if (topHallName.isNotEmpty) {
      return topHallName;
    }

    if (serviceName.isNotEmpty &&
        serviceName != 'قاعات اعراس' &&
        serviceName != 'قاعة عرس') {
      return serviceName;
    }

    // Fallback label.
    return 'قاعة أعراس';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ضروري لـ AutomaticKeepAliveClientMixin
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل ${widget.providerName}'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final images = ImageUtils.getImages(fullProviderData);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar مع الصور
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: const SizedBox.shrink(),
              background: images.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          controller: _imagePageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                openImageViewer(
                                  context,
                                  imageUrls: images
                                      .map((e) => e.toString())
                                      .toList(),
                                  initialIndex: index,
                                );
                              },
                              child: RepaintBoundary(
                                child: ImageUtils.buildCachedImage(
                                  imageUrl: images[index].toString(),
                                  width: MediaQuery.of(context).size.width,
                                  height: 300,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // مؤشر الصور
                        if (images.length > 1)
                          Positioned(
                            bottom: 16,
                            right: 0,
                            left: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                images.length,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFB46A6A).withOpacity(0.3),
                            const Color(0xFFB46A6A).withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.event, size: 80, color: Colors.white),
                      ),
                    ),
            ),
          ),

          // المحتوى
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hall Basic Information
                  _buildHallBasicInfo(),

                  const SizedBox(height: 16),

                  // Location Button
                  _buildLocationButton(),

                  const SizedBox(height: 16),

                  // Chat Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ChatHelper.startChatWithUser(
                          context: context,
                          otherUserId: widget.providerId,
                          otherUserName: widget.providerName,
                          otherUserRole: 'provider',
                          serviceName: displayedHallName(),
                        );
                      },
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'محادثة المزود',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Hall Details
                  _buildHallDetailsCard(),

                  const SizedBox(height: 24),

                  // Price Card
                  _buildPriceCard(),

                  const SizedBox(height: 24),

                  // Included Services Card
                  _buildIncludedServicesCard(),

                  const SizedBox(height: 24),

                  // Booking Buttons
                  _buildBookingButtons(),

                  const SizedBox(height: 100), // مساحة إضافية
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHallBasicInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hall Name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB46A6A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event,
                    color: Color(0xFFB46A6A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    fullProviderData['hallData'] != null &&
                            fullProviderData['hallData']['hallName'] != null &&
                            fullProviderData['hallData']['hallName']
                                .toString()
                                .trim()
                                .isNotEmpty
                        ? fullProviderData['hallData']['hallName'].toString()
                        : displayedHallName(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Hall Name from hallData
            if (fullProviderData['hallData'] != null &&
                fullProviderData['hallData']['hallName'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFB46A6A).withOpacity(0.1),
                      const Color(0xFFB46A6A).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFB46A6A).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.home_work,
                      color: Color(0xFFB46A6A),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اسم القاعة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fullProviderData['hallData']['hallName'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Capacity and Governorate - عرض السعة فقط للقاعات وليس للتصوير
            Row(
              children: [
                if (!isPhotography)
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.people,
                      label: 'سعة القاعة',
                      value: _getCapacity(),
                    ),
                  ),
                if (!isPhotography) const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.location_city,
                    label: 'المحافظة',
                    value: fullProviderData['governorate'] ?? 'غير محدد',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Area
            _buildInfoItem(
              icon: Icons.place,
              label: 'المنطقة',
              value: fullProviderData['area'] ?? 'غير محدد',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showLocationOnMap,
        icon: const Icon(Icons.map, color: Colors.white),
        label: const Text(
          'إظهار الموقع على الخريطة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildHallDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPhotography ? Icons.camera_alt : Icons.info,
                    color: const Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  isPhotography ? 'تفاصيل خدمة التصوير' : 'تفاصيل القاعة',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // نوع الكاميرا للتصوير
            if (isPhotography && fullProviderData['cameraType'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.purple, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'نوع الكاميرا',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fullProviderData['cameraType'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Text(
                fullProviderData['description'] ??
                    (isPhotography
                        ? 'خدمة تصوير احترافية تشمل:\n\n• تصوير فوتوغرافي عالي الجودة\n• تصوير فيديو سينمائي\n• طاقم محترف\n• معدات حديثة\n• مونتاج احترافي\n• ألبوم رقمي\n• توصيل سريع للصور'
                        : 'قاعة أعراس فاخرة مجهزة بأحدث التقنيات والديكورات العصرية لتوفير أجواء مثالية لحفل زفافكم المميز. تشمل القاعة:\n\n• نظام صوت متطور\n• إضاءة احترافية\n• تكييف مركزي\n• مواقف سيارات\n• أماكن تصوير مميزة\n• خدمات طعام'),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4A5568),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFFB46A6A).withOpacity(0.1), Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB46A6A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Color(0xFFB46A6A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'السعر',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatPrice(_getBasePrice()),
                  style: const TextStyle(
                    fontSize: 32,
                    color: Color(0xFFB46A6A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'دينار عراقي',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4A5568),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ملاحظة: السعر الأساسي
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    isPhotography
                        ? 'السعر للساعة الواحدة'
                        : 'السعر الأساسي للقاعة (لا يشمل الخدمات الضمنية)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isFoodService(String name) {
    final lower = name.toLowerCase();
    return lower.contains('طعام') ||
        lower.contains('ضيافة') ||
        lower.contains('وليمة') ||
        lower.contains('أكل') ||
        lower.contains('اكل') ||
        lower.contains('food') ||
        lower.contains('catering');
  }

  List<dynamic> _getSelectedIncludedServices() {
    List<dynamic> all = [];
    if (fullProviderData['hallData'] != null) {
      all = fullProviderData['hallData']['includedServices'] ?? [];
    }
    if (all.isEmpty) {
      all = fullProviderData['includedServices'] ?? [];
    }
    return [
      for (int i = 0; i < all.length; i++)
        if (!_deselectedServiceIndexes.contains(i)) all[i],
    ];
  }

  Widget _buildIncludedServicesCard() {
    // إخفاء الخدمات الضمنية للتصوير
    if (isPhotography) {
      return const SizedBox.shrink();
    }

    // الحصول على الخدمات الضمنية من البيانات
    List<dynamic> includedServices = [];

    // محاولة الحصول على الخدمات من hallData أولاً
    if (fullProviderData['hallData'] != null) {
      includedServices = fullProviderData['hallData']['includedServices'] ?? [];
    }

    // إذا لم توجد في hallData، جرب مباشرة من fullProviderData
    if (includedServices.isEmpty) {
      includedServices = fullProviderData['includedServices'] ?? [];
    }

    // إذا لم توجد خدمات ضمنية، لا تعرض البطاقة
    if (includedServices.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasFoodService = includedServices.any(
      (s) => _isFoodService(s['name']?.toString() ?? ''),
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.room_service,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'الخدمات الضمنية المتوفرة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'تشمل القاعة الخدمات التالية:',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),

            // رسالة توضيحية لخدمات الطعام
            if (hasFoodService) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يمكنك إلغاء اختيار خدمات الطعام والضيافة إذا كنت لا تحتاجها عن طريق الضغط على المربع بجانب الخدمة',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // عرض الخدمات الضمنية
            ...List.generate(includedServices.length, (i) {
              final service = includedServices[i];
              String serviceName = service['name'] ?? 'خدمة غير محددة';
              double servicePrice = (service['price'] ?? 0).toDouble();
              final isFood = _isFoodService(serviceName);
              final isSelected = !_deselectedServiceIndexes.contains(i);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isFood && !isSelected
                      ? Colors.grey.withOpacity(0.05)
                      : const Color(0xFF10B981).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFood && !isSelected
                        ? Colors.grey.withOpacity(0.3)
                        : const Color(0xFF10B981).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (isFood)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: isSelected,
                          activeColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _deselectedServiceIndexes.remove(i);
                            } else {
                              _deselectedServiceIndexes.add(i);
                            }
                          }),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        serviceName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isFood && !isSelected
                              ? Colors.grey
                              : const Color(0xFF2D3748),
                          decoration: isFood && !isSelected
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (servicePrice > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isFood && !isSelected
                              ? Colors.grey
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isFood && !isSelected
                              ? '-'
                              : '${_formatPrice(servicePrice)} د.ع',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // إجمالي سعر الخدمات الضمنية المختارة
            Builder(
              builder: (context) {
                final selectedServices = [
                  for (int i = 0; i < includedServices.length; i++)
                    if (!_deselectedServiceIndexes.contains(i))
                      includedServices[i],
                ];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.2),
                        const Color(0xFF10B981).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'إجمالي قيمة الخدمات الضمنية',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatPrice(_calculateTotalServicesPrice(selectedServices))} د.ع',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalServicesPrice(List<dynamic> services) {
    double total = 0.0;
    for (var service in services) {
      total += (service['price'] ?? 0).toDouble();
    }
    return total;
  }

  String _getCapacity() {
    // محاولة الحصول على السعة من أماكن مختلفة
    String? capacity;

    // من hallData أولاً
    if (fullProviderData['hallData'] != null) {
      capacity = fullProviderData['hallData']['capacity']?.toString();
    }

    // إذا لم توجد، جرب من fullProviderData مباشرة
    if (capacity == null || capacity.isEmpty) {
      capacity = fullProviderData['capacity']?.toString();
    }

    // إذا لم توجد بعد، استخدم قيمة افتراضية
    if (capacity == null || capacity.isEmpty) {
      return '300 شخص';
    }

    // إذا كانت السعة رقم فقط، أضف "شخص"
    if (int.tryParse(capacity) != null) {
      return '$capacity شخص';
    }

    return capacity;
  }

  double _getBasePrice() {
    // محاولة الحصول على السعر الأساسي من أماكن مختلفة
    double? price;

    print('💰 محاولة جلب السعر...');

    // من hallData.basePrice أولاً
    if (fullProviderData['hallData'] != null) {
      var basePrice = fullProviderData['hallData']['basePrice'];
      print('   📦 hallData.basePrice: $basePrice');
      if (basePrice != null) {
        price = (basePrice is int)
            ? basePrice.toDouble()
            : basePrice as double?;
      }
    }

    // إذا لم توجد، جرب من fullProviderData.basePrice
    if (price == null || price == 0) {
      var basePrice = fullProviderData['basePrice'];
      print('   📦 fullProviderData.basePrice: $basePrice');
      if (basePrice != null) {
        price = (basePrice is int)
            ? basePrice.toDouble()
            : basePrice as double?;
      }
    }

    // إذا لم توجد، جرب من fullProviderData.price
    if (price == null || price == 0) {
      var priceValue = fullProviderData['price'];
      print('   📦 fullProviderData.price: $priceValue');
      if (priceValue != null) {
        price = (priceValue is int)
            ? priceValue.toDouble()
            : priceValue as double?;
      }
    }

    print('   ✅ السعر النهائي: $price');
    return price ?? 0.0;
  }

  bool get _canCurrentOrderEdit {
    if (currentOrder == null) return false;
    return currentOrder!.canEdit &&
        !currentOrder!.isAccepted &&
        !currentOrder!.isCancelled;
  }

  bool get _hasActiveOrder {
    if (currentOrder == null) return false;
    return !currentOrder!.isCancelled && !currentOrder!.isDeleted;
  }

  bool get _isConfirmLocked {
    if (!_hasActiveOrder) return false;
    final elapsed = DateTime.now().difference(currentOrder!.createdAt);
    return elapsed < const Duration(hours: 24);
  }

  bool get _canConfirmBooking {
    return !_isConfirmLocked;
  }

  Future<void> _sendOrderNotification(
    String providerId,
    String title,
    String body,
  ) async {
    final providerDoc = await FirebaseFirestore.instance
        .collection('providers')
        .doc(providerId)
        .get();
    final token = providerDoc.data()?['fcmToken']?.toString();
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance.collection('fcm_notifications').add({
      'token': token,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _editCurrentOrder() async {
    if (!_canCurrentOrderEdit || currentOrder == null) return;

    final existingScheduled = (currentOrder!.data['scheduledAt'] as Timestamp?)
        ?.toDate();
    final existingTimeSlotData =
        currentOrder!.data['timeSlot'] as Map<String, dynamic>?;
    final existingTimeSlot = existingTimeSlotData != null
        ? TimeSlot.fromMap(existingTimeSlotData)
        : null;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          serviceData: {
            'id': hallDocumentId ?? widget.providerId,
            'name': displayedHallName(),
            'providerId': widget.providerId,
            'providerName': widget.providerName,
            'serviceType': 'hall',
            'category': 'hall',
            'price': _getBasePrice(),
            'includedServices': _getSelectedIncludedServices(),
          },
          existingItemPrice: _getBasePrice().toString(),
          isEditMode: true,
          editOrderId: currentOrder!.id,
          orderId: currentOrder!.id,
          existingScheduledAt: existingScheduled,
          existingIsFullDayBooking:
              currentOrder!.data['isFullDayBooking'] == true,
          existingTimeSlot: existingTimeSlot,
          existingNotes: currentOrder!.data['notes']?.toString(),
        ),
      ),
    );

    if (result == true) {
      // إعادة تحميل بيانات الطلب بعد التعديل
      _subscribeToOrder();
    }
  }

  Future<void> _cancelCurrentOrder() async {
    if (!_canCurrentOrderEdit || currentOrder == null) return;

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(currentOrder!.id)
        .update({
          'isCancelled': true,
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

    await _sendOrderNotification(
      widget.providerId,
      'الطلب تم إلغاؤه',
      'قام المستخدم بإلغاء طلبك على القاعة ${displayedHallName()}',
    );
  }

  Widget _buildBookingButtons() {
    return Column(
      children: [
        // Confirm Booking Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirmBooking,
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
            label: const Text(
              'تثبيت الحجز',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB46A6A),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (currentOrder != null) ...[
          if (currentOrder!.isAccepted)
            const Text(
              '⚠️ تم قبول الطلب من قبل المزود، لا يمكن تعديل أو حذف الطلب.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            )
          else ...[],
        ],

        // Chat Button removed — moved above booking buttons

        // Favorite Button
        StreamBuilder<bool>(
          stream: FavoriteService().isFavoriteStream(
            customerId: _userId ?? '',
            itemId: hallDocumentId ?? widget.providerId,
          ),
          builder: (context, snapshot) {
            final isFavorite = snapshot.data ?? false;
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (_userId == null || _userId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى تسجيل الدخول أولاً'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  try {
                    final images = ImageUtils.getImages(fullProviderData);
                    final imageUrl = images.isNotEmpty
                        ? images.first.toString()
                        : null;

                    final added = await FavoriteService().toggleFavorite(
                      customerId: _userId!,
                      itemId: hallDocumentId ?? widget.providerId,
                      itemName: displayedHallName(),
                      providerId: widget.providerId,
                      providerName: widget.providerName,
                      category: 'hall',
                      price: _getBasePrice(),
                      imageUrl: imageUrl,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            added
                                ? '❤️ تمت الإضافة للمفضلات'
                                : '💔 تمت الإزالة من المفضلات',
                          ),
                          backgroundColor: added ? Colors.green : Colors.grey,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('حدث خطأ: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Color(0xFFB46A6A),
                  size: 20,
                ),
                label: Text(
                  isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isFavorite ? Colors.red : Color(0xFFB46A6A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isFavorite ? Colors.red : Color(0xFFB46A6A),
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFB46A6A), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationOnMap() async {
    try {
      double? lat;
      double? lng;

      final location = fullProviderData['location'];
      if (location != null) {
        if (location is GeoPoint) {
          lat = location.latitude;
          lng = location.longitude;
        } else if (location is Map) {
          lat = (location['latitude'] ?? location['lat'])?.toDouble();
          lng = (location['longitude'] ?? location['lng'])?.toDouble();
        } else if (location is String) {
          final parts = location.split(',');
          if (parts.length >= 2) {
            lat = double.tryParse(parts[0].trim());
            lng = double.tryParse(parts[1].trim());
          }
        }
      }

      if ((lat == null || lng == null) &&
          fullProviderData['latitude'] != null &&
          fullProviderData['longitude'] != null) {
        lat = (fullProviderData['latitude']).toDouble();
        lng = (fullProviderData['longitude']).toDouble();
      }

      if ((lat == null || lng == null) &&
          fullProviderData['lat'] != null &&
          fullProviderData['lng'] != null) {
        lat = (fullProviderData['lat']).toDouble();
        lng = (fullProviderData['lng']).toDouble();
      }

      if (lat != null && lng != null) {
        final googleMapsUrl =
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        final uri = Uri.parse(googleMapsUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح خرائط جوجل'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('موقع القاعة غير متوفر'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('خطأ في فتح الموقع: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في فتح الموقع'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmBooking() async {

    // التحقق من وجود معرف فريد
    if (hallDocumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: لا يمكن الحجز. يرجى إعادة تحميل الصفحة.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user_phone');
    if (userPhone == null || userPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول أولاً للحجز.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _userId = userPhone;
    });

    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    await orderRef.set({
      'userId': _userId,
      'providerId': widget.providerId,
      'createdAt': FieldValue.serverTimestamp(),
      'isAccepted': false,
      'isCancelled': false,
      'isDeleted': false,
      'status': 'pending',
      'serviceName': displayedHallName(),
      'hallId': hallDocumentId,
    });

    await _sendOrderNotification(
      widget.providerId,
      'طلب جديد من مستخدم',
      'تم إنشاء طلب جديد للقاعة ${displayedHallName()} من قِبل المستخدم',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          serviceData: {
            'id': hallDocumentId!, // استخدام document ID الفريد فقط
            'name': displayedHallName(),
            'providerId': widget.providerId,
            'providerPhone': fullProviderData['phone'] ?? widget.providerId,
            'price': _getBasePrice().toString(), // استخدام السعر الصحيح
            'serviceType': 'hall',
            'category': 'hall',
            'providerName':
                fullProviderData['providerName'] ?? widget.providerName,
            'includedServices': _getSelectedIncludedServices(),
          },
          orderId: orderRef.id,
        ),
      ),
    );
  }

  void _viewBookings() {
    // TODO: Implement view bookings functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.history, color: Color(0xFFB46A6A)),
            SizedBox(width: 8),
            Text('الحجوزات'),
          ],
        ),
        content: const Text(
          'ستظهر هنا قائمة بجميع حجوزاتك السابقة والحالية',
          style: TextStyle(fontSize: 16),
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

  String _formatPrice(dynamic price) {
    if (price == null) return '0';

    try {
      num priceNum = 0;
      if (price is String) {
        priceNum = num.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      } else if (price is num) {
        priceNum = price;
      }

      return priceNum
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    } catch (e) {
      return price.toString();
    }
  }
}
