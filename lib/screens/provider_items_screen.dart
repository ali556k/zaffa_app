import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_details_screen.dart';
import '../utils/image_utils.dart';
import '../utils/map_utils.dart';
import '../utils/chat_helper.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class ProviderItemsScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String category;

  const ProviderItemsScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.category,
  });

  @override
  State<ProviderItemsScreen> createState() => _ProviderItemsScreenState();
}

class _ProviderItemsScreenState extends State<ProviderItemsScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  String searchQuery = '';
  Map<String, dynamic>? providerLocation;
  String? providerAddress;
  String? serviceName;
  String? serviceImage;

  @override
  bool get wantKeepAlive => true; // للحفاظ على حالة الشاشة

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadProviderLocation();
  }

  Future<void> _loadProviderLocation() async {
    try {
      // جلب بيانات المزود من published_providers
      final providerDoc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(widget.providerId)
          .get();

      if (providerDoc.exists) {
        final data = providerDoc.data();
        setState(() {
          providerLocation = data?['location'];
          final area = data?['area'] ?? '';
          final governorate = data?['governorate'] ?? '';
          providerAddress = '$area - $governorate';
          serviceName = data?['serviceName'];
          serviceImage = data?['serviceImage'] ?? data?['serviceImageUrl'];
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل موقع المزود: $e');
    }
  }

  Future<void> _loadItems() async {
    try {
      print('🔍 تحميل عناصر المزود: ${widget.providerId}');
      print('📝 اسم المزود: ${widget.providerName}');
      print('📝 الفئة: ${widget.category}');

      if (widget.providerId.isEmpty) {
        print('❌ معرف المزود فارغ!');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('published_items')
          .where('providerId', isEqualTo: widget.providerId)
          .where('isActive', isEqualTo: true)
          .limit(8) // تقليل للهواتف الضعيفة
          .get();

      print('📊 عدد العناصر المسترجعة: ${snapshot.docs.length}');

      // طباعة تفاصيل كل عنصر
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print(
          '📄 عنصر: ${doc.id} - ${data['name']} - لمزود: ${data['providerId']}',
        );
      }

      setState(() {
        items = snapshot.docs.map((doc) {
          final data = doc.data();
          data['itemId'] = doc.id;
          return data;
        }).toList();
        isLoading = false;
      });

      print('✅ تم تحميل ${items.length} عنصر');
    } catch (e) {
      print('❌ خطأ في تحميل العناصر: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredItems {
    if (searchQuery.isEmpty) return items;

    return items.where((item) {
      final name = (item['name'] ?? '').toLowerCase();
      final details = (item['details'] ?? '').toLowerCase();

      return name.contains(searchQuery.toLowerCase()) ||
          details.contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ضروري لـ AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6E1229),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.providerName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'خدمات متاحة',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // شريط البحث
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).appBarTheme.backgroundColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'البحث في الخدمات...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'اضغط على أي عنصر لعرض التفاصيل الكاملة والحجز',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // قائمة العناصر
          Expanded(
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : filteredItems.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadItems,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: filteredItems.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      cacheExtent: 200,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildItemCard(item);
                      },
                    ),
                  ),
          ),

          // زر عرض الموقع والمحادثة
          if (providerLocation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // فتح الموقع الدقيق باستخدام الإحداثيات التي اختارها المزود
                        final lat = providerLocation!['latitude'];
                        final lng = providerLocation!['longitude'];
                        MapUtils.openMap('$lat,$lng');
                      },
                      icon: const Icon(Icons.location_on, size: 24),
                      label: const Text(
                        'عرض الموقع',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ChatHelper.startChatWithUser(
                          context: context,
                          otherUserId: widget.providerId,
                          otherUserName: widget.providerName,
                          otherUserImage: serviceImage,
                          otherUserRole: 'provider',
                          serviceName: serviceName ?? widget.providerName,
                        );
                      },
                      icon: const Icon(Icons.chat_rounded, size: 24),
                      label: const Text(
                        'المحادثة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).appBarTheme.backgroundColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty
                ? 'لا توجد خدمات متاحة حالياً'
                : 'لم يتم العثور على نتائج للبحث',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isEmpty
                ? 'سيتم عرض الخدمات هنا بمجرد إضافتها من قبل مزود الخدمة'
                : 'جرب كلمات بحث مختلفة',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => searchQuery = ''),
              icon: const Icon(Icons.clear),
              label: const Text('مسح البحث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB46A6A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final images = ImageUtils.getImages(item);
    final imageUrl = images.isNotEmpty ? images.first : '';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailsScreen(
              item: item,
              providerName: widget.providerName,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة العنصر
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      color: Colors.grey[100],
                    ),
                    child: imageUrl.isNotEmpty
                        ? RepaintBoundary(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: ImageUtils.buildCachedImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(
                                          0xFFB46A6A,
                                        ).withOpacity(0.1),
                                        const Color(
                                          0xFFB46A6A,
                                        ).withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFB46A6A).withOpacity(0.1),
                                  const Color(0xFFB46A6A).withOpacity(0.3),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                  ),

                  // شريط "غير متوفر" للخدمات غير القابلة للحجز
                  if (!isBookableCategory(widget.category))
                    StreamBuilder<bool>(
                      stream: BookingService().getItemAvailability(
                        item['id'] ?? '',
                      ),
                      builder: (context, snapshot) {
                        final isAvailable = snapshot.data ?? true;

                        if (isAvailable) return const SizedBox.shrink();

                        return Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cancel,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'غير متوفر حالياً',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // معلومات العنصر
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'عنصر بدون اسم',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    if (item['details'] != null &&
                        item['details'].toString().isNotEmpty) ...[
                      Expanded(
                        child: Text(
                          item['details'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
