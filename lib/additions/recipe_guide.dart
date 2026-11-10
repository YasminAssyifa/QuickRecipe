import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ai_chat.dart';
import 'intent_classifier.dart';
import 'kitchen_repository.dart';

const quickMinutes = 30;
const fewIngredients = 5;
const lowCalories = 400;
const maxSuggestions = 3;
const _catalogLifetime = Duration(minutes: 5);

/// QuickRecipe AI without a language model: the trained intent model picks
/// what the user wants, and the answer is built from the recipe catalog, the
/// user's fridge and the substitution table.
class RecipeGuideRepository extends FirestoreChatRepository {
  RecipeGuideRepository(
    super.uid,
    this.kitchen, {
    Future<RecipeGuide> Function()? loader,
  }) : _loader = loader ?? RecipeGuide.load;
  final KitchenRepository kitchen;
  final Future<RecipeGuide> Function() _loader;
  Future<RecipeGuide>? _guide;
  List<DocumentSnapshot<Map<String, dynamic>>>? _catalog;
  DateTime? _catalogTime;

  @override
  Future<AiReply> reply(
    List<ChatMessage> conversation, {
    MealPreference preference = MealPreference.none,
  }) async {
    final question = conversation.lastWhere(
      (message) => message.fromUser,
      orElse: () => throw StateError('Type a question first.'),
    );
    final RecipeGuide guide;
    try {
      guide = await (_guide ??= _loader());
    } catch (_) {
      _guide = null;
      throw StateError(
        'QuickRecipe AI is not available right now. Try again later.',
      );
    }
    return guide.answer(
      question.text,
      recipes: await _recipes(),
      fridge: _fridge,
      preference: preference,
    );
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _recipes() async {
    final time = _catalogTime;
    if (_catalog != null &&
        time != null &&
        DateTime.now().difference(time) < _catalogLifetime) {
      return _catalog!;
    }
    try {
      _catalog = await kitchen.recipes();
      _catalogTime = DateTime.now();
      return _catalog!;
    } catch (_) {
      throw StateError(
        'Recipes could not be loaded. Check your connection and try again.',
      );
    }
  }

  Future<List<FridgeItem>> _fridge() async {
    try {
      return await kitchen.fridge();
    } catch (_) {
      throw StateError(
        'Your fridge could not be loaded. Check your connection and try again.',
      );
    }
  }
}

class SubstituteEntry {
  const SubstituteEntry({
    required this.label,
    required this.names,
    required this.options,
    this.note = '',
  });
  factory SubstituteEntry.fromJson(Map<String, dynamic> json) =>
      SubstituteEntry(
        label: json['label'] as String,
        names: List<String>.from(json['names'] as List),
        options: List<String>.from(json['options'] as List),
        note: json['note'] as String? ?? '',
      );
  final String label;
  final List<String> names, options;
  final String note;

  static List<SubstituteEntry> parse(String source) =>
      ((jsonDecode(source) as Map<String, dynamic>)['items'] as List)
          .map((item) => SubstituteEntry.fromJson(item as Map<String, dynamic>))
          .toList();
}

class RecipeGuide {
  RecipeGuide({
    required this.classifier,
    required this.substitutes,
    math.Random? random,
  }) : _random = random ?? math.Random();
  final IntentClassifier classifier;
  final List<SubstituteEntry> substitutes;
  final math.Random _random;

  static Future<RecipeGuide> load() async => RecipeGuide(
    classifier: IntentClassifier.parse(
      await rootBundle.loadString('assets/ai/intent_model.json'),
    ),
    substitutes: SubstituteEntry.parse(
      await rootBundle.loadString('assets/ai/substitutes.json'),
    ),
  );

