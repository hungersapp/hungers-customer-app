import 'package:flutter/material.dart';

class RecentSearchWidget extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String>? onSearchTap;
  final VoidCallback? onClearAll;

  const RecentSearchWidget({
    super.key,
    required this.recentSearches,
    this.onSearchTap,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Searches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              if (onClearAll != null)
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Clear All'),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentSearches.map((search) {
              return ActionChip(
                avatar: const Icon(
                  Icons.history,
                  size: 18,
                ),
                label: Text(search),
                onPressed: () {
                  onSearchTap?.call(search);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}