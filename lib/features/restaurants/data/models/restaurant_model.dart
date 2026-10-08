import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/restaurant_entity.dart';
import '../../domain/restaurant_customer_visibility.dart';

class RestaurantModel extends RestaurantEntity {
  const RestaurantModel({
    required super.id,
    required super.name,
    required super.description,
    super.restaurantImages,
    required super.logoUrl,
    required super.coverImageUrl,
    required super.address,
    required super.latitude,
    required super.longitude,
    super.phone,
    required super.rating,
    required super.totalRatings,
    required super.deliveryTime,
    required super.deliveryFee,
    required super.minimumOrderAmount,
    required super.isPureVeg,
    required super.isOpen,
    required super.isFeatured,
    required super.openingTime,
    required super.closingTime,
    required super.cuisines,
    super.isCustomerVisible,
    super.isActive,
    super.approvedFoodCount,
    super.onboardingStatus,
    super.isVerified,
    required super.createdAt,
    required super.updatedAt,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    return RestaurantModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      restaurantImages: _readStringList(map['restaurantImages']),
      logoUrl: map['logoUrl'] ?? '',
      coverImageUrl: map['coverImageUrl'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      phone: map['phone'] is String ? (map['phone'] as String).trim() : '',
      rating: (map['rating'] ?? 0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      deliveryTime: map['deliveryTime'] ?? 0,
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      minimumOrderAmount: (map['minimumOrderAmount'] ?? 0).toDouble(),
      isPureVeg: map['isPureVeg'] ?? false,
      isOpen: map['isOpen'] ?? false,
      isFeatured: map['isFeatured'] ?? false,
      openingTime: map['openingTime'] ?? '',
      closingTime: map['closingTime'] ?? '',
      cuisines: List<String>.from(map['cuisines'] ?? []),
      isCustomerVisible: map['isCustomerVisible'] == true,
      isActive: map['isActive'] == true,
      approvedFoodCount: _readNonNegativeInt(map['approvedFoodCount']),
      onboardingStatus: (map['onboardingStatus'] as String?)?.trim() ?? '',
      isVerified: map['isVerified'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory RestaurantModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final mapped = Map<String, dynamic>.from(data);
    if ((mapped['id'] as String?)?.trim().isEmpty ?? true) {
      mapped['id'] = doc.id;
    }
    return RestaurantModel.fromMap(mapped);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'restaurantImages': restaurantImages,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'rating': rating,
      'totalRatings': totalRatings,
      'deliveryTime': deliveryTime,
      'deliveryFee': deliveryFee,
      'minimumOrderAmount': minimumOrderAmount,
      'isPureVeg': isPureVeg,
      'isOpen': isOpen,
      'isFeatured': isFeatured,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'cuisines': cuisines,
      'isCustomerVisible': isCustomerVisible,
      'isActive': isActive,
      'approvedFoodCount': approvedFoodCount,
      'onboardingStatus': onboardingStatus,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get isCustomerListable =>
      RestaurantCustomerVisibility.isCustomerListable(
        onboardingStatus: onboardingStatus,
        isVerified: isVerified,
        isCustomerVisible: isCustomerVisible,
        isActive: isActive,
        isOpen: isOpen,
        approvedFoodCount: approvedFoodCount,
      );

  static int _readNonNegativeInt(Object? value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }
    if (value is num) {
      final n = value.toInt();
      return n < 0 ? 0 : n;
    }
    return 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
