import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quick_recipe/services/recipe_admin_repository.dart';

import 'fake_kitchen.dart';

class FakeRecipeAdmin implements RecipeAdminRepository {
  List<String> names = ['Dinner', 'Lunch', 'Snack'];
  List<TestRecipe> catalog = [];
  final created = <RecipeDraft>[];
  final updated = <String, RecipeDraft>{};
  final deleted = <String>[];
  bool imageTaken = false, failLoad = false, failSave = false;

  @override
  Future<List<String>> categories() async {
    if (failLoad) throw StateError('Offline');
    return List.of(names);
  }

  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes() async {
    if (failLoad) throw StateError('Offline');
    return List.of(catalog);
  }

  @override
  Future<bool> imageInUse(String image, {String? exceptId}) async => imageTaken;

  @override
  Future<void> create(RecipeDraft draft) async {
    if (failSave) throw StateError('Offline');
    created.add(draft);
  }

  @override
  Future<void> update(String id, RecipeDraft draft) async {
    if (failSave) throw StateError('Offline');
    updated[id] = draft;
  }

  @override
  Future<void> delete(String id) async {
    if (failSave) throw StateError('Offline');
    deleted.add(id);
    catalog.removeWhere((recipe) => recipe.id == id);
  }
}
