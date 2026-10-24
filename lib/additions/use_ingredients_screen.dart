import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Utils/constants.dart';
import 'kitchen_repository.dart';
import 'shared.dart';

class UseIngredientsScreen extends StatefulWidget {
  const UseIngredientsScreen({super.key});
  @override
  State<UseIngredientsScreen> createState() => _UseIngredientsScreenState();
}

class _UseIngredientsScreenState extends State<UseIngredientsScreen> {
  final _form = GlobalKey<FormState>();
  final _selected = <String>{};
  final _amounts = <String, TextEditingController>{};
  late final KitchenRepository _repo;
  late final String _operationId;
  late Future<List<FridgeItem>> _future;
  bool _busy = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<KitchenRepository?>()!;
    _operationId = _repo.newId('stockOperations');
    _future = _repo.fridge();
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reload() => setState(() {
    _future = _repo.fridge();
  });

  Future<void> _save(List<FridgeItem> items) async {
    if (_busy) return;
    if (_selected.isEmpty) {
      showMessage(context, 'Pilih minimal satu bahan.');
      return;
    }
    if (_selected.length > 50) {
      showMessage(context, 'Pilih maksimal 50 bahan sekaligus.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    final selected = items
        .where((item) => _selected.contains(item.id))
        .toList();
    if (selected.length != _selected.length) {
      showMessage(context, 'Stok berubah. Pilih ulang bahan yang tersedia.');
      setState(() => _selected.retainAll(items.map((item) => item.id)));
      return;
    }
    final usages = selected
        .map(
          (item) => StockUse(
            itemId: item.id,
            unit: item.unit,
            amount: double.parse(_amounts[item.id]!.text.replaceAll(',', '.')),
          ),
        )
        .toList();
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pakai bahan ini?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < selected.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${selected[index].name}: ${amountText(usages[index].amount)} ${selected[index].unit} dipakai, sisa ${amountText(remainingStock(selected[index], usages[index]))} ${selected[index].unit}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _saving = true);
      await _repo.useStock(_operationId, usages);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showMessage(context, messageFor(error));
        _reload();
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: kbackgroundColor,
      appBar: AppBar(
        backgroundColor: kbackgroundColor,
        title: const Text('Pakai bahan'),
      ),
      body: LoadPanel(
        future: _future,
        retry: _reload,
        builder: (allItems) {
          final items = allItems.where((item) => item.inStock).toList();
          if (items.isEmpty) {
            return FeedbackPanel(
              title: 'Tidak ada stok tersedia',
              message:
                  'Tambah atau edit jumlah bahan di Fridge terlebih dahulu.',
              action: 'Kembali',
              onAction: () => Navigator.pop(context),
            );
          }
          return Column(
            children: [
              Expanded(
                child: Form(
                  key: _form,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Pilih bahan dan isi jumlah yang dipakai. Satuan tetap mengikuti stok.',
                        ),
                        const SizedBox(height: 16),
                        for (final item in items)
                          Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.name),
                                    subtitle: Text(
                                      'Stok: ${amountText(item.amount)} ${item.unit}',
                                    ),
                                    value: _selected.contains(item.id),
                                    onChanged: _busy
                                        ? null
                                        : (checked) => setState(() {
                                            ScaffoldMessenger.of(context)
                                                .hideCurrentSnackBar();
                                            if (checked == true) {
                                              _selected.add(item.id);
                                            } else {
                                              _selected.remove(item.id);
                                            }
                                          }),
                                  ),
                                  if (_selected.contains(item.id))
                                    TextFormField(
                                      key: ValueKey(item.id),
                                      controller: _amounts.putIfAbsent(
                                        item.id,
                                        () => TextEditingController(),
                                      ),
                                      enabled: !_busy,
                                      decoration: fieldStyle(
                                        'Jumlah dipakai (${item.unit})',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        final error = positiveAmount(value);
                                        if (error != null) {
                                          return error;
                                        }
                                        if (double.parse(
                                              value!.replaceAll(',', '.'),
                                            ) >
                                            item.amount) {
                                          return 'Maksimal ${amountText(item.amount)} ${item.unit}.';
                                        }
                                        return null;
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: PrimaryAction(
                    label: 'Tinjau pemakaian',
                    busy: _saving,
                    onPressed: _busy ? null : () => _save(items),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
