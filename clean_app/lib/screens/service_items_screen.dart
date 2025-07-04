import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/service_item.dart';
import '../services/service_item_repository.dart';
import 'booking_screen.dart'; // تأكد من استيراد شاشة الحجز
import 'chat/chat_screen.dart';

class ServiceItemsScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  const ServiceItemsScreen({required this.serviceId, required this.serviceName, super.key});

  @override
  State<ServiceItemsScreen> createState() => _ServiceItemsScreenState();
}

class _ServiceItemsScreenState extends State<ServiceItemsScreen> {
  final ServiceItemRepository _repo = ServiceItemRepository();
  final ImagePicker _picker = ImagePicker();

  void _showItemDialog({ServiceItem? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final locationController = TextEditingController(text: item?.location ?? '');
    final priceController = TextEditingController(text: item?.price.toString() ?? '');
    final capacityController = TextEditingController(text: item?.capacity?.toString() ?? '');
    String? pickedImagePath;
    String? imageUrl = item?.imageUrl;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'إضافة عنصر' : 'تعديل عنصر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'اسم العنصر'),
                ),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(labelText: 'المكان'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'السعر'),
                ),
                if (widget.serviceId == 'hall')
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'عدد الضيوف (السعة)'),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(imageUrl != null ? 'تم اختيار صورة' : 'لم يتم اختيار صورة'),
                    ),
                    IconButton(
                      icon: Icon(Icons.image, color: Colors.pink[400]),
                      tooltip: 'اختيار صورة',
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() {
                            pickedImagePath = image.path;
                            imageUrl = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (pickedImagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Image.file(
                      File(pickedImagePath!),
                      width: 100,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (imageUrl != null && imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Image.network(
                      imageUrl!,
                      width: 100,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text(item == null ? 'إضافة' : 'تعديل'),
              onPressed: () async {
                if (nameController.text.isNotEmpty && locationController.text.isNotEmpty && priceController.text.isNotEmpty) {
                  String finalImageUrl = imageUrl ?? '';
                  if (pickedImagePath != null) {
                    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
                    final ref = FirebaseStorage.instance.ref().child('service_items/${widget.serviceId}/$fileName');
                    await ref.putFile(File(pickedImagePath!));
                    finalImageUrl = await ref.getDownloadURL();
                  }
                  final newItem = ServiceItem(
                    id: item?.id ?? '',
                    name: nameController.text,
                    location: locationController.text,
                    price: double.tryParse(priceController.text) ?? 0,
                    imageUrl: finalImageUrl,
                    capacity: widget.serviceId == 'hall' && capacityController.text.isNotEmpty ? int.tryParse(capacityController.text) : null,
                  );
                  if (item == null) {
                    await _repo.addItem(widget.serviceId, newItem);
                  } else {
                    await _repo.updateItem(widget.serviceId, newItem);
                  }
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('عناصر ${widget.serviceName}')),
      body: Stack(
        children: [
          StreamBuilder<List<ServiceItem>>(
            stream: _repo.getItems(widget.serviceId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Center(child: Text('لا توجد عناصر بعد'));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: item.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(item.imageUrl, width: 60, height: 40, fit: BoxFit.cover),
                            )
                          : Icon(Icons.image, size: 40, color: Colors.grey),
                      title: Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('المكان: ${item.location}\nالسعر: ${item.price}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.amber[800]),
                            onPressed: () => _showItemDialog(item: item),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red[700]),
                            onPressed: () async {
                              await _repo.deleteItem(widget.serviceId, item.id);
                            },
                          ),
                        ],
                      ),
                      // زر تثبيت الحجز
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookingScreen(
                              serviceData: {
                                'id': item.id,
                                'name': item.name,
                                'location': item.location,
                                'price': item.price,
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'chat_vendor',
              backgroundColor: Colors.blueAccent,
              onPressed: () {
                // مثال: افتح شاشة المحادثة مع مزود الخدمة (حدد المنطق المناسب للعنصر أو الخدمة)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: 'user-vendor-${widget.serviceId}', // يمكنك تخصيص chatId حسب الخدمة أو العنصر
                      currentUserId: '', // ضع هنا uid أو رقم الهاتف للمستخدم الحالي
                    ),
                  ),
                );
              },
              child: Icon(Icons.chat),
              tooltip: 'تواصل مع مزود الخدمة',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(),
        tooltip: 'إضافة عنصر',
        child: Icon(Icons.add),
      ),
    );
  }
}
