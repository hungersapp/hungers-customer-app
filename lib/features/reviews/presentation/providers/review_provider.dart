import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/review_functions_datasource.dart';
import '../../domain/submit_order_review_request.dart';
import '../../domain/usecases/submit_order_review_usecase.dart';

final reviewFunctionsDatasourceProvider = Provider<ReviewFunctionsDatasource>(
  (ref) => FirebaseReviewFunctionsDatasource(),
);

final submitOrderReviewUseCaseProvider = Provider<SubmitOrderReviewUseCase>(
  (ref) =>
      SubmitOrderReviewUseCase(ref.watch(reviewFunctionsDatasourceProvider)),
);
