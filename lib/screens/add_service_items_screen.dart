import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddServiceItemsScreen extends StatefulWidget {
  final Map<String, dynamic> providerData;
  const AddServiceItemsScreen({super.key, required this.providerData});

  @override
  State<AddServiceItemsScreen> createState() => _AddServiceItemsScreenState();
}

class _AddServiceItemsScreenState extends State<AddServiceItemsScreen> {
  List<Map<String, dynamic>> items = [];
  // لتتبع الصور المختارة مؤقتاً وحذفها عند الحاجة
  final List<XFile> _tempPickedImages = [];

  @override
  void dispose() {
    // تحرير الذاكرة المؤقتة لجميع الصور المختارة
    for (var image in _tempPickedImages) {
      try {
        File(image.path).delete();
      } catch (e) {
        // تجاهل الخطأ إذا كان الملف محذوف بالفعل
      }
    }
    super.dispose();
  }

  void _addItem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemDialog(
          onItemAdded: (item) {
            setState(() {
              items.add(item);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('item added'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isLoading = false;

  void _submit() async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة عنصر واحد على الأقل')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      print('بدء رفع البيانات...');
      print('عدد العناصر: ${items.length}');

      // رفع الصور وحفظ البيانات
      final List<Map<String, dynamic>> itemsToSave = [];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        print('معالجة العنصر $i: ${item['name']}');

        // رفع الصور للـ Firebase Storage
        final List<String> imageUrls = [];
        final List<XFile> images = item['images'] as List<XFile>;

        for (int j = 0; j < images.length; j++) {
          try {
            final imageFile = File(images[j].path);
            final fileName =
                'provider_items/${DateTime.now().millisecondsSinceEpoch}_$j.jpg';
            final ref = FirebaseStorage.instance.ref().child(fileName);

            print('رفع الصورة $j للعنصر $i...');
            final uploadTask = await ref.putFile(imageFile);
            final downloadUrl = await uploadTask.ref.getDownloadURL();
            imageUrls.add(downloadUrl);
            print('تم رفع الصورة $j بنجاح: $downloadUrl');
          } catch (e) {
            print('فشل رفع الصورة $j للعنصر $i: $e');
            // المتابعة بدون هذه الصورة
          }
        }

        itemsToSave.add({
          'name': item['name'],
          'price': item['price'] ?? 'غير محدد',
          'details': item['details'],
          'imageUrls': imageUrls,
        });
        print('تم معالجة العنصر $i بنجاح');
      }

      print('حفظ البيانات في Firestore...');
      print('بيانات المزود: ${widget.providerData}');
      print('الاسم: ${widget.providerData['name']}');
      print('المحافظة: ${widget.providerData['governorate']}');
      print('المنطقة: ${widget.providerData['area']}');
      print('البطاقة الائتمانية: ${widget.providerData['credit']}');
      print('نوع الخدمة: ${widget.providerData['serviceType']}');

      // التأكد من أن serviceType هو النوع العربي الصحيح
      String serviceType = widget.providerData['serviceType'] ?? 'قاعات اعراس';
      String serviceName = widget.providerData['serviceName'] ?? serviceType;

      // تحويل من الإنجليزية إلى العربية إذا لزم الأمر
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

      if (englishToArabicMapping.containsKey(serviceType)) {
        serviceType = englishToArabicMapping[serviceType]!;
        serviceName = serviceType;
      }

      print('نوع الخدمة النهائي: $serviceType');

      // استخراج الموقع بشكل صحيح
      dynamic locationData = widget.providerData['location'];
      double? latitude;
      double? longitude;

      if (locationData != null) {
        if (locationData is GeoPoint) {
          latitude = locationData.latitude;
          longitude = locationData.longitude;
        } else if (locationData is Map) {
          latitude = locationData['latitude'];
          longitude = locationData['longitude'];
        }
      }

      // الحصول على providerId
      final providerId =
          widget.providerData['providerId'] ?? widget.providerData['phone'];

      // جلب العناصر القديمة من provider_services إذا كان المزود مسجلاً
      List<dynamic> existingItems = [];
      bool isRegisteredProvider = false;

      // جلب serviceImage من published_providers إذا كان المزود مسجلاً
      String? serviceImageFromPublished;
      String? serviceImageUrlFromPublished;

      try {
        final providerServicesDoc = await FirebaseFirestore.instance
            .collection('provider_services')
            .doc(providerId)
            .get();

        if (providerServicesDoc.exists) {
          final data = providerServicesDoc.data();
          existingItems = data?['items'] ?? [];
        }

        // التحقق من وجود بيانات في published_providers لتحديد إذا كان مزود مسجل
        final publishedDoc = await FirebaseFirestore.instance
            .collection('published_providers')
            .doc(providerId)
            .get();

        isRegisteredProvider = publishedDoc.exists;

        // جلب serviceImage من published_providers للحفاظ عليها
        if (isRegisteredProvider && publishedDoc.exists) {
          final publishedData = publishedDoc.data();
          serviceImageFromPublished = publishedData?['serviceImage'];
          serviceImageUrlFromPublished = publishedData?['serviceImageUrl'];
          print(
            '🖼️ تم جلب serviceImage من published_providers: $serviceImageFromPublished',
          );
        }
      } catch (e) {
        print('خطأ في جلب العناصر القديمة: $e');
      }

      print('📦 عدد العناصر القديمة: ${existingItems.length}');
      print('📦 عدد العناصر الجديدة: ${itemsToSave.length}');
      print('✅ مزود مسجل: $isRegisteredProvider');

      // إعداد بيانات الطلب الكاملة
      final requestData = {
        // معلومات المستخدم
        'userName':
            widget.providerData['userName'] ??
            widget.providerData['name'] ??
            'غير محدد',
        'name':
            widget.providerData['serviceName'] ??
            widget.providerData['name'] ??
            'غير محدد',
        'serviceName': serviceName,
        'phone': widget.providerData['phone'] ?? 'غير محدد',
        'userPhone':
            widget.providerData['userPhone'] ??
            widget.providerData['phone'] ??
            'غير محدد',
        'governorate':
            widget.providerData['governorate'] ??
            widget.providerData['userGovernorate'] ??
            'غير محدد',
        'userGovernorate':
            widget.providerData['userGovernorate'] ??
            widget.providerData['governorate'] ??
            'غير محدد',
        'area':
            widget.providerData['area'] ??
            widget.providerData['userArea'] ??
            'غير محدد',
        'userArea':
            widget.providerData['userArea'] ??
            widget.providerData['area'] ??
            'غير محدد',
        'creditCard':
            widget.providerData['creditCard'] ??
            widget.providerData['credit'] ??
            'غير محدد',

        // معلومات الموقع
        'location': locationData,
        'latitude': latitude,
        'longitude': longitude,

        // معلومات الخدمة
        'serviceType': serviceType,
        'services': [serviceType],
        'serviceImage':
            serviceImageFromPublished ?? // أولاً من published_providers
            widget.providerData['serviceImage'] ??
            widget.providerData['serviceImageUrl'] ??
            widget.providerData['imageUrl'],
        'serviceImageUrl':
            serviceImageUrlFromPublished ?? // أولاً من published_providers
            widget.providerData['serviceImageUrl'] ??
            widget.providerData['serviceImage'] ??
            widget.providerData['imageUrl'],
        'imageUrl':
            widget.providerData['imageUrl'] ??
            widget.providerData['serviceImage'],
        'profileImage':
            widget.providerData['profileImage'] ??
            widget.providerData['serviceImage'],

        // معلومات المزود
        'providerId': providerId,
        'providerPhone':
            widget.providerData['providerPhone'] ??
            widget.providerData['phone'],
        'providerName':
            widget.providerData['providerName'] ?? widget.providerData['phone'],

        // العناصر
        'items': itemsToSave, // العناصر الجديدة
        'existingItems': existingItems, // العناصر القديمة
        'isRegisteredProvider': isRegisteredProvider, // علامة المزود المسجل
        // معلومات إضافية
        'accountType': widget.providerData['accountType'] ?? 'provider',
        'createdAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'hasImages': items.any((item) => item['images'].isNotEmpty),
      };

      // حفظ الطلب في Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('provider_requests')
          .add(requestData);

      // أيضاً حفظ في admin_requests
      await FirebaseFirestore.instance
          .collection('admin_requests')
          .add(requestData);

      print('تم حفظ البيانات بنجاح. معرف الوثيقة: ${docRef.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم إرسال الطلب بنجاح! (الصور ستُرفع لاحقاً)'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('خطأ في إرسال الطلب: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text('حدث خطأ أثناء إرسال الطلب!'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'التفاصيل: ${e.toString()}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إضافة عناصر الخدمة',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'لم يتم إضافة أي عنصر بعد',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF90A4AE),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading:
                                    item['images'] != null &&
                                        item['images'].isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(item['images'][0].path),
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  width: 54,
                                                  height: 54,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  child: const Icon(
                                                    Icons.image,
                                                    size: 30,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                        ),
                                      )
                                    : Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: Colors.grey.shade300,
                                        ),
                                        child: const Icon(
                                          Icons.image,
                                          size: 30,
                                          color: Colors.grey,
                                        ),
                                      ),
                                title: Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item['price'] != null)
                                      Text(
                                        'السعر: ${item['price']}',
                                        style: const TextStyle(
                                          color: Color(0xFF4CAF50),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Text(
                                      item['details'],
                                      style: const TextStyle(
                                        color: Color(0xFF607D8B),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      // حذف الصور المؤقتة
                                      if (item['images'] != null) {
                                        for (var img in item['images']) {
                                          try {
                                            File(img.path).delete();
                                          } catch (e) {}
                                        }
                                      }
                                      items.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة عنصر جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: _addItem,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.send),
                        label: Text('send request'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: items.isNotEmpty && !_isLoading
                            ? _submit
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
              ),
            ),
        ],
      ),
    );
  }
}

class AddItemDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onItemAdded;

  const AddItemDialog({super.key, required this.onItemAdded});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _picker = ImagePicker();
  List<XFile> _pickedImages = [];

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عنصر جديد'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم العنصر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'تفاصيل العنصر',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.camera_alt),
                label: Text('اختيار صور (${_pickedImages.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_pickedImages.isNotEmpty) ...[
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _pickedImages.length,
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_pickedImages[index].path),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text('لم يتم اختيار صور بعد')),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _addItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'إضافة العنصر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 100);
      if (images.isNotEmpty) {
        setState(() {
          _pickedImages = images.take(5).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في اختيار الصور: $e')));
      }
    }
  }

  void _addItem() {
    if (_nameController.text.trim().isEmpty ||
        _detailsController.text.trim().isEmpty ||
        _pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول واختيار صورة واحدة على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final item = {
      'name': _nameController.text.trim(),
      'price':
          'يحدد لاحقاً', // قيمة افتراضية لأن السعر لن يتم إدخاله في هذه المرحلة
      'details': _detailsController.text.trim(),
      'images': List<XFile>.from(_pickedImages),
    };

    widget.onItemAdded(item);
    Navigator.pop(context);
  }
}
