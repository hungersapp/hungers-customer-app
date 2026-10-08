import 'package:flutter/material.dart';

import '../features/authentication/presentation/pages/forgotpassword_screen.dart';
import '../features/authentication/presentation/pages/login_screen.dart';
import '../features/authentication/presentation/pages/otp_screen.dart';
import '../features/authentication/presentation/pages/registration_screen.dart';
import '../features/authentication/presentation/pages/zone_registration_screen.dart';
import '../features/authentication/presentation/pages/reset_password_screen.dart';
import '../features/cart/presentation/screens/cart_screen.dart';
import '../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../features/dashboard/domain/entities/category.dart';
import '../features/foods/presentation/screens/category_foods_screen.dart';
import '../features/foods/presentation/screens/food_details_args.dart';
import '../features/foods/presentation/screens/food_details_screen.dart';
import '../features/orders/domain/entities/placed_order.dart';
import '../features/orders/presentation/screens/checkout_screen.dart';
import '../features/orders/presentation/screens/my_orders_screen.dart';
import '../features/orders/presentation/screens/order_confirmation_screen.dart';
import '../features/orders/presentation/screens/order_details_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/restaurants/domain/entities/restaurant_entity.dart';
import '../features/restaurants/presentation/screens/restaurant_details_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.registration: (_) => const RegistrationScreen(),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.otp: (_) => const OtpScreen(),
    AppRoutes.zoneRegistration: (_) => const ZoneRegistrationScreen(),
    AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),
    AppRoutes.dashboard: (_) => const DashboardScreen(),
    AppRoutes.cart: (_) => const CartScreen(),
    AppRoutes.orders: (_) => const MyOrdersScreen(showBackButton: true),
    AppRoutes.profile: (_) => const ProfileScreen(showBackButton: true),
    AppRoutes.editProfile: (_) => const EditProfileScreen(),
  };

  /// Builds argument-based routes so Chrome never shows a blank page for
  /// `/restaurant-details`, `/checkout`, or `/order-confirmation`.
  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings, {
    RestaurantEntity? lastViewedRestaurant,
  }) {
    if (settings.name == AppRoutes.checkout) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const CheckoutScreen(),
      );
    }

    if (settings.name == AppRoutes.restaurantDetails) {
      final restaurant = settings.arguments is RestaurantEntity
          ? settings.arguments as RestaurantEntity
          : lastViewedRestaurant;
      if (restaurant != null) {
        return MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.restaurantDetails,
            arguments: restaurant,
          ),
          builder: (_) => RestaurantDetailsScreen(restaurant: restaurant),
        );
      }
      return _dashboardRoute();
    }

    if (settings.name == AppRoutes.categoryFoods) {
      final args = settings.arguments;
      if (args is Category && args.name.trim().isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CategoryFoodsScreen(category: args),
        );
      }
      return _dashboardRoute();
    }

    if (settings.name == AppRoutes.foodDetails) {
      final args = settings.arguments;
      if (args is FoodDetailsArgs) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => FoodDetailsScreen(
            food: args.food,
            restaurantName: args.restaurantName,
          ),
        );
      }
      return _dashboardRoute();
    }

    if (settings.name == AppRoutes.orderConfirmation) {
      final order = settings.arguments;
      if (order is PlacedOrder) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrderConfirmationScreen(order: order),
        );
      }
      return _dashboardRoute();
    }

    if (settings.name == AppRoutes.orderDetails) {
      final args = settings.arguments;
      if (args is PlacedOrder) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrderDetailsScreen(
            orderId: args.id,
            initialOrder: args,
          ),
        );
      }
      if (args is String && args.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => OrderDetailsScreen(orderId: args),
        );
      }
      return MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.orders),
        builder: (_) => const MyOrdersScreen(showBackButton: true),
      );
    }

    if (settings.name == AppRoutes.orders) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const MyOrdersScreen(showBackButton: true),
      );
    }

    if (settings.name == AppRoutes.profile) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ProfileScreen(showBackButton: true),
      );
    }

    if (settings.name == AppRoutes.editProfile) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const EditProfileScreen(),
      );
    }

    return null;
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _dashboardRoute();
  }

  static MaterialPageRoute<void> _dashboardRoute() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: AppRoutes.dashboard),
      builder: (_) => const DashboardScreen(),
    );
  }
}
