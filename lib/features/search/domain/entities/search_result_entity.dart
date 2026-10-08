import 'package:equatable/equatable.dart';

enum SearchResultType { restaurant, food, category }

class SearchResultEntity extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final SearchResultType type;

  /// The restaurant a FOOD result is sold by. Empty for restaurant results
  /// (use [owningRestaurantId]) and for a food whose document names no
  /// restaurant — such a result cannot be placed against a delivery
  /// destination, so search drops it.
  final String restaurantId;

  const SearchResultEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.type,
    this.restaurantId = '',
  });

  /// The restaurant whose location decides whether this result can be
  /// delivered to the customer: the restaurant itself, or a food's seller.
  String get owningRestaurantId =>
      (type == SearchResultType.restaurant ? id : restaurantId).trim();

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    imageUrl,
    type,
    restaurantId,
  ];
}
