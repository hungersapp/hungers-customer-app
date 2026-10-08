import 'package:flutter/material.dart';

import '../../../../core/widgets/sized_network_image.dart';
import '../../domain/entities/search_result_entity.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResultEntity result;
  final VoidCallback? onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: result.imageUrl.isNotEmpty
            ? SizedNetworkImage(
                url: result.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                error: _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Text(
        result.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        result.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        switch (result.type) {
          SearchResultType.restaurant => Icons.storefront,
          SearchResultType.food => Icons.fastfood,
          SearchResultType.category => Icons.grid_view_rounded,
        },
        color: Theme.of(context).colorScheme.primary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.restaurant,
        color: Colors.grey,
      ),
    );
  }
}