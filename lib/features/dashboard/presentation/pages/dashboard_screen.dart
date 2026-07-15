import 'package:flutter/material.dart';

import '../widgets/dashboard_app_bar.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/category_section.dart';
import '../widgets/offer_banner.dart';
import '../widgets/restaurant_section.dart';
import '../widgets/food_section.dart';
import '../widgets/bottom_nav_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void _onBottomNavTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    // TODO:
    // Home
    // Orders
    // Wallet
    // Profile
  }

  @override
  Widget build(BuildContext context) {
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
            const SliverToBoxAdapter(
              child: CategorySection(),
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