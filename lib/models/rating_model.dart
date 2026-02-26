import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج التقييم
class RatingModel {
  final String? id;
  final String bookingId;        // معرف الحجز
  final String itemId;           // معرف العنصر
  final String providerId;       // معرف المزود
  final String customerId;       // معرف الزبون
  final String customerName;     // اسم الزبون
  final double rating;           // التقييم من 1 إلى 5
  final String comment;          // التعليق النصي
  final DateTime createdAt;      // تاريخ الإنشاء
  final bool isVisible;          // هل التقييم مرئي (للمالك فقط)

  RatingModel({
    this.id,
    required this.bookingId,
    required this.itemId,
    required this.providerId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    DateTime? createdAt,
    this.isVisible = true,
  }) : createdAt = createdAt ?? DateTime.now();

  /// تحويل إلى Map لـ Firestore
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'itemId': itemId,
      'providerId': providerId,
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVisible': isVisible,
    };
  }

  /// إنشاء من Map
  factory RatingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RatingModel(
      id: documentId,
      bookingId: map['bookingId'] ?? '',
      itemId: map['itemId'] ?? '',
      providerId: map['providerId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVisible: map['isVisible'] ?? true,
    );
  }

  /// نسخة مع تعديلات
  RatingModel copyWith({
    String? id,
    String? bookingId,
    String? itemId,
    String? providerId,
    String? customerId,
    String? customerName,
    double? rating,
    String? comment,
    DateTime? createdAt,
    bool? isVisible,
  }) {
    return RatingModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      itemId: itemId ?? this.itemId,
      providerId: providerId ?? this.providerId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

/// إحصائيات التقييم للمزود
class ProviderRatingStats {
  final String providerId;
  final double averageRating;    // متوسط التقييم
  final int totalRatings;        // عدد التقييمات
  final Map<int, int> ratingDistribution; // توزيع التقييمات (1-5)

  ProviderRatingStats({
    required this.providerId,
    required this.averageRating,
    required this.totalRatings,
    required this.ratingDistribution,
  });

  factory ProviderRatingStats.empty(String providerId) {
    return ProviderRatingStats(
      providerId: providerId,
      averageRating: 0.0,
      totalRatings: 0,
      ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    );
  }
}
