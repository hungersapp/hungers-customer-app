import 'package:flutter/material.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({
    super.key,
    required this.foodName,
    required this.restaurantName,
    required this.price,
    required this.rating,
    this.imageUrl,
    this.isVeg = true,
    this.isFavorite = false,
    this.offerText,
    this.onTap,
    this.onFavoriteTap,
    this.onAddTap,
  });

  final String foodName;
  final String restaurantName;
  final String price;
  final double rating;

  final String? imageUrl;
  final String? offerText;

  final bool isVeg;
  final bool isFavorite;

  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 180,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// Image
              Stack(
                children: [

                  AspectRatio(
                    aspectRatio: 1.35,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(
                                Icons.fastfood,
                                size: 55,
                              ),
                            ),
                          ),
                  ),

                  if (offerText != null)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          offerText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onFavoriteTap,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      Row(
                        children: [

                          Icon(
                            isVeg
                                ? Icons.circle
                                : Icons.change_history,
                            color: isVeg
                                ? Colors.green
                                : Colors.red,
                            size: 14,
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              foodName,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: theme
                                  .textTheme.titleSmall
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),

                      const Spacer(),

                      Row(
                        children: [

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius:
                                  BorderRadius.circular(
                                      5),
                            ),
                            child: Row(
                              children: [

                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 12,
                                ),

                                const SizedBox(width: 2),

                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          Text(
                            price,
                            style: theme
                                .textTheme.titleMedium
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onAddTap,
                          child: const Text("ADD"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}