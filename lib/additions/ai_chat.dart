import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

const questionLimit = 500;
const answerLimit = 4000;
const historyWindow = 10;

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

class ChatExchange {
  const ChatExchange({
    required this.id,
    required this.question,
    required this.answer,
  });
  final String id, question, answer;
  List<ChatMessage> get messages => [
    ChatMessage(fromUser: true, text: question),
    ChatMessage(fromUser: false, text: answer),
  ];
  Map<String, dynamic> toMap() => {'question': question, 'answer': answer};
  factory ChatExchange.fromMap(String id, Map<String, dynamic> data) =>
      ChatExchange(
        id: id,
        question: data['question'] as String? ?? '',
        answer: data['answer'] as String? ?? '',
      );
}

/// Filter chosen in the "Meal preference" menu. It stays active for every
/// recipe suggestion until the user picks another option.
enum MealPreference { none, quick, fridge, fewIngredients, lowCalorie }

/// A recipe shown as a card under the latest answer. [available] and
/// [missing] are filled only for suggestions based on the user's fridge.
class RecipeSuggestion {
  const RecipeSuggestion(
    this.recipe, {
    this.available = const [],
    this.missing = const [],
  });
  final DocumentSnapshot<Map<String, dynamic>> recipe;
  final List<String> available, missing;
  bool get fromFridge => available.isNotEmpty || missing.isNotEmpty;
}

class AiReply {
  const AiReply(this.text, {this.recipes = const []});
  final String text;
  final List<RecipeSuggestion> recipes;
}

abstract class AiRepository {
  String newId();
  Future<List<ChatExchange>> history();
  Future<AiReply> reply(
    List<ChatMessage> conversation, {
    MealPreference preference = MealPreference.none,
  });
  Future<void> save(ChatExchange exchange);
  Future<void> clear();
}

/// Stores the chat in users/{uid}/aiChats. Only the question and the answer
/// text are saved, so recipe cards appear for the latest answer only.
abstract class FirestoreChatRepository implements AiRepository {
  FirestoreChatRepository(this.uid);
  final String uid;
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection('users').doc(uid).collection('aiChats');

  @override
  String newId() => _ref.doc().id;

  @override
  Future<List<ChatExchange>> history() async {
    final snapshot = await _ref
        .orderBy('createdAt')
        .limitToLast(50)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => ChatExchange.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> save(ChatExchange exchange) => _ref.doc(exchange.id).set({
    ...exchange.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> clear() async {
    final snapshot = await _ref.get(const GetOptions(source: Source.server));
    for (var i = 0; i < snapshot.docs.length; i += 400) {
      final batch = _db.batch();
      for (final doc in snapshot.docs.skip(i).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}

const _instruction =
    'You are the cooking assistant inside the QuickRecipe app. '
    'Help with recipes, meal ideas, ingredient substitutes, and cooking steps. '
    'Reply in the language the user writes in. Keep answers short and practical. '
    'Politely decline topics unrelated to food or cooking. '
    'Remind the user to check allergies when suggesting ingredients.';

/// Gemini through Firebase AI Logic. Not wired in main.dart while the
/// project's AI Logic setup is unavailable; kept so it can be switched back on.
class FirebaseAiRepository extends FirestoreChatRepository {
  FirebaseAiRepository(super.uid);
  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.5-flash',
    systemInstruction: Content.system(_instruction),
    generationConfig: GenerationConfig(maxOutputTokens: 1024),
  );

  @override
  Future<AiReply> reply(
    List<ChatMessage> conversation, {
    MealPreference preference = MealPreference.none,
  }) async {
    final recent = conversation.length > historyWindow
        ? conversation.sublist(conversation.length - historyWindow)
        : conversation;
    final GenerateContentResponse response;
    try {
      response = await _model.generateContent(
        recent.map(
          (message) => Content(message.fromUser ? 'user' : 'model', [
            TextPart(message.text),
          ]),
        ),
      );
    } on FirebaseAIException {
      throw StateError(
        'QuickRecipe AI is not available right now. Try again later.',
      );
    }
    final text = (response.text ?? '').trim();
    if (text.isEmpty) throw StateError('No answer was returned. Try again.');
    return AiReply(
      text.length > answerLimit ? text.substring(0, answerLimit) : text,
    );
  }
}
