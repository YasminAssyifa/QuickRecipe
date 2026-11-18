import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:quick_recipe/services/chat_repository.dart';
import 'package:quick_recipe/services/intent_classifier.dart';
import 'package:quick_recipe/services/kitchen_repository.dart';

const quickMinutes = 30;
const fewIngredients = 5;
const lowCalories = 400;
const maxSuggestions = 3;
const maxSwaps = 2;
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
  final ChatMemory _memory = ChatMemory();

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
    final reply = await guide.answer(
      question.text,
      recipes: await _recipes(),
      fridge: _fridge,
      preference: preference,
      memory: _memory,
    );
    return reply;
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

/// What the chat remembers between questions while the AI screen is open:
/// the recipes shown last, the last meal plan and the last recipe search.
class ChatMemory {
  List<String> shown = [];
  List<List<String>> plan = [];
  String? search;
  MealPreference searchPreference = MealPreference.none;
}

class SubstituteOption {
  const SubstituteOption(this.text, {this.uses = const []});
  factory SubstituteOption.fromJson(Object? json) => json is String
      ? SubstituteOption(json)
      : SubstituteOption(
          (json as Map<String, dynamic>)['text'] as String,
          uses: List<String>.from(json['uses'] ?? const []),
        );
  final String text;

  /// Ingredients this option needs, used to check the user's fridge.
  final List<String> uses;
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
        options: [
          for (final option in json['options'] as List)
            SubstituteOption.fromJson(option),
        ],
        note: json['note'] as String? ?? '',
      );
  final String label;
  final List<String> names;
  final List<SubstituteOption> options;
  final String note;

  static List<SubstituteEntry> parse(String source) =>
      ((jsonDecode(source) as Map<String, dynamic>)['items'] as List)
          .map((item) => SubstituteEntry.fromJson(item as Map<String, dynamic>))
          .toList();
}

/// Ingredient keys of the fridge items in stock.
Set<String> _stockKeys(List<FridgeItem> fridge) => {
  for (final item in fridge)
    if (item.inStock) ingredientKey(item.name),
};

/// How an ingredient is named in answers: in Indonesian when the catalog
/// uses an English name.
String _display(String ingredient) =>
    _indonesianNames[_ingredient(ingredient)] ?? ingredient.toLowerCase();

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Shallots, garlic and onion are in almost every kitchen, so they make a
/// weak reason on their own.
const _aromatics = {'bawang merah', 'shallot', 'garlic', 'onion'};

bool _isStaple(String ingredient) =>
    pantryStaples.contains(ingredientKey(ingredient));

/// A recipe from the fridge with the substitutes that cover missing items.
class _FridgeMatch {
  _FridgeMatch(this.recipe, this.match, this.swaps)
    : unsolved = [
        for (final name in match.missing)
          if (!swaps.containsKey(name)) name,
      ];
  final _Recipe recipe;
  final IngredientMatch match;
  final Map<String, SubstituteOption> swaps;
  final List<String> unsolved;

