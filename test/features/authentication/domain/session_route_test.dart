import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/domain/session_route.dart';

void main() {
  test('unauthenticated session routes to login', () {
    expect(
      resolveSessionRoute(isAuthenticated: false, hasCustomerProfile: false),
      SessionRoute.login,
    );
  });

  test('authenticated existing customer restores to home', () {
    expect(
      resolveSessionRoute(isAuthenticated: true, hasCustomerProfile: true),
      SessionRoute.dashboard,
    );
  });

  test('authenticated new customer goes to zone registration', () {
    expect(
      resolveSessionRoute(isAuthenticated: true, hasCustomerProfile: false),
      SessionRoute.zoneRegistration,
    );
  });
}