  Future<AiReply> answer(
    String question, {
    required List<DocumentSnapshot<Map<String, dynamic>>> recipes,
    required Future<List<FridgeItem>> Function() fridge,
    MealPreference preference = MealPreference.none,
  }) async {
    final catalog = recipes.map(_Recipe.new).toList();
    final text = _Text(classifier.normalize(question, keepNumbers: true));
    final request = _Request.read(text, catalog, preference);
    final prediction = classifier.predict(question);
    var intent = prediction.intent;
    if (!prediction.confident) {
      // Unsure about the intent, but the question names an ingredient,
      // a recipe or a filter: searching recipes is the safest answer.
      if (!request.hasCriteria && text.namedRecipes(catalog).isEmpty) {
        return const AiReply(_unclear);
      }
      intent = 'cari_resep';
    }
    final AiReply reply;
    switch (intent) {
      case 'cari_resep' when request.fridge:
      case 'pakai_kulkas':
        reply = _fromFridge(request, catalog, await fridge());
      case 'cari_resep':
        reply = _find(request, text, catalog);
      case 'info_resep':
        reply = _info(text, catalog);
      case 'substitusi_bahan':
        reply = _substitute(text, catalog);
      case 'bantuan':
        reply = AiReply(text.hasAny(_thanks) ? _welcome : _help);
      default:
        reply = const AiReply(_outOfScope);
    }
    return reply.text.length <= answerLimit
        ? reply
        : AiReply(reply.text.substring(0, answerLimit), recipes: reply.recipes);
  }

  AiReply _find(_Request request, _Text text, List<_Recipe> catalog) {
    if (catalog.isEmpty) return const AiReply('Katalog resep masih kosong.');
    final named = text.namedRecipes(catalog);
    if (named.isNotEmpty) {
      final fitting = named.where(request.fits).toList();
      if (fitting.isEmpty) return AiReply(request.nothingFound());
      return _list(
        'Ini resep yang paling cocok dengan yang kamu cari:',
        fitting.take(maxSuggestions).toList(),
        request,
      );
    }
    if (request.ingredients.isEmpty && request.unknownIngredients.isNotEmpty) {
      return AiReply(
        'Belum ada resep dengan ${_join(request.unknownIngredients)} di katalog. '
        'Coba bahan lain, misalnya telur, tahu, atau ayam.',
      );
    }
    final fitting = catalog.where(request.fits).toList();
    if (!request.hasCriteria) {
      fitting.shuffle(_random);
      return _list(
        'Ini beberapa ide masakan. Sebutkan bahan, waktu, atau jenis makanan '
        'supaya hasilnya lebih pas.',
        fitting.take(maxSuggestions).toList(),
        request,
      );
    }
    final all = fitting.where((r) => r.hasAll(request.ingredients)).toList();
    if (all.isNotEmpty) {
      return _list(
        'Ini resep untuk ${request.describe()}:',
        _rank(all, request).take(maxSuggestions).toList(),
        request,
      );
    }
    final some = request.ingredients.length < 2
        ? <_Recipe>[]
        : fitting.where((r) => r.countOf(request.ingredients) > 0).toList();
    if (some.isEmpty) return AiReply(request.nothingFound());
    return _list(
      'Belum ada resep yang memakai semua bahan itu sekaligus. '
      'Ini yang memakai sebagian:',
      _rank(some, request).take(maxSuggestions).toList(),
      request,
    );
  }

  List<_Recipe> _rank(List<_Recipe> recipes, _Request request) =>
      recipes..sort((a, b) {
        final byMatch = b
            .countOf(request.ingredients)
            .compareTo(a.countOf(request.ingredients));
        if (byMatch != 0) return byMatch;
        final byTime = (a.minutes ?? 999).compareTo(b.minutes ?? 999);
        return byTime != 0 ? byTime : a.name.compareTo(b.name);
      });

  AiReply _list(String intro, List<_Recipe> recipes, _Request request) {
    final lines = [
      intro,
      for (final recipe in recipes) '• ${recipe.summary}',
      if (request.notes.isNotEmpty) '',
      ...request.notes,
    ];
    return AiReply(
      lines.join('\n'),
      recipes: [for (final recipe in recipes) RecipeSuggestion(recipe.doc)],
    );
  }

