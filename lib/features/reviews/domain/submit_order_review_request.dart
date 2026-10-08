class SubmitOrderReviewRequest {
  const SubmitOrderReviewRequest({
    required this.orderId,
    required this.restaurantRating,
    this.restaurantComment = '',
    this.restaurantTags = const [],
    this.deliveryRating,
    this.deliveryComment = '',
    this.deliveryTags = const [],
    this.foodRatings = const [],
  });

  final String orderId;
  final int restaurantRating;
  final String restaurantComment;
  final List<String> restaurantTags;
  final int? deliveryRating;
  final String deliveryComment;
  final List<String> deliveryTags;
  final List<FoodRatingInput> foodRatings;
}

class FoodRatingInput {
  const FoodRatingInput({
    required this.foodId,
    required this.rating,
    this.tags = const [],
  });

  final String foodId;
  final int rating;
  final List<String> tags;
}

abstract class ReviewFunctionsDatasource {
  Future<String> submitOrderReview(SubmitOrderReviewRequest request);
}
