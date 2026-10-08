import '../submit_order_review_request.dart';

class SubmitOrderReviewUseCase {
  const SubmitOrderReviewUseCase(this._datasource);

  final ReviewFunctionsDatasource _datasource;

  Future<String> call(SubmitOrderReviewRequest request) {
    if (request.orderId.trim().isEmpty) {
      throw ArgumentError('A valid order is required.');
    }
    if (request.restaurantRating < 1 || request.restaurantRating > 5) {
      throw ArgumentError('Choose a restaurant rating between 1 and 5.');
    }
    return _datasource.submitOrderReview(request);
  }
}
