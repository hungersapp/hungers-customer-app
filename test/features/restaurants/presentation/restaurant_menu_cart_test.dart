import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:customer_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:customer_app/features/cart/presentation/widgets/bottom_cart_bar.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/foods/presentation/widgets/food_section.dart';
import 'package:customer_app/features/foods/presentation/widgets/menu_item_row.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/presentation/screens/restaurant_details_screen.dart';

class _MemoryCartRepository implements CartRepository {
  _MemoryCartRepository([List<CartEntity> seed = const []]) {
    for (final item in seed) {
      _items[item.foodId] = item;
    }
  }

  final Map<String, CartEntity> _items = {};
  int clearCallCount = 0;

  List<CartEntity> get items => _items.values.toList();

  @override
  Future<void> addToCart(CartEntity cart) async {
    _items[cart.foodId] = cart;
  }

  @override
  Future<List<CartEntity>> getCartItems(String userId) async => items;

  @override
  Future<CartEntity?> getCartItem({
    required String userId,
    required String foodId,
  }) async => _items[foodId];

  @override
  Future<void> updateQuantity({
    required String userId,
    required String foodId,
    required int quantity,
  }) async {
    final item = _items[foodId];
    if (item != null) {
      _items[foodId] = item.copyWith(quantity: quantity);
    }
  }

  @override
  Future<void> removeItem({
    required String userId,
    required String foodId,
  }) async {
    _items.remove(foodId);
  }

  @override
  Future<void> clearCart(String userId) async {
    clearCallCount += 1;
    _items.clear();
  }

  @override
  Future<int> getCartItemCount(String userId) async => _items.length;

  @override
  Future<double> getCartTotal(String userId) async =>
      items.fold<double>(0, (total, item) => total + item.totalPrice);
}

