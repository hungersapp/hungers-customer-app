import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/cart_entity.dart';

class CartModel extends CartEntity {
  const CartModel({
    required super.id,
    required super.userId,
    required super.restaurantId,
    required super.restaurantName,
    required super.foodId,
    required super.foodName,
    required super.foodImage,
    required super.price,
    super.offerPrice,
    required super.quantity,
    required super.isVeg,
    required super.isAvailable,
    required super.createdAt,
  });

  factory CartModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return CartModel(
      id: documentId,
      userId: map['userId'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      foodId: _readFoodId(map, documentId),
      foodName: _readString(map['foodName']).isNotEmpty
          ? _readString(map['foodName'])
          : _readString(map['name']),
      foodImage: map['foodImage'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      offerPrice: map['offerPrice'] != null
          ? (map['offerPrice'] as num).toDouble()
          : null,
      quantity: map['quantity'] ?? 1,
      isVeg: map['isVeg'] ?? true,
      isAvailable: map['isAvailable'] ?? true,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  static String _readFoodId(Map<String, dynamic> map, String documentId) {
    final foodId = _readString(map['foodId']);
    if (foodId.isNotEmpty) {
      return foodId;
    }
    return documentId;
  }

  static String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'foodId': foodId,
      'foodName': foodName,
      'foodImage': foodImage,
      'price': price,
      'offerPrice': offerPrice,
      'quantity': quantity,
      'isVeg': isVeg,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CartModel.fromEntity(CartEntity entity) {
    return CartModel(
      id: entity.id,
      userId: entity.userId,
      restaurantId: entity.restaurantId,
      restaurantName: entity.restaurantName,
      foodId: entity.foodId,
      foodName: entity.foodName,
      foodImage: entity.foodImage,
      price: entity.price,
      offerPrice: entity.offerPrice,
      quantity: entity.quantity,
      isVeg: entity.isVeg,
      isAvailable: entity.isAvailable,
      createdAt: entity.createdAt,
    );
  }

  CartEntity toEntity() {
    return CartEntity(
      id: id,
      userId: userId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      foodId: foodId,
      foodName: foodName,
      foodImage: foodImage,
      price: price,
      offerPrice: offerPrice,
      quantity: quantity,
      isVeg: isVeg,
      isAvailable: isAvailable,
      createdAt: createdAt,
    );
  }

  @override

  CartModel copyWith({
    String? id,
    String? userId,
    String? restaurantId,
    String? restaurantName,
    String? foodId,
    String? foodName,
    String? foodImage,
    double? price,
    double? offerPrice,
    int? quantity,
    bool? isVeg,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return CartModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      foodImage: foodImage ?? this.foodImage,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
      quantity: quantity ?? this.quantity,
      isVeg: isVeg ?? this.isVeg,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}