import 'package:flutter/material.dart';
import '../utils/price_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ItemEditScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemEditScreen({super.key, required this.item});

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['name']);
    _descriptionController = TextEditingController(
      text: widget.item['details'] ?? widget.item['description'] ?? '',
    );
    _priceController = TextEditingController(
      text: PriceFormatter.formatString(widget.item['price']?.toString() ?? ''),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('items')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      return null;
    }
  }

  String? _getItemImageUrl() {
    // البحث عن الصورة في مفاتيح مختلفة
    if (widget.item['imageUrls'] != null &&
        widget.item['imageUrls'] is List &&
        (widget.item['imageUrls'] as List).isNotEmpty) {
      return (widget.item['imageUrls'] as List).first.toString();
    } else if (widget.item['imageUrl'] != null &&
        widget.item['imageUrl'].toString().isNotEmpty) {
      return widget.item['imageUrl'];
    } else if (widget.item['image'] != null &&
        widget.item['image'].toString().isNotEmpty) {
      return widget.item['image'];
    }
    return null;
  }

  Future<void> _updateItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // الحصول على URL الصورة الحالية
      List<String> imageUrls = [];
      if (widget.item['imageUrls'] != null &&
          widget.item['imageUrls'] is List) {
        imageUrls = List<String>.from(widget.item['imageUrls']);
      } else if (widget.item['imageUrl'] != null) {
        imageUrls = [widget.item['imageUrl'].toString()];
      }

      // رفع صورة جديدة إذا تم اختيارها
      if (_selectedImage != null) {
        String? newImageUrl = await _uploadImage();
        if (newImageUrl != null) {
          imageUrls = [newImageUrl]; // استبدال الصورة القديمة
        }
      }

      // تحديد الـ collection الصحيح بناءً على category
      // أولاً: نحاول قراءة category من بيانات العنصر
      String category = widget.item['category']?.toString() ?? '';

      // ثانياً: إذا كان category خاطئ، نحاول قراءته من serviceType أو categoryArabic
      String serviceType = widget.item['serviceType']?.toString() ?? '';
      String categoryArabic = widget.item['categoryArabic']?.toString() ?? '';

      // خريطة لتحويل serviceType العربي إلى category
      Map<String, String> arabicToCategory = {
        'مطعم': 'restaurant',
        'مطاعم': 'restaurant',
        'قاعات اعراس': 'hall',
        'قاعة عرس': 'hall',
        'فنادق': 'hotel',
        'فندق': 'hotel',
        'كيك': 'cake',
        'تأجير سيارات': 'car',
        'سيارات': 'car',
        'ورود': 'flowers',
        'تصوير': 'photography',
        'جلسات تصوير': 'photography',
        'صالونات تجميل': 'salon_care',
        'صالون': 'salon_care',
        'شهر عسل': 'honeymoon',
        'فساتين زفاف': 'bride_dress',
        'فساتين': 'bride_dress',
        'بدلات رجالية': 'groom_suit',
        'بدلات': 'groom_suit',
        'تزيين السيارات': 'car_decoration',
        'تزيين سيارة': 'car_decoration',
      };

      // إذا كان serviceType موجود، استخدمه لتحديد category
      if (arabicToCategory.containsKey(serviceType)) {
        category = arabicToCategory[serviceType]!;
        print('✅ تم تصحيح category من serviceType: $serviceType → $category');
      } else if (arabicToCategory.containsKey(categoryArabic)) {
        category = arabicToCategory[categoryArabic]!;
        print(
          '✅ تم تصحيح category من categoryArabic: $categoryArabic → $category',
        );
      }

      // ignore: unused_local_variable
      String collectionName = 'provider_items'; // افتراضي

      // تحويل category إلى اسم collection
      Map<String, String> categoryToCollection = {
        'hall': 'hall',
        'hotel': 'hotel',
        'cake': 'cake',
        'restaurant': 'restaurant',
        'car': 'car',
        'flowers': 'flowers',
        'photography': 'photography',
        'salon_care': 'salon_care',
        'honeymoon': 'honeymoon',
        'bride_dress': 'bride_dress',
        'groom_suit': 'groom_suit',
        'car_decoration': 'car_decoration',
      };

      String originalCollection = categoryToCollection[category] ?? '';

      print('📝 بدء عملية التحديث:');
      print('   - ID في provider_items: ${widget.item['id']}');
      print('   - ProviderId: ${widget.item['providerId']}');
      print('   - الاسم القديم: ${widget.item['name']}');
      print('   - الاسم الجديد: ${_nameController.text.trim()}');
      print('   - Category: $category');
      print('   - Original Collection: $originalCollection');
      print(
        '   - السعر الجديد: ${PriceFormatter.parseToDouble(_priceController.text)}',
      );

      // البيانات المحدثة
      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'details': _descriptionController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': PriceFormatter.parseToDouble(_priceController.text),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrls.isNotEmpty) {
        updateData['imageUrls'] = imageUrls;
        updateData['imageUrl'] = imageUrls.first;
        print('   - تم تحديث الصور: ${imageUrls.length} صورة');
      }

      print('\n📦 البيانات المحدثة:');
      updateData.forEach((key, value) {
        if (key != 'updatedAt') {
          print('   - $key: $value');
        }
      });

      // تحويل السعر من double إلى int إذا كان عدداً صحيحاً
      final priceDouble = PriceFormatter.parseToDouble(_priceController.text);
      final priceToSave = (priceDouble % 1 == 0)
          ? priceDouble.toInt()
          : priceDouble;
      updateData['price'] = priceToSave;
      print('   - السعر النهائي: $priceToSave (${priceToSave.runtimeType})');

      // تحديث في provider_items (المجموعة الأساسية)
      print('\n🔄 المرحلة 1: التحديث في provider_items');
      await FirebaseFirestore.instance
          .collection('provider_items')
          .doc(widget.item['id'])
          .update(updateData);

      print('✅ تم التحديث في provider_items بنجاح');

      // تحديث في المجموعة الأصلية (التي يقرأ منها العملاء)
      print('\n🔄 المرحلة 2: التحديث في المجموعة الأصلية');
      if (originalCollection.isNotEmpty) {
        try {
          final providerId = widget.item['providerId']?.toString() ?? '';
          final oldItemName = widget.item['name']?.toString() ?? '';

          if (providerId.isNotEmpty && oldItemName.isNotEmpty) {
            print(
              '🔍 البحث في $originalCollection عن providerId=$providerId, name="$oldItemName"',
            );

            // البحث بـ providerId والاسم القديم معاً للتأكد من التطابق الدقيق
            var query = await FirebaseFirestore.instance
                .collection(originalCollection)
                .where('providerId', isEqualTo: providerId)
                .where('name', isEqualTo: oldItemName)
                .get();

            print('📊 وجد ${query.docs.length} مستند(ات) مطابقة');

            if (query.docs.isNotEmpty) {
              // تحديث جميع المستندات المطابقة
              print(
                '✅ تم العثور على ${query.docs.length} مستند - جاري التحديث...',
              );

              for (var doc in query.docs) {
                final docData = doc.data();
                print('   📄 المستند القديم:');
                print('      - ID: ${doc.id}');
                print('      - الاسم: ${docData['name']}');
                print('      - السعر: ${docData['price']}');

                await FirebaseFirestore.instance
                    .collection(originalCollection)
                    .doc(doc.id)
                    .update(updateData);

                // التحقق من التحديث
                final updatedDoc = await FirebaseFirestore.instance
                    .collection(originalCollection)
                    .doc(doc.id)
                    .get();

                print('   ✅ تم التحديث بنجاح:');
                print('      - الاسم الجديد: ${updatedDoc.data()?['name']}');
                print('      - السعر الجديد: ${updatedDoc.data()?['price']}');
              }

              if (query.docs.length > 1) {
                print(
                  '⚠️ تنبيه: تم تحديث ${query.docs.length} عناصر بنفس الاسم',
                );
              }
            } else {
              print(
                '❌ لم يتم العثور على "$oldItemName" في $originalCollection',
              );
              print('   - ProviderId المستخدم في البحث: $providerId');
              print('   - الاسم المستخدم في البحث: "$oldItemName"');
              print('ℹ️ العنصر قد يكون:');
              print('   1. لم تتم الموافقة عليه من الأدمن بعد');
              print('   2. موجود بمجموعة أخرى غير $originalCollection');
              print('   3. الاسم في المجموعة الأصلية مختلف عن provider_items');
            }
          }
        } catch (e) {
          print('⚠️ خطأ في التحديث في $originalCollection: $e');
        }
      }

      // تحديث في published_items إذا كانت موجودة (للعملاء)
      print('\n🔄 المرحلة 3: التحديث في published_items');
      try {
        final providerId = widget.item['providerId']?.toString() ?? '';
        final oldItemName = widget.item['name']?.toString() ?? '';

        if (providerId.isNotEmpty) {
          var publishedQuery = await FirebaseFirestore.instance
              .collection('published_items')
              .where('providerId', isEqualTo: providerId)
              .where('name', isEqualTo: oldItemName)
              .limit(1)
              .get();

          if (publishedQuery.docs.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('published_items')
                .doc(publishedQuery.docs.first.id)
                .update(updateData);

            print('✅ تم التحديث في published_items');
          } else {
            print('ℹ️ العنصر غير موجود في published_items');
          }
        }
      } catch (e) {
        print('⚠️ خطأ في التحديث في published_items: $e');
      }

      print('\n✨ اكتمل التحديث في جميع المجموعات');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ تم تحديث العنصر بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ خطأ في التحديث: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تعديل العنصر'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // صورة العنصر
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : _getItemImageUrl() != null
                    ? DecorationImage(
                        image: NetworkImage(_getItemImageUrl()!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: InkWell(
                onTap: _pickImage,
                child: _selectedImage == null && _getItemImageUrl() == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 50,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text('اضغط لإضافة صورة'),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // اسم العنصر
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم العنصر',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم العنصر';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // الوصف
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال وصف العنصر';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // السعر
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'السعر (دينار عراقي)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال السعر';
                }
                if (double.tryParse(value) == null) {
                  return 'يرجى إدخال رقم صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),

            // زر التحديث
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'تحديث العنصر',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
