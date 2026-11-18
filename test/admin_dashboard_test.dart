import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/services/recipe_admin_repository.dart';
import 'package:quick_recipe/screens/admin_main_screen.dart';

import 'support/fake_kitchen.dart';
import 'support/fake_recipe_admin.dart';

Map<String, dynamic> complete(
  String name,
  String category, {
  Object? createdAt,
}) => {
  'name': name,
  'category': category,
  'image': 'https://example.com/$name.jpg',
  'cal': 300,
  'time': 20,
  'ingredientsName': ['Tempe', 'Kecap manis'],
  'ingredientsAmount': [120, 15],
  'step': ['Tumis.'],
  'createdAt': ?createdAt,
};

void main() {
  final now = DateTime(2026, 11, 16);

  test('Dashboard counts and insights come from the catalog', () {
    final data = DashboardData.from(
      recipes: [
        complete(
          'Tempe Orek',
          'Dinner',
          createdAt: Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        ),
        complete(
          'Tahu Kecap',
          'Dinner',
          createdAt: Timestamp.fromDate(now.subtract(const Duration(days: 10))),
        ),
        complete('Pancake', 'Snack'),
        {
          ...complete('Puding', 'Dessert'),
          'ingredientsName': ['Susu'],
          'ingredientsAmount': [200],
          'cal': '200',
        },
      ],
      recipeIds: ['a', 'b', 'c', 'd'],
      categories: ['Breakfast', 'Dessert', 'Dinner', 'Snack'],
      users: 14,
      favoriteIds: ['a', 'a', 'b', 'gone'],
      now: now,
    );
    expect(data.recipes, 4);
    expect(data.categories, 4);
    expect(data.users, 14);
    expect(data.newThisWeek, 1);
    expect(data.insights.map((i) => i.title), [
      'Breakfast has no recipes yet',
      'Most saved: Tempe Orek',
      '2 recipes have no favorites yet',
      '1 recipe is incomplete',
    ]);
    expect(
      data.insights[1].description,
      'This recipe has been saved by 2 users.',
    );
  });

  test('Dashboard insights handle an empty catalog', () {
    final data = DashboardData.from(
      recipes: const [],
      recipeIds: const [],
      categories: const [],
      users: 0,
      favoriteIds: const [],
      now: now,
    );
    expect(data.insights.map((i) => i.title), [
      'No categories yet',
      'No saved recipes yet',
      'Every recipe has been saved',
      'All recipes are complete',
    ]);
  });

  testWidgets('Dashboard shows live numbers and retries after an error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRecipeAdmin()
      ..failLoad = true
      ..users = 7
      ..names = ['Dinner', 'Snack']
      ..catalog = [TestRecipe('a', complete('Tempe Orek', 'Dinner'))]
      ..favoriteIds = ['a'];
    await tester.pumpWidget(
      Provider<RecipeAdminRepository?>.value(
        value: repo,
        child: const MaterialApp(home: AdminMainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load dashboard'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(4));
    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Snack has no recipes yet'), findsOneWidget);
    expect(find.text('Most saved: Tempe Orek'), findsOneWidget);
    expect(find.text('Every recipe has been saved'), findsOneWidget);
    expect(find.text('All recipes are complete'), findsOneWidget);
  });
}
