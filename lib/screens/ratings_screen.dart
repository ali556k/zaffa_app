import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';

/// شاشة عرض التقييمات
class RatingsScreen extends StatelessWidget {
  final String providerId;
  final String providerName;
  final bool isOwner; // هل المستخدم هو المالك؟

  const RatingsScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratingService = RatingService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقييمات'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<RatingModel>>(
        stream: ratingService.getProviderRatings(providerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B0000)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('خطأ: ${snapshot.error}'),
            );
          }

          final ratings = snapshot.data ?? [];

          return Column(
            children: [
              // إحصائيات التقييم
              FutureBuilder<ProviderRatingStats>(
                future: ratingService.getProviderRatingStats(providerId),
                builder: (context, statsSnapshot) {
                  if (!statsSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final stats = statsSnapshot.data!;

                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B0000), Color(0xFFB46A6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B0000).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // متوسط التقييم
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    stats.averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (index) {
                                      return Icon(
                                        index < stats.averageRating.round()
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: Colors.amber,
                                        size: 24,
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${stats.totalRatings} تقييم',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // توزيع التقييمات
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [5, 4, 3, 2, 1].map((star) {
                                  final count = stats.ratingDistribution[star] ?? 0;
                                  final percentage = stats.totalRatings > 0
                                      ? (count / stats.totalRatings)
                                      : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          child: Text(
                                            '$star',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: percentage,
                                              backgroundColor: Colors.white24,
                                              valueColor: const AlwaysStoppedAnimation<Color>(
                                                Colors.amber,
                                              ),
                                              minHeight: 8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 30,
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // قائمة التقييمات
              Expanded(
                child: ratings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star_outline,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد تقييمات بعد',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: ratings.length,
                        itemBuilder: (context, index) {
                          return _buildRatingCard(context, ratings[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingCard(BuildContext context, RatingModel rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الزبون والتقييم
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF8B0000).withOpacity(0.1),
                  child: Text(
                    rating.customerName.isNotEmpty
                        ? rating.customerName[0].toUpperCase()
                        : '؟',
                    style: const TextStyle(
                      color: Color(0xFF8B0000),
                      fontWeight: FontWeight.bold,
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
                          fontSize: 16,
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
                      size: 20,
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
                ),
                textAlign: TextAlign.right,
              ),
            ),

            // أزرار المالك
            if (isOwner) ...[
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleVisibility(context, rating),
                    icon: Icon(
                      rating.isVisible ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(rating.isVisible ? 'إخفاء' : 'إظهار'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteRating(context, rating),
                    icon: Icon(Icons.delete, size: 18),
                    label: Text('delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVisibility(BuildContext context, RatingModel rating) async {
    try {
      await RatingService().toggleRatingVisibility(rating.id!, !rating.isVisible);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ${rating.isVisible ? 'إخفاء' : 'إظهار'} التقييم'),
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

  Future<void> _deleteRating(BuildContext context, RatingModel rating) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: const Text('هل أنت متأكد من حذف هذا التقييم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RatingService().deleteRating(rating.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف التقييم بنجاح'),
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
