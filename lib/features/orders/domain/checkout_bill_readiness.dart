/// Pure readiness gate for checkout final-bill display.
///
/// The payable bill must only appear after a delivery address is finalized
/// and the order can be sent to the backend for pricing. The delivery fee
/// itself is never decided here: it arrives with the backend quote.
bool isCheckoutFinalBillReady({
  required bool addressFinalized,
  required bool checkingServiceability,
  required bool deliveryPriceable,
  required String? feeBlockMessage,
  required String? addressBlockReason,
}) {
  if (!addressFinalized || checkingServiceability) {
    return false;
  }
  if (!deliveryPriceable) {
    return false;
  }
  if (feeBlockMessage != null && feeBlockMessage.trim().isNotEmpty) {
    return false;
  }
  if (addressBlockReason != null && addressBlockReason.trim().isNotEmpty) {
    return false;
  }
  return true;
}
