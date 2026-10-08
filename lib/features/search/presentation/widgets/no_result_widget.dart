import 'package:flutter/material.dart';

class NoResultWidget extends StatelessWidget {
  final String? query;
  final VoidCallback? onClear;

  /// Overrides the default heading / message — used when nothing is found
  /// because of the delivery location rather than the search words.
  final String? title;
  final String? message;

  const NoResultWidget({
    super.key,
    this.query,
    this.onClear,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 20),

            Text(
              title ?? 'No Results Found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message ??
                  (query == null || query!.trim().isEmpty
                      ? 'Try searching for restaurants or foods.'
                      : 'No results found for "$query".'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            if (onClear != null)
              FilledButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.refresh),
                label: const Text('Clear Search'),
              ),
          ],
        ),
      ),
    );
  }
}
