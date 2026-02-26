import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'provider_items_screen.dart';
import 'hall_details_screen.dart';
import '../utils/image_utils.dart';

class PublishedProvidersScreen extends StatefulWidget {
  final String category;
  final String categoryTitle;
  final String? filterProviderId;

  const PublishedProvidersScreen({
    super.key,
    required this.category,
    this.categoryTitle = '',
    this.filterProviderId,
  });

  @override
  State<PublishedProvidersScreen> createState() =>
      _PublishedProvidersScreenState();
}

class _PublishedProvidersScreenState extends State<PublishedProvidersScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> providers = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  bool get wantKeepAlive => true; // للحفاظ على حالة الشاشة

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      print('');
      print('═══════════════════════════════════════════════');
      print('🔍 تحميل مزودي الخدمة للزبائن');
      print('═══════════════════════════════════════════════');
      print('📂 المجموعة: published_providers');
      print('🏷️ الفئة المطلوبة: ${widget.category}');
      print('');

      // استعلام Firebase مع تحديد عدد النتائج لتحسين الأداء
      Query query = FirebaseFirestore.instance
          .collection('published_providers')
          .where('category', isEqualTo: widget.category)
          .where('isActive', isEqualTo: true)
          .limit(10); // تقليل العدد للهواتف الضعيفة

      // إذا كان هناك فلتر لمزود معين
      if (widget.filterProviderId != null &&
          widget.filterProviderId!.isNotEmpty) {
        query = query.where('providerId', isEqualTo: widget.filterProviderId);
      }

      final snapshot = await query.get();

      print('📊 عدد المستندات المسترجعة: ${snapshot.docs.length}');
      print('');

      if (snapshot.docs.isEmpty) {
        print(
          '⚠️ تحذير: لم يتم العثور على أي مزودي خدمة في published_providers!',
        );

        // محاولة احتياطية: جلب من مجموعة الفئة مباشرة (مثلاً hall)
        if (widget.category == 'hall' ||
            widget.category == 'hotel' ||
            widget.category == 'cake' ||
            widget.category == 'restaurant' ||
            widget.category == 'bride_dress' ||
            widget.category == 'salon_care' ||
            widget.category == 'flowers' ||
            widget.category == 'groom_suit' ||
            widget.category == 'car' ||
            widget.category == 'car_decoration' ||
            widget.category == 'honeymoon') {
          print('🛟 تفعيل خطة الطوارئ: التحميل من مجموعة ${widget.category}');
          final altSnap = await FirebaseFirestore.instance
              .collection(widget.category)
              .where('isActive', isEqualTo: true)
              .get();
          print(
            '📊 تم العثور على ${altSnap.docs.length} سجل في ${widget.category}',
          );

          // تجميع حسب providerId لتجنب التكرار
          final Map<String, Map<String, dynamic>> byProvider = {};
          for (var d in altSnap.docs) {
            final data = d.data();
            final pid = (data['providerId'] ?? '').toString();
            if (pid.isEmpty) continue;
            // احتفظ بأول عنصر لكل مزود
            byProvider.putIfAbsent(pid, () {
              return {
                'id': pid,
                'providerId': pid,
                'providerName': (data['providerName'] ?? 'مزود خدمة')
                    .toString(),
                'category': widget.category,
                'phone': data['providerPhone'] ?? data['phone'] ?? '',
                'governorate': data['governorate'] ?? '',
                'area': data['area'] ?? '',
                'location': data['location'] ?? '',
                'profileImage': data['imageUrl'] ?? '',
                'serviceImage':
                    (data['imageUrls'] is List &&
                        (data['imageUrls'] as List).isNotEmpty)
                    ? (data['imageUrls'] as List).first.toString()
                    : (data['imageUrl'] ?? ''),
                'description': data['description'] ?? data['details'] ?? '',
                'rating': data['rating'] ?? 0.0,
                'reviewCount': data['reviewCount'] ?? 0,
                'isActive': true,
                'serviceName': data['serviceName'] ?? widget.categoryTitle,
                // خصائص خاصة بالقاعة
                'hallName': data['hallName'] ?? data['name'] ?? 'قاعة',
                'name': data['name'] ?? data['hallName'],
                'capacity': data['capacity'],
                'basePrice': data['basePrice'] ?? data['price'],
                'price': data['price'] ?? data['basePrice'],
              };
            });
          }

          setState(() {
            providers = byProvider.values.toList();
            isLoading = false;
          });

          print(
            '✅ تم تحميل ${providers.length} مزود من مجموعة ${widget.category} كخطة بديلة',
          );
          return;
        }

        print('');
        print('💡 التحقق من:');
        print('   1. هل تمت الموافقة على الطلب من المالك؟');
        print('   2. هل الحقل category = "${widget.category}"؟');
        print('   3. هل الحقل isActive = true؟');
        print('   4. هل البيانات موجودة في مجموعة published_providers؟');
        print('');
      } else {
        print('✅ تفاصيل المزودين المسترجعين:');
        print('');
        // طباعة معرفات المزودين للتحقق
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print('📄 مزود #${snapshot.docs.indexOf(doc) + 1}:');
          print('   🆔 ID: ${doc.id}');
          print('   � اسم المزود: ${data['providerName']}');
          print('   🏷️ الفئة: ${data['category']}');
          print('   📍 الموقع: ${data['area']} - ${data['governorate']}');
          print('   ✅ نشط: ${data['isActive']}');
          if (data['category'] == 'hall') {
            print('   🏛️ اسم القاعة: ${data['hallName']}');
            print('   � السعة: ${data['capacity']}');
            print('   💰 السعر: ${data['basePrice'] ?? data['price']}');
          }
          print('   📋 جميع الحقول: ${data.keys.toList()}');
          print('   ---');
        }
      }

      // بناء قائمة مبدئية من published_providers (استخدام البيانات الموجودة مباشرة)
      List<Map<String, dynamic>> loadedProviders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        // استخدام البيانات الموجودة في published_providers مباشرة بدون استعلامات إضافية
        return data;
      }).toList();

      print(
        '✅ تم تحميل ${loadedProviders.length} مزود بنجاح (بدون استعلامات إضافية)',
      );
      print(
        '💡 تحسين: تم تجنب ${loadedProviders.length * 3} استعلام إضافي لتحسين الأداء',
      );
      print('   - البيانات المستخدمة من published_providers مباشرة');
      print('   - governorate و area موجودة مسبقاً في المستندات');
      print('   - الصور محسّنة للعرض السريع');

      if (!mounted) return;
      setState(() {
        providers = loadedProviders;
        isLoading = false;
      });

      print('');
      print('✅ اكتمل التحميل: ${providers.length} مزود خدمة (بعد الدمج)');
      print('═══════════════════════════════════════════════');
      print('');
    } catch (e, stackTrace) {
      print('');
      print('❌ خطأ في تحميل مزودي الخدمة:');
      print('   الخطأ: $e');
      print('   التتبع: $stackTrace');
      print('');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredProviders {
    if (searchQuery.isEmpty) return providers;

    return providers.where((provider) {
      final name = (provider['providerName'] ?? '').toLowerCase();
      final service = (provider['serviceName'] ?? '').toLowerCase();
      final area = (provider['area'] ?? '').toLowerCase();
      final governorate = (provider['governorate'] ?? '').toLowerCase();

      return name.contains(searchQuery.toLowerCase()) ||
          service.contains(searchQuery.toLowerCase()) ||
          area.contains(searchQuery.toLowerCase()) ||
          governorate.contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ضروري لـ AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'البحث في ${widget.categoryTitle}...',
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
          ),

          // قائمة مزودي الخدمة
          Expanded(
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : filteredProviders.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadProviders,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredProviders.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      cacheExtent: 200,
                      itemBuilder: (context, index) {
                        final provider = filteredProviders[index];
                        return _buildProviderCard(provider);
                      },
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
          Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
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
                ? 'سيتم عرض الخدمات هنا بمجرد موافقة الإدارة عليها'
                : 'جرب كلمات بحث مختلفة',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // زر إعادة التحميل
          if (searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                setState(() => isLoading = true);
                await _loadProviders();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة التحميل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB46A6A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),

          if (searchQuery.isNotEmpty)
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
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          print('🎯 النقر على مزود الخدمة:');
          print('- ID: ${provider['id']}');
          print('- ProviderId: ${provider['providerId']}');
          print('- Name: ${provider['providerName']}');
          print('- Category: ${provider['category']}');
          print('- Full data: $provider');

          // التحقق من نوع الخدمة لتوجيه التنقل المناسب
          if (provider['category'] == 'hall' ||
              widget.category == 'hall' ||
              provider['category'] == 'photography' ||
              widget.category == 'photography') {
            // لقاعات الأعراس والتصوير: الانتقال لشاشة تفاصيل مباشرة
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HallDetailsScreen(
                  providerId: provider['providerId'] ?? provider['id'] ?? '',
                  providerName: provider['providerName'] ?? 'مزود الخدمة',
                  providerData: provider,
                ),
              ),
            );
          } else {
            // لباقي الخدمات: الانتقال لشاشة العناصر
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProviderItemsScreen(
                  providerId: provider['providerId'] ?? provider['id'] ?? '',
                  providerName:
                      provider['serviceName'] ??
                      provider['providerName'] ??
                      'مزود الخدمة',
                  category: provider['category'] ?? widget.category,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, const Color(0xFFB46A6A).withOpacity(0.05)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // صورة المزود
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFB46A6A).withOpacity(0.1),
                      border: Border.all(
                        color: const Color(0xFFB46A6A).withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB46A6A).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildProviderImage(provider),
                  ),

                  const SizedBox(width: 20),

                  // معلومات المزود
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // عرض اسم القاعة للقاعات أو اسم الخدمة للخدمات الأخرى
                        Text(
                          (provider['category'] == 'hall' ||
                                  widget.category == 'hall')
                              ? (provider['hallName']?.toString() ??
                                    provider['name']?.toString() ??
                                    'اسم القاعة غير محدد')
                              : (provider['serviceName'] == null ||
                                    provider['serviceName']
                                        .toString()
                                        .isEmpty ||
                                    provider['serviceName'] ==
                                        provider['providerName'] ||
                                    provider['serviceName'] ==
                                        provider['userName'])
                              ? 'اسم الخدمة غير محدد'
                              : provider['serviceName'],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // الموقع (المحافظة والمنطقة)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${provider['governorate'] ?? 'غير محدد'} - ${provider['area'] ?? 'غير محدد'}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // معلومات إضافية (وصف، سعر، تقييم)
              const SizedBox(height: 16),

              // الوصف إن وجد
              if (provider['description'] != null &&
                  provider['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    provider['description'].toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // معلومات إضافية (سعر، سعة، تقييم)
              Row(
                children: [
                  // ملاحظة: تم إزالة عرض حقل السعة وحقل التقييم من تحت كرت الخدمة حسب طلب العميل

                  // السعر (للقاعات)
                  if ((provider['category'] == 'hall' ||
                          widget.category == 'hall') &&
                      (provider['basePrice'] != null ||
                          provider['price'] != null))
                    Expanded(
                      child: _buildInfoChip(
                        Icons.attach_money,
                        '${provider['basePrice'] ?? provider['price']} د.ع',
                        const Color(0xFFB46A6A),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderImage(Map<String, dynamic> provider) {
    // استخدام ImageUtils لجلب الصور
    final images = ImageUtils.getImages(provider);
    final imageUrl = images.isNotEmpty ? images.first : null;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // استخدام الصورة المحسّنة مع caching
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ImageUtils.buildCachedImage(
          imageUrl: imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorWidget: _buildDefaultProviderIcon(),
        ),
      );
    } else {
      return _buildDefaultProviderIcon();
    }
  }

  Widget _buildDefaultProviderIcon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFB46A6A).withOpacity(0.1),
            const Color(0xFFB46A6A).withOpacity(0.2),
          ],
        ),
      ),
      child: const Icon(Icons.person, size: 50, color: Color(0xFFB46A6A)),
    );
  }
}
