import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quick_recipe/additions/kitchen_repository.dart';

class TestRecipe implements DocumentSnapshot<Map<String, dynamic>> {
  TestRecipe(this.id, this.fields);
  @override
  final String id;
  final Map<String, dynamic> fields;
  @override
  Map<String, dynamic> data() => fields;
  @override
  bool get exists => true;
  @override
  dynamic operator [](Object field) => fields[field];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeKitchen implements KitchenRepository {
  List<FridgeItem> items = [];
  List<RecipeCollection> folders = [];
  List<DocumentSnapshot<Map<String, dynamic>>> catalog = [
    TestRecipe('recipe-1', {
      'name': 'Egg rice',
      'ingredientsName': ['Egg', 'Cooked rice'],
    }),
  ];
  int saveCount = 0, reads = 0, serial = 0;
  bool fail = false;
  Completer<void>? pendingSave;
  @override
  String newId(String module) => 'test-${serial++}';
  @override
  Future<List<FridgeItem>> fridge() async {
    reads++;
    if (fail) throw StateError('Offline');
    return List.of(items);
  }

  @override
  Future<List<RecipeCollection>> collections() async {
    if (fail) throw StateError('Offline');
    return List.of(folders);
  }

  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes() async =>
      List.of(catalog);
  @override
  Future<void> saveFridge(FridgeItem item, {required bool create}) async {
    saveCount++;
    if (pendingSave != null) await pendingSave!.future;
    if (fail) throw StateError('Offline');
    items.removeWhere((old) => old.id == item.id);
    items.add(item);
  }

  @override
  Future<void> saveCollection(
    RecipeCollection item, {
    required bool create,
  }) async {
    saveCount++;
    if (pendingSave != null) await pendingSave!.future;
    if (fail) throw StateError('Offline');
    folders.removeWhere((old) => old.id == item.id);
    folders.add(item);
  }

  @override
  Future<void> delete(String module, String id) async {
    if (fail) throw StateError('Offline');
    if (module == 'fridge') items.removeWhere((item) => item.id == id);
    if (module == 'collections') folders.removeWhere((item) => item.id == id);
  }
}
