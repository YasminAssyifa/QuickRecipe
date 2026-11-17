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

abstract class RecipeAdminRepository {
  Future<List<String>> categories();
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes();

  /// Whether another recipe already uses [image]. The image URL is the hero
  /// tag of a recipe, so it must be unique.
  Future<bool> imageInUse(String image, {String? exceptId});
  Future<void> create(RecipeDraft draft);
  Future<void> update(String id, RecipeDraft draft);
  Future<void> delete(String id);
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
    return snapshot.docs
        .map((doc) => '${doc.data()['name'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
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
}
