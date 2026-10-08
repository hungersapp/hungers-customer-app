import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/sized_network_image.dart';
import '../../domain/entities/category.dart';
import 'category_local_image.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.categories,
    this.onCategoryTap,
  });

  final List<Category> categories;

  /// Optional override for tests; defaults to [AppRoutes.categoryFoods].
  final ValueChanged<Category>? onCategoryTap;

  static const double _imageSize = 80;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              'Food Categories',
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
              itemBuilder: (context, index) {
                final category = categories[index];

                return InkWell(
                  key: Key('home-category-${category.id}'),
                  borderRadius: BorderRadius.circular(_imageSize / 2),
                  onTap: () {
                    final handler = onCategoryTap;
                    if (handler != null) {
                      handler(category);
                      return;
                    }
                    Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.categoryFoods, arguments: category);
                  },
                  child: SizedBox(
                    width: 84,
                    child: Column(
                      children: [
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _CategoryImage(
                            name: category.name,
                            imageUrl: category.imageUrl,
                            size: _imageSize,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
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

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({
    required this.name,
    required this.imageUrl,
    required this.size,
  });

  final String name;
  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final localAsset = CategoryLocalImage.assetForName(name);
    final remoteUrl = imageUrl.trim();

    Widget fallback() {
      if (localAsset != null) {
        return Image.asset(
          localAsset,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, _, _) => _fallbackIcon(size),
        );
      }
      return _fallbackIcon(size);
    }

    final image = remoteUrl.isNotEmpty
        ? SizedNetworkImage(
            url: remoteUrl,
            fit: BoxFit.cover,
            width: size,
            height: size,
            error: fallback(),
          )
        : fallback();

    return ClipOval(
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  static Widget _fallbackIcon(double size) {
    return ColoredBox(
      color: AppColors.surface,
      child: Icon(
        Icons.fastfood_rounded,
        size: size * 0.38,
        color: AppColors.primary,
      ),
    );
  }
}
