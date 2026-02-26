import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/favorite_model.dart';

/// خدمة إدارة المفضلات
class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _favoritesCollection = 'favorites';

  /// إضافة خدمة للمفضلات
  Future<void> addToFavorites({
    required String customerId,
    required String itemId,
    required String itemName,
    required String providerId,
    required String providerName,
    required String category,
    required num price,
    String? imageUrl,
  }) async {
    try {
      // التحقق من عدم وجود المفضلة مسبقاً
      final existing = await _firestore
          .collection(_favoritesCollection)
          .where('customerId', isEqualTo: customerId)
          .where('itemId', isEqualTo: itemId)
          .get();

      if (existing.docs.isNotEmpty) {
        print('الخدمة موجودة في المفضلات بالفعل');
        return;
      }

      final favorite = FavoriteModel(
        customerId: customerId,
        itemId: itemId,
        itemName: itemName,
        providerId: providerId,
        providerName: providerName,
        category: category,
        price: price,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await _firestore.collection(_favoritesCollection).add(favorite.toMap());
      print('✅ تمت إضافة الخدمة للمفضلات');
    } catch (e) {
      print('❌ خطأ في إضافة المفضلة: $e');
      rethrow;
    }
  }

  /// إزالة خدمة من المفضلات
  Future<void> removeFromFavorites({
    required String customerId,
    required String itemId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_favoritesCollection)
          .where('customerId', isEqualTo: customerId)
          .where('itemId', isEqualTo: itemId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      print('✅ تمت إزالة الخدمة من المفضلات');
    } catch (e) {
      print('❌ خطأ في إزالة المفضلة: $e');
      rethrow;
    }
  }

  /// التحقق من وجود خدمة في المفضلات
  Future<bool> isFavorite({
    required String customerId,
    required String itemId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_favoritesCollection)
          .where('customerId', isEqualTo: customerId)
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ خطأ في التحقق من المفضلة: $e');
      return false;
    }
  }

  /// Stream للتحقق من حالة المفضلة (real-time)
  Stream<bool> isFavoriteStream({
    required String customerId,
    required String itemId,
  }) {
    return _firestore
        .collection(_favoritesCollection)
        .where('customerId', isEqualTo: customerId)
        .where('itemId', isEqualTo: itemId)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// الحصول على جميع مفضلات العميل
  Stream<List<FavoriteModel>> getCustomerFavorites(String customerId) {
    return _firestore
        .collection(_favoritesCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      // ترتيب النتائج في الذاكرة بدلاً من Firestore
      final favorites = snapshot.docs
          .map((doc) => FavoriteModel.fromMap(doc.data(), doc.id))
          .toList();
      
      // ترتيب حسب تاريخ الإنشاء (الأحدث أولاً)
      favorites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return favorites;
    });
  }

  /// عدد المفضلات للعميل
  Future<int> getFavoritesCount(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection(_favoritesCollection)
          .where('customerId', isEqualTo: customerId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ خطأ في الحصول على عدد المفضلات: $e');
      return 0;
    }
  }

  /// تبديل حالة المفضلة (إضافة/إزالة)
  Future<bool> toggleFavorite({
    required String customerId,
    required String itemId,
    required String itemName,
    required String providerId,
    required String providerName,
    required String category,
    required num price,
    String? imageUrl,
  }) async {
    try {
      final isFav = await isFavorite(customerId: customerId, itemId: itemId);

      if (isFav) {
        await removeFromFavorites(customerId: customerId, itemId: itemId);
        return false; // تمت الإزالة
      } else {
        await addToFavorites(
          customerId: customerId,
          itemId: itemId,
          itemName: itemName,
          providerId: providerId,
          providerName: providerName,
          category: category,
          price: price,
          imageUrl: imageUrl,
        );
        return true; // تمت الإضافة
      }
    } catch (e) {
      print('❌ خطأ في تبديل المفضلة: $e');
      rethrow;
    }
  }

  /// حذف جميع المفضلات لعميل معين
  Future<void> clearAllFavorites(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection(_favoritesCollection)
          .where('customerId', isEqualTo: customerId)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ تم حذف جميع المفضلات');
    } catch (e) {
      print('❌ خطأ في حذف المفضلات: $e');
      rethrow;
    }
  }

  /// الحصول على عدد مرات إضافة خدمة معينة للمفضلات (للإحصائيات)
  Future<int> getItemFavoriteCount(String itemId) async {
    try {
      final snapshot = await _firestore
          .collection(_favoritesCollection)
          .where('itemId', isEqualTo: itemId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ خطأ في الحصول على عدد مفضلات الخدمة: $e');
      return 0;
    }
  }
}
