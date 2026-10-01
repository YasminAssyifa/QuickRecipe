import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/additions/kitchen_repository.dart';
import 'package:quick_recipe/additions/fridge_screen.dart';
import 'package:quick_recipe/additions/collection_screens.dart';
import 'package:quick_recipe/additions/recipe_matches_screen.dart';
import 'package:quick_recipe/additions/ai_access.dart';

import 'support/fake_kitchen.dart';

FridgeItem sample() => FridgeItem(
  id: 'egg',
  name: 'Egg',
  amount: 2,
  unit: 'pcs',
  categoryId: 'protein',
  expiry: DateTime(2030),
);
Widget host(FakeKitchen repo, Widget child) =>
    Provider<KitchenRepository?>.value(
      value: repo,
      child: MaterialApp(home: child),
    );
Future<void> click(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Fridge empty state provides add ingredient action', (
    tester,
  ) async {
    await tester.pumpWidget(host(FakeKitchen(), const FridgeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Your fridge is empty'), findsOneWidget);
    await click(tester, 'Add ingredient');
    expect(find.text('Ingredient name'), findsOneWidget);
  });
  testWidgets('Fridge form rejects empty mandatory fields', (tester) async {
    final repo = FakeKitchen();
    await tester.pumpWidget(host(repo, const FridgeFormScreen()));
    await click(tester, 'Save ingredient');
    expect(find.text('Please enter a name.'), findsOneWidget);
    expect(find.text('Select a use-by date.'), findsOneWidget);
    expect(repo.saveCount, 0);
  });
  testWidgets(
    'Fridge form writes selected values and disables repeated submit',
    (tester) async {
      final repo = FakeKitchen()..pendingSave = Completer<void>();
      await tester.pumpWidget(host(repo, FridgeFormScreen(item: sample())));
      await tester.enterText(find.byType(TextFormField).at(0), 'Garlic');
      await tester.enterText(find.byType(TextFormField).at(1), '1,5');
      final button = find.widgetWithText(ElevatedButton, 'Save ingredient');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(repo.saveCount, 1);
      repo.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(repo.items.single.name, 'Garlic');
      expect(repo.items.single.amount, 1.5);
    },
  );
  testWidgets('Fridge save failure keeps entered values for retry', (
    tester,
  ) async {
    final repo = FakeKitchen()..fail = true;
    await tester.pumpWidget(host(repo, FridgeFormScreen(item: sample())));
    await click(tester, 'Save ingredient');
    expect(find.text('Offline'), findsOneWidget);
    expect(repo.items, isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Egg',
    );
  });
  testWidgets('Fridge deletion supports cancel and confirmation', (
    tester,
  ) async {
    final repo = FakeKitchen()..items = [sample()];
    await tester.pumpWidget(host(repo, const FridgeScreen()));
    await tester.pumpAndSettle();
    await click(tester, 'Delete');
    await click(tester, 'Cancel');
    expect(repo.items, hasLength(1));
    await click(tester, 'Delete');
    await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
    await tester.pumpAndSettle();
    expect(repo.items, isEmpty);
    expect(find.text('Your fridge is empty'), findsOneWidget);
  });
  testWidgets('Fridge demo failure retries Firestore source', (tester) async {
    final repo = FakeKitchen()..items = [sample()];
    await tester.pumpWidget(host(repo, const FridgeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Demo scenarios'));
    await tester.pumpAndSettle();
    await click(tester, 'Demo: failed loading');
    expect(find.text('Unable to load'), findsOneWidget);
    await click(tester, 'Try again');
    expect(find.text('Egg'), findsOneWidget);
    expect(repo.items, hasLength(1));
  });
  testWidgets('Collections empty action opens form and validates name', (
    tester,
  ) async {
    final repo = FakeKitchen();
    await tester.pumpWidget(host(repo, const CollectionsScreen()));
    await tester.pumpAndSettle();
    await click(tester, 'Create collection');
    await click(tester, 'Save collection');
    expect(repo.saveCount, 0);
    expect(find.text('Please enter a name.'), findsOneWidget);
  });
  testWidgets('Collection saves recipe ID and name', (tester) async {
    final repo = FakeKitchen();
    await tester.pumpWidget(host(repo, const CollectionFormScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Quick dinners');
    await click(tester, 'Egg rice');
    await click(tester, 'Save collection');
    expect(repo.folders.single.recipeIds, ['recipe-1']);
    expect(repo.folders.single.name, 'Quick dinners');
  });
  testWidgets('Collection edit removes recipe without deleting catalog', (
    tester,
  ) async {
    final repo = FakeKitchen();
    const folder = RecipeCollection(
      id: 'c',
      name: 'Dinner',
      recipeIds: ['recipe-1'],
    );
    repo.folders = [folder];
    await tester.pumpWidget(
      host(repo, const CollectionFormScreen(item: folder)),
    );
    await tester.pumpAndSettle();
    await click(tester, 'Egg rice');
    await click(tester, 'Save collection');
    expect(repo.folders.single.recipeIds, isEmpty);
    expect(repo.catalog, hasLength(1));
  });
  testWidgets('Collection deletion preserves recipe catalog', (tester) async {
    final repo = FakeKitchen()
      ..folders = [
        const RecipeCollection(
          id: 'c',
          name: 'Dinner',
          recipeIds: ['recipe-1'],
        ),
      ];
    await tester.pumpWidget(host(repo, const CollectionsScreen()));
    await tester.pumpAndSettle();
    await click(tester, 'Delete');
    await click(tester, 'Delete');
    expect(repo.folders, isEmpty);
    expect(repo.catalog, hasLength(1));
  });
  testWidgets('Recipe matches show missing ingredients', (tester) async {
    await tester.pumpWidget(
      host(FakeKitchen(), RecipeMatchesScreen(fridge: [sample()])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available: Egg'), findsOneWidget);
    expect(find.text('Still needed: Cooked rice'), findsOneWidget);
  });
  testWidgets(
    'AI preview reports empty input and does not claim generated answer',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AiScreen()));
      await tester.tap(find.byTooltip('Preview message'));
      await tester.pump();
      expect(find.text('Type a question first.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Dinner ideas');
      await tester.tap(find.byTooltip('Preview message'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('AI answers'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('AI shortcut opens AI and hides on AI screen', (tester) async {
    aiShortcutVisible.value = true;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [AiRouteObserver()],
        builder: (_, child) => AiShortcutLayer(child: child!),
        home: const Scaffold(body: Text('Original screen')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(AiShortcutLayer),
            matching: find.byType(InkWell),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('QuickRecipe AI'), findsOneWidget);
    expect(find.bySemanticsLabel('Open QuickRecipe AI'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Original screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Form fits a small screen with keyboard inset', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(host(FakeKitchen(), const FridgeFormScreen()));
    await tester.scrollUntilVisible(
      find.text('Save ingredient'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
