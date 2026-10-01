import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../Utils/constants.dart';
import '../views/recipe_detail_screen.dart';
import 'kitchen_repository.dart';
import 'shared.dart';

class RecipeMatchesScreen extends StatefulWidget {
  const RecipeMatchesScreen({super.key, required this.fridge});
  final List<FridgeItem> fridge;
  @override
  State<RecipeMatchesScreen> createState() => _RecipeMatchesScreenState();
}

class _RecipeMatchesScreenState extends State<RecipeMatchesScreen> {
  late Future<List<DocumentSnapshot<Map<String, dynamic>>>> _future;
  @override
  void initState() {
    super.initState();
    _future = context.read<KitchenRepository?>()!.recipes();
  }

  void _reload() =>
      setState(() => _future = context.read<KitchenRepository?>()!.recipes());
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kbackgroundColor,
    appBar: AppBar(
      backgroundColor: kbackgroundColor,
      title: const Text('Recipes from your fridge'),
    ),
    body: LoadPanel(
      future: _future,
      retry: _reload,
      builder: (recipes) {
        final ranked =
            recipes
                .map(
                  (doc) => (
                    doc: doc,
                    match: IngredientMatch(
                      List<String>.from(doc.data()?['ingredientsName'] ?? []),
                      widget.fridge,
                      DateTime.now(),
                    ),
                  ),
                )
                .where((entry) => entry.match.present.isNotEmpty)
                .toList()
              ..sort((a, b) => b.match.ratio.compareTo(a.match.ratio));
        if (ranked.isEmpty) {
          return SingleChildScrollView(
            child: FeedbackPanel(
              title: 'No matching recipes yet',
              message: 'Add another ingredient to your fridge. Expired ingredients are excluded.',
              action: 'Back to fridge',
              onAction: () => Navigator.pop(context),
              icon: Icons.search_off,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            const Text(
              'Matches are based on ingredient names, not quantities. Check amounts and use-by dates before cooking.',
            ),
            const SizedBox(height: 16),
            ...ranked.map(
              (entry) => Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/recipe-detail'),
                      builder: (_) =>
                          RecipeDetailScreen(documentSnapshot: entry.doc),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.doc.data()?['name']?.toString() ?? 'Recipe',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Available: ${entry.match.present.join(', ')}',
                          style: TextStyle(color: kBannerColor),
                        ),
                        Text(
                          entry.match.missing.isEmpty
                              ? 'All ingredient types available'
                              : 'Still needed: ${entry.match.missing.join(', ')}',
                        ),
                        const SizedBox(height: 8),
                        const Text('View recipe →'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
