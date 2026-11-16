
import 'package:flutter/material.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'admin_add_recipe_screen.dart';

class AdminRecipeListScreen extends StatelessWidget {
  const AdminRecipeListScreen({super.key});

  // Placeholder recipe names
  static const List<String> recipeList = [
    'Chicken Soup',
    'Egg Fried Rice',
    'Vegetable Salad',
    'Banana Pancake',
    'Grilled Chicken',
  ];

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
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Recipe',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                  const AdminAddRecipeScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.add_circle_outline,
              color: kprimaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        itemCount: recipeList.length,
        separatorBuilder: (context, index) =>
        const SizedBox(height: 10),
        itemBuilder: (context, index) {
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
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 4,
              ),
              title: Text(
                recipeList[index],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