RestaurantEntity _restaurant() {
  return RestaurantEntity(
    id: 'a2b',
    name: 'A2B Restaurant',
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: 'Anna Nagar, Madurai',
    latitude: 0,
    longitude: 0,
    rating: 4.5,
    totalRatings: 10,
    deliveryTime: 25,
    deliveryFee: 30,
    minimumOrderAmount: 150,
    isPureVeg: true,
    isOpen: true,
    isFeatured: false,
    openingTime: '08:00',
    closingTime: '22:00',
    cuisines: const ['South Indian'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

FoodEntity _food({
  required String id,
  required String name,
  double price = 160,
  String category = 'meals',
  bool isRecommended = false,
}) {
  return FoodEntity(
    id: id,
    restaurantId: 'a2b',
    name: name,
    description: '',
    price: price,
    imageUrl: '',
    category: category,
    isVeg: true,
    isAvailable: true,
    isRecommended: isRecommended,
    rating: 4.5,
  );
}

CartEntity _otherRestaurantLine() {
  return CartEntity(
    id: 'pizza-1',
    userId: 'user-1',
    restaurantId: 'pizza-hub',
    restaurantName: 'Pizza Hub',
    foodId: 'pizza-1',
    foodName: 'Margherita',
    foodImage: '',
    price: 250,
    quantity: 1,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpMenu(
  WidgetTester tester, {
  required _MemoryCartRepository cart,
  List<FoodEntity>? foods,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        cartRepositoryProvider.overrideWithValue(cart),
        restaurantFoodsProvider.overrideWith(
          (ref, restaurantId) async =>
              foods ??
              [
                _food(id: 'food-a', name: 'Mini Meals'),
                _food(id: 'food-b', name: 'Curd Rice', price: 90),
              ],
        ),
      ],
      child: MaterialApp(
        home: RestaurantDetailsScreen(restaurant: _restaurant()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('restaurant page opens and renders menu items as rows', (
    tester,
  ) async {
    await _pumpMenu(tester, cart: _MemoryCartRepository());

    expect(find.text('A2B Restaurant'), findsOneWidget);
    expect(find.byType(MenuItemRow), findsNWidgets(2));
    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('Curd Rice'), findsOneWidget);
    expect(find.text('ADD'), findsNWidgets(2));
    expect(find.byType(BottomCartBar), findsNothing);
  });

  testWidgets(
    'ADD keeps the customer on the menu and shows the sticky cart bar',
    (tester) async {
      final cart = _MemoryCartRepository();
      await _pumpMenu(tester, cart: cart);

      await _tap(tester, 'menu-add-food-a');

      // Still the same page, and the menu has not collapsed behind the bar.
      expect(find.byType(RestaurantDetailsScreen), findsOneWidget);
      expect(find.byType(MenuItemRow), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(CustomScrollView)).height,
        greaterThan(600),
      );
      expect(tester.getSize(find.byType(BottomCartBar)).height, lessThan(120));

      // ADD became [-] 1 [+] for that item only.
      expect(find.byKey(const ValueKey('menu-quantity-food-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-add-food-a')), findsNothing);
      expect(find.byKey(const ValueKey('menu-add-food-b')), findsOneWidget);

      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('₹160'), findsWidgets);
      expect(find.text('View Cart'), findsOneWidget);
      expect(cart.items.single.quantity, 1);
    },
  );

  testWidgets('quantity and cart bar update before the cart write finishes', (
    tester,
  ) async {
    await _pumpMenu(tester, cart: _MemoryCartRepository());

    final add = find.byKey(const ValueKey('menu-add-food-a'));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    // One frame only: the repository future has not completed yet.
    await tester.pump();

    expect(find.byKey(const ValueKey('menu-quantity-food-a')), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('increase, decrease and removal keep count and subtotal in sync', (
    tester,
  ) async {
    final cart = _MemoryCartRepository();
    await _pumpMenu(tester, cart: cart);

    await _tap(tester, 'menu-add-food-a');
    await _tap(tester, 'menu-increase-food-a');

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('menu-quantity-food-a'))).data,
      '2',
    );
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₹320'), findsOneWidget);
    expect(cart.items.single.quantity, 2);

    await _tap(tester, 'menu-add-food-b');
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('₹410'), findsOneWidget);

    await _tap(tester, 'menu-decrease-food-a');
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);

    // Removing the last unit returns the item to ADD.
    await _tap(tester, 'menu-decrease-food-a');
    expect(find.byKey(const ValueKey('menu-add-food-a')), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('₹90'), findsWidgets);

    await _tap(tester, 'menu-decrease-food-b');
    expect(find.byType(BottomCartBar), findsNothing);
    expect(cart.items, isEmpty);
    expect(find.byType(RestaurantDetailsScreen), findsOneWidget);
  });

  testWidgets('a failed cart write restores the saved quantity', (tester) async {
    final cart = _FailingCartRepository();
    await _pumpMenu(tester, cart: cart);

    await _tap(tester, 'menu-add-food-a');

    expect(find.byKey(const ValueKey('menu-add-food-a')), findsOneWidget);
    expect(find.byType(BottomCartBar), findsNothing);
    expect(find.text('Unable to add item. Please try again.'), findsOneWidget);
  });

  testWidgets('adding from another restaurant asks before replacing the cart', (
    tester,
  ) async {
    final cart = _MemoryCartRepository([_otherRestaurantLine()]);
    await _pumpMenu(tester, cart: cart);

    await _tap(tester, 'menu-add-food-a');

    expect(find.text(FoodSection.replaceCartMessage), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Clear Cart & Add'), findsOneWidget);
    // Nothing has changed yet.
    expect(cart.clearCallCount, 0);
    expect(cart.items.single.foodId, 'pizza-1');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(cart.clearCallCount, 0);
    expect(cart.items.single.foodId, 'pizza-1');
    expect(find.byKey(const ValueKey('menu-add-food-a')), findsOneWidget);

    await _tap(tester, 'menu-add-food-a');
    await tester.tap(find.text('Clear Cart & Add'));
    await tester.pumpAndSettle();

    expect(cart.clearCallCount, 1);
    expect(cart.items.single.foodId, 'food-a');
    expect(cart.items.single.restaurantId, 'a2b');
    expect(find.byKey(const ValueKey('menu-quantity-food-a')), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('category tabs list only categories the restaurant has', (
    tester,
  ) async {
    await _pumpMenu(
      tester,
      cart: _MemoryCartRepository(),
      foods: [
        _food(id: 'b1', name: 'Chicken Biryani', category: 'biryani', isRecommended: true),
        _food(id: 's1', name: 'Paneer Tikka', category: 'starters'),
        _food(id: 'd1', name: 'Gulab Jamun', category: 'desserts'),
      ],
    );

    for (final label in ['All', 'Popular', 'Biryani', 'Starters', 'Desserts']) {
      expect(find.byKey(ValueKey('menu-tab-$label')), findsOneWidget);
    }
    for (final label in ['Breads', 'Drinks', 'Rice', 'Main Course']) {
      expect(find.byKey(ValueKey('menu-tab-$label')), findsNothing);
    }

    await _tap(tester, 'menu-tab-Starters');
    expect(find.text('Paneer Tikka'), findsOneWidget);
    expect(find.text('Chicken Biryani'), findsNothing);

    await _tap(tester, 'menu-tab-Popular');
    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Gulab Jamun'), findsNothing);
  });

  testWidgets('menu search filters items in place', (tester) async {
    await _pumpMenu(tester, cart: _MemoryCartRepository());

    await tester.enterText(find.byKey(const ValueKey('menu-search')), 'curd');
    await tester.pumpAndSettle();

    expect(find.text('Curd Rice'), findsOneWidget);
    expect(find.text('Mini Meals'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('menu-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No items match "zzz".'), findsOneWidget);
  });
}

class _FailingCartRepository extends _MemoryCartRepository {
  @override
  Future<void> addToCart(CartEntity cart) async {
    throw StateError('write failed');
  }
}
