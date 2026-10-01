import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../Utils/constants.dart';
import '../views/recipe_detail_screen.dart';
import 'kitchen_repository.dart';
import 'shared.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});
  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  late KitchenRepository _repo;
  late Future<List<RecipeCollection>> _future;
  final Set<String> _deleting = {};
  @override
  void initState() {
    super.initState();
    _repo = context.read<KitchenRepository?>()!;
    _future = _repo.collections();
  }

  void _reload() => setState(() => _future = _repo.collections());
  Future<void> _edit([RecipeCollection? item]) async {
    if (await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CollectionFormScreen(item: item),
              ),
            ) ==
            true &&
        mounted) {
      _reload();
      showMessage(context, 'Collection saved.');
    }
  }

  Future<void> _delete(RecipeCollection item) async {
    if (_deleting.contains(item.id)) return;
    if (!await confirmRemoval(context, item.name) || !mounted) return;
    setState(() => _deleting.add(item.id));
    try {
      await _repo.delete('collections', item.id);
      if (mounted) {
        _reload();
        showMessage(
          context,
          'Collection deleted. Recipes are still available.',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _deleting.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kbackgroundColor,
    appBar: AppBar(
      backgroundColor: kbackgroundColor,
      title: const Text('Recipe collections'),
      actions: [
        IconButton(
          tooltip: 'New collection',
          onPressed: _edit,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: LoadPanel(
      future: _future,
      retry: _reload,
      builder: (items) => RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            const Text(
              'Organize recipes into folders, such as Breakfast or Quick dinners. Your Favorites stay in their own list.',
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              FeedbackPanel(
                title: 'No collections yet',
                message: 'Create your first folder and choose recipes to keep in it.',
                action: 'Create collection',
                onAction: _edit,
                icon: Icons.folder_outlined,
              ),
            ...items.map(
              (item) => Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    ListTile(
                      isThreeLine: item.notes.isNotEmpty,
                      leading: Icon(Icons.folder_outlined, color: kBannerColor),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.recipeIds.length} recipes${item.notes.isEmpty ? '' : '\n${item.notes}'}',
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CollectionDetailScreen(id: item.id),
                          ),
                        );
                        if (mounted) _reload();
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _deleting.contains(item.id)
                              ? null
                              : () => _edit(item),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: _deleting.contains(item.id)
                              ? null
                              : () => _delete(item),
                          child: Text(
                            _deleting.contains(item.id)
                                ? 'Deleting…'
                                : 'Delete',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CollectionFormScreen extends StatefulWidget {
  const CollectionFormScreen({super.key, this.item});
  final RecipeCollection? item;
  @override
  State<CollectionFormScreen> createState() => _CollectionFormScreenState();
}

class _CollectionFormScreenState extends State<CollectionFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _notes;
  late final Set<String> _selected;
  late final KitchenRepository _repo;
  late final String _id;
  late Future<List<DocumentSnapshot<Map<String, dynamic>>>> _recipes;
  bool _busy = false;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _repo = context.read<KitchenRepository?>()!;
    _id = widget.item?.id ?? _repo.newId('collections');
    _name = TextEditingController(text: widget.item?.name ?? '');
    _notes = TextEditingController(text: widget.item?.notes ?? '');
    _selected = {...?widget.item?.recipeIds};
    _recipes = _repo.recipes();
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_selected.length > 100) {
      showMessage(context, 'Choose at most 100 recipes.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await _repo.saveCollection(
        RecipeCollection(
          id: _id,
          name: _name.text,
          notes: _notes.text,
          recipeIds: _selected.toList(),
        ),
        create: widget.item == null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: kbackgroundColor,
      appBar: AppBar(
        backgroundColor: kbackgroundColor,
        title: Text(
          widget.item == null ? 'Create collection' : 'Edit collection',
        ),
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                decoration: fieldStyle('Collection name'),
                maxLength: 60,
                validator: requiredName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                enabled: !_busy,
                decoration: fieldStyle('Description (optional)'),
                maxLength: 300,
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                '${_selected.length} recipes selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !_busy,
                decoration: fieldStyle('Search recipes'),
                onChanged: (query) =>
                    setState(() => _query = query.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              LoadPanel(
                future: _recipes,
                retry: () => setState(() => _recipes = _repo.recipes()),
                builder: (recipes) {
                  final found = recipes
                      .where(
                        (doc) => (doc.data()?['name'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_query),
                      )
                      .toList();
                  final missing = _selected.difference(
                    recipes.map((doc) => doc.id).toSet(),
                  );
                  return Column(
                    children: [
                      if (found.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No recipes found. Try another name.'),
                        ),
                      ...found.map(
                        (doc) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            doc.data()?['name']?.toString() ?? 'Recipe',
                          ),
                          value: _selected.contains(doc.id),
                          onChanged: _busy
                              ? null
                              : (checked) => setState(() {
                                  if (checked == true) {
                                    _selected.add(doc.id);
                                  } else {
                                    _selected.remove(doc.id);
                                  }
                                }),
                        ),
                      ),
                      ...missing.map(
                        (id) => CheckboxListTile(
                          title: const Text('Recipe no longer available'),
                          subtitle: const Text(
                            'Uncheck to remove it from this collection.',
                          ),
                          value: true,
                          onChanged: _busy
                              ? null
                              : (_) => setState(() => _selected.remove(id)),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              PrimaryAction(
                label: 'Save collection',
                busy: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late KitchenRepository _repo;
  late Future<(RecipeCollection?, List<DocumentSnapshot<Map<String, dynamic>>>)>
  _future;
  @override
  void initState() {
    super.initState();
    _repo = context.read<KitchenRepository?>()!;
    _future = _load();
  }

  Future<(RecipeCollection?, List<DocumentSnapshot<Map<String, dynamic>>>)>
  _load() async {
    final collections = await _repo.collections();
    final found = collections.where((item) => item.id == widget.id);
    return (found.isEmpty ? null : found.first, await _repo.recipes());
  }

  void _reload() => setState(() => _future = _load());
  Future<void> _edit(RecipeCollection item) async {
    if (await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CollectionFormScreen(item: item),
              ),
            ) ==
            true &&
        mounted) {
      _reload();
      showMessage(context, 'Collection updated.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kbackgroundColor,
    appBar: AppBar(
      backgroundColor: kbackgroundColor,
      title: const Text('Collection details'),
    ),
    body: LoadPanel(
      future: _future,
      retry: _reload,
      builder: (result) {
        final item = result.$1;
        if (item == null) {
          return FeedbackPanel(
            title: 'Collection removed',
            message: 'Return to your collections to choose another one.',
            action: 'Back',
            onAction: () => Navigator.pop(context),
          );
        }
        final recipes = {for (final doc in result.$2) doc.id: doc};
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (item.notes.isNotEmpty) Text(item.notes),
            const SizedBox(height: 16),
            PrimaryAction(
              label: 'Edit collection / choose recipes',
              onPressed: () => _edit(item),
            ),
            const SizedBox(height: 16),
            if (item.recipeIds.isEmpty)
              const Text(
                'This collection is empty. Choose recipes using the button above.',
              ),
            ...item.recipeIds.map((id) {
              final doc = recipes[id];
              return Card(
                color: Colors.white,
                elevation: 0,
                child: ListTile(
                  title: Text(
                    doc?.data()?['name']?.toString() ??
                        'Recipe no longer available',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: doc == null
                      ? () => _edit(item)
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: '/recipe-detail'),
                            builder: (_) =>
                                RecipeDetailScreen(documentSnapshot: doc),
                          ),
                        ),
                ),
              );
            }),
          ],
        );
      },
    ),
  );
}
