import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/dashboard/domain/entities/category.dart';
import 'package:customer_app/features/dashboard/presentation/widgets/category_section.dart';

void main() {
  testWidgets('category tap passes category id and name', (tester) async {
    Category? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategorySection(
            categories: const [
              Category(
                id: 'pizza',
                name: 'Pizza',
                imageUrl: '',
                isActive: true,
                displayOrder: 1,
              ),
              Category(
                id: 'burger',
                name: 'Burger',
                imageUrl: '',
                isActive: true,
                displayOrder: 2,
              ),
            ],
            onCategoryTap: (category) => tapped = category,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('home-category-pizza')));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.id, 'pizza');
    expect(tapped!.name, 'Pizza');
  });
}
