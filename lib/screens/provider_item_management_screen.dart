import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../widgets/provider_calendar_management.dart';
import '../widgets/availability_toggle.dart';

/// شاشة إدارة العنصر للمزود (تقويم أو توفر حسب نوع الخدمة)
class ProviderItemManagementScreen extends StatelessWidget {
  final String itemId;
  final String itemName;
  final String providerId;
  final String category;

  const ProviderItemManagementScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.providerId,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isBookableService = bookableCategories.contains(category);

    if (isBookableService) {
      // عرض تقويم إدارة الحجوزات للخدمات القابلة للحجز
      return ProviderCalendarManagement(providerId: providerId, itemId: itemId);
    } else {
      // عرض إدارة التوفر للخدمات غير القابلة للحجز
      return Scaffold(
        appBar: AppBar(
          title: Text(itemName),
          backgroundColor: const Color(0xFF6E1229),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // معلومات الخدمة
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            color: const Color(0xFF8B0000),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getCategoryLabel(category),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // لوحة إدارة التوفر
              AvailabilityManagementPanel(
                itemId: itemId,
                category: category,
                onAvailabilityChanged: () {
                  // يمكن إضافة إجراءات إضافية هنا إذا لزم الأمر
                },
              ),

              const SizedBox(height: 24),

              // معلومات إضافية
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amber,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'نصيحة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'هذه_الخدمة_غير_قابلة_للحجز',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber.shade900,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'سيرى العملاء حالة "متوفر" أو "غير متوفر" عند عرض تفاصيل الخدمة.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'restaurant':
        return Icons.restaurant;
      case 'bride_dress':
        return Icons.checkroom;
      case 'groom_suit':
        return Icons.person;
      case 'car_decoration':
        return Icons.car_rental;
      case 'cake':
        return Icons.cake;
      case 'flowers':
        return Icons.local_florist;
      case 'photography':
        return Icons.camera_alt;
      case 'honeymoon':
        return Icons.flight;
      default:
        return Icons.category;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'restaurant':
        return 'خدمة طعام';
      case 'bride_dress':
        return 'فستان العروس';
      case 'groom_suit':
        return 'بدلة العريس';
      case 'car_decoration':
        return 'تزيين السيارات';
      case 'cake':
        return 'كيك الزفاف';
      case 'flowers':
        return 'الورود والزينة';
      case 'photography':
        return 'التصوير الفوتوغرافي';
      case 'honeymoon':
        return 'شهر العسل والسياحة';
      default:
        return 'خدمة أخرى';
    }
  }
}
