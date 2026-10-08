import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/submit_order_review_request.dart';

class FirebaseReviewFunctionsDatasource implements ReviewFunctionsDatasource {
  FirebaseReviewFunctionsDatasource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  static const String callableName = 'submitOrderReview';

  @override
  Future<String> submitOrderReview(SubmitOrderReviewRequest request) async {
    try {
      final result = await _functions.httpsCallable(callableName).call(
        <String, dynamic>{
          'orderId': request.orderId,
          'restaurantRating': request.restaurantRating,
          'restaurantComment': request.restaurantComment,
          'restaurantTags': request.restaurantTags,
          if (request.deliveryRating != null)
            'deliveryRating': request.deliveryRating,
          'deliveryComment': request.deliveryComment,
          'deliveryTags': request.deliveryTags,
          'foodRatings': [
            for (final food in request.foodRatings)
              {'foodId': food.foodId, 'rating': food.rating, 'tags': food.tags},
          ],
        },
      );
      final data = result.data;
      if (data is Map && data['reviewId'] is String) {
        return data['reviewId'] as String;
      }
      return '${request.orderId}_review';
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Unable to submit the review.');
    }
  }
}