  AiReply _fromFridge(
    _Request request,
    List<_Recipe> catalog,
    List<FridgeItem> fridge,
  ) {
    if (!fridge.any((item) => item.inStock)) {
      return const AiReply(
        'Kulkasmu masih kosong atau stoknya habis. Tambahkan bahan di menu '
        'Fridge dulu, lalu tanya lagi.',
      );
    }
    final ranked =
        catalog
            .where(
              (recipe) =>
                  request.fits(recipe) && recipe.hasAll(request.ingredients),
            )
            .map(
              (recipe) => (
                recipe: recipe,
                match: IngredientMatch(recipe.ingredients, fridge),
              ),
            )
            .where((entry) => entry.match.present.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final byRatio = b.match.ratio.compareTo(a.match.ratio);
            if (byRatio != 0) return byRatio;
            return a.match.missing.length.compareTo(b.match.missing.length);
          });
    final filters = request.describe();
    if (ranked.isEmpty) {
      return AiReply(
        'Belum ada resep yang cocok dengan isi kulkasmu'
        '${filters.isEmpty ? '' : ' untuk $filters'}. '
        'Coba tambah bahan lain di menu Fridge.',
      );
    }
    final top = ranked.take(maxSuggestions).toList();
    final lines = [
      'Ini resep yang bisa dibuat dari isi kulkasmu'
          '${filters.isEmpty ? '' : ' ($filters)'}:',
      for (final entry in top)
        '• ${entry.recipe.name}: ada ${_join(entry.match.present)}'
            '${entry.match.missing.isEmpty ? ', semua jenis bahan tersedia' : '; masih perlu ${_join(entry.match.missing)}'}',
      '',
      'Cek jumlah bahannya dulu sebelum memasak.',
      ...request.notes,
    ];
    return AiReply(
      lines.join('\n'),
      recipes: [
        for (final entry in top)
          RecipeSuggestion(
            entry.recipe.doc,
            available: entry.match.present,
            missing: entry.match.missing,
          ),
      ],
    );
  }

  AiReply _info(_Text text, List<_Recipe> catalog) {
    final named = text.namedRecipes(catalog);
    if (named.isEmpty) {
      return const AiReply(
        'Resep mana yang kamu maksud? Sebutkan namanya, misalnya '
        '"Tempe Orek berapa kalori?".',
      );
    }
    if (named.length > 1) {
      final options = named.take(maxSuggestions).toList();
      return AiReply(
        'Ada beberapa resep yang mirip: ${_join([for (final r in options) r.name])}. '
        'Sebutkan nama lengkapnya supaya aku bisa jawab dengan tepat.',
        recipes: [for (final r in options) RecipeSuggestion(r.doc)],
      );
    }
    final recipe = named.single;
    var calories = text.hasAny(_calorieWords);
    var time = text.hasAny(_timeWords);
    final steps = text.hasAny(_stepWords);
    var ingredients = text.hasAny(_ingredientWords);
    if (!(calories || time || steps || ingredients)) {
      calories = time = ingredients = true;
    }
    final lines = <String>[
      '${recipe.name}:',
      if (calories)
        recipe.calories == null
            ? '• Kalori: belum ada datanya.'
            : '• Kalori: sekitar ${recipe.calories} kkal per porsi.',
      if (time)
        recipe.minutes == null
            ? '• Waktu masak: belum ada datanya.'
            : '• Waktu masak: ${recipe.minutes} menit.',
      if (ingredients) '• Bahan: ${recipe.ingredientList}.',
      if (steps) ...[
        'Langkah:',
        for (var i = 0; i < recipe.steps.length; i++)
          '${i + 1}. ${recipe.steps[i]}',
        if (recipe.steps.isEmpty) 'Belum ada langkah untuk resep ini.',
      ],
    ];
    return AiReply(lines.join('\n'), recipes: [RecipeSuggestion(recipe.doc)]);
  }