  /// Cookable now: every missing item has a substitute in the fridge, at
  /// most [maxSwaps] are needed, and at least half the ingredients are there.
  bool get ready =>
      unsolved.isEmpty &&
      swaps.length <= maxSwaps &&
      match.present.length * 2 >= match.present.length + match.missing.length;
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
    ChatMemory? memory,
  }) async {
    memory ??= ChatMemory();
    final recent = memory.shown.toSet();
    final catalog = recipes.map(_Recipe.new).toList();
    for (final recipe in catalog) {
      recipe.order =
          _random.nextDouble() + (recent.contains(recipe.doc.id) ? 1 : 0);
    }
    var asked = question;
    var filter = preference;
    var text = _Text(classifier.normalize(asked, keepNumbers: true));
    var request = _Request.read(text, catalog, filter);
    // "yang lain dong" repeats the last recipe search. Recipes shown last
    // are ranked after the others, so the answer brings new ones.
    final previous = memory.search;
    if (previous != null &&
        text.tokens.length <= 4 &&
        text.hasAny(_moreWords) &&
        !request.hasCriteria) {
      asked = previous;
      filter = memory.searchPreference;
      text = _Text(classifier.normalize(asked, keepNumbers: true));
      request = _Request.read(text, catalog, filter);
    }
    final prediction = classifier.predict(asked);
    var intent = prediction.intent;
    if (!prediction.confident) {
      // Unsure about the intent, but the question names an ingredient,
      // a recipe or a filter: searching recipes is the safest answer.
      if (!request.hasCriteria && text.namedRecipes(catalog).isEmpty) {
        return const AiReply(_unclear);
      }
      intent = 'cari_resep';
    }

    List<FridgeItem>? items;
    Future<List<FridgeItem>> stock() async => items ??= await fridge();
    // The fridge only adds hints to these answers, so they still work when
    // it cannot be loaded.
    Future<Set<String>?> stockIfAvailable() async {
      try {
        return _stockKeys(await stock());
      } catch (_) {
        return null;
      }
    }

    final AiReply reply;
    switch (intent) {
      case 'cari_resep' when request.fridge:
      case 'pakai_kulkas':
        reply = _fromFridge(request, catalog, await stock());
      case 'cari_resep':
        reply = _find(request, text, catalog, await stockIfAvailable());
      case 'info_resep':
        reply = _info(text, catalog);
      case 'substitusi_bahan':
        reply = _substitute(text, catalog, await stockIfAvailable());
      case 'daftar_belanja':
        reply = _shopping(text, catalog, await stockIfAvailable(), memory);
      case 'rencana_menu':
        reply = _plan(text, request, catalog, await stockIfAvailable());
      case 'bantuan':
        reply = AiReply(text.hasAny(_thanks) ? _welcome : _help);
      default:
        reply = const AiReply(_outOfScope);
    }
    if (intent == 'cari_resep' || intent == 'pakai_kulkas') {
      memory
        ..search = asked
        ..searchPreference = filter;
    }
    if (reply.recipes.isNotEmpty) {
      memory.shown = [for (final card in reply.recipes) card.recipe.id];
    }
    if (reply.plan.isNotEmpty) memory.plan = reply.plan;
    return reply.text.length <= answerLimit
        ? reply
        : AiReply(
            reply.text.substring(0, answerLimit),
            recipes: reply.recipes,
            plan: reply.plan,
          );
  }

  AiReply _find(
    _Request request,
    _Text text,
    List<_Recipe> catalog,
    Set<String>? stock,
  ) {
    if (catalog.isEmpty) return const AiReply('Katalog resep masih kosong.');
    final named = text.namedRecipes(catalog);
    if (named.isNotEmpty) {
      final fitting = named.where(request.fits).toList();
      if (fitting.isEmpty) return AiReply(request.nothingFound());
      return _list(
        'Ini resep yang paling cocok dengan yang kamu cari:',
        fitting.take(maxSuggestions).toList(),
        request,
        stock,
      );
    }
    if (request.ingredients.isEmpty && request.unknownIngredients.isNotEmpty) {
      return AiReply(
        'Belum ada resep dengan ${_join(request.unknownIngredients)} di katalog. '
        'Coba bahan lain, misalnya telur, tahu, atau ayam.',
      );
    }
    final fitting = catalog.where(request.fits).toList();
    final partly = text.partlyNamedRecipes(catalog);
    if (!request.hasCriteria && partly.isNotEmpty) {
      return _list(
        'Ini resep yang namanya mirip dengan yang kamu cari:',
        _rank(partly, request).take(maxSuggestions).toList(),
        request,
        stock,
      );
    }
    if (!request.hasCriteria && text.hasUnknownWords(catalog)) {
      return const AiReply(_notFound);
    }
    if (!request.hasCriteria) {
      fitting.sort((a, b) => a.order.compareTo(b.order));
      return _list(
        'Ini beberapa ide masakan. Sebutkan bahan, waktu, atau jenis makanan '
        'supaya hasilnya lebih pas.',
        fitting.take(maxSuggestions).toList(),
        request,
        stock,
      );
    }
    final all = fitting.where((r) => r.hasAll(request.ingredients)).toList();
    if (all.isNotEmpty) {
      return _list(
        'Ini resep untuk ${request.describe()}:',
        _rank(all, request).take(maxSuggestions).toList(),
        request,
        stock,
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
      stock,
    );
  }

  List<_Recipe> _rank(List<_Recipe> recipes, _Request request) =>
      recipes..sort((a, b) {
        final byMatch = b
            .countOf(request.ingredients)
            .compareTo(a.countOf(request.ingredients));
        return byMatch != 0 ? byMatch : a.order.compareTo(b.order);
      });

  AiReply _list(
    String intro,
    List<_Recipe> recipes,
    _Request request,
    Set<String>? stock,
  ) {
    final lines = [
      intro,
      for (final recipe in recipes)
        '• ${recipe.summary(request)}${_reason(recipe, recipes, request, stock)}',
      if (request.notes.isNotEmpty) '',
      ...request.notes,
    ];
    return AiReply(
      lines.join('\n'),
      recipes: [for (final recipe in recipes) RecipeSuggestion(recipe.doc)],
    );
  }

  /// One short reason per suggestion, taken from the fridge, the question,
  /// or how the recipe compares with the other suggestions.
  String _reason(
    _Recipe recipe,
    List<_Recipe> shown,
    _Request request,
    Set<String>? stock,
  ) {
    String pick() {
      final have = [
        for (final name in recipe.ingredients)
          if (stock != null &&
              !_isStaple(name) &&
              !_aromatics.contains(ingredientKey(name)) &&
              stock.contains(ingredientKey(name)))
            _display(name),
      ];
      if (have.isNotEmpty) {
        return '${_join(have.take(2).toList())} sudah ada di kulkasmu';
      }
      final wanted = [
        for (final name in recipe.ingredients)
          if (request.ingredients.contains(_ingredient(name))) _display(name),
      ];
      if (wanted.isNotEmpty) return 'memakai ${_join(wanted.take(2).toList())}';
      if (shown.length > 1) {
        final fastest = shown.reduce(
          (a, b) => (b.minutes ?? 9999) < (a.minutes ?? 9999) ? b : a,
        );
        if (identical(fastest, recipe)) return 'paling cepat';
        final lightest = shown.reduce(
          (a, b) => (b.calories ?? 99999) < (a.calories ?? 99999) ? b : a,
        );
        if (identical(lightest, recipe)) return 'paling rendah kalori';
      }
      final main = recipe.ingredients.where((name) => !_isStaple(name)).length;
      if (main <= 4) return 'cuma $main bahan utama';
      for (final tag in ['vegetarian', 'bekal', 'ramah-anak', 'hemat']) {
        if (recipe.tags.contains(tag)) return _tagNames[tag]!;
      }
      final category = _categoryNames[recipe.category.toLowerCase()];
      return category == null ? '' : 'cocok untuk $category';
    }

    final reason = pick();
    return reason.isEmpty ? '' : ': $reason';
  }

  SubstituteEntry? _entryFor(String ingredient) {
    final key = ingredientKey(ingredient);
    for (final entry in substitutes) {
      if (entry.names.any((name) => ingredientKey(name) == key)) return entry;
    }
    return null;
  }

  bool _canUse(SubstituteOption option, Set<String> stock) =>
      option.uses.isNotEmpty &&
      option.uses.every(
        (use) => _isStaple(use) || stock.contains(ingredientKey(use)),
      );

  /// A substitute for [ingredient] that the user can make from the fridge.
  SubstituteOption? _swapFor(String ingredient, Set<String> stock) {
    for (final option in _entryFor(ingredient)?.options ?? const []) {
      if (_canUse(option, stock)) return option;
    }
    return null;
  }

  String _swapLine(String missing, SubstituteOption option) =>
      '   Kurang ${_display(missing)}, tapi kamu punya '
      '${_join(option.uses)}: ${option.text.toLowerCase()}.';

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
    final stock = _stockKeys(fridge);
    final ranked = <_FridgeMatch>[];
    for (final recipe in catalog) {
      if (!request.fits(recipe) || !recipe.hasAll(request.ingredients)) {
        continue;
      }
      final match = IngredientMatch(recipe.ingredients, fridge);
      if (match.present.isEmpty) continue;
      // The ingredients in a recipe's name are what makes the dish, so they
      // are never swapped for something else.
      ranked.add(
        _FridgeMatch(recipe, match, {
          for (final name in match.missing)
            if (!recipe.nameForms.contains(_form(name)))
              name: ?_swapFor(name, stock),
        }),
      );
    }
    ranked.sort((a, b) {
      if (a.ready != b.ready) return a.ready ? -1 : 1;
      final byRatio = b.match.ratio.compareTo(a.match.ratio);
      if (byRatio != 0) return byRatio;
      final byUnsolved = a.unsolved.length.compareTo(b.unsolved.length);
      return byUnsolved != 0
          ? byUnsolved
          : a.recipe.order.compareTo(b.recipe.order);
    });
    final filters = request.describe();
    final suffix = filters.isEmpty ? '' : ' ($filters)';
    if (ranked.isEmpty) {
      return AiReply(
        'Belum ada resep yang cocok dengan isi kulkasmu$suffix. '
        'Coba tambah bahan lain di menu Fridge.',
      );
    }
    final top = ranked.take(maxSuggestions).toList();
    final ready = top.where((entry) => entry.ready).toList();
    final later = top.where((entry) => !entry.ready).toList();
    var number = 0;
    final explained = <String>{};
    List<String> describe(_FridgeMatch entry) {
      number++;
      final total = entry.match.present.length + entry.match.missing.length;
      return [
        entry.ready
            ? '$number. ${entry.recipe.name}: '
                  '${entry.match.missing.isEmpty ? 'semua bahan utama sudah ada' : '${entry.match.present.length} dari $total bahan utama sudah ada'}.'
            : '$number. ${entry.recipe.name}: tinggal beli '
                  '${_join([for (final name in entry.unsolved) _display(name)])}.',
        for (final swap in entry.swaps.entries)
          explained.add(ingredientKey(swap.key))
              ? _swapLine(swap.key, swap.value)
              : '   Kurang ${_display(swap.key)}: pakai pengganti yang sama.',
      ];
    }

    final lines = [
      ready.isNotEmpty
          ? 'Ada ${ready.length} resep yang bisa kamu masak sekarang juga$suffix:'
          : 'Belum ada resep yang semua bahannya ada di kulkasmu$suffix. '
                'Ini yang paling dekat:',
      for (final entry in ready) ...describe(entry),
      if (ready.isNotEmpty && later.isNotEmpty) ...[
        '',
        'Kalau mau belanja sedikit:',
      ],
      for (final entry in later) ...describe(entry),
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
    var named = text.namedRecipes(catalog);
    if (named.isEmpty) named = text.partlyNamedRecipes(catalog);
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

  AiReply _substitute(_Text text, List<_Recipe> catalog, Set<String>? stock) {
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
      final known = stock != null && stock.isNotEmpty;
      final usable = [
        for (final option in found.options)
          stock != null && stock.isNotEmpty && _canUse(option, stock),
      ];
      return AiReply(
        [
          'Pengganti ${found.label.toLowerCase()}:',
          for (var i = 0; i < found.options.length; i++)
            '• ${found.options[i].text}${usable[i] ? ' (ada di kulkasmu)' : ''}',
          if (found.note.isNotEmpty) found.note,
          if (known && !usable.contains(true)) 'Kamu belum punya bahan penggantinya di kulkas, jadi perlu beli salah satunya.',
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

  /// Ingredients to buy for [recipes], grouped by ingredient with the grams
  /// added up. Pantry staples and ingredients in the fridge are left out.
  ({List<String> lines, List<String> have}) _toBuy(
    List<_Recipe> recipes,
    Set<String>? stock, {
    bool withSwaps = true,
  }) {
    final rows = <String, ({String name, List<num> grams})>{};
    final have = <String>{};
    for (final recipe in recipes) {
      for (var i = 0; i < recipe.ingredients.length; i++) {
        final name = recipe.ingredients[i];
        if (_isStaple(name)) continue;
        final key = ingredientKey(name);
        if (stock != null && stock.contains(key)) {
          have.add(_display(name));
          continue;
        }
        final row = rows.putIfAbsent(key, () => (name: name, grams: <num>[]));
        final amount = i < recipe.amounts.length ? recipe.amounts[i] : null;
        if (amount != null) row.grams.add(amount);
      }
    }
    String grams(num value) => '${amountText(value.toDouble())} g';
    return (
      lines: [
        for (final row in rows.values)
          [
            '• ${_capitalize(_display(row.name))}',
            if (row.grams.isNotEmpty)
              ': ${grams(row.grams.reduce((a, b) => a + b))}',
            if (row.grams.length > 1) ' (${row.grams.map(grams).join(' + ')})',
            if (withSwaps && stock != null)
              if (_swapFor(row.name, stock) case final option?)
                ' (bisa diganti ${_join(option.uses)} dari kulkasmu)',
          ].join(),
      ],
      have: have.toList(),
    );
  }

  /// Recipes a shopping question points at: names in the question, a day of
  /// the last meal plan, a numbered suggestion, or the last suggestions.
  List<_Recipe> _shoppingTargets(
    _Text text,
    List<_Recipe> catalog,
    ChatMemory memory,
  ) {
    final named = text.mentionedRecipes(catalog);
    if (named.isNotEmpty) return named;
    final byId = {for (final recipe in catalog) recipe.doc.id: recipe};
    List<_Recipe> pick(Iterable<String> ids) => [
      for (final id in ids) ?byId[id],
    ];
    final day = _numberAfter(text, ['hari', 'hari ke', 'day']);
    if (day != null && day >= 1 && day <= memory.plan.length) {
      return pick(memory.plan[day - 1]);
    }
    final position = _numberAfter(text, [
      'nomor',
      'no',
      'yang ke',
      'ke',
      'yang',
    ]);
    if (position != null && position >= 1 && position <= memory.shown.length) {
      return pick([memory.shown[position - 1]]);
    }
    if (memory.plan.isNotEmpty &&
        text.hasAny(['menu', 'rencana', 'plan', 'seminggu', 'meal plan'])) {
      return pick(memory.plan.expand((ids) => ids));
    }
    return pick(memory.shown);
  }

  AiReply _shopping(
    _Text text,
    List<_Recipe> catalog,
    Set<String>? stock,
    ChatMemory memory,
  ) {
    final targets = _shoppingTargets(text, catalog, memory);
    if (targets.isEmpty) {
      return const AiReply(
        'Resep mana yang mau dibelanjakan? Sebutkan namanya, misalnya '
        '"mau masak Tempe Orek, belanja apa aja?", atau minta rencana menu dulu.',
      );
    }
    final names = _join([for (final recipe in targets) recipe.name]);
    final list = _toBuy(targets, stock);
    final lines = [
      if (list.lines.isEmpty)
        'Semua bahan utama untuk $names sudah ada di kulkasmu. Selamat memasak!'
      else ...[
        'Daftar belanja untuk $names:',
        ...list.lines,
      ],
      if (list.have.isNotEmpty) ...[
        '',
        'Sudah ada di kulkas: ${_join(list.have)}.',
      ],
      '',
      if (stock == null)
        'Isi kulkas tidak bisa dimuat, jadi semua bahan dicantumkan.',
      'Takaran untuk 1 porsi per resep. Aku hanya mencocokkan jenis bahan, '
          'jadi cek juga jumlah stokmu.',
    ];
    return AiReply(
      lines.join('\n'),
      recipes: [
        for (final recipe in targets.take(9)) RecipeSuggestion(recipe.doc),
      ],
    );
  }

  AiReply _plan(
    _Text text,
    _Request request,
    List<_Recipe> catalog,
    Set<String>? stock,
  ) {
    final days =
        (_numberBefore(text, ['hari', 'day', 'days']) ??
                (text.hasAny(_weekWords)
                    ? 7
                    : text.hasAny(['hari ini', 'besok', 'today', 'tomorrow'])
                    ? 1
                    : 3))
            .clamp(1, 7);
    final available = {
      for (final recipe in catalog) recipe.category.toLowerCase(),
    };
    final wanted = request.category != null
        ? [request.category!]
        : ['breakfast', 'lunch', 'dinner'];
    final slots = wanted.where(available.contains).toList();
    final notes = [
      for (final slot in wanted)
        if (!available.contains(slot))
          '${_slotNames[slot]} belum ada karena katalog belum punya resep ${_categoryNames[slot]}.',
    ];
    if (slots.isEmpty) return AiReply(notes.join('\n'));

    final have = {...?stock};
    final planned = <String>{};
    final used = <String>{};
    final short = <String>{};
    final plan = <List<(String, _Recipe)>>[];
    for (var day = 0; day < days; day++) {
      final mains = <String>{};
      final meals = <(String, _Recipe)>[];
      for (final slot in slots) {
        _Recipe? best;
        var bestScore = -2.0;
        for (final recipe in catalog) {
          if (recipe.category.toLowerCase() != slot ||
              used.contains(recipe.doc.id) ||
              !request.fits(recipe, checkCategory: false)) {
            continue;
          }
          final keys = recipe.mainKeys;
          final covered = keys
              .where((key) => have.contains(key) || planned.contains(key))
              .length;
          var score = keys.isEmpty ? 0.0 : covered / keys.length;
          if (recipe.leads.any(mains.contains)) score -= 1;
          if (score > bestScore ||
              (score == bestScore && recipe.order < best!.order)) {
            best = recipe;
            bestScore = score;
          }
        }
        if (best == null) {
          short.add(slot);
          continue;
        }
        used.add(best.doc.id);
        planned.addAll(best.mainKeys);
        mains.addAll(best.leads);
        meals.add((slot, best));
      }
      if (meals.isNotEmpty) plan.add(meals);
    }
    if (plan.isEmpty) return AiReply(request.nothingFound());

    final recipes = [
      for (final day in plan)
        for (final meal in day) meal.$2,
    ];
    final filters = request.describe();
    String status(_Recipe recipe) {
      if (stock == null) return '';
      final missing = [
        for (final name in recipe.ingredients)
          if (!_isStaple(name) && !stock.contains(ingredientKey(name)))
            _display(name),
      ];
      if (missing.isEmpty) return ' (semua bahan ada)';
      final shown = missing.take(3).toList();
      return ' (beli ${_join(shown)}${missing.length > 3 ? ', dll.' : ''})';
    }

    final list = _toBuy(recipes, stock);
    final repeated = <String, int>{};
    for (final recipe in recipes) {
      for (final key in recipe.mainKeys) {
        if (have.contains(key)) repeated[key] = (repeated[key] ?? 0) + 1;
      }
    }
    final lines = [
      'Menu ${plan.length} hari${stock != null && stock.isNotEmpty ? ' dari isi kulkasmu' : ''}'
          '${filters.isEmpty ? '' : ' ($filters)'}:',
      for (var day = 0; day < plan.length; day++) ...[
        '',
        'Hari ${day + 1}',
        for (final (slot, recipe) in plan[day])
          '   ${_slotNames[slot]}: ${recipe.name}${status(recipe)}',
      ],
      '',
      if (list.lines.isEmpty)
        'Semua bahan utama sudah ada di kulkasmu.'
      else ...[
        'Belanja sekali untuk ${plan.length} hari:',
        ...list.lines,
      ],
      for (final slot in short)
        'Resep ${_categoryNames[slot]} di katalog tidak cukup untuk ${plan.length} hari tanpa mengulang.',
      ...notes,
      ...request.notes,
      if (repeated.values.any((times) => times > 1)) 'Beberapa bahan dari kulkas dipakai lebih dari sekali, jadi cek jumlahnya.',
    ];
    return AiReply(
      lines.join('\n'),
      recipes: [
        for (final recipe in recipes.take(9)) RecipeSuggestion(recipe.doc),
      ],
      plan: [
        for (final day in plan) [for (final meal in day) meal.$2.doc.id],
      ],
    );
  }
}

const _numberWords = {
  'satu': 1,
  'dua': 2,
  'tiga': 3,
  'empat': 4,
  'lima': 5,
  'enam': 6,
  'tujuh': 7,
  'pertama': 1,
  'kedua': 2,
  'ketiga': 3,
  'keempat': 4,
  'kelima': 5,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'first': 1,
  'second': 2,
  'third': 3,
};

int? _number(String word) => int.tryParse(word) ?? _numberWords[word];

/// The number right after one of [words], as in "hari 3" or "nomor dua".
int? _numberAfter(_Text text, List<String> words) {
  for (final word in words) {
    final match = RegExp(' $word ([a-z0-9]+) ').firstMatch(text.padded);
    final value = match == null ? null : _number(match.group(1)!);
    if (value != null) return value;
  }
  return null;
}

/// The number right before one of [words], as in "3 hari".
int? _numberBefore(_Text text, List<String> words) {
  for (final word in words) {
    final match = RegExp(' ([a-z0-9]+) $word ').firstMatch(text.padded);
    final value = match == null ? null : _number(match.group(1)!);
    if (value != null) return value;
  }
  return null;
}

/// Everyday words of a recipe request that carry no ingredient or recipe.
const _generalWords = {
  'yang',
  'ada',
  'apa',
  'dong',
  'aku',
  'saya',
  'kamu',
  'kita',
  'mau',
  'ingin',
  'bisa',
  'boleh',
  'minta',
  'tolong',
  'kasih',
  'cari',
  'cariin',
  'buat',
  'untuk',
  'dengan',
  'pakai',
  'sama',
  'dan',
  'atau',
  'tidak',
  'saja',
  'lagi',
  'juga',
  'hari',
  'ini',
  'itu',
  'besok',
  'nanti',
  'sekarang',
  'pagi',
  'siang',
  'sore',
  'malam',
  'makan',
  'makanan',
  'masak',
  'masakan',
  'memasak',
  'resep',
  'menu',
  'ide',
  'saran',
  'rekomendasi',
  'enak',
  'gampang',
  'mudah',
  'praktis',
  'bingung',
  'kira',
  'sesuatu',
  'yuk',
  'bagaimana',
  'coba',
  'dulu',
  'punya',
  'bahan',
  'harus',
  'sebaiknya',
  'kalau',
  'jadi',
  'what',
  'should',
  'can',
  'could',
  'cook',
  'cooking',
  'make',
  'recipe',
  'recipes',
  'meal',
  'meals',
  'idea',
  'ideas',
  'suggest',
  'give',
  'some',
  'something',
  'please',
  'today',
  'tonight',
  'tomorrow',
  'for',
  'with',
  'the',
  'and',
  'have',
  'want',
  'eat',
  'food',
  'dish',
  'any',
  'good',
  'easy',
  'you',
};

/// Words that never identify a recipe on their own.
const _commonWords = {
  'resep',
  'masak',
  'masakan',
  'menu',
  'bikin',
  'buat',
  'membuat',
  'mau',
  'ingin',
  'tolong',
  'kasih',
  'cari',
  'cariin',
  'yang',
  'untuk',
  'dengan',
  'pakai',
  'bisa',
  'apa',
  'saja',
  'enak',
  'gampang',
  'mudah',
  'cara',
  'bagaimana',
  'berapa',
  'kalori',
  'lama',
  'menit',
  'bahan',
  'langkah',
  'recipe',
  'recipes',
  'cook',
  'make',
  'with',
  'what',
  'show',
  'please',
  'goreng',
  'tumis',
  'kuah',
  'bakar',
  'sayur',
  'manis',
  'pedas',
};

const _moreWords = [
  'yang lain',
  'lainnya',
  'lain',
  'resep lain',
  'opsi lain',
  'ada lagi',
  'other',
  'more',
  'another',
  'something else',
];
const _weekWords = [
  'seminggu',
  'sepekan',
  'mingguan',
  'minggu ini',
  'minggu depan',
  'week',
  'weekly',
];
const _slotNames = {
  'breakfast': 'Sarapan',
  'lunch': 'Siang',
  'dinner': 'Malam',
  'snack': 'Camilan',
  'dessert': 'Pencuci mulut',
};

String _join(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} dan ${items.last}';

const _unclear =
    'Aku belum yakin maksudmu. Coba tanya seperti "masak apa pakai telur?", '
    '"santan bisa diganti apa?", atau "isi kulkasku bisa jadi apa?".';
const _notFound =
    'Aku belum menemukan bahan atau nama resep di pertanyaanmu. '
    'Coba sebut bahannya, misalnya "resep pakai ayam".';
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
    '• Daftar belanja. Contoh: "mau masak tempe orek, belanja apa aja?"\n'
    '• Rencana menu beberapa hari. Contoh: "buatin menu 3 hari dari isi kulkas"\n'
    'Kamu juga bisa minta resep vegetarian, tidak pedas, hemat, untuk bekal, '
    'ramah anak, atau tanpa bahan tertentu, misalnya "resep tanpa telur".\n'
    'Menu Meal preference di bawah bisa dipakai sebagai filter yang terus aktif.';

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

/// Indonesian names used when an answer repeats an ingredient the user asked
/// for, so "eggs" is answered as "telur".
const _indonesianNames = {
  'egg': 'telur',
  'chicken': 'ayam',
  'tofu': 'tahu',
  'tempeh': 'tempe',
  'cooked rice': 'nasi',
  'rice': 'beras',
  'noodles': 'mie',
  'spinach': 'bayam',
  'carrot': 'wortel',
  'tomato': 'tomat',
  'potato': 'kentang',
  'corn': 'jagung',
  'cabbage': 'kol',
  'milk': 'susu',
  'banana': 'pisang',
  'flour': 'tepung',
  'bread': 'roti',
  'butter': 'mentega',
  'sugar': 'gula',
  'cooking oil': 'minyak',
  'soy sauce': 'kecap asin',
  'sweet soy sauce': 'kecap manis',
  'garlic': 'bawang putih',
  'shallot': 'bawang merah',
  'onion': 'bawang bombay',
  'chili': 'cabai',
  'salt': 'garam',
  'pepper': 'merica',
  'cheese': 'keju',
  'coconut milk': 'santan',
};

/// Words that ask for a recipe tag. Checked in order, and a matched phrase is
/// removed so "anak kos" is not also read as "anak".
const _tagWords = [
  ('anak kos', 'hemat'),
  ('akhir bulan', 'hemat'),
  ('ramah anak', 'ramah-anak'),
  ('kid friendly', 'ramah-anak'),
  ('anak', 'ramah-anak'),
  ('balita', 'ramah-anak'),
  ('kids', 'ramah-anak'),
  ('vegetarian', 'vegetarian'),
  ('vegan', 'vegetarian'),
  ('tanpa daging', 'vegetarian'),
  ('meatless', 'vegetarian'),
  ('hemat', 'hemat'),
  ('murah', 'hemat'),
  ('irit', 'hemat'),
  ('budget', 'hemat'),
  ('cheap', 'hemat'),
  ('bekal', 'bekal'),
  ('lunchbox', 'bekal'),
  ('pack for lunch', 'bekal'),
  ('pedas', 'pedas'),
  ('pedes', 'pedas'),
  ('spicy', 'pedas'),
];
const _notSpicyWords = [
  'tidak pedas',
  'tanpa pedas',
  'not spicy',
  'no spicy',
  'non spicy',
  'mild',
];
const _tagNames = {
  'vegetarian': 'vegetarian',
  'pedas': 'pedas',
  'hemat': 'hemat',
  'bekal': 'cocok untuk bekal',
  'ramah-anak': 'ramah anak',
};

/// Words for each allergen, read after "tanpa", "alergi", "bebas", "no" or
/// "without", or before "free".
const _allergenWords = {
  'telur': 'telur',
  'egg': 'telur',
  'eggs': 'telur',
  'susu': 'susu',
  'milk': 'susu',
  'dairy': 'susu',
  'keju': 'susu',
  'kacang': 'kacang',
  'kacang tanah': 'kacang',
  'peanut': 'kacang',
  'peanuts': 'kacang',
  'nuts': 'kacang',
  'seafood': 'seafood',
  'udang': 'seafood',
  'ikan': 'seafood',
  'cumi': 'seafood',
  'shrimp': 'seafood',
  'prawn': 'seafood',
  'fish': 'seafood',
  'gluten': 'gluten',
  'terigu': 'gluten',
  'tepung terigu': 'gluten',
  'wheat': 'gluten',
};
const _allergenIngredients = {
  'telur': {'egg'},
  'susu': {'milk', 'cheese', 'butter'},
  'kacang': <String>{},
  'seafood': <String>{},
  'gluten': {'flour', 'bread', 'noodles'},
};
const _negations = ['tanpa', 'alergi', 'bebas', 'no', 'without', 'tidak pakai'];

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
    tags = Set<String>.from(data['tags'] ?? const []);
    mainKeys = {
      for (final name in ingredients)
        if (!_isStaple(name)) ingredientKey(name),
    }.toList();
    final listed = data['allergens'];
    allergens = listed is List ? Set<String>.from(listed) : null;
  }
  final DocumentSnapshot<Map<String, dynamic>> doc;
  late final String name, category;
  late final int? minutes, calories;
  late final List<String> ingredients, steps;
  late final List<num?> amounts;
  late final Set<String> keys, nameForms, tags;

  /// Fridge keys of the ingredients other than pantry staples, in recipe
  /// order, so the first one is the main ingredient.
  late final List<String> mainKeys;

  /// The ingredients a dish is about: the first one and those in its name,
  /// such as egg and tomato for "Orak-Arik Telur Tomat".
  Set<String> get leads => {
    if (mainKeys.isNotEmpty) mainKeys.first,
    for (final key in mainKeys)
      if (nameForms.contains(_form(key))) key,
  };

  /// Allergens marked by the admin, or null for recipes saved before the
  /// allergen field existed.
  late final Set<String>? allergens;

  /// Random position used to vary suggestions; recently shown recipes are
  /// moved to the end.
  double order = 0;

  bool hasAll(Set<String> wanted) => keys.containsAll(wanted);
  int countOf(Set<String> wanted) => wanted.where(keys.contains).length;

  String summary(_Request request) =>
      '$name (${[if (minutes != null) '$minutes menit', if (calories != null) '$calories kkal', if (request.maxIngredients != null) '${ingredients.length} bahan'].join(', ')})';

  String get ingredientList => [
    for (var i = 0; i < ingredients.length; i++)
      i < amounts.length && amounts[i] != null
          ? '${ingredients[i]} (${amountText(amounts[i]!.toDouble())} g)'
          : ingredients[i],
  ].join(', ');
}

/// The question as normalised tokens, with numbers kept.
class _Text {
  _Text(List<String> words) : this._(words.map(_withoutNya).toList());
  _Text._(this.tokens) : padded = ' ${tokens.join(' ')} ';

  /// "cabainya" means "the chili": drop the "-nya" suffix so the word
  /// matches ingredient and recipe names.
  static String _withoutNya(String word) =>
      word.length > 5 && word.endsWith('nya')
      ? word.substring(0, word.length - 3)
      : word;

  final List<String> tokens;
  final String padded;

  bool has(String phrase) => padded.contains(' $phrase ');
  bool hasAny(List<String> phrases) => phrases.any(has);
  int indexOf(String phrase) => padded.indexOf(' $phrase ');

  /// Every recipe whose full name is in the question, for questions that
  /// name several recipes. Falls back to a single close match.
  List<_Recipe> mentionedRecipes(List<_Recipe> catalog) {
    final words = tokens.map(_form).toSet();
    final full = [
      for (final recipe in catalog)
        if (recipe.nameForms.isNotEmpty && words.containsAll(recipe.nameForms))
          recipe,
    ];
    final kept = [
      for (final recipe in full)
        if (!full.any(
          (other) =>
              other.nameForms.length > recipe.nameForms.length &&
              other.nameForms.containsAll(recipe.nameForms),
        ))
          recipe,
    ];
    if (kept.isNotEmpty) return kept;
    final named = namedRecipes(catalog);
    return named.length == 1 ? named : [];
  }

  /// Whether the question has a word that is neither a general request word
  /// nor a known ingredient, category or recipe word, such as a misspelled
  /// ingredient. A plain "masak apa hari ini?" has none.
  bool hasUnknownWords(List<_Recipe> catalog) {
    final known = <String>{
      ..._generalWords,
      ..._commonWords,
      for (final phrase in [..._ingredientTerms, ..._categoryWords.keys])
        ...phrase.split(' '),
      for (final recipe in catalog) ...[
        ...recipe.nameForms,
        for (final name in recipe.ingredients) ..._words(name),
      ],
    };
    return tokens.any(
      (token) =>
          token.length >= 3 &&
          int.tryParse(token) == null &&
          !known.contains(token) &&
          !known.contains(_form(token)),
    );
  }

  /// Recipes with a distinctive word of their name in the question, as in
  /// "resep rendang" for Rendang Daging. Common words are ignored.
  List<_Recipe> partlyNamedRecipes(List<_Recipe> catalog) {
    final words = {
      for (final token in tokens)
        if (token.length >= 4 && !_commonWords.contains(token)) _form(token),
    };
    return [
      for (final recipe in catalog)
        if (recipe.nameForms.any(words.contains)) recipe,
    ];
  }

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
    var padded = text.padded;
    for (final entry in _allergenWords.entries) {
      for (final negation in _negations) {
        for (final phrase in [
          '$negation ${entry.key}',
          if (negation == _negations.first) '${entry.key} free',
        ]) {
          if (padded.contains(' $phrase ')) {
            request.excludedAllergens.add(entry.value);
            padded = padded.replaceAll(' $phrase ', ' | ');
          }
        }
      }
    }
    for (final phrase in _notSpicyWords) {
      if (padded.contains(' $phrase ')) {
        request.excludedTags.add('pedas');
        padded = padded.replaceAll(' $phrase ', ' | ');
      }
    }
    for (final (phrase, tag) in _tagWords) {
      if (padded.contains(' $phrase ')) {
        request.requiredTags.add(tag);
        padded = padded.replaceAll(' $phrase ', ' | ');
      }
    }
    final known = {for (final recipe in catalog) ...recipe.keys};
    final (found, rest) = mentions(
      _Text(padded.split(' ').where((word) => word.isNotEmpty).toList()),
      catalog,
    );
    found.forEach((key, word) {
      if (known.contains(key)) {
        request.ingredients.add(key);
        request.ingredientNames.add(_indonesianNames[key] ?? word);
      } else {
        request.unknownIngredients.add(_indonesianNames[key] ?? word);
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
      case MealPreference.vegetarian:
        request.requiredTags.add('vegetarian');
      case MealPreference.notSpicy:
        request.excludedTags.add('pedas');
      case MealPreference.budget:
        request.requiredTags.add('hemat');
      case MealPreference.lunchbox:
        request.requiredTags.add('bekal');
      case MealPreference.kidFriendly:
        request.requiredTags.add('ramah-anak');
      case MealPreference.none:
        break;
    }
    request.requiredTags.removeAll(request.excludedTags);
    if (request.excludedAllergens.isNotEmpty &&
        catalog.any((recipe) => recipe.allergens == null)) {
      request.notes.add(
        'Resep yang belum punya data alergen tidak ditampilkan. '
        'Tetap cek bahannya sebelum memasak.',
      );
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

  final Set<String> ingredients = {}, requiredTags = {}, excludedTags = {};
  final Set<String> excludedAllergens = {};
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
      requiredTags.isNotEmpty ||
      excludedTags.isNotEmpty ||
      excludedAllergens.isNotEmpty ||
      ingredients.isNotEmpty ||
      unknownIngredients.isNotEmpty;

  bool fits(_Recipe recipe, {bool checkCategory = true}) =>
      (!checkCategory ||
          category == null ||
          recipe.category.toLowerCase() == category) &&
      (maxMinutes == null ||
          (recipe.minutes != null && recipe.minutes! <= maxMinutes!)) &&
      (maxCalories == null ||
          (recipe.calories != null && recipe.calories! <= maxCalories!)) &&
      (maxIngredients == null ||
          recipe.ingredients.length <= maxIngredients!) &&
      recipe.tags.containsAll(requiredTags) &&
      !recipe.tags.any(excludedTags.contains) &&
      (excludedAllergens.isEmpty || _safeFor(recipe));

  /// A recipe is only safe when the admin marked its allergens and neither
  /// the marks nor the ingredient names contain an excluded allergen.
  bool _safeFor(_Recipe recipe) {
    final marked = recipe.allergens;
    if (marked == null || marked.any(excludedAllergens.contains)) return false;
    return !excludedAllergens.any(
      (allergen) => recipe.keys.any(_allergenIngredients[allergen]!.contains),
    );
  }

  String describe() => _join([
    if (ingredientNames.isNotEmpty) 'bahan ${_join(ingredientNames)}',
    if (category != null) 'kategori ${_categoryNames[category]}',
    if (maxMinutes != null) 'maksimal $maxMinutes menit',
    if (maxIngredients != null) 'maksimal $maxIngredients bahan',
    if (maxCalories != null) 'maksimal $maxCalories kkal',
    for (final tag in requiredTags) _tagNames[tag]!,
    if (excludedTags.contains('pedas')) 'tidak pedas',
    if (excludedAllergens.isNotEmpty)
      'tanpa ${_join(excludedAllergens.toList())}',
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
