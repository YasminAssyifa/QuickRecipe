import 'package:cloud_firestore/cloud_firestore.dart';

const foodGroups = {
  'produce': 'Vegetables & fruit',
  'protein': 'Meat, eggs & tofu',
  'dairy': 'Dairy',
  'grains': 'Rice, bread & noodles',
  'other': 'Other',
};
const ingredientUnits = ['g', 'kg', 'ml', 'l', 'pcs'];

String ingredientKey(String name) {
  final value = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const aliases = {
    'telur': 'egg',
    'eggs': 'egg',
    'bawang putih': 'garlic',
    'ayam': 'chicken',
    'chicken breast': 'chicken',
    'tahu': 'tofu',
    'tempe': 'tempeh',
    'nasi': 'cooked rice',
    'beras': 'rice',
    'mie': 'noodles',
    'mi': 'noodles',
    'egg noodles': 'noodles',
    'bayam': 'spinach',
    'wortel': 'carrot',
    'tomat': 'tomato',
    'kentang': 'potato',
    'jagung': 'corn',
    'kol': 'cabbage',
    'susu': 'milk',
    'pisang': 'banana',
    'tepung': 'flour',
    'roti': 'bread',
    'mentega': 'butter',
    'gula': 'sugar',
    'minyak': 'cooking oil',
    'kecap asin': 'soy sauce',
    'kecap manis': 'sweet soy sauce',
    'air': 'water',
  };
  return aliases[value] ?? value;
}

class FridgeItem {
  const FridgeItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.categoryId,
    required this.expiry,
    this.notes = '',
  });
  final String id, name, unit, categoryId, notes;
  final double amount;
  final DateTime expiry;
  bool expiredAt(DateTime day) =>
      expiry.isBefore(DateTime(day.year, day.month, day.day));
  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'ingredientId': ingredientKey(name),
    'amount': amount,
    'unit': unit,
    'categoryId': categoryId,
    'expiry': dateText(expiry),
    'notes': notes.trim(),
  };
  factory FridgeItem.fromMap(String id, Map<String, dynamic> data) =>
      FridgeItem(
        id: id,
        name: data['name'] as String,
        amount: (data['amount'] as num).toDouble(),
        unit: data['unit'] as String,
        categoryId: data['categoryId'] as String,
        expiry: DateTime.parse(data['expiry'] as String),
        notes: data['notes'] as String? ?? '',
      );
}

class RecipeCollection {
  const RecipeCollection({
    required this.id,
    required this.name,
    this.notes = '',
    this.recipeIds = const [],
  });
  final String id, name, notes;
  final List<String> recipeIds;
  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'notes': notes.trim(),
    'recipeIds': recipeIds.toSet().toList(),
  };
  factory RecipeCollection.fromMap(String id, Map<String, dynamic> data) =>
      RecipeCollection(
        id: id,
        name: data['name'] as String,
        notes: data['notes'] as String? ?? '',
        recipeIds: List<String>.from(data['recipeIds'] ?? []),
      );
}

String dateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String? requiredName(String? value) => (value ?? '').trim().isEmpty
    ? 'Please enter a name.'
    : value!.trim().length > 60
    ? 'Use no more than 60 characters.'
    : null;
String? positiveAmount(String? value) {
  final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
  return amount == null || !amount.isFinite || amount <= 0 || amount > 100000
      ? 'Enter a quantity greater than 0 and at most 100000.'
      : null;
}

class IngredientMatch {
  IngredientMatch(
    List<String> ingredients,
    List<FridgeItem> fridge,
    DateTime today,
  ) {
    final available = fridge
        .where((item) => !item.expiredAt(today))
        .map((item) => ingredientKey(item.name))
        .toSet();
    for (final ingredient in ingredients) {
      (available.contains(ingredientKey(ingredient)) ? present : missing).add(
        ingredient,
      );
    }
  }
  final List<String> present = [], missing = [];
  double get ratio => present.isEmpty && missing.isEmpty
      ? 0
      : present.length / (present.length + missing.length);
}

abstract class KitchenRepository {
  String newId(String module);
  Future<List<FridgeItem>> fridge();
  Future<List<RecipeCollection>> collections();
  Future<void> saveFridge(FridgeItem item, {required bool create});
  Future<void> saveCollection(RecipeCollection item, {required bool create});
  Future<void> delete(String module, String id);
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes();
}

class FirebaseKitchenRepository implements KitchenRepository {
  FirebaseKitchenRepository(this.uid);
  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _ref(String module) =>
      _db.collection('users').doc(uid).collection(module);
  @override
  String newId(String module) => _ref(module).doc().id;
  @override
  Future<List<FridgeItem>> fridge() async {
    final snapshot = await _ref('fridge')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => FridgeItem.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.expiry.compareTo(b.expiry));
  }

  @override
  Future<List<RecipeCollection>> collections() async {
    final snapshot = await _ref('collections')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => RecipeCollection.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _save(
    String module,
    String id,
    Map<String, dynamic> data,
    bool create,
  ) async {
    final ref = _ref(module).doc(id);
    await _db.runTransaction(
      (transaction) async {
        final existing = await transaction.get(ref);
        if (!create && !existing.exists) {
          throw StateError(
            'This item was removed. Return to the list and refresh.',
          );
        }
        if (create && existing.exists) return;
        transaction.set(ref, {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
      timeout: const Duration(seconds: 20),
      maxAttempts: 3,
    );
  }

  @override
  Future<void> saveFridge(FridgeItem item, {required bool create}) =>
      _save('fridge', item.id, item.toMap(), create);
  @override
  Future<void> saveCollection(RecipeCollection item, {required bool create}) =>
      _save('collections', item.id, item.toMap(), create);
  @override
  Future<void> delete(String module, String id) async {
    if (!['fridge', 'collections'].contains(module)) {
      throw ArgumentError('Invalid module');
    }
    final ref = _ref(module).doc(id);
    await _db.runTransaction(
      (transaction) async {
        await transaction.get(ref);
        transaction.delete(ref);
      },
      timeout: const Duration(seconds: 20),
      maxAttempts: 3,
    );
  }

  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes() async =>
      (await _db
              .collection('Complete-Flutter-App')
              .get(const GetOptions(source: Source.server)))
          .docs;
}

enum DemoScenario { normal, empty, failure }

class FridgeDemoRepository {
  const FridgeDemoRepository(
    this.source, {
    this.delay = const Duration(milliseconds: 900),
  });
  final KitchenRepository source;
  final Duration delay;
  Future<List<FridgeItem>> load(DemoScenario scenario) async {
    await Future<void>.delayed(delay);
    if (scenario == DemoScenario.failure) {
      throw StateError(
        'Demo connection failure. Tap Try again to load your Firestore data.',
      );
    }
    if (scenario == DemoScenario.empty) return [];
    return source.fridge();
  }
}