  AiReply _substitute(_Text text, List<_Recipe> catalog) {
    SubstituteEntry? found;
    var foundAt = -1, foundLength = 0;
    for (final entry in substitutes) {
      for (final name in entry.names) {
        final phrase = classifier.normalize(name).join(' ');
        final at = text.indexOf(phrase);
        if (at < 0) continue;
        if (foundAt < 0 ||
            at < foundAt ||
            (at == foundAt && phrase.length > foundLength)) {
          found = entry;
          foundAt = at;
          foundLength = phrase.length;
        }
      }
    }
    if (found != null) {
      return AiReply(
        [
          'Pengganti ${found.label.toLowerCase()}:',
          for (final option in found.options) '• $option',
          if (found.note.isNotEmpty) found.note,
          'Rasa dan teksturnya bisa sedikit berbeda, jadi tambahkan sedikit demi sedikit.',
        ].join('\n'),
      );
    }
    final known = _join([for (final e in substitutes) e.label.toLowerCase()]);
    final mentioned = _Request.mentions(text, catalog).$1.values.toList();
    return AiReply(
      mentioned.isEmpty
          ? 'Bahan apa yang mau diganti? Contoh: "santan bisa diganti apa?". '
                'Aku punya daftar pengganti untuk: $known.'
          : 'Aku belum punya data pengganti untuk ${_join(mentioned)}. '
                'Yang tersedia: $known.',
    );
  }
}

String _join(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} dan ${items.last}';

const _unclear =
    'Aku belum yakin maksudmu. Coba tanya seperti "masak apa pakai telur?", '
    '"santan bisa diganti apa?", atau "isi kulkasku bisa jadi apa?".';
const _outOfScope =
    'Maaf, aku hanya bisa bantu soal resep di QuickRecipe: mencari resep, '
    'memakai isi kulkas, info resep, dan bahan pengganti.';
const _welcome = 'Sama-sama! Selamat memasak.';
const _help =
    'Halo! Aku bisa bantu:\n'
    '• Cari resep dari bahan, waktu, atau jenis makanan. Contoh: "masak apa pakai telur?"\n'
    '• Cari resep dari isi kulkasmu. Contoh: "isi kulkasku bisa jadi apa?"\n'
    '• Info resep: kalori, waktu, bahan, dan langkah. Contoh: "tempe orek berapa kalori?"\n'
    '• Bahan pengganti. Contoh: "santan bisa diganti apa?"\n'
    'Menu Meal preference di bawah bisa dipakai untuk filter resep cepat, '
    'sedikit bahan, rendah kalori, atau dari isi kulkas.';

const _thanks = ['makasih', 'terima kasih', 'thanks', 'thank you', 'thx'];
const _calorieWords = [
  'kalori',
  'kalorinya',
  'kkal',
  'kcal',
  'calorie',
  'calories',
  'cal',
];
const _timeWords = [
  'berapa lama',
  'lama',
  'menit',
  'waktu',
  'how long',
  'minutes',
  'time',
];
const _stepWords = [
  'cara',
  'langkah',
  'step',
  'steps',
  'urutan',
  'how to',
  'how do i make',
  'bagaimana',
  'make',
];
const _ingredientWords = [
  'bahan',
  'bahannya',
  'bumbu',
  'ingredients',
  'ingredient',
  'need',
];
const _quickWords = [
  'cepat',
  'kilat',
  'sebentar',
  'singkat',
  'buru buru',
  'instan',
  'quick',
  'fast',
];
const _fewWords = [
  'bahan sedikit',
  'sedikit bahan',
  'bahannya sedikit',
  'minim bahan',
  'simple',
  'simpel',
  'sederhana',
  'tidak ribet',
  'few ingredients',
];
const _lowCalorieWords = [
  'rendah kalori',
  'diet',
  'ringan',
  'tidak gendut',
  'low calorie',
  'low cal',
  'light',
];
const _categoryWords = {
  'sarapan': 'breakfast',
  'makan pagi': 'breakfast',
  'breakfast': 'breakfast',
  'makan siang': 'lunch',
  'bekal': 'lunch',
  'lunch': 'lunch',
  'makan malam': 'dinner',
  'malam ini': 'dinner',
  'dinner': 'dinner',
  'tonight': 'dinner',
  'camilan': 'snack',
  'ngemil': 'snack',
  'snack': 'snack',
  'snacks': 'snack',
  'dessert': 'dessert',
  'pencuci mulut': 'dessert',
  'makanan penutup': 'dessert',
  'manis': 'dessert',
  'sweet': 'dessert',
};
const _categoryNames = {
  'breakfast': 'sarapan',
  'lunch': 'makan siang',
  'dinner': 'makan malam',
  'snack': 'camilan',
  'dessert': 'pencuci mulut',
};

