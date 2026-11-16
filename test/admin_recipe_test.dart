import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/services/recipe_admin_repository.dart';
import 'package:quick_recipe/views/admin_add_recipe_screen.dart';

import 'support/fake_kitchen.dart';
import 'support/fake_recipe_admin.dart';

Widget adminHost(FakeRecipeAdmin repo, Widget child) =>
    Provider<RecipeAdminRepository?>.value(
      value: repo,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<bool>(builder: (_) => child),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

Future<void> open(
  WidgetTester tester,
  FakeRecipeAdmin repo,
  Widget child,
) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(adminHost(repo, child));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> fillValidRecipe(WidgetTester tester) async {
  await tester.enterText(field('Recipe Name'), 'Tempe Orek');
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dinner').last);
  await tester.pumpAndSettle();
  await tester.enterText(field('Image'), 'https://example.com/tempe.jpg');
  await tester.enterText(field('Calories (cal)'), '360');
  await tester.enterText(field('Cooking Time (min)'), '20');
  await tester.enterText(field('Ingredients Name'), 'Tempe\nKecap manis');
  await tester.enterText(field('Ingredients Amount (g)'), '120\n15');
  await tester.enterText(field('Cooking Steps'), 'Potong tempe.\nTumis.');
}

void main() {
  testWidgets('Add recipe saves numbers, tags and allergens', (tester) async {
    final repo = FakeRecipeAdmin();
    await open(tester, repo, const AdminAddRecipeScreen());
    await fillValidRecipe(tester);
    await tester.tap(find.text('Budget-friendly'));
    await tester.tap(find.text('Nuts'));
    await tester.pump();
    await tester.tap(find.text('Save Recipe'));
    await tester.pumpAndSettle();
    final draft = repo.created.single;
    expect(draft.name, 'Tempe Orek');
    expect(draft.category, 'Dinner');
    expect(draft.calories, 360);
    expect(draft.minutes, 20);
    expect(draft.ingredients, ['Tempe', 'Kecap manis']);
    expect(draft.amounts, [120, 15]);
    expect(draft.steps, hasLength(2));
    expect(draft.tags, ['hemat']);
    expect(draft.allergens, ['kacang']);
    expect(find.text('Recipe added.'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('Add recipe explains invalid numbers and amounts', (
    tester,
  ) async {
    final repo = FakeRecipeAdmin();
    await open(tester, repo, const AdminAddRecipeScreen());
    await fillValidRecipe(tester);
    await tester.enterText(field('Cooking Time (min)'), '30 min');
    await tester.enterText(field('Ingredients Amount (g)'), '2 siung\n15');
    await tester.enterText(field('Ingredients Name'), 'Tempe');
    await tester.tap(find.text('Save Recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Cooking time must be a whole number.'), findsOneWidget);
    expect(
      find.text('A recipe must have at least 2 ingredients.'),
      findsOneWidget,
    );
    expect(
      find.text('The number of ingredients and amounts must match.'),
      findsOneWidget,
    );
    await tester.enterText(field('Ingredients Name'), 'Tempe\nKecap manis');
    await tester.tap(find.text('Save Recipe'));
    await tester.pumpAndSettle();
    expect(
      find.text('Write each amount in grams as a number, for example 120.'),
      findsOneWidget,
    );
    expect(repo.created, isEmpty);
  });

  testWidgets('Add recipe rejects an image another recipe uses', (
    tester,
  ) async {
    final repo = FakeRecipeAdmin()..imageTaken = true;
    await open(tester, repo, const AdminAddRecipeScreen());
    await fillValidRecipe(tester);
    await tester.tap(find.text('Save Recipe'));
    await tester.pumpAndSettle();
    expect(
      find.text('Another recipe already uses this image URL.'),
      findsOneWidget,
    );
    expect(repo.created, isEmpty);
    expect(find.text('Add Recipe'), findsOneWidget);
  });

  testWidgets('Edit recipe fills older data and saves numbers', (tester) async {
    final repo = FakeRecipeAdmin();
    final legacy = TestRecipe('legacy', {
      'name': 'Puding',
      'category': 'Dessert',
      'image': 'https://example.com/puding.jpg',
      'cal': '200',
      'time': 10,
      'ingredientsName': ['Susu', 'Gula'],
      'ingredientsAmount': [200.0, 20],
      'step': ['Masak susu dan gula.'],
    });
    await open(tester, repo, AdminAddRecipeScreen(recipe: legacy));
    expect(find.text('Edit Recipe'), findsOneWidget);
    expect(find.text('Dessert'), findsOneWidget);
    expect(find.text('200'), findsWidgets);
    expect(find.text('200\n20'), findsOneWidget);
    await tester.tap(find.text('Kid-friendly'));
    await tester.tap(find.text('Milk'));
    await tester.pump();
    await tester.tap(find.text('Save Recipe'));
    await tester.pumpAndSettle();
    final draft = repo.updated['legacy']!;
    expect(draft.calories, 200);
    expect(draft.category, 'Dessert');
    expect(draft.tags, ['ramah-anak']);
    expect(draft.allergens, ['susu']);
    expect(find.text('Recipe updated.'), findsOneWidget);
  });

  testWidgets('Category load failure offers retry', (tester) async {
    final repo = FakeRecipeAdmin()..failLoad = true;
    await open(tester, repo, const AdminAddRecipeScreen());
    expect(find.text('Unable to load'), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Recipe Information'), findsOneWidget);
  });
}
