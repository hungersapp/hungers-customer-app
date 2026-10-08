import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/checkout_bill_readiness.dart';

void main() {
  group('isCheckoutFinalBillReady', () {
    test('bill is not ready before address finalization', () {
      expect(
        isCheckoutFinalBillReady(
          addressFinalized: false,
          checkingServiceability: false,
          deliveryPriceable: true,
          feeBlockMessage: null,
          addressBlockReason: null,
        ),
        isFalse,
      );
    });

    test('bill appears after address finalization when the order can be priced', () {
      expect(
        isCheckoutFinalBillReady(
          addressFinalized: true,
          checkingServiceability: false,
          deliveryPriceable: true,
          feeBlockMessage: null,
          addressBlockReason: null,
        ),
        isTrue,
      );
    });

    test('address change / editing invalidates the prior bill', () {
      // Editing clears addressFinalized in CheckoutScreen.
      expect(
        isCheckoutFinalBillReady(
          addressFinalized: false,
          checkingServiceability: false,
          deliveryPriceable: true,
          feeBlockMessage: null,
          addressBlockReason: null,
        ),
        isFalse,
      );
    });

    test('new finalized address is priced only when the order can be quoted', () {
      expect(
        isCheckoutFinalBillReady(
          addressFinalized: true,
          checkingServiceability: false,
          deliveryPriceable: false,
          feeBlockMessage:
              'Add a complete delivery address to see delivery fee.',
          addressBlockReason: null,
        ),
        isFalse,
      );
      expect(
        isCheckoutFinalBillReady(
          addressFinalized: true,
          checkingServiceability: false,
          deliveryPriceable: true,
          feeBlockMessage: null,
          addressBlockReason: null,
        ),
        isTrue,
      );
    });

    test('serviceability check and block reasons keep the bill hidden', () {
      expect(
        isCheckoutFinalBillReady(
          addressFinalized: true,
          checkingServiceability: true,
          deliveryPriceable: true,
          feeBlockMessage: null,
          addressBlockReason: null,
        ),
        isFalse,
      );
      expect(
        isCheckoutFinalBillReady(
          addressFinalized: true,
          checkingServiceability: false,
          deliveryPriceable: true,
          feeBlockMessage: null,
          addressBlockReason:
              'Delivery is not available to the selected location.',
        ),
        isFalse,
      );
    });
  });
}
