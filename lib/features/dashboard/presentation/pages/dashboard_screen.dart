import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dashboard_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/category_section.dart';
import '../widgets/dashboard_app_bar.dart';
import '../widgets/food_section.dart';
import '../widgets/offer_banner.dart';
import '../widgets/restaurant_section.dart';
import '../widgets/search_bar_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref
          .read(dashboardProvider.notifier)
          .loadCategories();
    });
  }

  void _onBottomNavTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    // TODO:
    // Home
    // Orders
    // Cart
    // Profile
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(dashboardProvider);

    return Scaffold(
      bottomNavigationBar: HungersBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            /// App Bar
            const SliverToBoxAdapter(
              child: DashboardAppBar(),
            ),

            /// Search
            const SliverToBoxAdapter(
              child: SearchBarWidget(),
            ),

            /// Categories
            SliverToBoxAdapter(
              child: categoriesState.when(
                data: (categories) {
                  return CategorySection(
                    categories: categories,
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      error.toString(),
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            /// Offer Banner
            const SliverToBoxAdapter(
              child: OfferBanner(),
            ),

            /// Nearby Restaurants
            const SliverToBoxAdapter(
              child: RestaurantSection(),
            ),

            /// Popular Foods
            const SliverToBoxAdapter(
              child: FoodSection(),
            ),

            const SliverPadding(
              padding: EdgeInsets.only(bottom: 20),
            ),
          ],
        ),
      ),
    );
  }
}