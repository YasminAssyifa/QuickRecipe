
import 'package:flutter/material.dart';
import 'package:quick_recipe/Utils/constants.dart';

class AdminAddRecipeScreen extends StatefulWidget {
  const AdminAddRecipeScreen({super.key});

  @override
  State<AdminAddRecipeScreen> createState() =>
      _AdminAddRecipeScreenState();
}

class _AdminAddRecipeScreenState
    extends State<AdminAddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  final _calController = TextEditingController();
  final _timeController = TextEditingController();
  final _ingredientsNameController = TextEditingController();
  final _ingredientsAmountController = TextEditingController();
  final _stepController = TextEditingController();

  // Selected category
  String? selectedCategory;

  final List<String> categories = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Dessert',
    'Drinks',
  ];

  // Available recipe tags
  final List<String> availableTags = [
    'Vegetarian',
    'Pedas',
    'Hemat',
  ];

  // Store selected tags
  final Set<String> selectedTags = {};

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    _calController.dispose();
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: kprimaryColor,
          width: 1.5,
        ),
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
      decoration: _inputDecoration(label).copyWith(
        hintText: hint,
      ),
      validator: validator ??
              (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }
            return null;
          },
    );
  }

  // Validate calories
  String? _validateCalories(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Calories is required';
    }

    final calories = int.tryParse(value.trim());

    if (calories == null) {
      return 'Calories must be a number';
    }

    if (calories <= 0) {
      return 'Calories must be greater than 0';
    }

    return null;
  }

  // Validate image URL
  String? _validateImage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Image URL is required';
    }

    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return 'Please enter a valid image URL';
    }

    return null;
  }

  // Convert multiline input into a list
  List<String> _getLines(String value) {
    return value
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // Validate ingredients and amounts
  bool _validateIngredients() {
    final ingredients = _getLines(
      _ingredientsNameController.text,
    );

    final amounts = _getLines(
      _ingredientsAmountController.text,
    );

    if (ingredients.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A recipe must have at least 2 ingredients.',
          ),
        ),
      );
      return false;
    }

    if (ingredients.length != amounts.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The number of ingredients and amounts must match.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  // Recipe tags section
  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recipe Tags',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select tags that describe this recipe.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: availableTags.map((tag) {
            final isSelected = selectedTags.contains(tag);

            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              selectedColor: kprimaryColor.withValues(
                alpha: 0.2,
              ),
              checkmarkColor: kprimaryColor,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedTags.add(tag);
                  } else {
                    selectedTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // Save recipe form
  void _saveRecipe() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a recipe category.'),
        ),
      );
      return;
    }

    if (!_validateIngredients()) {
      return;
    }

    // Placeholder only.
    // Firestore integration will be added later.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recipe form completed! '
              'Selected tags: ${selectedTags.isEmpty ? "None" : selectedTags.join(", ")}. '
              'Database integration will be added later.',
        ),
      ),
    );
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
          'Add Recipe',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recipe Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Recipe name
              _buildTextField(
                label: 'Recipe Name',
                controller: _nameController,
                hint: 'Enter recipe name',
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: selectedCategory,
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
                    return 'Please select a category';
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
                validator: _validateImage,
              ),
              const SizedBox(height: 16),

              // Calories and cooking time
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Calories (cal)',
                      controller: _calController,
                      hint: 'e.g. 250',
                      keyboardType: TextInputType.number,
                      validator: _validateCalories,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      label: 'Cooking Time',
                      controller: _timeController,
                      hint: 'e.g. 30 min',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Ingredients section
              const Text(
                'Ingredients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                label: 'Ingredients Name',
                controller: _ingredientsNameController,
                hint: 'Enter ingredients, one per line',
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                label: 'Ingredients Amount',
                controller: _ingredientsAmountController,
                hint: 'Enter amounts, one per line',
                maxLines: 4,
              ),
              const SizedBox(height: 28),

              // Cooking instructions
              const Text(
                'Cooking Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                label: 'Cooking Steps',
                controller: _stepController,
                hint: 'Write cooking instructions, one step per line',
                maxLines: 5,
              ),
              const SizedBox(height: 28),

              // Recipe tags
              _buildTagsSection(),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kprimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
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
    );
  }
}
