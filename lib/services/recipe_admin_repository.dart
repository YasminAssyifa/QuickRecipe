import 'package:cloud_firestore/cloud_firestore.dart';

const recipeCollection = 'Complete-Flutter-App';
const categoryCollection = 'App-Category';
const recipeTags = ['vegetarian', 'pedas', 'hemat', 'bekal', 'ramah-anak'];
const recipeAllergens = ['telur', 'susu', 'kacang', 'seafood', 'gluten'];

/// Recipe fields edited in the admin form. Ingredient amounts are grams for
/// one serving, the format every recipe in the catalog uses.
class RecipeDraft {
  const RecipeDraft({
    required this.name,
    required this.category,
    required this.image,
    required this.calories,
    required this.minutes,
    required this.ingredients,
    required this.amounts,
    required this.steps,
    this.tags = const [],
    this.allergens = const [],
    this.imageAttribution = '',
    this.calorieNote = '',
  });

  factory RecipeDraft.fromMap(Map<String, dynamic> data) => RecipeDraft(
    name: '${data['name'] ?? ''}',
    category: '${data['category'] ?? ''}',
    image: '${data['image'] ?? ''}',
    calories:
        int.tryParse(
          RegExp(r'\d+').stringMatch('${data['cal'] ?? ''}') ?? '',
        ) ??
        0,
    minutes: data['time'] is num ? (data['time'] as num).round() : 0,
    ingredients: List<String>.from(data['ingredientsName'] ?? const []),
    amounts: [
      for (final value in (data['ingredientsAmount'] as List?) ?? const [])
        value is num ? value : num.tryParse('$value') ?? 0,
    ],
    steps: List<String>.from(data['step'] ?? const []),
    tags: List<String>.from(data['tags'] ?? const []),
    allergens: List<String>.from(data['allergens'] ?? const []),
    imageAttribution: '${data['imageAttribution'] ?? ''}',
    calorieNote: '${data['calorieNote'] ?? ''}',
  );

  final String name, category, image, imageAttribution, calorieNote;
  final int calories, minutes;
  final List<String> ingredients, steps, tags, allergens;
  final List<num> amounts;

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'category': category,
    'image': image.trim(),
    'cal': calories,
    'time': minutes,
    'ingredientsName': ingredients,
    'ingredientsAmount': amounts,
    'step': steps,
    'tags': tags,
    'allergens': allergens,
    'imageAttribution': imageAttribution.trim(),
    'calorieNote': calorieNote.trim(),
  };
}

/// Category names a recipe can have. The "All" entry in App-Category is only
/// the filter chip on the Home screen, so it is left out.
List<String> recipeCategories(Iterable<String> names) =>
    names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty && name.toLowerCase() != 'all')
        .toSet()
        .toList()
      ..sort();

abstract class RecipeAdminRepository {
  Future<List<String>> categories();
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes();

  /// Whether another recipe already uses [image]. The image URL is the hero
  /// tag of a recipe, so it must be unique.
  Future<bool> imageInUse(String image, {String? exceptId});
  Future<void> create(RecipeDraft draft);
  Future<void> update(String id, RecipeDraft draft);
  Future<void> delete(String id);
  Future<DashboardData> dashboard();
}

class FirebaseRecipeAdminRepository implements RecipeAdminRepository {
  FirebaseRecipeAdminRepository(this.uid);
  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _recipes =>
      _db.collection(recipeCollection);

  @override
  Future<List<String>> categories() async {
    final snapshot = await _db
        .collection(categoryCollection)
        .get(const GetOptions(source: Source.server));
    return recipeCategories([
      for (final doc in snapshot.docs) '${doc.data()['name'] ?? ''}',
    ]);
  }

  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes() async {
    final snapshot = await _recipes.get(
      const GetOptions(source: Source.server),
    );
    return snapshot.docs.toList()..sort(
      (a, b) => '${a.data()['name']}'.toLowerCase().compareTo(
        '${b.data()['name']}'.toLowerCase(),
      ),
    );
  }

  @override
  Future<bool> imageInUse(String image, {String? exceptId}) async {
    final snapshot = await _recipes
        .where('image', isEqualTo: image.trim())
        .limit(2)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.any((doc) => doc.id != exceptId);
  }

  @override
  Future<void> create(RecipeDraft draft) => _recipes.doc().set({
    ...draft.toMap(),
    'servings': 1,
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  });

  @override
  Future<void> update(String id, RecipeDraft draft) => _recipes.doc(id).update({
    ...draft.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': uid,
  });

  @override
  Future<void> delete(String id) => _recipes.doc(id).delete();

  @override
  Future<DashboardData> dashboard() async {
    const server = GetOptions(source: Source.server);
    final results = await Future.wait([
      _recipes.get(server),
      categories(),
      _db.collection('users').count().get(),
      _db.collectionGroup('favorites').get(server),
    ]);
    final recipes = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final favorites = results[3] as QuerySnapshot<Map<String, dynamic>>;
    return DashboardData.from(
      recipes: [for (final doc in recipes.docs) doc.data()],
      recipeIds: [for (final doc in recipes.docs) doc.id],
      categories: results[1] as List<String>,
      users: (results[2] as AggregateQuerySnapshot).count ?? 0,
      favoriteIds: [for (final doc in favorites.docs) doc.id],
      now: DateTime.now(),
    );
  }
}

