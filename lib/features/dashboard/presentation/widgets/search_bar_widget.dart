import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO:
          // Navigate to Search Screen
        },
        child: IgnorePointer(
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search food, restaurants...",
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),

              prefixIcon: const Icon(
                Icons.search_rounded,
              ),

              suffixIcon: IconButton(
                onPressed: null,
                icon: const Icon(
                  Icons.mic_none_rounded,
                ),
              ),

              filled: true,
              fillColor: theme.colorScheme.surface,

              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}