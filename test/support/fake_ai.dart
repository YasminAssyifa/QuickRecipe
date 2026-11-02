import 'dart:async';

import 'package:quick_recipe/additions/ai_chat.dart';

class FakeAi implements AiRepository {
  List<ChatExchange> saved = [];
  List<List<ChatMessage>> asked = [];
  String answer = 'Try an omelette.';
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
  Future<String> reply(List<ChatMessage> conversation) async {
    asked.add(List.of(conversation));
    if (pendingReply != null) await pendingReply!.future;
    if (failReply) {
      throw StateError(
        'QuickRecipe AI is not available right now. Try again later.',
      );
    }
    return answer;
  }

  @override
  Future<void> save(ChatExchange exchange) async {
    if (failSave) throw StateError('Offline');
    saved.add(exchange);
  }

  @override
  Future<void> clear() async => saved.clear();
}
