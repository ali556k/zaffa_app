import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';
import '../screens/ratings_screen.dart';

/// عنصر واجهة لعرض تقييمات خدمة معينة
class ItemRatingsWidget extends StatelessWidget {
  final String itemId;
  final String providerId;
  final String? providerName;

  const ItemRatingsWidget({
    super.key,
    required this.itemId,
    required this.providerId,
    this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    final ratingService = RatingService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان القسم مع إحصائيات سريعة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFC107),
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'التقييمات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              FutureBuilder<ProviderRatingStats>(
                future: ratingService.getProviderRatingStats(providerId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final stats = snapshot.data!;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B0000).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stats.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B0000),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${stats.totalRatings})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // قائمة التقييمات
        StreamBuilder<List<RatingModel>>(
          stream: ratingService.getItemRatings(itemId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFF8B0000)),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'خطأ في تحميل التقييمات: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final ratings = snapshot.data ?? [];

            if (ratings.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 60,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد تقييمات بعد',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'كن أول من يقيّم هذه الخدمة',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            // عرض أول 3 تقييمات فقط
            final displayRatings = ratings.take(3).toList();

            return Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayRatings.length,
                  itemBuilder: (context, index) {
                    return _buildRatingCard(displayRatings[index]);
                  },
                ),

                // زر عرض جميع التقييمات إذا كان هناك أكثر من 3
                if (ratings.length > 3)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RatingsScreen(
                              providerId: providerId,
                              providerName: providerName ?? 'المزود',
                              isOwner: false,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text('عرض جميع التقييمات (${ratings.length})'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B0000),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRatingCard(RatingModel rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات العميل والنجوم
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF8B0000).withOpacity(0.1),
                  child: Text(
                    rating.customerName.isNotEmpty
                        ? rating.customerName[0].toUpperCase()
                        : '؟',
                    style: const TextStyle(
                      color: Color(0xFF8B0000),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.customerName.isEmpty ? 'زبون' : rating.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy', 'ar').format(rating.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFFFC107),
                      size: 18,
                    );
                  }),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // التعليق
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rating.comment,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF2D3748),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
