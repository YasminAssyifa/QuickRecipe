import 'package:flutter/material.dart';

import '../Utils/constants.dart';
import 'shared.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final aiShortcutVisible = ValueNotifier<bool>(true);
final aiRouteObserver = AiRouteObserver();

class AiRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  void _update() {
    final top = _routes.isEmpty ? null : _routes.last;
    final visible = top is! PopupRoute &&
        !const {'/ai', '/recipe-detail', '/cooking-steps'}.contains(top?.settings.name);
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
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _preview() {
    if (_input.text.trim().isEmpty) {
      showMessage(context, 'Type a question first.');
      return;
    }
    FocusScope.of(context).unfocus();
    showMessage(
      context,
      'AI is not connected yet. Your message was not sent or saved.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kbackgroundColor,
    appBar: AppBar(
      backgroundColor: kbackgroundColor,
      title: const Text('QuickRecipe AI'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 64,
                      height: 64,
                    ),
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'This is a preview of your recipe assistant. AI answers will be available in a future update.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Try a question',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                        _input.text = text;
                        _input.selection = TextSelection.collapsed(
                          offset: text.length,
                        );
                      },
                      child: Text(text),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Preview only • No messages are sent or stored.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
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
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    decoration: fieldStyle('Ask about cooking'),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _preview(),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton.filled(
                    tooltip: 'Preview message',
                    style: IconButton.styleFrom(backgroundColor: kprimaryColor),
                    onPressed: _preview,
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