/// Indonesian and English words for ingredients, so questions match recipes
/// written in either language. Names from the catalog are added at runtime.
const _ingredientTerms = [
  'telur',
  'telur ayam',
  'ayam',
  'daging ayam',
  'tahu',
  'tempe',
  'nasi',
  'nasi putih',
  'beras',
  'mie',
  'mi',
  'bakmi',
  'bayam',
  'kangkung',
  'wortel',
  'tomat',
  'kentang',
  'jagung',
  'kol',
  'kubis',
  'susu',
  'pisang',
  'tepung',
  'tepung terigu',
  'roti',
  'mentega',
  'gula',
  'minyak',
  'minyak goreng',
  'kecap asin',
  'kecap manis',
  'bawang putih',
  'bawang merah',
  'bawang bombay',
  'cabai',
  'cabai merah',
  'garam',
  'merica',
  'lada',
  'keju',
  'santan',
  'egg',
  'eggs',
  'chicken',
  'tofu',
  'tempeh',
  'rice',
  'cooked rice',
  'noodles',
  'noodle',
  'spinach',
  'carrot',
  'carrots',
  'tomato',
  'tomatoes',
  'potato',
  'potatoes',
  'corn',
  'sweet corn',
  'cabbage',
  'milk',
  'banana',
  'bananas',
  'flour',
  'bread',
  'butter',
  'sugar',
  'cooking oil',
  'soy sauce',
  'sweet soy sauce',
  'garlic',
  'shallot',
  'onion',
  'onions',
  'chili',
  'salt',
  'pepper',
  'cheese',
  'coconut milk',
];

/// Extra aliases on top of [ingredientKey] so both languages share one key.
const _sameIngredient = {
  'sweet corn': 'corn',
  'rice': 'cooked rice',
  'nasi putih': 'cooked rice',
  'telur ayam': 'egg',
  'daging ayam': 'chicken',
  'bawang merah': 'shallot',
  'bawang bombay': 'onion',
  'onions': 'onion',
  'cabai': 'chili',
  'cabai merah': 'chili',
  'garam': 'salt',
  'merica': 'pepper',
  'lada': 'pepper',
  'kubis': 'cabbage',
  'noodle': 'noodles',
  'bakmi': 'noodles',
  'potatoes': 'potato',
  'tomatoes': 'tomato',
  'carrots': 'carrot',
  'bananas': 'banana',
  'tepung terigu': 'flour',
  'minyak goreng': 'cooking oil',
  'keju': 'cheese',
  'santan': 'coconut milk',
};
const _ignoredIngredients = {'water'};

/// Phrases where an ingredient word means something else ("tidak tahu" is
/// "don't know", not tofu).
const _notIngredients = ['tidak tahu', 'belum tahu', 'mau tahu', 'ingin tahu'];

String _ingredient(String name) {
  final key = ingredientKey(name);
  return _sameIngredient[key] ?? key;
}

/// Comparable form of a word in a recipe name: Indonesian and English
/// ingredient words share one form and simple English plurals are dropped.
String _form(String word) {
  final key = _ingredient(word);
  return key.length > 3 && key.endsWith('s') && !key.endsWith('ss')
      ? key.substring(0, key.length - 1)
      : key;
}

