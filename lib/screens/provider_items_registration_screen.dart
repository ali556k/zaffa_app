import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'provider_main_professional.dart';

class ProviderItemsRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;

  const ProviderItemsRegistrationScreen({super.key, required this.serviceData});

  @override
  State<ProviderItemsRegistrationScreen> createState() =>
      _ProviderItemsRegistrationScreenState();
}

class _ProviderItemsRegistrationScreenState
    extends State<ProviderItemsRegistrationScreen> {
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;

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
                child: Column(
                  children: [
                    const Icon(Icons.inventory, size: 80, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'إضافة عناصر الخدمة',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'خدمة: ${widget.serviceData['serviceName']}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Container
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF1E88E5),
                              ),
                              SizedBox(height: 16),
                              Text('جاري إرسال الطلب للإدارة...'),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Items List
                            Expanded(
                              child: _items.isEmpty
                                  ? _buildEmptyState()
                                  : _buildItemsList(),
                            ),

                            // Action Buttons
                            _buildActionButtons(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 120, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'لم تتم إضافة أي عناصر بعد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'اضغط على "إضافة عنصر جديد" لبدء إضافة عناصر خدمتك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Item Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item['images'] != null && item['images'].isNotEmpty
                      ? Image.file(
                          item['images'][0],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _editItem(index),
                      icon: const Icon(Icons.edit, color: Color(0xFF1E88E5)),
                    ),
                    IconButton(
                      onPressed: () => _deleteItem(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Add Item Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _addNewItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'إضافة عنصر جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_items.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Submit Request Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.send),
                label: const Text(
                  'إرسال الطلب للإدارة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addNewItem() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(serviceData: widget.serviceData),
      ),
    );

    if (result != null) {
      setState(() {
        _items.add(result);
      });
    }
  }

  void _editItem(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddItemScreen(item: _items[index], serviceData: widget.serviceData),
      ),
    );

    if (result != null) {
      setState(() {
        _items[index] = result;
      });
    }
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_item'),
        content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة عنصر واحد على الأقل')),
      );
      return;
    }

    print('📋 بيانات الخدمة المُرسلة: ${widget.serviceData}');
    print('📋 serviceName من البيانات: ${widget.serviceData['serviceName']}');
    print('📋 serviceType من البيانات: ${widget.serviceData['serviceType']}');
    print(
      '📋 هل serviceType عربي أم إنجليزي؟ ${widget.serviceData['serviceType']}',
    );

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload item images and prepare data
      List<Map<String, dynamic>> itemsData = [];

      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        List<String> imageUrls = [];

        // Upload images
        if (item['images'] != null) {
          for (File image in item['images']) {
            final ref = FirebaseStorage.instance
                .ref()
                .child('item_images')
                .child(
                  '${widget.serviceData['userPhone']}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
                );

            await ref.putFile(image);
            final url = await ref.getDownloadURL();
            imageUrls.add(url);
          }
        }

        itemsData.add({
          'name': item['name'],
          'details': item['details'],
          'price': item['price'],
          'imageUrls': imageUrls,
          'capacity': item['capacity'],
        });
      }

      // جلب المعلومات الكاملة من نفس المصدر (users + provider_services)
      final providerId =
          widget.serviceData['providerId'] ??
          widget.serviceData['phone'] ??
          widget.serviceData['userPhone'];

      print('🔄 جلب المعلومات الكاملة للمزود: $providerId');
      print('📸 الصور في widget.serviceData:');
      print('   - serviceImage: ${widget.serviceData['serviceImage']}');
      print('   - serviceImageUrl: ${widget.serviceData['serviceImageUrl']}');
      print('   - imageUrl: ${widget.serviceData['imageUrl']}');

      // جلب معلومات المستخدم من users
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .get();

      final userData = userDoc.data() ?? {};

      // جلب معلومات الخدمة من provider_services
      final providerServicesDoc = await FirebaseFirestore.instance
          .collection('provider_services')
          .doc(providerId)
          .get();

      Map<String, dynamic> serviceDataFromDb = {};
      List<dynamic> existingItems = [];

      if (providerServicesDoc.exists) {
        serviceDataFromDb = providerServicesDoc.data() ?? {};
        existingItems = serviceDataFromDb['items'] ?? [];
      }

      // التحقق من كون المزود مسجلاً
      final publishedDoc = await FirebaseFirestore.instance
          .collection('published_providers')
          .doc(providerId)
          .get();

      bool isRegisteredProvider = publishedDoc.exists;

      // جلب serviceImage من published_providers إذا كان مسجلاً
      String? serviceImageFromPublished;
      String? serviceImageUrlFromPublished;
      if (isRegisteredProvider && publishedDoc.exists) {
        final publishedData = publishedDoc.data();
        serviceImageFromPublished = publishedData?['serviceImage'];
        serviceImageUrlFromPublished = publishedData?['serviceImageUrl'];

        // تجاهل القيم الفارغة
        if (serviceImageFromPublished?.isEmpty ?? true) {
          serviceImageFromPublished = null;
        }
        if (serviceImageUrlFromPublished?.isEmpty ?? true) {
          serviceImageUrlFromPublished = null;
        }

        print(
          '🖼️ تم جلب serviceImage من published_providers: $serviceImageFromPublished',
        );
        print(
          '🖼️ تم جلب serviceImageUrl من published_providers: $serviceImageUrlFromPublished',
        );
      }

      print('📦 عدد العناصر القديمة: ${existingItems.length}');
      print('📦 عدد العناصر الجديدة: ${itemsData.length}');
      print('✅ مزود مسجل: $isRegisteredProvider');

      // بناء بيانات الطلب الكاملة (نفس منطق service_information_screen)
      final requestData = {
        // معلومات المستخدم من users
        'userName':
            userData['name'] ??
            serviceDataFromDb['userName'] ??
            widget.serviceData['userName'] ??
            'مستخدم',
        'name':
            serviceDataFromDb['serviceName'] ??
            widget.serviceData['serviceName'] ??
            widget.serviceData['name'],
        'serviceName':
            serviceDataFromDb['serviceName'] ??
            widget.serviceData['serviceName'] ??
            widget.serviceData['name'],

        // معلومات الاتصال
        'phone': providerId,
        'userPhone': providerId,
        'providerPhone': providerId,
        'providerId': providerId,
        'providerName': providerId,

        // معلومات الموقع
        'governorate':
            userData['governorate'] ??
            serviceDataFromDb['governorate'] ??
            widget.serviceData['governorate'] ??
            'غير محدد',
        'userGovernorate':
            userData['governorate'] ??
            serviceDataFromDb['userGovernorate'] ??
            widget.serviceData['userGovernorate'] ??
            'غير محدد',
        'area':
            serviceDataFromDb['area'] ??
            userData['area'] ??
            widget.serviceData['area'] ??
            'غير محدد',
        'userArea':
            serviceDataFromDb['userArea'] ??
            userData['area'] ??
            widget.serviceData['userArea'] ??
            'غير محدد',

        // معلومات الموقع على الخريطة
        'location':
            serviceDataFromDb['location'] ?? widget.serviceData['location'],
        'latitude':
            serviceDataFromDb['latitude'] ?? widget.serviceData['latitude'],
        'longitude':
            serviceDataFromDb['longitude'] ?? widget.serviceData['longitude'],

        // معلومات الخدمة
        'serviceType':
            serviceDataFromDb['serviceType'] ??
            widget.serviceData['serviceType'],
        'services':
            serviceDataFromDb['services'] ??
            widget.serviceData['services'] ??
            [
              serviceDataFromDb['serviceType'] ??
                  widget.serviceData['serviceType'],
            ],

        // الصور - مع فحص القيم الفارغة
        'serviceImage':
            serviceImageFromPublished ?? // من published_providers أولاً
            ((serviceDataFromDb['serviceImage']?.toString().isNotEmpty ?? false)
                ? serviceDataFromDb['serviceImage']
                : null) ??
            ((serviceDataFromDb['serviceImageUrl']?.toString().isNotEmpty ??
                    false)
                ? serviceDataFromDb['serviceImageUrl']
                : null) ??
            ((userData['profileImage']?.toString().isNotEmpty ?? false)
                ? userData['profileImage']
                : null) ??
            ((widget.serviceData['serviceImage']?.toString().isNotEmpty ??
                    false)
                ? widget.serviceData['serviceImage']
                : null),
        'serviceImageUrl':
            serviceImageUrlFromPublished ?? // من published_providers أولاً
            ((serviceDataFromDb['serviceImageUrl']?.toString().isNotEmpty ??
                    false)
                ? serviceDataFromDb['serviceImageUrl']
                : null) ??
            ((serviceDataFromDb['serviceImage']?.toString().isNotEmpty ?? false)
                ? serviceDataFromDb['serviceImage']
                : null) ??
            ((widget.serviceData['serviceImageUrl']?.toString().isNotEmpty ??
                    false)
                ? widget.serviceData['serviceImageUrl']
                : null),
        'imageUrl':
            serviceImageFromPublished ?? // من published_providers أولاً
            ((serviceDataFromDb['imageUrl']?.toString().isNotEmpty ?? false)
                ? serviceDataFromDb['imageUrl']
                : null) ??
            ((serviceDataFromDb['serviceImage']?.toString().isNotEmpty ?? false)
                ? serviceDataFromDb['serviceImage']
                : null) ??
            ((widget.serviceData['imageUrl']?.toString().isNotEmpty ?? false)
                ? widget.serviceData['imageUrl']
                : null),
        'profileImage':
            ((userData['profileImage']?.toString().isNotEmpty ?? false)
                ? userData['profileImage']
                : null) ??
            serviceDataFromDb['profileImage'] ??
            widget.serviceData['profileImage'],

        // معلومات إضافية
        'creditCard':
            serviceDataFromDb['creditCard'] ??
            widget.serviceData['creditCard'] ??
            widget.serviceData['credit'],
        'accountType': userData['accountType'] ?? 'provider',

        // العناصر
        'items': itemsData,
        'existingItems': existingItems,
        'isRegisteredProvider': isRegisteredProvider,

        // معلومات الطلب
        'submittedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'provider_service_items',
      };

      print('🔄 محاولة حفظ الطلب في provider_requests...');
      print('� الصور في الطلب:');
      print('   - serviceImage: ${requestData['serviceImage']}');
      print('   - serviceImageUrl: ${requestData['serviceImageUrl']}');
      print('   - imageUrl: ${requestData['imageUrl']}');
      print('�📄 بيانات الطلب: $requestData');

      // Save to provider_requests collection (for admin review)
      final docRef = await FirebaseFirestore.instance
          .collection('provider_requests')
          .add(requestData);

      // أيضاً حفظ في admin_requests
      await FirebaseFirestore.instance
          .collection('admin_requests')
          .add(requestData);

      print('✅ تم حفظ الطلب بنجاح! معرف الطلب: ${docRef.id}');

      // احتفاظ بالاسم العربي للخدمة كما هو
      String serviceName =
          widget.serviceData['serviceName']?.toString() ?? 'قاعات اعراس';
      String serviceType =
          widget.serviceData['serviceType']?.toString() ?? 'قاعات اعراس';

      // التأكد من أن serviceType هو النوع العربي الصحيح
      Map<String, String> englishToArabicMapping = {
        'hall': 'قاعات اعراس',
        'hotel': 'فنادق',
        'restaurant': 'مطاعم',
        'cake': 'كيك',
        'car_rental': 'تأجير سيارات',
        'flowers': 'ورود',
        'photography': 'تصوير',
        'salon_care': 'صالونات تجميل',
        'honeymoon': 'شهر عسل',
        'bride_dress': 'فساتين زفاف',
        'groom_suit': 'بدلات رجالية',
        'car': 'تأجير سيارات',
        'car_decoration': 'تزيين السيارات',
        'general': 'خدمات عامة',
      };

      // تحويل من الإنجليزية إلى العربية إذا كان النوع باللغة الإنجليزية
      if (englishToArabicMapping.containsKey(serviceType)) {
        serviceType = englishToArabicMapping[serviceType]!;
        serviceName = serviceType; // استخدام نفس النوع كاسم
      }

      // تحديد مجموعة قاعدة البيانات (للتخزين الداخلي)
      Map<String, String> arabicToCollectionMapping = {
        'قاعات اعراس': 'hall',
        'فنادق': 'hotel',
        'مطاعم': 'restaurant',
        'كيك': 'cake',
        'تأجير سيارات': 'car',
        'ورود': 'flowers',
        'تصوير': 'photography',
        'صالونات تجميل': 'salon_care',
        'شهر عسل': 'honeymoon',
        'فساتين زفاف': 'bride_dress',
        'بدلات رجالية': 'groom_suit',
        'تزيين السيارات': 'car_decoration',
        'خدمات عامة': 'other',
      };

      String collectionName = arabicToCollectionMapping[serviceType] ?? 'hall';

      print('🔍 اسم الخدمة المستلم: $serviceName');
      print('🔍 نوع الخدمة العربي: $serviceType');
      print('🔍 مجموعة قاعدة البيانات: $collectionName');
      print(
        '🔄 إضافة العناصر إلى مجموعة: $collectionName مع serviceType: $serviceType',
      );

      // تحديث requestData بالنوع العربي الصحيح
      await docRef.update({
        'serviceType': serviceType, // الاحتفاظ بالنوع العربي في الطلبات
        'serviceName': serviceName,
      });

      // حفظ العناصر في provider_items مباشرة بحالة "pending"
      for (var itemData in itemsData) {
        final itemWithProvider = {
          ...itemData,
          'providerId': widget.serviceData['providerId'],
          'providerName': widget.serviceData['providerName'],
          'providerPhone': widget.serviceData['providerPhone'],
          'serviceType': serviceType, // استخدام النوع العربي الصحيح
          'serviceName': serviceName, // استخدام الاسم العربي الصحيح
          'category': collectionName, // المجموعة الداخلية
          'area': widget.serviceData['area'],
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending', // العناصر تبدأ كمعلقة حتى يوافق المدير
          'approvedAt': null,
          'approvedBy': null,
        };

        print('💾 حفظ عنصر بـ providerId: ${widget.serviceData['providerId']}');
        print('💾 اسم العنصر: ${itemData['name']}');
        print('💾 نوع الخدمة في العنصر: $serviceType');

        // حفظ في provider_items ليظهر فوراً في حساب المزود
        await FirebaseFirestore.instance
            .collection('provider_items')
            .add(itemWithProvider);
      }

      print(
        '✅ تم إضافة جميع العناصر إلى مجموعة $collectionName مع serviceType: $serviceType',
      );

      // التوجه مباشرة إلى حساب مزود الخدمة المهني
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const ProviderMainProfessional(),
        ),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة العناصر بنجاح وإرسال الطلب للإدارة'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// شاشة إضافة/تعديل عنصر
