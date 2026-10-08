import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../search/presentation/pages/search_screen.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.search),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.search),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            );
          },
          child: IgnorePointer(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search for restaurants, dishes...',
                hintStyle: theme.textTheme.bodyMedium,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.search),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.search),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.search),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
