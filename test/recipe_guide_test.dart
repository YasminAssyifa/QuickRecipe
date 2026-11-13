import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_recipe/additions/ai_chat.dart';
import 'package:quick_recipe/additions/intent_classifier.dart';
import 'package:quick_recipe/additions/kitchen_repository.dart';
import 'package:quick_recipe/additions/recipe_guide.dart';

import 'support/fake_kitchen.dart';

List<DocumentSnapshot<Map<String, dynamic>>> seedCatalog() => [
  for (final file in [
    'tools/seed_recipes.json',
    'tools/indonesian_recipes.json',
  ])
    for (final recipe
        in (jsonDecode(File(file).readAsStringSync())
                as Map<String, dynamic>)['Complete-Flutter-App']
            as List)
      TestRecipe(recipe['id'] as String, Map<String, dynamic>.from(recipe)),
];

FridgeItem item(String name, {double amount = 1}) => FridgeItem(
  id: name,
  name: name,
  amount: amount,
  unit: 'pcs',
  categoryId: 'other',
);

class BrokenCatalog extends FakeKitchen {
  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> recipes() async =>
      throw StateError('Offline');
}

void main() {
  final guide = RecipeGuide(
    classifier: IntentClassifier.parse(
      File('assets/ai/intent_model.json').readAsStringSync(),
    ),
    substitutes: SubstituteEntry.parse(
      File('assets/ai/substitutes.json').readAsStringSync(),
    ),
    random: math.Random(1),
  );
  final catalog = seedCatalog();
  var fridge = <FridgeItem>[];

  Future<AiReply> ask(
    String question, {
    MealPreference preference = MealPreference.none,
  }) => guide.answer(
    question,
    recipes: catalog,
    fridge: () async => fridge,
    preference: preference,
  );
  Map<String, dynamic> data(RecipeSuggestion s) => s.recipe.data()!;
  List<String> names(AiReply reply) => [
    for (final s in reply.recipes) data(s)['name'] as String,
  ];

  setUp(() => fridge = []);

  test(
    'Finds recipes by an Indonesian ingredient in either language',
    () async {
      final reply = await ask('masak apa pakai telur?');
      expect(reply.recipes, isNotEmpty);
      expect(reply.recipes.length, lessThanOrEqualTo(maxSuggestions));
      for (final s in reply.recipes) {
        final ingredients = List<String>.from(data(s)['ingredientsName']);
        expect(
          ingredients.map((name) => name.toLowerCase()),
          anyOf(contains('egg'), contains('telur')),
        );
      }
      expect(reply.text, startsWith('Ini resep untuk bahan telur'));
    },
  );

  test('Meal preference filters stay applied', () async {
    for (final (preference, check) in [
      (MealPreference.quick, (Map<String, dynamic> r) => r['time'] <= 30),
      (
        MealPreference.lowCalorie,
        (Map<String, dynamic> r) => int.parse(r['cal']) <= 400,
      ),
      (
        MealPreference.fewIngredients,
        (Map<String, dynamic> r) => (r['ingredientsName'] as List).length <= 5,
      ),
    ]) {
      final reply = await ask('resep pakai ayam', preference: preference);
      expect(reply.recipes, isNotEmpty, reason: '$preference');
      for (final s in reply.recipes) {
        expect(check(data(s)), isTrue, reason: '$preference ${data(s)}');
      }
    }
  });

  test('Reads minutes from the question', () async {
    final reply = await ask('resep yang 15 menit jadi');
    expect(reply.recipes, isNotEmpty);
    for (final s in reply.recipes) {
      expect(data(s)['time'], lessThanOrEqualTo(15));
    }
    expect(reply.text, contains('maksimal 15 menit'));
  });

  test('Fridge suggestions rank by available ingredients', () async {
    fridge = [item('Telur'), item('Nasi'), item('Bawang merah')];
    final reply = await ask('isi kulkasku bisa jadi apa');
    expect(names(reply).first, 'Nasi Goreng Telur');
    expect(
      reply.recipes.first.available,
      containsAll(['Nasi', 'Telur', 'Bawang merah']),
    );
    expect(reply.recipes.first.missing, isNotEmpty);
    expect(reply.text, contains('masih perlu'));
  });

  test(
    'Fridge preference turns a recipe question into a fridge search',
    () async {
      fridge = [item('Egg')];
      final reply = await ask(
        'resep yang cepat',
        preference: MealPreference.fridge,
      );
      expect(reply.recipes, isNotEmpty);
      expect(reply.recipes.every((s) => s.fromFridge), isTrue);
    },
  );

  test('An empty fridge is explained', () async {
    fridge = [item('Telur', amount: 0)];
    final reply = await ask('isi kulkasku bisa jadi apa');
    expect(reply.recipes, isEmpty);
    expect(reply.text, contains('Kulkasmu masih kosong'));
  });

  test('Answers recipe details from the catalog', () async {
    final calories = await ask('nasi goreng telur berapa kalori');
    expect(calories.text, contains('440 kkal'));
    expect(calories.text, isNot(contains('Waktu masak')));
    expect(names(calories), ['Nasi Goreng Telur']);

    final steps = await ask('cara buat pancake pisang');
    expect(names(steps), ['Banana Pancakes']);
    expect(steps.text, contains('Langkah:'));
    expect(steps.text, contains('1. '));

    final summary = await ask('info egg fried rice');
    expect(summary.text, contains('Kalori'));
    expect(summary.text, contains('Waktu masak'));
    expect(summary.text, contains('Bahan'));
  });

  test('Suggests substitutes and prefers the most specific name', () async {
    expect(
      (await ask('santan bisa diganti apa')).text,
      startsWith('Pengganti santan'),
    );
    expect(
      (await ask('tepung maizena gantinya apa')).text,
      startsWith('Pengganti maizena'),
    );
    expect(
      (await ask('gula merah bisa diganti gula pasir?')).text,
      startsWith('Pengganti gula merah'),
    );
    expect(
      (await ask('How can I replace milk?')).text,
      startsWith('Pengganti susu'),
    );
  });

  test('Greets, thanks and declines other topics', () async {
    expect((await ask('halo')).text, startsWith('Halo!'));
    expect((await ask('makasih ya')).text, 'Sama-sama! Selamat memasak.');
    final weather = await ask('cuaca besok gimana');
    expect(weather.text, startsWith('Maaf, aku hanya bisa bantu'));
    expect(weather.recipes, isEmpty);
  });

  test('Ignores words that only look like ingredients or categories', () async {
    final unsure = await ask('aku ga tahu mau masak apa');
    expect(unsure.text, isNot(contains('bahan tahu')));
    expect(unsure.recipes, isNotEmpty);

    final soy = await ask('resep pakai kecap manis');
    expect(soy.text, isNot(contains('pencuci mulut')));
    expect(names(soy), contains('Tempe Orek'));
  });

  test('Explains missing ingredients and categories', () async {
    final cheese = await ask('resep pakai keju');
    expect(cheese.text, contains('Belum ada resep dengan keju'));
    expect(cheese.recipes, isEmpty);

    final breakfast = await ask('menu sarapan pakai telur');
    expect(breakfast.text, contains('kategori sarapan'));
    expect(breakfast.recipes, isNotEmpty);
  });

  test('Reports when nothing fits every filter', () async {
    final reply = await ask(
      'resep ayam 5 menit',
      preference: MealPreference.lowCalorie,
    );
    expect(reply.recipes, isEmpty);
    expect(reply.text, contains('Belum ada resep yang cocok'));
    expect(reply.text, contains('Custom'));
  });

  test('Answers stay within the saved answer limit', () async {
    final reply = await ask('langkah langkah bikin bread and butter pudding');
    expect(reply.text.length, lessThanOrEqualTo(answerLimit));
  });

  test('Repository caches the model and reports load failures', () async {
    var loads = 0;
    var failLoad = true;
    final kitchen = FakeKitchen()..catalog = catalog;
    final repo = RecipeGuideRepository(
      'user',
      kitchen,
      loader: () async {
        loads++;
        if (failLoad) throw StateError('Missing asset');
        return guide;
      },
    );
    const question = [ChatMessage(fromUser: true, text: 'resep tahu')];
    await expectLater(
      repo.reply(question),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'QuickRecipe AI is not available right now. Try again later.',
        ),
      ),
    );
    failLoad = false;
    expect((await repo.reply(question)).recipes, isNotEmpty);
    await repo.reply(question);
    expect(loads, 2);

    final offline = RecipeGuideRepository(
      'user',
      BrokenCatalog(),
      loader: () async => guide,
    );
    await expectLater(
      offline.reply(question),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Recipes could not be loaded. Check your connection and try again.',
        ),
      ),
    );
  });
}
