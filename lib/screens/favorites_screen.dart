import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/favorite_model.dart';
import '../services/favorite_service.dart';
import 'item_details_screen.dart';
import '../utils/image_utils.dart';

/// شاشة عرض المفضلات
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String? userId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('user_phone');

      setState(() {
        userId = storedUserId;
        isLoading = false;
      });

      if (storedUserId != null) {
        print('تم تحميل معرف المستخدم للمفضلات: $storedUserId');
      }
    } catch (e) {
      print('خطأ في تحميل معرف المستخدم: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('المفضلات'),
          backgroundColor: const Color(0xFF8B0000),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B0000)),
        ),
      );
    }

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('المفضلات'),
          backgroundColor: const Color(0xFF8B0000),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'يرجى تسجيل الدخول',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المفضلات'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmClearAll(context, userId!),
            tooltip: 'حذف الكل',
          ),
        ],
      ),
      body: StreamBuilder<List<FavoriteModel>>(
        stream: FavoriteService().getCustomerFavorites(userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B0000)),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 100,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'لا توجد مفضلات بعد',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ابدأ بإضافة خدماتك المفضلة',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              return _buildFavoriteCard(context, favorites[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, FavoriteModel favorite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          // جلب بيانات العنصر الكاملة وفتح صفحة التفاصيل
          try {
            // محاولة البحث في published_items
            final itemDoc = await FirebaseFirestore.instance
                .collection('published_items')
                .doc(favorite.itemId)
                .get();

            if (itemDoc.exists && context.mounted) {
              final itemData = itemDoc.data()!;
              itemData['itemId'] = favorite.itemId;
              itemData['id'] = favorite.itemId;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemDetailsScreen(
                    item: itemData,
                    providerName: favorite.providerName,
                  ),
                ),
              );
            } else {
              // إذا لم يوجد في published_items، نبحث في مجموعات الخدمات
              final serviceTypes = [
                'hall',
                'hotel',
                'cake',
                'restaurant',
                'bride_dress',
                'salon_care',
                'flowers',
                'groom_suit',
                'car',
                'car_decoration',
                'honeymoon',
              ];

              bool found = false;
              for (String serviceType in serviceTypes) {
                final serviceDoc = await FirebaseFirestore.instance
                    .collection('services')
                    .doc(serviceType)
                    .collection('items')
                    .doc(favorite.itemId)
                    .get();

                if (serviceDoc.exists && context.mounted) {
                  final itemData = serviceDoc.data()!;
                  itemData['itemId'] = favorite.itemId;
                  itemData['id'] = favorite.itemId;
                  itemData['category'] = serviceType;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemDetailsScreen(
                        item: itemData,
                        providerName: favorite.providerName,
                      ),
                    ),
                  );
                  found = true;
                  break;
                }
              }

              if (!found && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لم يتم العثور على تفاصيل العنصر'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطأ: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // صورة الخدمة
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: favorite.imageUrl != null
                    ? RepaintBoundary(
                        child: ImageUtils.buildCachedImage(
                          imageUrl: favorite.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image, color: Colors.grey.shade400),
                      ),
              ),

              const SizedBox(width: 16),

              // معلومات الخدمة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.itemName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      favorite.providerName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B0000).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${favorite.price} د.ع',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B0000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // زر الحذف
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _confirmRemove(context, favorite),
                tooltip: 'إزالة من المفضلات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    FavoriteModel favorite,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة من المفضلات'),
        content: Text('هل تريد إزالة "${favorite.itemName}" من المفضلات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FavoriteService().removeFromFavorites(
            customerId: user.uid,
            itemId: favorite.itemId,
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تمت الإزالة من المفضلات'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmClearAll(BuildContext context, String customerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف جميع المفضلات'),
        content: const Text(
          'هل أنت متأكد من حذف جميع المفضلات؟\nلا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FavoriteService().clearAllFavorites(customerId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف جميع المفضلات'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
