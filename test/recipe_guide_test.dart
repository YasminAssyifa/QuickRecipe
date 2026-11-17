import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_recipe/services/chat_repository.dart';
import 'package:quick_recipe/services/intent_classifier.dart';
import 'package:quick_recipe/services/kitchen_repository.dart';
import 'package:quick_recipe/services/recipe_guide.dart';

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

/// The seed catalog with tags and allergens on a few recipes, the way the
/// admin form stores them.
List<DocumentSnapshot<Map<String, dynamic>>> taggedCatalog() {
  const marks = {
    'recipe-tempe-orek': (['vegetarian', 'hemat', 'bekal'], <String>[]),
    'recipe-telur-balado': (
      ['vegetarian', 'pedas', 'hemat', 'bekal'],
      ['telur'],
    ),
    'recipe-tahu-kecap': (
      ['vegetarian', 'hemat', 'bekal', 'ramah-anak'],
      <String>[],
    ),
    'recipe-sayur-bening-bayam': (
      ['vegetarian', 'hemat', 'ramah-anak'],
      <String>[],
    ),
    'recipe-soy-sauce-chicken': (['bekal', 'ramah-anak'], <String>[]),
    'recipe-banana-pancakes': (
      ['vegetarian', 'ramah-anak'],
      ['telur', 'susu', 'gluten'],
    ),
  };
  return [
    for (final doc in seedCatalog())
      TestRecipe(doc.id, {
        ...doc.data()!,
        if (marks[doc.id] case final mark?) ...{
          'tags': mark.$1,
          'allergens': mark.$2,
        },
      }),
  ];
}

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
    expect(reply.text, contains('Ini yang paling dekat'));
    expect(
      reply.text,
      contains('1. Nasi Goreng Telur: tinggal beli kecap manis.'),
    );
    expect(
      reply.text,
      contains('Kurang bawang putih, tapi kamu punya bawang merah'),
    );
    // Ingredients in a recipe's name are never swapped.
    expect(reply.text, isNot(contains('Kurang tofu')));
  });

  test('Fridge answers name recipes that can be cooked with a swap', () async {
    fridge = [
      item('Tempe'),
      item('Bawang merah'),
      item('Bawang putih'),
      item('Kecap asin'),
      item('Gula merah'),
    ];
    final reply = await ask('isi kulkasku bisa jadi apa');
    // Sweet Soy Tempeh is the older copy of Tempe Orek in the seed data.
    expect(names(reply).take(2), contains('Tempe Orek'));
    expect(reply.text, contains('bisa kamu masak sekarang juga'));
    expect(
      reply.text,
      contains('Kurang kecap manis, tapi kamu punya kecap asin dan gula merah'),
    );
  });

  test('Suggestions give a reason from the fridge or the question', () async {
    fridge = [item('Nasi')];
    final reply = await ask('masak apa pakai telur?');
    final lines = reply.text.split('\n').where((l) => l.startsWith('• '));
    expect(lines, hasLength(reply.recipes.length));
    for (final line in lines) {
      expect(
        line,
        anyOf(contains('sudah ada di kulkasmu'), contains('memakai telur')),
      );
    }
  });

  test('Says so when no ingredient or recipe is recognised', () async {
    final typo = await ask('resep yg ada ayammm');
    expect(typo.text, startsWith('Aku belum menemukan bahan atau nama resep'));
    expect(typo.recipes, isEmpty);
    final ideas = await ask('masak apa ya hari ini');
    expect(ideas.text, startsWith('Ini beberapa ide masakan'));
    expect(ideas.recipes, isNotEmpty);
    final chicken = await ask('resep yg ada ayamnya');
    expect(chicken.text, startsWith('Ini resep untuk bahan ayam'));
  });

  test('Recognises a single word of a recipe name and -nya', () async {
    expect(names(await ask('resep pancake dong')), ['Banana Pancakes']);
    expect(
      (await ask('cabainya bisa diganti apa?')).text,
      startsWith('Pengganti cabai'),
    );
  });

  group('Shopping lists, meal plans and follow-ups', () {
    test('Shopping list adds up grams and skips the fridge', () async {
      fridge = [item('Telur'), item('Nasi')];
      final reply = await ask(
        'besok mau masak tempe orek sama nasi goreng telur, belanja apa aja?',
      );
      expect(
        names(reply),
        unorderedEquals(['Tempe Orek', 'Nasi Goreng Telur']),
      );
      expect(reply.text, contains('• Tempe: 120 g'));
      expect(reply.text, contains('• Bawang merah: 30 g (15 g + 15 g)'));
      expect(reply.text, contains('Sudah ada di kulkas: nasi dan telur.'));
      expect(reply.text, isNot(contains('Minyak')));
      expect(reply.text, isNot(contains('• Air')));
    });

    test('Meal plan fills lunch and dinner without repeats', () async {
      fridge = [item('Telur'), item('Nasi'), item('Tempe')];
      final memory = ChatMemory();
      final reply = await guide.answer(
        'buatin menu 3 hari dari isi kulkas',
        recipes: catalog,
        fridge: () async => fridge,
        memory: memory,
      );
      expect(reply.plan, hasLength(3));
      expect(reply.plan.every((day) => day.length == 2), isTrue);
      final ids = reply.plan.expand((day) => day).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(reply.text, contains('Hari 3'));
      expect(reply.text, contains('Belanja sekali untuk 3 hari:'));
      expect(reply.text, contains('Sarapan belum ada'));
      expect(memory.plan, reply.plan);

      final dayThree = await guide.answer(
        'yang hari 3 butuh beli apa aja?',
        recipes: catalog,
        fridge: () async => fridge,
        memory: memory,
      );
      expect([
        for (final s in dayThree.recipes) s.recipe.id,
      ], unorderedEquals(reply.plan[2]));
      expect(dayThree.text, startsWith('Daftar belanja untuk'));
    });

    test('Follow-up questions reuse the last answer', () async {
      final memory = ChatMemory();
      Future<AiReply> chat(String question) => guide.answer(
        question,
        recipes: catalog,
        fridge: () async => fridge,
        memory: memory,
      );
      final first = await chat('masak apa pakai telur?');
      final more = await chat('yang lain dong');
      expect(more.text, startsWith('Ini resep untuk bahan telur'));
      expect(
        {for (final s in more.recipes) s.recipe.id}
            .intersection({for (final s in first.recipes) s.recipe.id}),
        isEmpty,
      );
      final second = await chat('belanja untuk yang kedua');
      expect(second.recipes.single.recipe.id, more.recipes[1].recipe.id);
    });

    test('Substitutes point out what is already in the fridge', () async {
      fridge = [item('Kecap asin'), item('Gula merah')];
      final soy = await ask('kecap manis bisa diganti apa');
      expect(soy.text, contains('(ada di kulkasmu)'));
      fridge = [item('Telur')];
      final chili = await ask('cabai bisa diganti apa');
      expect(chili.text, contains('belum punya bahan penggantinya'));
    });
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

  test('Answers name ingredients in Indonesian', () async {
    final reply = await ask('What can I cook with eggs?');
    expect(reply.text, startsWith('Ini resep untuk bahan telur'));
  });

  group('Tags and allergens', () {
    final tagged = taggedCatalog();
    Future<AiReply> askTagged(
      String question, {
      MealPreference preference = MealPreference.none,
    }) => guide.answer(
      question,
      recipes: tagged,
      fridge: () async => fridge,
      preference: preference,
    );
    Set<String> tagsOf(RecipeSuggestion s) =>
        Set<String>.from(data(s)['tags'] ?? const []);

    test('Tag preferences keep only matching recipes', () async {
      for (final (preference, tag) in [
        (MealPreference.vegetarian, 'vegetarian'),
        (MealPreference.budget, 'hemat'),
        (MealPreference.lunchbox, 'bekal'),
        (MealPreference.kidFriendly, 'ramah-anak'),
      ]) {
        final reply = await askTagged('resep dong', preference: preference);
        expect(reply.recipes, isNotEmpty, reason: '$preference');
        expect(reply.recipes.every((s) => tagsOf(s).contains(tag)), isTrue);
      }
    });

    test('Words in the question become tag filters', () async {
      final notSpicy = await askTagged('menu vegetarian yang tidak pedas');
      expect(notSpicy.recipes, isNotEmpty);
      for (final s in notSpicy.recipes) {
        expect(tagsOf(s), contains('vegetarian'));
        expect(tagsOf(s), isNot(contains('pedas')));
      }
      expect(notSpicy.text, contains('tidak pedas'));

      final student = await askTagged('menu hemat buat anak kos');
      expect(student.text, contains('hemat'));
      expect(student.text, isNot(contains('ramah anak')));

      final lunchbox = await askTagged('ide bekal');
      expect(lunchbox.text, isNot(contains('makan siang')));
      expect(
        lunchbox.recipes.every((s) => tagsOf(s).contains('bekal')),
        isTrue,
      );
    });

    test('Excluded allergens drop unsafe and unmarked recipes', () async {
      final reply = await askTagged('resep tanpa telur');
      expect(reply.recipes, isNotEmpty);
      for (final s in reply.recipes) {
        expect(data(s)['allergens'], isNot(contains('telur')));
        expect(
          List<String>.from(data(s)['ingredientsName'])
              .map((n) => n.toLowerCase()),
          isNot(anyOf(contains('telur'), contains('egg'))),
        );
      }
      expect(reply.text, contains('tanpa telur'));
      expect(reply.text, contains('belum punya data alergen'));
    });

    test('Untagged catalogs explain that nothing matches', () async {
      final reply = await ask('resep vegetarian');
      expect(reply.recipes, isEmpty);
      expect(reply.text, contains('vegetarian'));
    });
  });

  test('Repeating a question shows other recipes', () async {
    final repo = RecipeGuideRepository(
      'user',
      FakeKitchen()..catalog = catalog,
      loader: () async => guide,
    );
    const question = [
      ChatMessage(fromUser: true, text: 'masak apa pakai telur?'),
    ];
    final first = {
      for (final s in (await repo.reply(question)).recipes) s.recipe.id,
    };
    final second = {
      for (final s in (await repo.reply(question)).recipes) s.recipe.id,
    };
    expect(first, hasLength(maxSuggestions));
    expect(second, hasLength(maxSuggestions));
    expect(first.intersection(second), isEmpty);
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
