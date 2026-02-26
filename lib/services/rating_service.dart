import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _ratingsCollection = 'ratings';

  /// إضافة تقييم جديد
  Future<String> addRating(RatingModel rating) async {
    try {
      print('⭐ إضافة تقييم جديد للحجز: ${rating.bookingId}');
      
      // التحقق من عدم وجود تقييم سابق لنفس الحجز
      final existingRating = await _firestore
          .collection(_ratingsCollection)
          .where('bookingId', isEqualTo: rating.bookingId)
          .where('customerId', isEqualTo: rating.customerId)
          .limit(1)
          .get();

      if (existingRating.docs.isNotEmpty) {
        throw Exception('لقد قمت بتقييم هذا الحجز مسبقاً');
      }

      // حفظ التقييم
      final docRef = await _firestore
          .collection(_ratingsCollection)
          .add(rating.toMap());

      // تحديث متوسط التقييم في بيانات المزود
      await _updateProviderAverageRating(rating.providerId);

      // تحديث متوسط التقييم في بيانات العنصر
      await _updateItemAverageRating(rating.itemId);

      print('✅ تم إضافة التقييم بنجاح: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ خطأ في إضافة التقييم: $e');
      rethrow;
    }
  }

  /// الحصول على تقييمات المزود
  Stream<List<RatingModel>> getProviderRatings(String providerId) {
    return _firestore
        .collection(_ratingsCollection)
        .where('providerId', isEqualTo: providerId)
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// الحصول على تقييمات عنصر محدد
  Stream<List<RatingModel>> getItemRatings(String itemId) {
    return _firestore
        .collection(_ratingsCollection)
        .where('itemId', isEqualTo: itemId)
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// التحقق من إمكانية تقييم الحجز
  Future<bool> canRateBooking(String bookingId, String customerId) async {
    try {
      // التحقق من عدم وجود تقييم سابق
      final existingRating = await _firestore
          .collection(_ratingsCollection)
          .where('bookingId', isEqualTo: bookingId)
          .where('customerId', isEqualTo: customerId)
          .limit(1)
          .get();

      return existingRating.docs.isEmpty;
    } catch (e) {
      print('❌ خطأ في التحقق من إمكانية التقييم: $e');
      return false;
    }
  }

  /// حساب إحصائيات التقييم للمزود
  Future<ProviderRatingStats> getProviderRatingStats(String providerId) async {
    try {
      final snapshot = await _firestore
          .collection(_ratingsCollection)
          .where('providerId', isEqualTo: providerId)
          .where('isVisible', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return ProviderRatingStats.empty(providerId);
      }

      final ratings = snapshot.docs
          .map((doc) => RatingModel.fromMap(doc.data(), doc.id))
          .toList();

      // حساب المتوسط
      double sum = 0;
      Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var rating in ratings) {
        sum += rating.rating;
        final ratingInt = rating.rating.round();
        distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
      }

      final average = sum / ratings.length;

      return ProviderRatingStats(
        providerId: providerId,
        averageRating: average,
        totalRatings: ratings.length,
        ratingDistribution: distribution,
      );
    } catch (e) {
      print('❌ خطأ في حساب إحصائيات التقييم: $e');
      return ProviderRatingStats.empty(providerId);
    }
  }

  /// تحديث متوسط التقييم في بيانات المزود
  Future<void> _updateProviderAverageRating(String providerId) async {
    try {
      final stats = await getProviderRatingStats(providerId);
      
      await _firestore
          .collection('published_providers')
          .doc(providerId)
          .update({
        'averageRating': stats.averageRating,
        'totalRatings': stats.totalRatings,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ تم تحديث متوسط تقييم المزود: ${stats.averageRating}');
    } catch (e) {
      print('⚠️ خطأ في تحديث متوسط تقييم المزود: $e');
    }
  }

  /// تحديث متوسط التقييم في بيانات العنصر
  Future<void> _updateItemAverageRating(String itemId) async {
    try {
      final snapshot = await _firestore
          .collection(_ratingsCollection)
          .where('itemId', isEqualTo: itemId)
          .where('isVisible', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return;

      final ratings = snapshot.docs
          .map((doc) => RatingModel.fromMap(doc.data(), doc.id))
          .toList();

      double sum = 0;
      for (var rating in ratings) {
        sum += rating.rating;
      }

      final average = sum / ratings.length;

      await _firestore
          .collection('published_items')
          .doc(itemId)
          .update({
        'averageRating': average,
        'totalRatings': ratings.length,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ تم تحديث متوسط تقييم العنصر: $average');
    } catch (e) {
      print('⚠️ خطأ في تحديث متوسط تقييم العنصر: $e');
    }
  }

  /// الحصول على جميع التقييمات (للمالك فقط)
  Stream<List<RatingModel>> getAllRatings() {
    return _firestore
        .collection(_ratingsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// إخفاء/إظهار تقييم (للمالك فقط)
  Future<void> toggleRatingVisibility(String ratingId, bool isVisible) async {
    try {
      await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .update({'isVisible': isVisible});

      print('✅ تم ${isVisible ? 'إظهار' : 'إخفاء'} التقييم');
    } catch (e) {
      print('❌ خطأ في تغيير حالة التقييم: $e');
      rethrow;
    }
  }

  /// حذف تقييم (للمالك فقط)
  Future<void> deleteRating(String ratingId) async {
    try {
      await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .delete();

      print('✅ تم حذف التقييم');
    } catch (e) {
      print('❌ خطأ في حذف التقييم: $e');
      rethrow;
    }
  }
}
