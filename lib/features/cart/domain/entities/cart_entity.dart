class CartEntity {
  final String id;

  /// Firebase User ID
  final String userId;

  /// Restaurant
  final String restaurantId;
  final String restaurantName;

  /// Food
  final String foodId;
  final String foodName;
  final String foodImage;

  /// Pricing
  final double price;
  final double? offerPrice;

  /// Quantity
  final int quantity;

  /// Veg / Non Veg
  final bool isVeg;

  /// Availability
  final bool isAvailable;

  /// Added Time
  final DateTime createdAt;

  const CartEntity({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.foodId,
    required this.foodName,
    required this.foodImage,
    required this.price,
    this.offerPrice,
    required this.quantity,
    required this.isVeg,
    required this.isAvailable,
    required this.createdAt,
  });

  /// Final Item Price
  double get finalPrice => offerPrice ?? price;

  /// Total Price
  double get totalPrice => finalPrice * quantity;

  CartEntity copyWith({
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
    return CartEntity(
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