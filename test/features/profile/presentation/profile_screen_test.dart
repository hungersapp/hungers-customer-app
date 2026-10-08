import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/app/app_pages.dart';
import 'package:customer_app/app/app_routes.dart';
import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';
import 'package:customer_app/features/orders/presentation/screens/my_orders_screen.dart';
import 'package:customer_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:customer_app/features/orders/presentation/widgets/order_status_chip.dart';
import 'package:customer_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:customer_app/features/profile/presentation/screens/profile_screen.dart';
import '../../../helpers/fixed_orders_notifier.dart';

const _user = AuthUser(
  uid: 'user-1',
  name: 'Priya Kumar',
  email: 'priya@example.com',
  mobileNumber: '9876543210',
  emailVerified: true,
  isAnonymous: false,
);

PlacedOrder _order({
  required String id,
  required OrderStatus status,
  String restaurantName = 'Ammaiappar Hotel',
  double grandTotal = 245,
}) {
  return PlacedOrder(
    id: id,
    userId: 'user-1',
    restaurantName: restaurantName,
    grandTotal: grandTotal,
    itemCount: 2,
    createdAt: DateTime(2026, 3, 12, 13, 30),
    status: status,
  );
}

Widget _app({
  List<PlacedOrder> orders = const [],
  UserLocation? location,
  Object? ordersError,
}) {
  return ProviderScope(
    overrides: [
      currentAuthUserProvider.overrideWithValue(_user),
      currentUserIdProvider.overrideWithValue('user-1'),
      customerOrdersProvider.overrideWith(
        () => FixedCustomerOrdersNotifier(orders, error: ordersError),
      ),
      userLocationProvider.overrideWith((ref, userId) async => location),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

void main() {
  testWidgets('profile header shows authenticated customer data', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Priya Kumar'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    await tester.ensureVisible(find.text('Logout'));
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('no active order empty state renders Explore Food', (
    tester,
  ) async {
    await tester.pumpWidget(_app(orders: const []));
    await tester.pumpAndSettle();

    expect(find.text('Track Your Order'), findsOneWidget);
    expect(find.text('No active orders right now.'), findsOneWidget);
    expect(find.text('Explore Food'), findsOneWidget);
    expect(find.text('Preparing'), findsNothing);
  });

  testWidgets('ongoing order card shows real status and navigates to details', (
    tester,
  ) async {
    final order = _order(id: 'abcdef12xyz', status: OrderStatus.preparing);

    await tester.pumpWidget(_app(orders: [order]));
    await tester.pumpAndSettle();

    expect(find.text('Ammaiappar Hotel'), findsOneWidget);
    expect(find.text('Order #ABCDEF12'), findsOneWidget);
    expect(find.text('₹245'), findsOneWidget);
    expect(find.byType(OrderStatusChip), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('View Order'), findsOneWidget);

    await tester.tap(find.text('View Order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    expect(find.text('Order #ABCDEF12'), findsWidgets);
  });

  testWidgets('delivered order is not treated as active', (tester) async {
    await tester.pumpWidget(
      _app(
        orders: [_order(id: 'pastorder1', status: OrderStatus.delivered)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active orders right now.'), findsOneWidget);
    expect(find.text('View Order'), findsNothing);
  });

  testWidgets('order load error shows retry without fake tracking', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ordersError: Exception('network')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load active order'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('View Order'), findsNothing);
  });

  testWidgets('My Orders opens the existing orders screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('My Orders'));
    await tester.tap(find.text('My Orders'));
    await tester.pumpAndSettle();

    expect(find.byType(MyOrdersScreen), findsOneWidget);
    expect(find.text('No orders yet'), findsOneWidget);
  });

  testWidgets('unsupported features remain non-actionable', (tester) async {
    final observer = _PushObserver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWithValue(_user),
          currentUserIdProvider.overrideWithValue('user-1'),
          customerOrdersProvider.overrideWith(
            () => FixedCustomerOrdersNotifier([]),
          ),
          userLocationProvider.overrideWith((ref, userId) async => null),
        ],
        child: MaterialApp(
          navigatorObservers: [observer],
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Favourites'));
    await tester.tap(find.text('Favourites'));
    await tester.pump();
    await tester.ensureVisible(find.text('Offers & Coupons'));
    await tester.tap(find.text('Offers & Coupons'));
    await tester.pump();

    expect(observer.pushCount, 0);
    expect(find.textContaining('will be available soon.'), findsWidgets);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('delivery location shows saved summary when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        location: UserLocation(
          latitude: 11.0,
          longitude: 78.0,
          city: 'Salem',
          state: 'TN',
          updatedAt: DateTime(2026, 1, 1),
          pincode: '636001',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delivery Location'), findsOneWidget);
    expect(find.text('Salem, TN · 636001'), findsOneWidget);
  });

  testWidgets('Edit Profile opens a writable name field', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Priya Kumar'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(
      find.text('Profile editing will be available in a later update.'),
      findsNothing,
    );
  });

  testWidgets('Reviews opens My Orders so delivered orders can be rated', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        orders: [_order(id: 'pastorder1', status: OrderStatus.delivered)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Reviews'));
    await tester.tap(find.text('Reviews'));
    await tester.pumpAndSettle();

    expect(find.byType(MyOrdersScreen), findsOneWidget);
    expect(find.text('Your Food Rating'), findsOneWidget);
  });

  testWidgets('logout asks for confirmation and cancel keeps profile', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Logout'));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Logout?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Priya Kumar'), findsOneWidget);
  });

  test('profile and edit-profile routes are registered', () {
    expect(AppPages.routes.containsKey(AppRoutes.profile), isTrue);
    expect(AppPages.routes.containsKey(AppRoutes.editProfile), isTrue);

    final profileRoute = AppPages.onGenerateRoute(
      const RouteSettings(name: AppRoutes.profile),
    );
    expect(profileRoute, isA<MaterialPageRoute<void>>());
    expect(profileRoute!.settings.name, AppRoutes.profile);
  });
}

class _PushObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      pushCount += 1;
    }
  }
}
