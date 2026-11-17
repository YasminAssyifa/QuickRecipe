import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/Utils/constants.dart';

import '../additions/kitchen_repository.dart' show amountText;
import '../additions/shared.dart';
import '../services/recipe_admin_repository.dart';

const _tagLabels = {
  'vegetarian': 'Vegetarian',
  'pedas': 'Spicy',
  'hemat': 'Budget-friendly',
  'bekal': 'Lunchbox',
  'ramah-anak': 'Kid-friendly',
};
const _allergenLabels = {
  'telur': 'Egg',
  'susu': 'Milk',
  'kacang': 'Nuts',
  'seafood': 'Seafood',
  'gluten': 'Gluten',
};

class AdminAddRecipeScreen extends StatefulWidget {
  const AdminAddRecipeScreen({super.key, this.recipe});

  /// The recipe to edit, or null to add a new one.
  final DocumentSnapshot<Map<String, dynamic>>? recipe;

  @override
  State<AdminAddRecipeScreen> createState() => _AdminAddRecipeScreenState();
}

class _AdminAddRecipeScreenState extends State<AdminAddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  final _imageCreditController = TextEditingController();
  final _calController = TextEditingController();
  final _calNoteController = TextEditingController();
  final _timeController = TextEditingController();
  final _ingredientsNameController = TextEditingController();
  final _ingredientsAmountController = TextEditingController();
  final _stepController = TextEditingController();

  RecipeAdminRepository? _repo;
  late Future<List<String>> _categories;
  bool _saving = false;

  // Selected category
  String? selectedCategory;

  // Store selected tags and allergens
  final Set<String> selectedTags = {};
  final Set<String> selectedAllergens = {};

  bool get _editing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    _repo = context.read<RecipeAdminRepository?>();
    _categories = _loadCategories();
    final data = widget.recipe?.data();
    if (data != null) {
      final draft = RecipeDraft.fromMap(data);
      _nameController.text = draft.name;
      _imageController.text = draft.image;
      _imageCreditController.text = draft.imageAttribution;
      _calController.text = draft.calories > 0 ? '${draft.calories}' : '';
      _calNoteController.text = draft.calorieNote;
      _timeController.text = draft.minutes > 0 ? '${draft.minutes}' : '';
      _ingredientsNameController.text = draft.ingredients.join('\n');
      _ingredientsAmountController.text = draft.amounts
          .map((amount) => amountText(amount.toDouble()))
          .join('\n');
      _stepController.text = draft.steps.join('\n');
      selectedCategory = draft.category.isEmpty ? null : draft.category;
      selectedTags.addAll(draft.tags.where(recipeTags.contains));
      selectedAllergens.addAll(draft.allergens.where(recipeAllergens.contains));
    }
  }

  Future<List<String>> _loadCategories() async {
    final repo = _repo;
    if (repo == null) {
      throw StateError('Sign in as an admin to manage recipes.');
    }
    final names = await repo.categories();
    final current = selectedCategory ?? widget.recipe?.data()?['category'];
    return [
      ...names,
      if (current is String && current.isNotEmpty && !names.contains(current))
        current,
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    _imageCreditController.dispose();
    _calController.dispose();
    _calNoteController.dispose();
    _timeController.dispose();
    _ingredientsNameController.dispose();
    _ingredientsAmountController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  // Input decoration
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kprimaryColor, width: 1.5),
      ),
    );
  }

  // Reusable text field
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label).copyWith(hintText: hint),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label is required.';
            }
            return null;
          },
    );
  }

  // Convert multiline input into a list
  List<String> _getLines(String value) {
    return value
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // Validate recipe name
  String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Recipe name is required.';
    if (name.length < 2 || name.length > 60) {
      return 'Use 2 to 60 characters.';
    }
    return null;
  }

  // Validate a whole number within a range
  String? Function(String?) _validateNumber(String label, int max) {
    return (value) {
      if (value == null || value.trim().isEmpty) return '$label is required.';
      final number = int.tryParse(value.trim());
      if (number == null) return '$label must be a whole number.';
      if (number <= 0 || number > max) {
        return '$label must be between 1 and $max.';
      }
      return null;
    };
  }

  // Validate image URL
  String? _validateImage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Image URL is required.';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return 'Please enter a valid image URL.';
    }
    if (value.trim().length > 500) return 'Use a shorter image URL.';
    return null;
  }

  // Validate optional short text
  String? _validateOptional(String? value) =>
      (value ?? '').trim().length > 200 ? 'Use at most 200 characters.' : null;

  // Validate ingredient names
  String? _validateIngredients(String? value) {
    final ingredients = _getLines(value ?? '');
    if (ingredients.length < 2) {
      return 'A recipe must have at least 2 ingredients.';
    }
    if (ingredients.length > 40) return 'Use at most 40 ingredients.';
    return null;
  }

  // Validate amounts in grams, one per ingredient
  String? _validateAmounts(String? value) {
    final amounts = _getLines(value ?? '');
    final ingredients = _getLines(_ingredientsNameController.text);
    if (amounts.length != ingredients.length) {
      return 'The number of ingredients and amounts must match.';
    }
    for (final amount in amounts) {
      final grams = num.tryParse(amount.replaceAll(',', '.'));
      if (grams == null || grams <= 0) {
        return 'Write each amount in grams as a number, for example 120.';
      }
    }
    return null;
  }

  // Validate cooking steps
  String? _validateSteps(String? value) {
    final steps = _getLines(value ?? '');
    if (steps.isEmpty) return 'Cooking steps are required.';
    if (steps.length > 30) return 'Use at most 30 steps.';
    return null;
  }

  // Chips used for tags and allergens
  Widget _buildChipSection({
    required String title,
    required String description,
    required Map<String, String> labels,
    required Set<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: labels.entries.map((entry) {
            final isSelected = selected.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              selectedColor: kprimaryColor.withValues(alpha: 0.2),
              checkmarkColor: kprimaryColor,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    selected.add(entry.key);
                  } else {
                    selected.remove(entry.key);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  RecipeDraft _draft() => RecipeDraft(
    name: _nameController.text,
    category: selectedCategory!,
    image: _imageController.text,
    calories: int.parse(_calController.text.trim()),
    minutes: int.parse(_timeController.text.trim()),
    ingredients: _getLines(_ingredientsNameController.text),
    amounts: [
      for (final amount in _getLines(_ingredientsAmountController.text))
        num.parse(amount.replaceAll(',', '.')),
    ],
    steps: _getLines(_stepController.text),
    tags: recipeTags.where(selectedTags.contains).toList(),
    allergens: recipeAllergens.where(selectedAllergens.contains).toList(),
    imageAttribution: _imageCreditController.text,
    calorieNote: _calNoteController.text,
  );

  // Save recipe form
  Future<void> _saveRecipe() async {
    final repo = _repo;
    if (_saving || repo == null) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final draft = _draft();
    setState(() => _saving = true);
    try {
      if (await repo.imageInUse(draft.image, exceptId: widget.recipe?.id)) {
        if (mounted) {
          showMessage(context, 'Another recipe already uses this image URL.');
        }
        return;
      }
      if (_editing) {
        await repo.update(widget.recipe!.id, draft);
      } else {
        await repo.create(draft);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text(_editing ? 'Recipe updated.' : 'Recipe added.')),
      );
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text(
          _editing ? 'Edit Recipe' : 'Add Recipe',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: LoadPanel<List<String>>(
        future: _categories,
        retry: () => setState(() {
          _categories = _loadCategories();
        }),
        builder: (categories) => Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recipe Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Recipe name
                _buildTextField(
                  label: 'Recipe Name',
                  controller: _nameController,
                  hint: 'Enter recipe name',
                  validator: _validateName,
                ),
                const SizedBox(height: 16),

                // Category dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: _inputDecoration('Category'),
                  hint: const Text('Select category'),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a category.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Image URL
                _buildTextField(
                  label: 'Image',
                  controller: _imageController,
                  hint: 'Enter image URL',
                  keyboardType: TextInputType.url,
                  validator: _validateImage,
                ),
                const SizedBox(height: 16),

                // Image credit
                _buildTextField(
                  label: 'Image Credit (optional)',
                  controller: _imageCreditController,
                  hint: 'e.g. Photo by the team',
                  validator: _validateOptional,
                ),
                const SizedBox(height: 16),

                // Calories and cooking time
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Calories (cal)',
                        controller: _calController,
                        hint: 'e.g. 250',
                        keyboardType: TextInputType.number,
                        validator: _validateNumber('Calories', 5000),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        label: 'Cooking Time (min)',
                        controller: _timeController,
                        hint: 'e.g. 30',
                        keyboardType: TextInputType.number,
                        validator: _validateNumber('Cooking time', 1440),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calorie note
                _buildTextField(
                  label: 'Calorie Note (optional)',
                  controller: _calNoteController,
                  hint: 'e.g. Estimated per serving',
                  validator: _validateOptional,
                ),
                const SizedBox(height: 28),

                // Ingredients section
                const Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Amounts are in grams for one serving, in the same order as the ingredients.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Ingredients Name',
                  controller: _ingredientsNameController,
                  hint: 'Enter ingredients, one per line',
                  maxLines: 4,
                  validator: _validateIngredients,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Ingredients Amount (g)',
                  controller: _ingredientsAmountController,
                  hint: 'Enter amounts, one per line',
                  maxLines: 4,
                  validator: _validateAmounts,
                ),
                const SizedBox(height: 28),

                // Cooking instructions
                const Text(
                  'Cooking Instructions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Cooking Steps',
                  controller: _stepController,
                  hint: 'Write cooking instructions, one step per line',
                  maxLines: 5,
                  validator: _validateSteps,
                ),
                const SizedBox(height: 28),

                // Recipe tags
                _buildChipSection(
                  title: 'Recipe Tags',
                  description: 'Select tags that describe this recipe.',
                  labels: _tagLabels,
                  selected: selectedTags,
                ),
                const SizedBox(height: 28),

                // Allergens
                _buildChipSection(
                  title: 'Allergens',
                  description: 'Select every allergen this recipe contains.',
                  labels: _allergenLabels,
                  selected: selectedAllergens,
                ),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kprimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Save Recipe',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
