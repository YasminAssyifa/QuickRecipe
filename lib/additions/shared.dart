import 'package:flutter/material.dart';

import '../Utils/constants.dart';
import '../Provider/profile_provider.dart';

String messageFor(Object error) =>
    error is StateError ? error.message.toString() : accountError(error);
void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirmRemoval(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
    false;

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kprimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    ),
  );
}

InputDecoration fieldStyle(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
);

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
    this.icon = Icons.kitchen_outlined,
  });
  final String title, message, action;
  final VoidCallback onAction;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kBannerColor, size: 48),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        PrimaryAction(label: action, onPressed: onAction),
      ],
    ),
  );
}

class LoadPanel<T> extends StatelessWidget {
  const LoadPanel({
    super.key,
    required this.future,
    required this.retry,
    required this.builder,
  });
  final Future<T> future;
  final VoidCallback retry;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (snapshot.hasError) {
        return SingleChildScrollView(
          child: FeedbackPanel(
            title: 'Unable to load',
            message: messageFor(snapshot.error!),
            action: 'Try again',
            onAction: retry,
            icon: Icons.wifi_off,
          ),
        );
      }
      return builder(snapshot.data as T);
    },
  );
}
