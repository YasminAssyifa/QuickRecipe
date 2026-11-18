import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/utils/constants.dart';

import 'package:quick_recipe/widgets/shared_widgets.dart';
import 'package:quick_recipe/services/recipe_admin_repository.dart';
import 'package:quick_recipe/screens/admin_add_recipe_screen.dart';

class AdminRecipeListScreen extends StatefulWidget {
  const AdminRecipeListScreen({super.key});

  @override
  State<AdminRecipeListScreen> createState() => _AdminRecipeListScreenState();
}

class _AdminRecipeListScreenState extends State<AdminRecipeListScreen> {
  RecipeAdminRepository? _repo;
  late Future<List<DocumentSnapshot<Map<String, dynamic>>>> _recipes;
  final Set<String> _deleting = {};

  @override
  void initState() {
    super.initState();
    _repo = context.read<RecipeAdminRepository?>();
    _recipes = _load();
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _load() async {
    final repo = _repo;
    if (repo == null) {
      throw StateError('Sign in as an admin to manage recipes.');
    }
    return repo.recipes();
  }

  void _reload() => setState(() {
    _recipes = _load();
  });

  // Open the form and refresh the list after a save
  Future<void> _openForm([
    DocumentSnapshot<Map<String, dynamic>>? recipe,
  ]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAddRecipeScreen(recipe: recipe),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> recipe) async {
    final repo = _repo;
    final name = '${recipe.data()?['name'] ?? 'this recipe'}';
    if (repo == null || _deleting.contains(recipe.id)) return;
    if (!await confirmRemoval(context, name)) return;
    setState(() => _deleting.add(recipe.id));
    try {
      await repo.delete(recipe.id);
      if (!mounted) return;
      showMessage(context, 'Recipe deleted.');
      _reload();
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _deleting.remove(recipe.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackgroundColor,
      appBar: AppBar(
        backgroundColor: kbackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Recipe List',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Recipe',
            onPressed: () => _openForm(),
            icon: const Icon(
              Icons.add_circle_outline,
              color: kprimaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: LoadPanel<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: _recipes,
        retry: _reload,
        builder: (recipes) {
          if (recipes.isEmpty) {
            return SingleChildScrollView(
              child: FeedbackPanel(
                title: 'No recipes yet',
                message: 'Add the first recipe to start the catalog.',
                action: 'Add recipe',
                onAction: () => _openForm(),
                icon: Icons.menu_book_outlined,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _recipes;
              } catch (_) {
                // The error is shown by the panel after the refresh.
              }
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: recipes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                final data = recipe.data() ?? const <String, dynamic>{};
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      onTap: () => _openForm(recipe),
                      title: Text(
                        '${data['name'] ?? 'Untitled recipe'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${data['category'] ?? '-'} • ${data['time'] ?? '-'} min',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: _deleting.contains(recipe.id)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'Delete recipe',
                              onPressed: () => _delete(recipe),
                              icon: const Icon(Icons.delete_outline),
                            ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
