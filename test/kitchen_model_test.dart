import 'package:flutter_test/flutter_test.dart';
import 'package:quick_recipe/additions/kitchen_repository.dart';

import 'support/fake_kitchen.dart';

FridgeItem egg({DateTime? expiry}) => FridgeItem(
  id: 'egg',
  name: 'Telur',
  amount: 2,
  unit: 'pcs',
  categoryId: 'protein',
  expiry: expiry ?? DateTime(2030),
);
void main() {
  for (final input in ['', '0', '-1', 'NaN', 'Infinity', 'text', '100001']) {
    test(
      'Quantity rejects "$input"',
      () => expect(positiveAmount(input), isNotNull),
    );
  }
  test('Quantity accepts decimal comma and positive number', () {
    expect(positiveAmount('1,5'), isNull);
    expect(positiveAmount('100'), isNull);
  });
  test('Names reject whitespace and oversized input', () {
    expect(requiredName('  '), isNotNull);
    expect(requiredName('a' * 61), isNotNull);
    expect(requiredName('Egg'), isNull);
  });
  test('Ingredient aliases normalize Indonesian and English', () {
    expect(ingredientKey(' TELUR '), 'egg');
    expect(ingredientKey('Bawang   putih'), 'garlic');
  });
  test('Fridge data roundtrip preserves quantity and ID relation', () {
    final item = egg();
    final restored = FridgeItem.fromMap(item.id, item.toMap());
    expect(restored.amount, 2);
    expect(item.toMap()['ingredientId'], 'egg');
    expect(restored.categoryId, 'protein');
  });
  test('Collection IDs are deduplicated on serialization', () {
    const folder = RecipeCollection(
      id: 'c',
      name: 'Dinner',
      recipeIds: ['r', 'r'],
    );
    expect(folder.toMap()['recipeIds'], ['r']);
  });
  test('Matching separates available and missing ingredients', () {
    final match = IngredientMatch(
      ['Egg', 'Cooked rice'],
      [egg()],
      DateTime(2026),
    );
    expect(match.present, ['Egg']);
    expect(match.missing, ['Cooked rice']);
    expect(match.ratio, .5);
  });
  test('Expired ingredients do not contribute to a match', () {
    final match = IngredientMatch(
      ['Egg'],
      [egg(expiry: DateTime(2025))],
      DateTime(2026),
    );
    expect(match.present, isEmpty);
    expect(match.ratio, 0);
  });
  test('Ingredients remain usable on their use-by date', () {
    expect(
      egg(expiry: DateTime(2026, 9, 30)).expiredAt(DateTime(2026, 9, 30, 20)),
      false,
    );
  });
  test(
    'Empty recipe match is finite',
    () => expect(IngredientMatch([], [], DateTime(2026)).ratio, 0),
  );
  test('Demo empty does not change repository data', () async {
    final repo = FakeKitchen()..items = [egg()];
    expect(
      await FridgeDemoRepository(
        repo,
        delay: Duration.zero,
      ).load(DemoScenario.empty),
      isEmpty,
    );
    expect(repo.items, hasLength(1));
    expect(repo.reads, 0);
  });
  test('Demo failure retries real repository without mutation', () async {
    final repo = FakeKitchen()..items = [egg()];
    final demo = FridgeDemoRepository(repo, delay: Duration.zero);
    await expectLater(demo.load(DemoScenario.failure), throwsStateError);
    expect(await demo.load(DemoScenario.normal), hasLength(1));
    expect(repo.saveCount, 0);
  });
}
