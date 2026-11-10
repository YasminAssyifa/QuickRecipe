import 'dart:async';

import 'package:quick_recipe/additions/ai_chat.dart';

class FakeAi implements AiRepository {
  List<ChatExchange> saved = [];
  List<List<ChatMessage>> asked = [];
  List<MealPreference> preferences = [];
  String answer = 'Try an omelette.';
  List<RecipeSuggestion> recipes = [];
  bool failReply = false, failSave = false, failLoad = false;
  Completer<void>? pendingReply;
  int serial = 0;

  @override
  String newId() => 'chat-${serial++}';

  @override
  Future<List<ChatExchange>> history() async {
    if (failLoad) throw StateError('Offline');
    return List.of(saved);
  }

  @override
  Future<AiReply> reply(
    List<ChatMessage> conversation, {
    MealPreference preference = MealPreference.none,
  }) async {
    asked.add(List.of(conversation));
    preferences.add(preference);
    if (pendingReply != null) await pendingReply!.future;
    if (failReply) {
      throw StateError(
        'QuickRecipe AI is not available right now. Try again later.',
      );
    }
    return AiReply(answer, recipes: List.of(recipes));
  }

  @override
  Future<void> save(ChatExchange exchange) async {
    if (failSave) throw StateError('Offline');
    saved.add(exchange);
  }

  @override
  Future<void> clear() async => saved.clear();
}