class AddItemScreen extends StatefulWidget {
  final Map<String, dynamic>? item;
  final Map<String, dynamic> serviceData;

  const AddItemScreen({super.key, this.item, required this.serviceData});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  // دالة للتحقق من نوع الخدمة
  bool _isHallService() {
    final serviceType =
        widget.serviceData['serviceType']?.toString().toLowerCase() ?? '';
    return serviceType.contains('قاعة') ||
        serviceType.contains('قاعات') ||
        serviceType.contains('اعراس') ||
        serviceType.contains('عرس') ||
        serviceType == 'hall';
  }

  List<File> _images = [];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name'] ?? '';
      _detailsController.text = widget.item!['details'] ?? '';
      _priceController.text = widget.item!['price']?.toString() ?? '';
      _capacityController.text = widget.item!['capacity'] ?? '';
      _images = widget.item!['images'] ?? [];
    }
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (images.isNotEmpty) {
        setState(() {
          _images = images.map((image) => File(image.path)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في اختيار الصور: $e')));
    }
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;
    if (_images.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار 3 صور على الأقل')),
      );
      return;
    }

    final itemData = {
      'name': _nameController.text.trim(),
      'details': _detailsController.text.trim(),
      'price': _priceController.text.trim(),
      if (_isHallService()) 'capacity': _capacityController.text.trim(),
      'images': _images,
    };

    Navigator.pop(context, itemData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item != null
                                ? 'تعديل العنصر'
                                : 'إضافة عنصر جديد',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'املأ بيانات العنصر بالتفصيل',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form Container
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // اسم العنصر
                          _buildTextField(
                            controller: _nameController,
                            label: 'اسم العنصر',
                            icon: Icons.label,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال اسم العنصر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // تفاصيل العنصر
                          _buildTextField(
                            controller: _detailsController,
                            label: 'تفاصيل العنصر',
                            icon: Icons.description,
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال تفاصيل العنصر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // سعر العنصر
                          _buildTextField(
                            controller: _priceController,
                            label: 'سعر العنصر (دينار)',
                            icon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال سعر العنصر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // السعة (فقط لقاعات الأعراس)
                          if (_isHallService()) ...[
                            _buildTextField(
                              controller: _capacityController,
                              label: 'السعة أو الكمية',
                              icon: Icons.people,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال السعة أو الكمية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ] else
                            const SizedBox(height: 24),

                          // صور العنصر
                          _buildImagePicker(),
                          const SizedBox(height: 32),

                          // زر الحفظ
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _saveItem,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              icon: const Icon(Icons.save),
                              label: const Text(
                                'حفظ العنصر',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'صور العنصر (3 صور على الأقل)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),

        // Images Grid
        if (_images.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _images.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

        const SizedBox(height: 12),

        // Add Images Button
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _images.length >= 3
                    ? const Color(0xFF10B981)
                    : Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  size: 48,
                  color: _images.length >= 3
                      ? const Color(0xFF10B981)
                      : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  _images.isEmpty ? 'اضغط لاختيار الصور' : 'اضغط لتغيير الصور',
                  style: TextStyle(
                    color: _images.length >= 3
                        ? const Color(0xFF10B981)
                        : Colors.grey,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '(${_images.length}/3 صور كحد أدنى)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }
}
