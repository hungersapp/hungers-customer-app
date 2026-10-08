import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/restaurants/domain/restaurant_customer_visibility.dart';

void main() {
  group('RestaurantCustomerVisibility', () {
    test('Restaurant A: approved + visible + open + 0 foods → hidden', () {
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'approved',
          isVerified: true,
          isCustomerVisible: true,
          isActive: true,
          isOpen: true,
          approvedFoodCount: 0,
        ),
        isFalse,
      );
    });

    test(
      'Restaurant B: approved + visible + active + open + 1 food → shown',
      () {
        expect(
          RestaurantCustomerVisibility.isCustomerListable(
            onboardingStatus: 'approved',
            isVerified: true,
            isCustomerVisible: true,
            isActive: true,
            isOpen: true,
            approvedFoodCount: 1,
          ),
          isTrue,
        );
      },
    );

    test('isActive=false excludes restaurant', () {
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'approved',
          isVerified: true,
          isCustomerVisible: true,
          isActive: false,
          isOpen: true,
          approvedFoodCount: 2,
        ),
        isFalse,
      );
    });

    test('Restaurant C/D: pending/rejected foods → count 0 → hidden', () {
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'approved',
          isVerified: true,
          isCustomerVisible: true,
          isActive: true,
          isOpen: true,
          approvedFoodCount: 0,
        ),
        isFalse,
      );
    });

    test('Restaurant E: mixed foods with approved count 1 → shown', () {
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'approved',
          isVerified: true,
          isCustomerVisible: true,
          isActive: true,
          isOpen: true,
          approvedFoodCount: 1,
        ),
        isTrue,
      );
    });

    test('Restaurant F: not approved + approved food → hidden', () {
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'pending',
          isVerified: false,
          isCustomerVisible: true,
          isActive: true,
          isOpen: true,
          approvedFoodCount: 2,
        ),
        isFalse,
      );
    });

    test('Restaurant G: approved + not customer-visible → hidden', () {
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'approved',
          isVerified: true,
          isCustomerVisible: false,
          isActive: true,
          isOpen: true,
          approvedFoodCount: 2,
        ),
        isFalse,
      );
    });

    test('Restaurant H: closed follows existing isOpen contract → hidden', () {
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'approved',
          isVerified: true,
          isCustomerVisible: true,
          isActive: true,
          isOpen: false,
          approvedFoodCount: 2,
        ),
        isFalse,
      );
    });

    test('approval alone does not imply customer visibility', () {
      expect(
        RestaurantCustomerVisibility.isRestaurantApproved(
          onboardingStatus: 'approved',
          isVerified: true,
        ),
        isTrue,
      );
      expect(
        RestaurantCustomerVisibility.isCustomerListable(
          onboardingStatus: 'approved',
          isVerified: true,
          isCustomerVisible: false,
          isActive: true,
          isOpen: true,
          approvedFoodCount: 5,
        ),
        isFalse,
      );
    });
  });

  group('FoodReviewStatus customer visibility', () {
    test('only approved is customer-visible', () {
      expect(
        FoodReviewStatus.isCustomerVisible(FoodReviewStatus.approved),
        isTrue,
      );
      expect(
        FoodReviewStatus.isCustomerVisible(FoodReviewStatus.draft),
        isFalse,
      );
      expect(
        FoodReviewStatus.isCustomerVisible(FoodReviewStatus.submitted),
        isFalse,
      );
      expect(
        FoodReviewStatus.isCustomerVisible(FoodReviewStatus.underReview),
        isFalse,
      );
      expect(
        FoodReviewStatus.isCustomerVisible(FoodReviewStatus.rejected),
        isFalse,
      );
      expect(FoodReviewStatus.isCustomerVisible(null), isFalse);
    });

    test('parses under_review firestore value', () {
      expect(
        FoodReviewStatus.tryParse('under_review'),
        FoodReviewStatus.underReview,
      );
    });
  });
}
