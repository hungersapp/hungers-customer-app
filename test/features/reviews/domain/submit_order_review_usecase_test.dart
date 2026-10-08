import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/reviews/domain/submit_order_review_request.dart';
import 'package:customer_app/features/reviews/domain/usecases/submit_order_review_usecase.dart';

class _FakeReviewDatasource implements ReviewFunctionsDatasource {
  String? lastOrderId;
  int calls = 0;
  Object? error;

  @override
  Future<String> submitOrderReview(SubmitOrderReviewRequest request) async {
    calls += 1;
    lastOrderId = request.orderId;
    if (error != null) {
      throw error!;
    }
    return '${request.orderId}_review';
  }
}

PlacedOrder _order({
  OrderStatus status = OrderStatus.delivered,
  String reviewId = '',
}) {
  return PlacedOrder(
    id: 'order-1',
    userId: 'user-1',
    restaurantName: 'A2B',
    grandTotal: 200,
    itemCount: 1,
    createdAt: DateTime(2026, 9, 24),
    status: status,
    reviewId: reviewId,
  );
}

void main() {
  test('delivered order without a review can be rated', () {
    expect(_order().canReview, isTrue);
    expect(_order().hasReview, isFalse);
  });

  test('pending and cancelled orders cannot be rated', () {
    expect(_order(status: OrderStatus.preparing).canReview, isFalse);
    expect(_order(status: OrderStatus.cancelled).canReview, isFalse);
  });

  test('duplicate review is treated as already reviewed', () {
    expect(_order(reviewId: 'order-1_user-1').canReview, isFalse);
    expect(_order(reviewId: 'order-1_user-1').hasReview, isTrue);
  });

  test('submit use case requires a restaurant rating', () async {
    final datasource = _FakeReviewDatasource();
    expect(
      () => SubmitOrderReviewUseCase(datasource)(
        const SubmitOrderReviewRequest(orderId: 'order-1', restaurantRating: 0),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(datasource.calls, 0);
  });

  test('submit use case forwards a valid review', () async {
    final datasource = _FakeReviewDatasource();
    final id = await SubmitOrderReviewUseCase(datasource)(
      const SubmitOrderReviewRequest(orderId: 'order-1', restaurantRating: 5),
    );
    expect(id, 'order-1_review');
    expect(datasource.lastOrderId, 'order-1');
  });

  test('backend failure is not swallowed', () async {
    final datasource = _FakeReviewDatasource()
      ..error = Exception('unavailable');
    expect(
      () => SubmitOrderReviewUseCase(datasource)(
        const SubmitOrderReviewRequest(orderId: 'order-1', restaurantRating: 5),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
