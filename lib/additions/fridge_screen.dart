import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Utils/constants.dart';
import 'kitchen_repository.dart';
import 'shared.dart';
import 'collection_screens.dart';
import 'recipe_matches_screen.dart';
import 'use_ingredients_screen.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});
  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  late KitchenRepository _repo;
  late Future<List<FridgeItem>> _future;
  DemoScenario _demo = DemoScenario.normal;
  String? _group;
  final Set<String> _deleting = {};
  @override
  void initState() {
    super.initState();
    _repo = context.read<KitchenRepository?>()!;
    _future = FridgeDemoRepository(_repo).load(_demo);
  }

  void _reload([DemoScenario scenario = DemoScenario.normal]) => setState(() {
    _demo = scenario;
    _future = FridgeDemoRepository(_repo).load(scenario);
  });
  Future<void> _edit([FridgeItem? item]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FridgeFormScreen(item: item)),
    );
    if (saved == true && mounted) {
      _reload();
      showMessage(context, 'Ingredient saved to your fridge.');
    }
  }

  Future<void> _delete(FridgeItem item) async {
    if (_deleting.contains(item.id)) return;
    if (!await confirmRemoval(context, item.name) || !mounted) return;
    setState(() => _deleting.add(item.id));
    try {
      await _repo.delete('fridge', item.id);
      if (mounted) {
        _reload();
        showMessage(context, 'Ingredient deleted.');
      }
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _deleting.remove(item.id));
    }
  }

  Future<void> _useIngredients() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const UseIngredientsScreen()),
    );
    if (saved == true && mounted) {
      _reload();
      showMessage(context, 'Stock updated.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kbackgroundColor,
    appBar: AppBar(
      backgroundColor: kbackgroundColor,
      title: const Text('My Fridge'),
      actions: [
        IconButton(
          tooltip: 'Recipe collections',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CollectionsScreen()),
          ),
          icon: const Icon(Icons.folder_outlined),
        ),
        PopupMenuButton<DemoScenario>(
          tooltip: 'Demo scenarios',
          onSelected: _reload,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: DemoScenario.normal,
              child: Text('Load Firestore data'),
            ),
            PopupMenuItem(
              value: DemoScenario.empty,
              child: Text('Demo: empty fridge'),
            ),
            PopupMenuItem(
              value: DemoScenario.failure,
              child: Text('Demo: failed loading'),
            ),
          ],
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_demo != DemoScenario.normal)
              Card(
                child: ListTile(
                  title: const Text('Demo preview — your data is unchanged'),
                  trailing: TextButton(
                    onPressed: _reload,
                    child: const Text('Exit demo'),
                  ),
                ),
              ),
            if (items.isEmpty)
              FeedbackPanel(
                title: 'Your fridge is empty',
                message: 'Add ingredients you have at home to find recipes you can cook.',
                action: _demo == DemoScenario.empty
                    ? 'Exit demo'
                    : 'Add ingredient',
                onAction: _demo == DemoScenario.empty ? _reload : _edit,
              ),
            if (items.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: items.any((item) => item.inStock)
                    ? _useIngredients
                    : null,
                icon: const Icon(Icons.restaurant),
                label: const Text('Pakai bahan'),
              ),
              const SizedBox(height: 12),
              PrimaryAction(
                label: 'Find recipes',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeMatchesScreen(fridge: items),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.add),
                label: const Text('Add ingredient'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _group ?? 'all',
                decoration: fieldStyle('Kelompok bahan'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All ingredients'),
                  ),
                  ...foodGroups.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _group = value == 'all' ? null : value),
              ),
              const SizedBox(height: 12),
              if (!items.any(
                (item) => _group == null || item.categoryId == _group,
              ))
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No ingredients in this group. Choose All ingredients or add one.',
                  ),
                ),
              ...items
                  .where((item) => _group == null || item.categoryId == _group)
                  .map(
                    (item) => Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${amountText(item.amount)} ${item.unit} • ${foodGroups[item.categoryId] ?? item.categoryId}',
                            ),
                            if (!item.inStock)
                              const Text(
                                'Habis',
                                style: TextStyle(color: Colors.red),
                              ),
                            if (item.notes.isNotEmpty) Text(item.notes),
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
                  ),
            ],
          ],
        ),
      ),
    ),
  );
}

class FridgeFormScreen extends StatefulWidget {
  const FridgeFormScreen({super.key, this.item});
  final FridgeItem? item;
  @override
  State<FridgeFormScreen> createState() => _FridgeFormScreenState();
}

class _FridgeFormScreenState extends State<FridgeFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _amount, _notes;
  late final KitchenRepository _repo;
  late final String _id;
  late String _unit, _category;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _repo = context.read<KitchenRepository?>()!;
    _id = item?.id ?? _repo.newId('fridge');
    _name = TextEditingController(text: item?.name ?? '');
    _amount = TextEditingController(text: item?.amount.toString() ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _unit = item?.unit ?? 'g';
    _category = item?.categoryId ?? 'produce';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await _repo.saveFridge(
        FridgeItem(
          id: _id,
          name: _name.text,
          amount: double.parse(_amount.text.replaceAll(',', '.')),
          unit: _unit,
          categoryId: _category,
          notes: _notes.text,
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

  void _adjustAmount(int delta) {
    final current = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final next = ((current.isFinite ? current : 0) + delta)
        .clamp(0, 100000)
        .toDouble();
    _amount.text = amountText(next);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: kbackgroundColor,
      appBar: AppBar(
        backgroundColor: kbackgroundColor,
        title: Text(widget.item == null ? 'Add ingredient' : 'Edit ingredient'),
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                decoration: fieldStyle('Ingredient name', hint: 'Egg / Telur'),
                maxLength: 60,
                validator: requiredName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                enabled: !_busy,
                decoration: fieldStyle('Quantity').copyWith(
                  prefixIcon: IconButton(
                    tooltip: 'Decrease quantity',
                    onPressed: _busy ? null : () => _adjustAmount(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Increase quantity',
                    onPressed: _busy ? null : () => _adjustAmount(1),
                    icon: const Icon(Icons.add),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    positiveAmount(value, allowZero: widget.item != null),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: fieldStyle('Unit'),
                items: ingredientUnits
                    .map(
                      (unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _unit = value!),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: fieldStyle('Kelompok bahan').copyWith(
                  helperText:
                      'Groups help you filter ingredients in your fridge.',
                ),
                items: foodGroups.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _notes,
                enabled: !_busy,
                decoration: fieldStyle('Notes (optional)'),
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              PrimaryAction(
                label: 'Save ingredient',
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
