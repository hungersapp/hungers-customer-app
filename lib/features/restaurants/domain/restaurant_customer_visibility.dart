/// Customer App restaurant listing eligibility.
///
/// Approval ≠ customer visibility ≠ owner Active ≠ menu approval.
/// All gates must pass before a restaurant is shown to customers.
class RestaurantCustomerVisibility {
  RestaurantCustomerVisibility._();

  /// Existing lifecycle: final approval / verified restaurant.
  static bool isRestaurantApproved({
    required String onboardingStatus,
    required bool isVerified,
  }) {
    if (isVerified) {
      return true;
    }
    return onboardingStatus.trim().toLowerCase() == 'approved';
  }

  /// Full customer listing gate (data layer — not UI-only).
  static bool isCustomerListable({
    required String onboardingStatus,
    required bool isVerified,
    required bool isCustomerVisible,
    required bool isActive,
    required bool isOpen,
    required int approvedFoodCount,
  }) {
    return isRestaurantApproved(
          onboardingStatus: onboardingStatus,
          isVerified: isVerified,
        ) &&
        isCustomerVisible &&
        isActive &&
        isOpen &&
        approvedFoodCount > 0;
  }
}
