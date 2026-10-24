import 'package:flutter_test/flutter_test.dart';
import 'package:quick_recipe/additions/kitchen_repository.dart';

import 'support/fake_kitchen.dart';

FridgeItem egg({double amount = 2}) => FridgeItem(
  id: 'egg',
  name: 'Telur',
  amount: amount,
  unit: 'pcs',
  categoryId: 'protein',
);
void main() {
  test('Stock usage validates quantities and preserves decimal precision', () {
    expect(
      remainingStock(
        egg(),
        const StockUse(itemId: 'egg', amount: 0.125, unit: 'pcs'),
      ),
      1.875,
    );
    expect(
      remainingStock(
        egg(),
        const StockUse(itemId: 'egg', amount: 2, unit: 'pcs'),
      ),
      0,
    );
    for (final amount in [0.0, -1.0, 3.0, double.nan]) {
      expect(
        () => remainingStock(
          egg(),
          StockUse(itemId: 'egg', amount: amount, unit: 'pcs'),
        ),
        throwsStateError,
      );
    }
    expect(
      () => remainingStock(
        egg(),
        const StockUse(itemId: 'egg', amount: 1, unit: 'g'),
      ),
      throwsStateError,
    );
    expect(positiveAmount('0.0001'), isNotNull);
    expect(positiveAmount('0', allowZero: true), isNull);
  });
  test('Repeated stock operation only deducts once', () async {
    final repo = FakeKitchen()..items = [egg()];
    const usage = [StockUse(itemId: 'egg', amount: 1, unit: 'pcs')];
    await repo.useStock('op', usage);
    await repo.useStock('op', usage);
    expect(repo.items.single.amount, 1);
  });
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
    final match = IngredientMatch(['Egg', 'Cooked rice'], [egg()]);
    expect(match.present, ['Egg']);
    expect(match.missing, ['Cooked rice']);
    expect(match.ratio, .5);
  });
  test('Empty stock does not contribute to a match', () {
    final match = IngredientMatch(['Egg'], [egg(amount: 0)]);
    expect(match.present, isEmpty);
    expect(match.ratio, 0);
  });
  test('Legacy dates are ignored and omitted on next save', () {
    final item = FridgeItem.fromMap('egg', {
      ...egg().toMap(),
      'expiry': '2020-01-01',
    });
    expect(item.inStock, true);
    expect(item.toMap().containsKey('expiry'), false);
  });
  test(
    'Empty recipe match is finite',
    () => expect(IngredientMatch([], []).ratio, 0),
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
