import '../entities/billing_config.dart';
import '../entities/billing_summary.dart';
import '../entities/cart_entity.dart';
import '../services/billing_calculator.dart';

class CalculateCartBillingUseCase {
  const CalculateCartBillingUseCase();

  BillingSummary call({
    required List<CartEntity> items,
    required BillingConfig config,
    double? deliveryFee,
    double packingCharge = 0,
  }) {
    if (items.isEmpty) {
      return BillingSummary.empty();
    }

    final itemTotal = items.fold<double>(
      0,
      (total, item) => total + item.totalPrice,
    );

    return BillingCalculator(config).calculate(
      itemTotal: itemTotal,
      deliveryFee: deliveryFee ?? config.defaultDeliveryFee,
      platformFee: config.platformFee,
      packingCharge: packingCharge,
    );
  }
}
