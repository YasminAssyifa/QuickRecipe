import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Utils/constants.dart';
import 'ai_chat.dart';
import 'shared.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final aiShortcutVisible = ValueNotifier<bool>(true);
final aiRouteObserver = AiRouteObserver();

class AiRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  void _update() {
    final top = _routes.isEmpty ? null : _routes.last;
    final visible =
        top is! PopupRoute &&
        !const {
          '/ai',
          '/recipe-detail',
          '/cooking-steps',
        }.contains(top?.settings.name);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      aiShortcutVisible.value = visible;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
    _update();
  }
}

class AiShortcutLayer extends StatefulWidget {
  const AiShortcutLayer({super.key, required this.child});
  final Widget child;
  @override
  State<AiShortcutLayer> createState() => _AiShortcutLayerState();
}

class _AiShortcutLayerState extends State<AiShortcutLayer> {
  Offset? _position;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final maxX = (constraints.maxWidth - 64).clamp(0.0, double.infinity);
      final minY = media.padding.top + 64;
      final maxY =
          (constraints.maxHeight -
                  media.viewInsets.bottom -
                  media.padding.bottom -
                  140)
              .clamp(minY, double.infinity);
      final position = Offset(
        (_position?.dx ?? maxX).clamp(0.0, maxX),
        (_position?.dy ?? maxY).clamp(minY, maxY),
      );
      return Stack(
        children: [
          widget.child,
          ValueListenableBuilder<bool>(
            valueListenable: aiShortcutVisible,
            builder: (context, visible, _) {
              if (!visible) return const SizedBox.shrink();
              return Positioned(
                left: position.dx,
                top: position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) =>
                      setState(() => _position = position + details.delta),
                  child: Semantics(
                    button: true,
                    label: 'Open QuickRecipe AI',
                    hint: 'Drag to move',
                    child: Material(
                      color: kprimaryColor,
                      elevation: 5,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => appNavigatorKey.currentState?.push(
                          MaterialPageRoute<void>(
                            settings: const RouteSettings(name: '/ai'),
                            builder: (_) => const AiScreen(),
                          ),
                        ),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  AiRepository? _repo;
  final List<ChatMessage> _messages = [];
  bool _loading = false, _busy = false;
  Object? _loadError;
  String _preference = 'Custom';
  static const _prompts = {
    'Custom': '',
    'Balanced meals': 'Suggest a balanced meal with vegetables and protein.',
    'Diet-friendly': 'Suggest a lighter meal with vegetables and protein.',
    'Quick & easy': 'Suggest an easy meal I can cook in under 20 minutes.',
    'Budget-friendly': 'Suggest a meal using affordable everyday ingredients.',
    'Vegetarian': 'Suggest a vegetarian meal without meat or fish.',
    'Use my ingredients':
        'Help me plan a meal using ingredients I already have.',
  };

  @override
  void initState() {
    super.initState();
    _repo = context.read<AiRepository?>();
    _load();
  }

  Future<void> _load() async {
    final repo = _repo;
    if (repo == null) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final history = await repo.history();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history.expand((exchange) => exchange.messages));
        _loading = false;
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _choosePreference(String? preference) {
    if (preference == null) return;
    setState(() => _preference = preference);
    final prompt = _prompts[preference]!;
    if (prompt.isNotEmpty) {
      _input.text = prompt;
      _input.selection = TextSelection.collapsed(offset: prompt.length);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty) {
      showMessage(context, 'Type a question first.');
      return;
    }
    final repo = _repo;
    if (repo == null) {
      showMessage(context, 'Sign in to use QuickRecipe AI.');
      return;
    }
    if (_busy || _loading || _loadError != null) return;
    FocusScope.of(context).unfocus();
    final asked = ChatMessage(fromUser: true, text: question);
    setState(() {
      _busy = true;
      _messages.add(asked);
      _input.clear();
    });
    _scrollToEnd();
    try {
      final answer = await repo.reply(List.of(_messages));
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(fromUser: false, text: answer));
        _busy = false;
      });
      _scrollToEnd();
      try {
        await repo.save(
          ChatExchange(id: repo.newId(), question: question, answer: answer),
        );
      } catch (_) {
        if (mounted) {
          showMessage(context, 'The answer could not be saved to your chat.');
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.remove(asked);
        _busy = false;
        if (_input.text.isEmpty) _input.text = question;
      });
      showMessage(context, messageFor(error));
    }
  }

  Future<void> _clear() async {
    final repo = _repo;
    if (repo == null || _busy) return;
    if (!await confirmRemoval(context, 'chat history')) return;
    try {
      await repo.clear();
      if (!mounted) return;
      setState(() => _messages.clear());
      showMessage(context, 'Chat history deleted.');
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    }
  }

  Widget _bubble(ChatMessage message) => Align(
    alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.fromUser ? kprimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: message.fromUser ? Colors.white : Colors.black,
          ),
        ),
      ),
    ),
  );

  List<Widget> _welcome() => [
    Align(
      alignment: Alignment.centerLeft,
      child: ClipOval(
        child: Image.asset('assets/icon/app_icon.png', width: 64, height: 64),
      ),
    ),
    const SizedBox(height: 20),
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi! What would you like to cook?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text('Ask for meal ideas, ingredient substitutes, or cooking tips.'),
        ],
      ),
    ),
    const SizedBox(height: 24),
    const Text('Try a question', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    ...[
      'What can I cook with eggs?',
      'Suggest a quick dinner',
      'How can I replace milk?',
    ].map(
      (text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton(
          onPressed: () {
            setState(() => _preference = 'Custom');
            _input.text = text;
            _input.selection = TextSelection.collapsed(offset: text.length);
          },
          child: Text(text),
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kbackgroundColor,
    appBar: AppBar(
      backgroundColor: kbackgroundColor,
      title: const Text('QuickRecipe AI'),
      actions: [
        if (_messages.isNotEmpty && !_busy)
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? SingleChildScrollView(
                    child: FeedbackPanel(
                      title: 'Unable to load chat',
                      message: messageFor(_loadError!),
                      action: 'Try again',
                      onAction: _load,
                      icon: Icons.wifi_off,
                    ),
                  )
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (_messages.isEmpty) ..._welcome(),
                      ..._messages.map(_bubble),
                      if (_busy)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Answers can be wrong. Check allergies and cooking times.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _preference,
              key: ValueKey(_preference),
              isExpanded: true,
              decoration: fieldStyle('Meal preference'),
              items: _prompts.keys
                  .map(
                    (label) =>
                        DropdownMenuItem(value: label, child: Text(label)),
                  )
                  .toList(),
              onChanged: _choosePreference,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: questionLimit,
                    minLines: 1,
                    maxLines: 4,
                    decoration: fieldStyle('Ask about cooking'),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton.filled(
                    tooltip: 'Send message',
                    style: IconButton.styleFrom(backgroundColor: kprimaryColor),
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