List<String> _words(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .split(' ')
    .where((word) => word.isNotEmpty)
    .toList();

class _Recipe {
  _Recipe(this.doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    name = (data['name'] ?? 'Recipe').toString();
    category = (data['category'] ?? '').toString();
    final time = data['time'];
    minutes = time is num ? time.round() : int.tryParse('${time ?? ''}');
    final cal = RegExp(r'\d+').firstMatch('${data['cal'] ?? ''}')?.group(0);
    calories = cal == null ? null : int.tryParse(cal);
    ingredients = List<String>.from(data['ingredientsName'] ?? const []);
    amounts = [
      for (final value in (data['ingredientsAmount'] as List?) ?? const [])
        value is num ? value : null,
    ];
    steps = List<String>.from(data['step'] ?? const []);
    keys = ingredients.map(_ingredient).toSet();
    nameForms = _words(name).map(_form).toSet();
  }
  final DocumentSnapshot<Map<String, dynamic>> doc;
  late final String name, category;
  late final int? minutes, calories;
  late final List<String> ingredients, steps;
  late final List<num?> amounts;
  late final Set<String> keys, nameForms;

  bool hasAll(Set<String> wanted) => keys.containsAll(wanted);
  int countOf(Set<String> wanted) => wanted.where(keys.contains).length;

  String get summary =>
      '$name (${[if (minutes != null) '$minutes menit', if (calories != null) '$calories kkal', '${ingredients.length} bahan'].join(', ')})';

  String get ingredientList => [
    for (var i = 0; i < ingredients.length; i++)
      i < amounts.length && amounts[i] != null
          ? '${ingredients[i]} (${amountText(amounts[i]!.toDouble())} g)'
          : ingredients[i],
  ].join(', ');
}

/// The question as normalised tokens, with numbers kept.
class _Text {
  _Text(this.tokens) : padded = ' ${tokens.join(' ')} ';
  final List<String> tokens;
  final String padded;

  bool has(String phrase) => padded.contains(' $phrase ');
  bool hasAny(List<String> phrases) => phrases.any(has);
  int indexOf(String phrase) => padded.indexOf(' $phrase ');

  /// Recipes whose name the question mentions, best match first. Only the
  /// recipes sharing the best score are returned.
  List<_Recipe> namedRecipes(List<_Recipe> catalog) {
    final words = tokens.map(_form).toSet();
    final scored = <(_Recipe, double, int)>[];
    for (final recipe in catalog) {
      final size = recipe.nameForms.length;
      if (size == 0) continue;
      final overlap = recipe.nameForms.where(words.contains).length;
      final score = overlap / size;
      if (overlap == size || (overlap >= 2 && score >= 0.5)) {
        scored.add((recipe, score, overlap));
      }
    }
    if (scored.isEmpty) return [];
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : b.$3.compareTo(a.$3);
    });
    final best = scored.first;
    return [
      for (final entry in scored)
        if (entry.$2 == best.$2 && entry.$3 == best.$3) entry.$1,
    ];
  }
}

class _Request {
  _Request._();

  factory _Request.read(
    _Text text,
    List<_Recipe> catalog,
    MealPreference preference,
  ) {
    final request = _Request._();
    final known = {for (final recipe in catalog) ...recipe.keys};
    final (found, rest) = mentions(text, catalog);
    found.forEach((key, word) {
      if (known.contains(key)) {
        request.ingredients.add(key);
        request.ingredientNames.add(word);
      } else {
        request.unknownIngredients.add(word);
      }
    });
    if (request.ingredients.isNotEmpty &&
        request.unknownIngredients.isNotEmpty) {
      request.notes.add(
        'Belum ada resep dengan ${_join(request.unknownIngredients)}, '
        'jadi bahan itu tidak dipakai.',
      );
    }

    final categories = {
      for (final recipe in catalog) recipe.category.toLowerCase(),
    };
    for (final entry in _categoryWords.entries) {
      if (!rest.contains(' ${entry.key} ')) continue;
      if (categories.contains(entry.value)) {
        request.category = entry.value;
      } else {
        request.notes.add(
          'Belum ada resep kategori ${_categoryNames[entry.value]} di katalog, '
          'jadi kategori itu tidak dipakai.',
        );
      }
      break;
    }

    final minutes = RegExp(r' (\d+) (menit|min|mins|minute|minutes) ')
        .firstMatch(text.padded);
    final hours = RegExp(r' (\d+) (jam|hour|hours) ').firstMatch(text.padded);
    if (minutes != null) {
      request._limitMinutes(int.parse(minutes.group(1)!));
    } else if (hours != null) {
      request._limitMinutes(int.parse(hours.group(1)!) * 60);
    } else if (text.hasAny(['setengah jam', 'half an hour', 'half hour'])) {
      request._limitMinutes(30);
    }
    if (text.hasAny(_quickWords)) request._limitMinutes(quickMinutes);

    final calories = RegExp(
      r' (\d+) (kalori|kal|kkal|kcal|cal|calorie|calories) ',
    ).firstMatch(text.padded);
    if (calories != null) {
      request._limitCalories(int.parse(calories.group(1)!));
    }
    if (text.hasAny(_lowCalorieWords)) request._limitCalories(lowCalories);

    final count =
        RegExp(r' (\d+) (bahan|ingredient|ingredients) ')
            .firstMatch(text.padded) ??
        RegExp(
          r' bahan(?:nya)? (?:kurang dari|maksimal|maks|max|di bawah|paling banyak) (\d+) ',
        ).firstMatch(text.padded);
    if (count != null) request._limitIngredients(int.parse(count.group(1)!));
    if (text.hasAny(_fewWords)) request._limitIngredients(fewIngredients);

    switch (preference) {
      case MealPreference.quick:
        request._limitMinutes(quickMinutes);
      case MealPreference.fewIngredients:
        request._limitIngredients(fewIngredients);
      case MealPreference.lowCalorie:
        request._limitCalories(lowCalories);
      case MealPreference.fridge:
        request.fridge = true;
      case MealPreference.none:
        break;
    }
    return request;
  }

