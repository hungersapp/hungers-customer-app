import '../../domain/entities/food_entity.dart';
import '../../domain/entities/food_review_status.dart';

class FoodModel extends FoodEntity {
  const FoodModel({
    required super.id,
    required super.restaurantId,
    required super.name,
    required super.description,
    required super.price,
    super.offerPrice,
    required super.imageUrl,
    required super.category,
    required super.isVeg,
    required super.isAvailable,
    required super.isRecommended,
    required super.rating,
    super.ratingCount,
    super.status,
  });

  factory FoodModel.fromMap(Map<String, dynamic> map, String documentId) {
    final offerRaw = _valueForKeys(map, const [
      'offerPrice',
      'offer_price',
      'discountPrice',
    ]);

    return FoodModel(
      id: documentId,
      restaurantId: _readString(
        _valueForKeys(map, const ['restaurantId', 'restaurant_id']),
      ),
      name: _readName(map),
      description: _readString(
        _valueForKeys(map, const ['description', 'desc']),
      ),
      price: _readDouble(_valueForKeys(map, const ['price'])),
      offerPrice: offerRaw == null ? null : _readDouble(offerRaw),
      imageUrl: _readString(
        _valueForKeys(map, const [
          'imageUrl',
          'image_url',
          'image',
          'photoUrl',
          'photo_url',
        ]),
      ),
      category: _readString(_valueForKeys(map, const ['category'])),
      isVeg: _readBool(_valueForKeys(map, const ['isVeg', 'is_veg']), true),
      isAvailable: _readBool(
        _valueForKeys(map, const ['isAvailable', 'is_available']),
        true,
      ),
      isRecommended: _readBool(
        _valueForKeys(map, const ['isRecommended', 'is_recommended']),
        false,
      ),
      rating: _readDouble(_valueForKeys(map, const ['rating'])),
      ratingCount: _readInt(
        _valueForKeys(map, const ['ratingCount', 'totalRatings']),
      ),
      status: FoodReviewStatus.tryParse(
        _valueForKeys(map, const ['status', 'reviewStatus', 'foodStatus']),
      ),
    );
  }

  /// Maps the real food title from the Firestore document.
  /// Does not invent or hardcode a name.
  static String _readName(Map<String, dynamic> map) {
    final raw = _valueForKeys(map, const [
      'name',
      'foodName',
      'food_name',
      'title',
      'itemName',
      'item_name',
      'dishName',
      'dish_name',
      'productName',
      'label',
    ]);
    final mapped = _readDisplayText(raw);
    if (mapped.isNotEmpty) {
      return mapped;
    }

    for (final entry in map.entries) {
      final key = entry.key.toLowerCase();
      if (!key.contains('name')) {
        continue;
      }
      if (key.contains('restaurant')) {
        continue;
      }
      final text = _readDisplayText(entry.value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static dynamic _valueForKeys(Map<String, dynamic> map, List<String> keys) {
    final lower = <String, dynamic>{
      for (final entry in map.entries) entry.key.toLowerCase(): entry.value,
    };

    for (final key in keys) {
      if (map[key] != null) {
        return map[key];
      }
      final match = lower[key.toLowerCase()];
      if (match != null) {
        return match;
      }
    }
    return null;
  }

  static String _readDisplayText(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is Map) {
      for (final nestedKey in const [
        'en',
        'en_IN',
        'en-IN',
        'default',
        'name',
        'value',
      ]) {
        final nested = value[nestedKey];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
      for (final nested in value.values) {
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }
    return '';
  }

  static String _readString(dynamic value) => _readDisplayText(value);

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static bool _readBool(dynamic value, bool fallback) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'offerPrice': offerPrice,
      'imageUrl': imageUrl,
      'category': category,
      'isVeg': isVeg,
      'isAvailable': isAvailable,
      'isRecommended': isRecommended,
      'rating': rating,
      'ratingCount': ratingCount,
      if (status != null) 'status': status!.firestoreValue,
    };
  }

  factory FoodModel.fromEntity(FoodEntity entity) {
    return FoodModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      name: entity.name,
      description: entity.description,
      price: entity.price,
      offerPrice: entity.offerPrice,
      imageUrl: entity.imageUrl,
      category: entity.category,
      isVeg: entity.isVeg,
      isAvailable: entity.isAvailable,
      isRecommended: entity.isRecommended,
      rating: entity.rating,
      ratingCount: entity.ratingCount,
      status: entity.status,
    );
  }

  FoodEntity toEntity() {
    return FoodEntity(
      id: id,
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      offerPrice: offerPrice,
      imageUrl: imageUrl,
      category: category,
      isVeg: isVeg,
      isAvailable: isAvailable,
      isRecommended: isRecommended,
      rating: rating,
      ratingCount: ratingCount,
      status: status,
    );
  }

  FoodModel copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? description,
    double? price,
    double? offerPrice,
    String? imageUrl,
    String? category,
    bool? isVeg,
    bool? isAvailable,
    bool? isRecommended,
    double? rating,
    int? ratingCount,
    FoodReviewStatus? status,
  }) {
    return FoodModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isVeg: isVeg ?? this.isVeg,
      isAvailable: isAvailable ?? this.isAvailable,
      isRecommended: isRecommended ?? this.isRecommended,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      status: status ?? this.status,
    );
  }
}
