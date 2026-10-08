import 'food_review_status.dart';

class FoodEntity {
  final String id;
  final String restaurantId;

  final String name;
  final String description;

  /// Base amount excluding tax (existing field name: [price]).
  final double price;
  final double? offerPrice;

  final String imageUrl;

  final String category;

  final bool isVeg;
  final bool isAvailable;
  final bool isRecommended;

  final double rating;
  final int ratingCount;

  /// Review lifecycle. Missing/unknown → not customer-visible.
  final FoodReviewStatus? status;

  const FoodEntity({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    this.offerPrice,
    required this.imageUrl,
    required this.category,
    required this.isVeg,
    required this.isAvailable,
    required this.isRecommended,
    required this.rating,
    this.ratingCount = 0,
    this.status,
  });

  double get finalPrice => offerPrice ?? price;

  bool get isCustomerVisibleFood =>
      isAvailable && FoodReviewStatus.isCustomerVisible(status);

  /// Offer badge text from entity prices. Null when there is no valid offer.
  String? get offerLabel {
    final offer = offerPrice;
    if (offer == null || price <= 0 || offer >= price) {
      return null;
    }
    final percent = (((price - offer) / price) * 100).round();
    if (percent <= 0) {
      return null;
    }
    return '$percent% OFF';
  }
}
