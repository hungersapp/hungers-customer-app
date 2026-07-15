import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.categories,
  });

  final List<Category> categories;

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final category = categories[index];

                return InkWell(
                  borderRadius:
                      BorderRadius.circular(18),
                  onTap: () {
                    // TODO:
                    // Navigate to Category Products
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
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                          child: category.imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(
                                          18),
                                  child: Image.network(
                                    category.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            const Icon(
                                      Icons.fastfood,
                                      size: 30,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.fastfood,
                                  size: 30,
                                ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          category.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              theme.textTheme.bodySmall,
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