import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات المفضلة
class FavoriteModel {
  final String? id;
  final String customerId;
  final String itemId;
  final String itemName;
  final String providerId;
  final String providerName;
  final String category;
  final num price;
  final String? imageUrl;
  final DateTime createdAt;

  FavoriteModel({
    this.id,
    required this.customerId,
    required this.itemId,
    required this.itemName,
    required this.providerId,
    required this.providerName,
    required this.category,
    required this.price,
    this.imageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'itemId': itemId,
      'itemName': itemName,
      'providerId': providerId,
      'providerName': providerName,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FavoriteModel.fromMap(Map<String, dynamic> map, String id) {
    return FavoriteModel(
      id: id,
      customerId: map['customerId'] ?? '',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      providerId: map['providerId'] ?? '',
      providerName: map['providerName'] ?? '',
      category: map['category'] ?? '',
      price: map['price'] ?? 0,
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  FavoriteModel copyWith({
    String? id,
    String? customerId,
    String? itemId,
    String? itemName,
    String? providerId,
    String? providerName,
    String? category,
    num? price,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      category: category ?? this.category,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