  /// Ingredient keys found in the text with the word the user wrote, and
  /// the text left after those words are taken out.
  static (Map<String, String>, String) mentions(
    _Text text,
    List<_Recipe> catalog,
  ) {
    final terms =
        <String>{
              ..._ingredientTerms,
              for (final recipe in catalog)
                for (final name in recipe.ingredients) _words(name).join(' '),
            }
            .where(
              (term) =>
                  term.isNotEmpty &&
                  !_ignoredIngredients.contains(_ingredient(term)),
            )
            .toList()
          ..sort((a, b) {
            final byWords = b.split(' ').length.compareTo(a.split(' ').length);
            return byWords != 0 ? byWords : b.length.compareTo(a.length);
          });
    var padded = text.padded;
    for (final phrase in _notIngredients) {
      padded = padded.replaceAll(' $phrase ', ' | ');
    }
    final found = <String, String>{};
    for (final term in terms) {
      if (!padded.contains(' $term ')) continue;
      found.putIfAbsent(_ingredient(term), () => term);
      padded = padded.replaceAll(' $term ', ' | ');
    }
    return (found, padded);
  }

  final Set<String> ingredients = {};
  final List<String> ingredientNames = [], unknownIngredients = [], notes = [];
  String? category;
  int? maxMinutes, maxCalories, maxIngredients;
  bool fridge = false;

  void _limitMinutes(int value) =>
      maxMinutes = math.min(maxMinutes ?? value, value);
  void _limitCalories(int value) =>
      maxCalories = math.min(maxCalories ?? value, value);
  void _limitIngredients(int value) =>
      maxIngredients = math.min(maxIngredients ?? value, value);

  bool get hasCriteria =>
      category != null ||
      maxMinutes != null ||
      maxCalories != null ||
      maxIngredients != null ||
      fridge ||
      ingredients.isNotEmpty ||
      unknownIngredients.isNotEmpty;

  bool fits(_Recipe recipe) =>
      (category == null || recipe.category.toLowerCase() == category) &&
      (maxMinutes == null ||
          (recipe.minutes != null && recipe.minutes! <= maxMinutes!)) &&
      (maxCalories == null ||
          (recipe.calories != null && recipe.calories! <= maxCalories!)) &&
      (maxIngredients == null || recipe.ingredients.length <= maxIngredients!);

  String describe() => _join([
    if (ingredientNames.isNotEmpty) 'bahan ${_join(ingredientNames)}',
    if (category != null) 'kategori ${_categoryNames[category]}',
    if (maxMinutes != null) 'maksimal $maxMinutes menit',
    if (maxIngredients != null) 'maksimal $maxIngredients bahan',
    if (maxCalories != null) 'maksimal $maxCalories kkal',
  ]);

  String nothingFound() {
    final criteria = describe();
    return [
      criteria.isEmpty
          ? 'Belum ada resep yang cocok.'
          : 'Belum ada resep yang cocok untuk $criteria.',
      'Coba kurangi syaratnya atau ganti bahan. Kalau filter Meal preference '
          'masih aktif, pilih Custom untuk melepasnya.',
    ].join(' ');
  }
}
