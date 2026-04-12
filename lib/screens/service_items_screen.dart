import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/service_item.dart';
import '../models/booking_model.dart';
import '../services/service_item_repository.dart';
import 'service_item_details_screen.dart';
import 'enhanced_item_details_screen.dart';
import 'booking_screen.dart';
import 'chat_room_screen.dart';
import '../utils/chat_utils.dart';
import '../utils/image_utils.dart';

class ServiceItemsScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  const ServiceItemsScreen({
    required this.serviceId,
    required this.serviceName,
    super.key,
  });

  @override
  State<ServiceItemsScreen> createState() => _ServiceItemsScreenState();
}

class _ServiceItemsScreenState extends State<ServiceItemsScreen> {
  final ServiceItemRepository _repo = ServiceItemRepository();
  final ImagePicker _picker = ImagePicker();

  void _showItemDialog({ServiceItem? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final locationController = TextEditingController(
      text: item?.location ?? '',
    );
    final detailsController = TextEditingController(text: item?.details ?? '');
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '',
    );
    final capacityController = TextEditingController(
      text: item?.capacity?.toString() ?? '',
    );
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
                  controller: detailsController,
                  decoration: InputDecoration(labelText: 'التفاصيل'),
                  maxLines: 3,
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'السعر (د.ع)'),
                ),
                if (widget.serviceId == 'hall')
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'عدد الضيوف (السعة)',
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        imageUrl != null
                            ? 'تم اختيار صورة'
                            : 'لم يتم اختيار صورة',
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.image, color: Colors.pink[400]),
                      tooltip: 'اختيار صورة',
                      onPressed: () async {
                        try {
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                            maxWidth: 1024,
                            maxHeight: 1024,
                          );
                          if (image != null) {
                            setState(() {
                              pickedImagePath = image.path;
                              imageUrl = null;
                            });
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ في اختيار الصورة: $e')),
                          );
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
              child: Text('cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text(item == null ? 'إضافة' : 'تعديل'),
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    locationController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  String finalImageUrl = imageUrl ?? '';
                  if (pickedImagePath != null) {
                    final fileName = DateTime.now().millisecondsSinceEpoch
                        .toString();
                    final ref = FirebaseStorage.instance.ref().child(
                      'service_items/${widget.serviceId}/$fileName',
                    );
                    await ref.putFile(File(pickedImagePath!));
                    finalImageUrl = await ref.getDownloadURL();
                  }
                  final newItem = ServiceItem(
                    id: item?.id ?? '',
                    name: nameController.text,
                    location: locationController.text,
                    details: detailsController.text,
                    price: double.tryParse(priceController.text) ?? 0,
                    imageUrl: finalImageUrl,
                    capacity:
                        widget.serviceId == 'hall' &&
                            capacityController.text.isNotEmpty
                        ? int.tryParse(capacityController.text)
                        : null,
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
      appBar: AppBar(
        title: Text(
          'عناصر ${widget.serviceName}',
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
      backgroundColor: const Color(0xFFF5F7FA),
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
                padding: const EdgeInsets.only(bottom: 90, top: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final images = ImageUtils.getImages({
                    'imageUrl': item.imageUrl,
                  });
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListTile(
                      leading: images.isNotEmpty && images[0].isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                images[0],
                                width: 60,
                                height: 44,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: const Color(0xFFE3EAF2),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF1E88E5),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: const Color(0xFFE3EAF2),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                              ),
                            )
                          : const Icon(
                              Icons.image,
                              size: 40,
                              color: Color(0xFF90A4AE),
                            ),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      trailing: FutureBuilder<SharedPreferences>(
                        future: SharedPreferences.getInstance(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return SizedBox.shrink();
                          final prefs = snapshot.data!;
                          final accountType =
                              prefs.getString('account_type') ?? '';

                          // إظهار أزرار التعديل والحذف للمزود فقط (وليس للزبائن)
                          // التحقق من أن المستخدم هو مزود خدمة
                          if (accountType == 'provider') {
                            // Check if this service has booking calendar
                            final hasBookingCalendar = isBookableCategory(
                              widget.serviceId,
                            );

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Show calendar button only for bookable services
                                if (hasBookingCalendar)
                                  IconButton(
                                    icon: Icon(
                                      Icons.calendar_month,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'تقويم الحجوزات',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ServiceItemCalendarScreen(
                                                itemId: item.id,
                                                itemName: item.name,
                                                isEditable: true,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showItemDialog(item: item),
                                  tooltip: 'تعديل',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('confirm_delete'),
                                        content: Text(
                                          'هل أنت متأكد من حذف "${item.name}"؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text('cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(
                                              'حذف',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _repo.deleteItem(
                                        widget.serviceId,
                                        item.id,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تم حذف العنصر بنجاح',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  tooltip: 'حذف',
                                ),
                              ],
                            );
                          } else {
                            // زر تثبيت الحجز للمستخدمين العاديين
                            return ElevatedButton.icon(
                              icon: Icon(Icons.event_available, size: 16),
                              label: Text(
                                'حجز',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF300606),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingScreen(
                                      serviceData: {
                                        'id': item.id,
                                        'name': item.name,
                                        'providerId': item.providerId,
                                        'providerPhone': item
                                            .providerId, // سيكون نفس providerId لأنه رقم الهاتف
                                        'price': item.price,
                                        'serviceType': widget.serviceId,
                                        'category': widget.serviceId,
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
                      onTap: () {
                        // الخدمات التي تستخدم الشاشة المحسّنة
                        final enhancedServices = [
                          'restaurant',
                          'restaurant_main_dishes',
                          'restaurant_appetizers',
                          'restaurant_desserts',
                          'restaurant_beverages',
                          'restaurant_salads',
                          'groom_suit',
                          'groom_suit_formal_suits',
                          'groom_suit_casual_suits',
                          'groom_suit_traditional_suits',
                          'groom_suit_accessories',
                          'bride_dress',
                          'bride_dress_wedding_dresses',
                          'bride_dress_engagement_dresses',
                          'bride_dress_reception_dresses',
                          'bride_dress_shoes_accessories',
                          'cake',
                          'cake_wedding_cakes',
                          'cake_engagement_cakes',
                          'cake_mini_cakes',
                          'cake_cupcakes',
                          'flowers',
                          'flowers_bridal_bouquets',
                          'flowers_venue_decoration',
                          'flowers_car_decoration',
                          'flowers_table_centerpieces',
                          'car',
                          'car_luxury_cars',
                          'car_classic_cars',
                          'car_sports_cars',
                          'car_limousines',
                          'car_decoration',
                          'car_decoration_external_decoration',
                          'car_decoration_internal_decoration',
                          'car_decoration_flower_decoration',
                          'car_decoration_ribbon_decoration',
                        ];

                        if (enhancedServices.contains(widget.serviceId)) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EnhancedItemDetailsScreen(
                                item: {
                                  'id': item.id,
                                  'name': item.name,
                                  'description': item.details,
                                  'location': item.location,
                                  'price': item.price,
                                  'imageUrl': item.imageUrl,
                                  'serviceType': widget.serviceId,
                                  'category': widget.serviceId,
                                },
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ServiceItemDetailsScreen(
                                name: item.name,
                                images: [item.imageUrl],
                                details: item.details,
                                location: item.location,
                                price: item.price,
                              ),
                            ),
                          );
                        }
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
              onPressed: () async {
                // الحصول على معرف المستخدم الحالي
                final prefs = await SharedPreferences.getInstance();
                final currentUserId = prefs.getString('user_phone') ?? '';

                if (currentUserId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
                  );
                  return;
                }

                // إنشاء chatId فريد بين المستخدم ومزود الخدمة
                final vendorId = '07721874360'; // رقم المالك/مزود الخدمة
                final chatId = ChatUtils.createChatId(currentUserId, vendorId);

                print('Current User ID: $currentUserId');
                print('Vendor ID: $vendorId');
                print('Generated Chat ID: $chatId');

                // إنشاء أو تحديث وثيقة المحادثة
                final chatDoc = FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId);
                final chatSnapshot = await chatDoc.get();

                if (!chatSnapshot.exists) {
                  await chatDoc.set({
                    'participants': [currentUserId, vendorId],
                    'lastMessage': '',
                    'lastTime': FieldValue.serverTimestamp(),
                    'type': 'user_vendor',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  print('تم إنشاء محادثة جديدة');
                } else {
                  print('المحادثة موجودة بالفعل');
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      chatId: chatId,
                      currentUserId: currentUserId,
                      otherUserId: vendorId,
                      otherUserName: 'مزود الخدمة',
                    ),
                  ),
                );
              },
              tooltip: 'تواصل مع مزود الخدمة',
              child: Icon(Icons.chat),
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return SizedBox.shrink();
          final prefs = snapshot.data!;
          final accountType = prefs.getString('account_type') ?? '';
          // إظهار زر الإضافة للمزود فقط (وليس للزبائن)
          if (accountType == 'provider') {
            return FloatingActionButton(
              onPressed: () => _showItemDialog(),
              tooltip: 'إضافة عنصر',
              child: Icon(Icons.add),
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }
}

class ServiceItemCalendarScreen extends StatefulWidget {
  final String itemId;
  final String itemName;
  final bool isEditable;
  const ServiceItemCalendarScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    this.isEditable = true,
  });
  @override
  State<ServiceItemCalendarScreen> createState() =>
      _ServiceItemCalendarScreenState();
}

class _ServiceItemCalendarScreenState extends State<ServiceItemCalendarScreen> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  List<String> bookedDates = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
  }

  Future<void> _loadBookedDates() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('service_items')
          .doc(widget.itemId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        bookedDates = List<String>.from(data['bookedDates'] ?? []);
      }
    } catch (e) {
      print('Error loading booked dates: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  bool isDateBooked(DateTime date) {
    String dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return bookedDates.any((booking) => booking.startsWith(dateString));
  }

  List<String> getBookingsForDate(DateTime date) {
    String dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return bookedDates
        .where((booking) => booking.startsWith(dateString))
        .toList();
  }

  Future<void> toggleDateBooking(DateTime date) async {
    if (!widget.isEditable) return;
    String dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    List<String> existingBookings = getBookingsForDate(date);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إدارة حجوزات ${date.day}/${date.month}/${date.year}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existingBookings.isNotEmpty) ...[
                Text(
                  'الحجوزات الحالية:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...existingBookings.map((booking) {
                  String time = booking.contains('T')
                      ? booking.split('T')[1]
                      : 'طوال اليوم';
                  return Card(
                    child: ListTile(
                      title: Text(time),
                      trailing: widget.isEditable
                          ? IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _removeBooking(booking);
                              },
                            )
                          : null,
                    ),
                  );
                }),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 16),
              ],
              if (widget.isEditable) ...[
                Text(
                  'إضافة حجز جديد:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: widget.isEditable
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _addFullDayBooking(dateString);
                  },
                  child: Text('حجز طوال اليوم'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showTimePickerDialog(dateString);
                  },
                  child: Text('حجز وقت محدد'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('close'),
                ),
              ],
      ),
    );
  }

  Future<void> _addFullDayBooking(String dateString) async {
    try {
      setState(() {
        isLoading = true;
      });
      bookedDates.add(dateString);
      await FirebaseFirestore.instance
          .collection('service_items')
          .doc(widget.itemId)
          .update({'bookedDates': bookedDates});
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة الحجز'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _removeBooking(String booking) async {
    try {
      setState(() {
        isLoading = true;
      });
      bookedDates.remove(booking);
      await FirebaseFirestore.instance
          .collection('service_items')
          .doc(widget.itemId)
          .update({'bookedDates': bookedDates});
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إلغاء الحجز'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _showTimePickerDialog(String dateString) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      String timeStr = picked.format(context);
      String booking = "$dateString T$timeStr";
      setState(() {
        isLoading = true;
      });
      bookedDates.add(booking);
      await FirebaseFirestore.instance
          .collection('service_items')
          .doc(widget.itemId)
          .update({'bookedDates': bookedDates});
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة الحجز للوقت المحدد'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تقويم ${widget.itemName}')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : TableCalendar<String>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              eventLoader: (day) => isDateBooked(day) ? ['booked'] : [],
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        width: 8,
                        height: 8,
                      ),
                    );
                  }
                  return null;
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  this.selectedDay = selectedDay;
                  this.focusedDay = focusedDay;
                });
                toggleDateBooking(selectedDay);
              },
              onPageChanged: (focusedDay) {
                this.focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: Colors.blue[400],
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFB46A6A),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
    );
  }
}
