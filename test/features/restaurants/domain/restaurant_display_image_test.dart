import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/restaurants/data/models/restaurant_model.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/restaurant_display_image.dart';

void main() {
  group('RestaurantDisplayImage', () {
    test('uses first valid HTTPS URL from restaurantImages', () {
      final url = RestaurantDisplayImage.resolve(
        restaurantImages: const [
          'https://firebasestorage.googleapis.com/v0/b/x/o/1.jpg',
          'https://firebasestorage.googleapis.com/v0/b/x/o/2.jpg',
          'https://firebasestorage.googleapis.com/v0/b/x/o/3.jpg',
          'https://firebasestorage.googleapis.com/v0/b/x/o/4.jpg',
          'https://firebasestorage.googleapis.com/v0/b/x/o/5.jpg',
        ],
        coverImageUrl: 'https://example.com/cover.jpg',
        logoUrl: 'https://example.com/logo.jpg',
      );

      expect(url, 'https://firebasestorage.googleapis.com/v0/b/x/o/1.jpg');
    });

    test('skips invalid restaurantImages and uses first valid entry', () {
      final url = RestaurantDisplayImage.resolve(
        restaurantImages: const [
          '',
          'http://insecure.example/old.jpg',
          '  ',
          'https://cdn.example/valid.jpg',
          'https://cdn.example/second.jpg',
        ],
      );

      expect(url, 'https://cdn.example/valid.jpg');
    });

    test('empty restaurantImages falls back to coverImageUrl', () {
      final url = RestaurantDisplayImage.resolve(
        restaurantImages: const [],
        coverImageUrl: 'https://example.com/cover.jpg',
        logoUrl: 'https://example.com/logo.jpg',
      );

      expect(url, 'https://example.com/cover.jpg');
    });

    test('missing restaurantImages falls back to coverImageUrl', () {
      final url = RestaurantDisplayImage.resolve(
        coverImageUrl: 'https://example.com/cover.jpg',
        logoUrl: 'https://example.com/logo.jpg',
      );

      expect(url, 'https://example.com/cover.jpg');
    });

    test('invalid restaurantImages falls back to logoUrl', () {
      final url = RestaurantDisplayImage.resolve(
        restaurantImages: const ['', 'ftp://bad', 'not-a-url'],
        coverImageUrl: 'http://not-https.example/cover.jpg',
        logoUrl: 'https://example.com/logo.jpg',
      );

      expect(url, 'https://example.com/logo.jpg');
    });

    test('all unavailable returns empty for placeholder', () {
      final url = RestaurantDisplayImage.resolve(
        restaurantImages: const ['', 'http://x'],
        coverImageUrl: '',
        logoUrl: '   ',
      );

      expect(url, isEmpty);
    });
  });

  group('RestaurantEntity.displayImageUrl', () {
    test('entity getter prefers restaurantImages', () {
      final restaurant = RestaurantEntity(
        id: 'rzR6p9R8zhqtD4PfDhbp',
        name: 'Ammaiappar Hotel',
        description: '',
        restaurantImages: const [
          'https://firebasestorage.googleapis.com/v0/b/x/o/a.jpg',
          'https://firebasestorage.googleapis.com/v0/b/x/o/b.jpg',
        ],
        logoUrl: 'https://example.com/logo.jpg',
        coverImageUrl: 'https://example.com/cover.jpg',
        address: '',
        latitude: 0,
        longitude: 0,
        rating: 0,
        totalRatings: 0,
        deliveryTime: 0,
        deliveryFee: 0,
        minimumOrderAmount: 0,
        isPureVeg: false,
        isOpen: true,
        isFeatured: false,
        openingTime: '',
        closingTime: '',
        cuisines: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(
        restaurant.displayImageUrl,
        'https://firebasestorage.googleapis.com/v0/b/x/o/a.jpg',
      );
    });
  });

  group('RestaurantModel restaurantImages mapping', () {
    test('maps restaurantImages list from Firestore map', () {
      final model = RestaurantModel.fromMap({
        'id': 'rzR6p9R8zhqtD4PfDhbp',
        'name': 'Ammaiappar Hotel',
        'restaurantImages': [
          'https://firebasestorage.googleapis.com/v0/b/x/o/1.jpg',
          '',
          'https://firebasestorage.googleapis.com/v0/b/x/o/2.jpg',
        ],
        'coverImageUrl': 'https://example.com/cover.jpg',
        'logoUrl': 'https://example.com/logo.jpg',
      });

      expect(model.restaurantImages, [
        'https://firebasestorage.googleapis.com/v0/b/x/o/1.jpg',
        'https://firebasestorage.googleapis.com/v0/b/x/o/2.jpg',
      ]);
      expect(
        model.displayImageUrl,
        'https://firebasestorage.googleapis.com/v0/b/x/o/1.jpg',
      );
    });

    test('missing restaurantImages keeps cover fallback', () {
      final model = RestaurantModel.fromMap({
        'id': 'legacy',
        'name': 'Legacy Kitchen',
        'coverImageUrl': 'https://example.com/cover.jpg',
        'logoUrl': 'https://example.com/logo.jpg',
      });

      expect(model.restaurantImages, isEmpty);
      expect(model.displayImageUrl, 'https://example.com/cover.jpg');
    });
  });
}
