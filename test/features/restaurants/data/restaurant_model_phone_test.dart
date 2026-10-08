import 'package:customer_app/features/restaurants/data/models/restaurant_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// `restaurants/{id}.phone` is the existing source of truth (the same field
/// Restaurant App writes); Customer App only reads it, for Call Restaurant.
void main() {
  Map<String, dynamic> base() => {'id': 'r1', 'name': 'Kitchen'};

  test('maps the stored phone number, trimmed and otherwise unchanged', () {
    final model = RestaurantModel.fromMap({
      ...base(),
      'phone': ' +914312345678 ',
    });

    expect(model.phone, '+914312345678');
  });

  test('preserves an existing national-format number as stored', () {
    final model = RestaurantModel.fromMap({...base(), 'phone': '04312345678'});

    expect(model.phone, '04312345678');
  });

  test('a restaurant document without a phone maps to an empty string', () {
    final model = RestaurantModel.fromMap(base());

    expect(model.phone, '');
  });

  test('a non-string phone value is ignored, never crashes', () {
    final model = RestaurantModel.fromMap({...base(), 'phone': 4312345678});

    expect(model.phone, '');
  });
}
