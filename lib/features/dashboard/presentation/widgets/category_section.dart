import 'package:flutter/material.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  static const List<_FoodCategory> _categories = [
    _FoodCategory(
      name: 'Pizza',
      icon: Icons.local_pizza_rounded,
    ),
    _FoodCategory(
      name: 'Burger',
      icon: Icons.lunch_dining_rounded,
    ),
    _FoodCategory(
      name: 'Biryani',
      icon: Icons.rice_bowl_rounded,
    ),
    _FoodCategory(
      name: 'Chicken',
      icon: Icons.set_meal_rounded,
    ),
    _FoodCategory(
      name: 'Drinks',
      icon: Icons.local_drink_rounded,
    ),
    _FoodCategory(
      name: 'Desserts',
      icon: Icons.icecream_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Categories',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final category = _categories[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    // TODO:
                    // Navigate to category screen
                  },
                  child: SizedBox(
                    width: 78,
                    child: Column(
                      children: [
                        Container(
                          height: 58,
                          width: 58,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            category.icon,
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodCategory {
  final String name;
  final IconData icon;

  const _FoodCategory({
    required this.name,
    required this.icon,
  });
}