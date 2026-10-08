import '../restaurant_display_image.dart';

class RestaurantEntity {
  /// Basic Details
  final String id;
  final String name;
  final String description;

  /// Images
  ///
  /// Canonical customer display gallery from Restaurant App uploads.
  final List<String> restaurantImages;
  final String logoUrl;
  final String coverImageUrl;

  /// Location
  final String address;
  final double latitude;
  final double longitude;

  /// Restaurant's own contact number (`restaurants/{id}.phone`), same field
  /// Restaurant App reads/writes. Used only for Call Restaurant — direct
  /// dial, never shown in the UI as text.
  final String phone;

  /// Rating
  final double rating;
  final int totalRatings;

  /// Delivery
  final int deliveryTime; // Minutes
  final double deliveryFee;
  final double minimumOrderAmount;

  /// Restaurant Type
  final bool isPureVeg;
  final bool isOpen;
  final bool isFeatured;

  /// Business Hours
  final String openingTime;
  final String closingTime;

  /// Categories
  final List<String> cuisines;

  /// Customer visibility contract (admin-controlled; not owner-writable).
  final bool isCustomerVisible;

  /// Owner operational availability for NEW customer discovery/orders.
  final bool isActive;

  /// Denormalized COUNT of foods with status == approved.
  /// Maintained by menu approval flows; missing → 0 (not listable).
  final int approvedFoodCount;

  /// Lifecycle fields used for customer eligibility (read-only here).
  final String onboardingStatus;
  final bool isVerified;

  /// Firestore Audit Fields
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantEntity({
    required this.id,
    required this.name,
    required this.description,
    this.restaurantImages = const [],
    required this.logoUrl,
    required this.coverImageUrl,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone = '',
    required this.rating,
    required this.totalRatings,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.minimumOrderAmount,
    required this.isPureVeg,
    required this.isOpen,
    required this.isFeatured,
    required this.openingTime,
    required this.closingTime,
    required this.cuisines,
    this.isCustomerVisible = false,
    this.isActive = false,
    this.approvedFoodCount = 0,
    this.onboardingStatus = '',
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Resolved display URL for cards/hero. Empty when no valid HTTPS image.
  String get displayImageUrl => RestaurantDisplayImage.resolve(
    restaurantImages: restaurantImages,
    coverImageUrl: coverImageUrl,
    logoUrl: logoUrl,
  );
}
