/// Restaurant-scoped food item review lifecycle.
///
/// Customer App may show only [approved] items.
enum FoodReviewStatus {
  draft,
  submitted,
  underReview,
  approved,
  rejected;

  String get firestoreValue {
    switch (this) {
      case FoodReviewStatus.draft:
        return 'draft';
      case FoodReviewStatus.submitted:
        return 'submitted';
      case FoodReviewStatus.underReview:
        return 'under_review';
      case FoodReviewStatus.approved:
        return 'approved';
      case FoodReviewStatus.rejected:
        return 'rejected';
    }
  }

  /// Missing / unknown status is not customer-visible.
  static FoodReviewStatus? tryParse(Object? raw) {
    if (raw is! String) {
      return null;
    }
    switch (raw.trim().toLowerCase()) {
      case 'draft':
        return FoodReviewStatus.draft;
      case 'submitted':
        return FoodReviewStatus.submitted;
      case 'under_review':
      case 'underreview':
        return FoodReviewStatus.underReview;
      case 'approved':
        return FoodReviewStatus.approved;
      case 'rejected':
        return FoodReviewStatus.rejected;
      default:
        return null;
    }
  }

  static bool isCustomerVisible(FoodReviewStatus? status) {
    return status == FoodReviewStatus.approved;
  }
}
