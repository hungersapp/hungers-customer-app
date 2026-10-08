import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../location/presentation/widgets/current_location_refresher.dart';
import '../../providers/dashboard_provider.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../orders/presentation/screens/my_orders_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/category_section.dart';
import '../widgets/dashboard_app_bar.dart';
import '../widgets/offer_banner.dart';
import '../../../restaurants/presentation/widgets/restaurant_section.dart';
import '../widgets/search_bar_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(dashboardProvider.notifier).loadCategories();
      // The active location is NOT reloaded here: the splash / login flow has
      // already resolved it (and its serviceability), and every later change
      // goes through LocationSetupNotifier, which refreshes it itself.
    });
  }

  void _onBottomNavTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
      return;
    }

    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  int get _bodyIndex {
    if (_currentIndex == 1) {
      return 1;
    }
    if (_currentIndex == 3) {
      return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(dashboardProvider);

    // Reads the phone's current location on open / resume / movement and
    // applies it to the active location as LocationRefreshPolicy allows.
    return CurrentLocationRefresher(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: HungersBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavTapped,
        ),
        body: IndexedStack(
          index: _bodyIndex,
          children: [
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: DashboardAppBar()),
                  const SliverToBoxAdapter(child: SearchBarWidget()),
                  const SliverToBoxAdapter(child: OfferBanner()),
                  SliverToBoxAdapter(
                    child: categoriesState.when(
                      data: (categories) =>
                          CategorySection(categories: categories),
                      loading: () => const SizedBox(
                        height: 118,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          error.toString(),
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: RestaurantSection()),
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xl),
                  ),
                ],
              ),
            ),
            MyOrdersScreen(
              onBrowseRestaurants: () {
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
            const ProfileScreen(),
          ],
        ),
      ),
    );
  }
}