enum InsightKind { category, mostSaved, unsaved, incomplete }

class DashboardInsight {
  const DashboardInsight(this.kind, this.title, this.description);
  final InsightKind kind;
  final String title, description;
}

/// Numbers and insights shown on the admin dashboard.
class DashboardData {
  const DashboardData({
    required this.recipes,
    required this.categories,
    required this.users,
    required this.newThisWeek,
    required this.insights,
  });

  /// Builds the dashboard from the catalog. [favoriteIds] holds one recipe id
  /// per saved favorite across all users.
  factory DashboardData.from({
    required List<Map<String, dynamic>> recipes,
    required List<String> recipeIds,
    required List<String> categories,
    required int users,
    required List<String> favoriteIds,
    required DateTime now,
  }) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final newThisWeek = recipes.where((recipe) {
      final created = recipe['createdAt'];
      return created is Timestamp && created.toDate().isAfter(weekAgo);
    }).length;

    final perCategory = {for (final name in categories) name: 0};
    for (final recipe in recipes) {
      final category = '${recipe['category'] ?? ''}';
      if (perCategory.containsKey(category)) {
        perCategory[category] = perCategory[category]! + 1;
      }
    }
    final names = {
      for (var i = 0; i < recipes.length; i++)
        recipeIds[i]: '${recipes[i]['name'] ?? 'Untitled recipe'}',
    };
    final saves = <String, int>{};
    for (final id in favoriteIds) {
      if (names.containsKey(id)) saves[id] = (saves[id] ?? 0) + 1;
    }
    final unsaved = names.keys.where((id) => !saves.containsKey(id)).length;
    final incomplete = recipes
        .where((recipe) => !_complete(recipe, categories))
        .length;

    return DashboardData(
      recipes: recipes.length,
      categories: categories.length,
      users: users,
      newThisWeek: newThisWeek,
      insights: [
        _categoryInsight(perCategory),
        _savedInsight(saves, names),
        DashboardInsight(
          InsightKind.unsaved,
          unsaved == 0
              ? 'Every recipe has been saved'
              : '${_count(unsaved, 'recipe has', 'recipes have')} no favorites yet',
          unsaved == 0
              ? 'Each recipe is in at least one favorite list.'
              : 'Consider reviewing their names and photos.',
        ),
        DashboardInsight(
          InsightKind.incomplete,
          incomplete == 0
              ? 'All recipes are complete'
              : '${_count(incomplete, 'recipe is', 'recipes are')} incomplete',
          incomplete == 0
              ? 'Every recipe has an image, steps and ingredient amounts.'
              : 'Some recipes are missing images, steps, amounts or a valid category.',
        ),
      ],
    );
  }

  final int recipes, categories, users, newThisWeek;
  final List<DashboardInsight> insights;

  static String _count(int value, String one, String many) =>
      '$value ${value == 1 ? one : many}';

  static bool _complete(Map<String, dynamic> recipe, List<String> categories) {
    final ingredients = recipe['ingredientsName'];
    final amounts = recipe['ingredientsAmount'];
    final steps = recipe['step'];
    final calories = int.tryParse(
      RegExp(r'\d+').stringMatch('${recipe['cal'] ?? ''}') ?? '',
    );
    return '${recipe['image'] ?? ''}'.startsWith('http') &&
        categories.contains(recipe['category']) &&
        recipe['time'] is num &&
        (recipe['time'] as num) > 0 &&
        calories != null &&
        calories > 0 &&
        ingredients is List &&
        ingredients.length >= 2 &&
        amounts is List &&
        amounts.length == ingredients.length &&
        amounts.every((amount) => amount is num && amount > 0) &&
        steps is List &&
        steps.isNotEmpty;
  }

  static DashboardInsight _categoryInsight(Map<String, int> perCategory) {
    if (perCategory.isEmpty) {
      return const DashboardInsight(
        InsightKind.category,
        'No categories yet',
        'Add categories so users can filter recipes.',
      );
    }
    final smallest = perCategory.entries.reduce(
      (a, b) => b.value < a.value ? b : a,
    );
    return DashboardInsight(
      InsightKind.category,
      smallest.value == 0
          ? '${smallest.key} has no recipes yet'
          : '${smallest.key} has only ${_count(smallest.value, 'recipe', 'recipes')}',
      'Add more ${smallest.key} recipes to balance the catalog.',
    );
  }

  static DashboardInsight _savedInsight(
    Map<String, int> saves,
    Map<String, String> names,
  ) {
    if (saves.isEmpty) {
      return const DashboardInsight(
        InsightKind.mostSaved,
        'No saved recipes yet',
        'Users have not added any recipe to their favorites.',
      );
    }
    final top = saves.entries.reduce((a, b) => b.value > a.value ? b : a);
    return DashboardInsight(
      InsightKind.mostSaved,
      'Most saved: ${names[top.key]}',
      'This recipe has been saved by ${_count(top.value, 'user', 'users')}.',
    );
  }
}
