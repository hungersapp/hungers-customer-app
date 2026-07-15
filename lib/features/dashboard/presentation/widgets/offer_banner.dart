import 'package:flutter/material.dart';

class OfferBanner extends StatefulWidget {
  const OfferBanner({super.key});

  @override
  State<OfferBanner> createState() => _OfferBannerState();
}

class _OfferBannerState extends State<OfferBanner> {
  final PageController _pageController = PageController(
    viewportFraction: 0.94,
  );

  int _currentPage = 0;

  final List<_OfferItem> _offers = const [
    _OfferItem(
      title: "50% OFF",
      subtitle: "On your first order",
      icon: Icons.local_offer_rounded,
    ),
    _OfferItem(
      title: "Free Delivery",
      subtitle: "Orders above ₹199",
      icon: Icons.delivery_dining_rounded,
    ),
    _OfferItem(
      title: "Weekend Special",
      subtitle: "Up to ₹150 Cashback",
      icon: Icons.card_giftcard_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [

        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _offers.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (_, index) {
              final offer = _offers[index];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primaryContainer,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [

                            Text(
                              offer.title,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              offer.subtitle,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        offer.icon,
                        size: 60,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _offers.length,
            (index) {
              final selected = _currentPage == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin:
                    const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: selected ? 24 : 8,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _OfferItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OfferItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}