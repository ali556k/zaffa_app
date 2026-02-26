import 'package:flutter/material.dart';
import '../widgets/image_viewer.dart';
import '../utils/price_formatter.dart';
import '../utils/map_utils.dart';
import 'booking_screen.dart';

class EnhancedItemDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EnhancedItemDetailsScreen({super.key, required this.item});

  @override
  State<EnhancedItemDetailsScreen> createState() =>
      _EnhancedItemDetailsScreenState();
}

class _EnhancedItemDetailsScreenState extends State<EnhancedItemDetailsScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getItemImages() {
    // إذا كان العنصر يحتوي على صور متعددة
    if (widget.item['images'] != null && widget.item['images'] is List) {
      return List<String>.from(widget.item['images']);
    }
    // إذا كان يحتوي على صورة واحدة فقط
    else if (widget.item['imageUrl'] != null) {
      return [widget.item['imageUrl']];
    }
    // صورة افتراضية إذا لم توجد صور
    return ['https://via.placeholder.com/400x300?text=No+Image'];
  }

  // تحويل أسماء الخدمات العربية إلى الأسماء الإنجليزية
  String _normalizeServiceType(String serviceType) {
    final normalized = serviceType.toLowerCase().trim();

    if (normalized.contains('قاع') || normalized.contains('hall')) {
      return 'hall';
    }
    if (normalized.contains('فند') ||
        normalized.contains('فناد') ||
        normalized.contains('hotel')) {
      return 'hotel';
    }
    if (normalized.contains('صال') ||
        normalized.contains('عناي') ||
        normalized.contains('تجميل') ||
        normalized.contains('مكياج') ||
        normalized.contains('salon') ||
        normalized.contains('care')) {
      return 'salon_care';
    }
    if ((normalized.contains('سيار') ||
            normalized.contains('تأجير') ||
            normalized.contains('تاجير') ||
            normalized.contains('car')) &&
        !normalized.contains('تزيين') &&
        !normalized.contains('decoration')) {
      return 'car';
    }
    if (normalized.contains('تصوير') ||
        normalized.contains('فيديو') ||
        normalized.contains('photo')) {
      return 'photography';
    }
    if (normalized.contains('مطع') || normalized.contains('restaurant')) {
      return 'restaurant';
    }
    if (normalized.contains('فست') || normalized.contains('dress')) {
      return 'bride_dress';
    }
    if (normalized.contains('بدل') || normalized.contains('suit')) {
      return 'groom_suit';
    }
    if (normalized.contains('تزيين') || normalized.contains('decoration')) {
      return 'car_decoration';
    }
    if (normalized.contains('كيك') || normalized.contains('cake')) {
      return 'cake';
    }
    if (normalized.contains('ورد') || normalized.contains('flower')) {
      return 'flowers';
    }
    if (normalized.contains('شهر') || normalized.contains('honey')) {
      return 'honeymoon';
    }

    return serviceType; // إرجاع القيمة الأصلية إذا لم يتم التعرف عليها
  }

  @override
  Widget build(BuildContext context) {
    final images = _getItemImages();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 216, 208, 208),
      appBar: AppBar(
        title: Text(
          widget.item['name'] ?? 'تفاصيل العنصر',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF300606),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معرض الصور مع إمكانية التمرير
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
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
                            imageUrls: images,
                            initialIndex: index,
                          );
                        },
                        child: SizedBox(
                          width: double.infinity,
                          height: 300,
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                    color: const Color(0xFF300606),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  // مؤشر الصور
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: images.asMap().entries.map((entry) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == entry.key
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // أزرار التنقل بين الصور
                  if (images.length > 1) ...[
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: () {
                            if (_currentImageIndex > 0) {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 30,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: () {
                            if (_currentImageIndex < images.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 30,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // معلومات العنصر
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم العنصر
                  Text(
                    widget.item['name'] ?? 'اسم العنصر',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF300606),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // التفاصيل
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'التفاصيل',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF300606),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.item['description'] != null &&
                                  widget.item['location'] != null
                              ? '${widget.item['description']}\nالمكان: ${widget.item['location']}'
                              : 'لا توجد تفاصيل متاحة',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // السعر
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF300606),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.attach_money,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${PriceFormatter.formatString('${widget.item['price'] ?? 'السعر غير محدد'}')} دينار عراقي',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // زر عرض الموقع
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        MapUtils.openMap(widget.item['location'] ?? '');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'عرض الموقع',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // زر تثبيت الحجز
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // التحقق من وجود معرف فريد
                        final itemId =
                            widget.item['itemId'] ?? widget.item['id'];
                        if (itemId == null || itemId.toString().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'خطأ: لا يمكن الحجز. هذا العنصر غير مسجل بشكل صحيح.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // تطبيع نوع الخدمة قبل التمرير
                        final itemData = Map<String, dynamic>.from(widget.item);
                        final rawServiceType =
                            itemData['serviceType'] ??
                            itemData['category'] ??
                            'hall';
                        itemData['serviceType'] = _normalizeServiceType(
                          rawServiceType,
                        );
                        itemData['id'] = itemId
                            .toString(); // تأكيد استخدام المعرف الفريد

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BookingScreen(serviceData: itemData),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF300606),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.book_online, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'تثبيت الحجز',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
}
