
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'package:quick_recipe/Widgets/my_icon_button.dart';
import 'package:quick_recipe/views/profile_screen.dart';

class AdminMainScreen extends StatelessWidget {
  const AdminMainScreen({super.key});

  // Placeholder statistics
  static const List<Map<String, dynamic>> overviewData = [
    {'title': 'Recipes', 'value': '26', 'icon': Iconsax.book_1},
    {'title': 'Categories', 'value': '5', 'icon': Iconsax.category},
    {'title': 'Users', 'value': '14', 'icon': Iconsax.profile_2user},
    {'title': 'New this week', 'value': '3', 'icon': Iconsax.trend_up},
  ];

  // Placeholder insights
  static const List<Map<String, dynamic>> insightsData = [
    {
      'title': 'Snack has only 3 recipes',
      'description': 'Add more Snack recipes to balance the catalog.',
      'icon': Iconsax.chart,
    },
    {
      'title': 'Most saved: Egg Fried Rice',
      'description': 'This recipe has been saved by 12 users.',
      'icon': Iconsax.heart,
    },
    {
      'title': '5 recipes have no favorites yet',
      'description': 'Consider reviewing their names and photos.',
      'icon': Iconsax.bookmark,
    },
    {
      'title': '2 recipes are incomplete',
      'description': 'Some recipes are missing images or cooking steps.',
      'icon': Iconsax.info_circle,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  MyIconButton(
                    icon: Iconsax.profile_circle,
                    pressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Welcome banner
              _buildWelcomeBanner(),

              const SizedBox(height: 28),

              // Overview
              _buildSectionTitle('Overview'),
              const SizedBox(height: 14),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: overviewData.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.45,
                ),
                itemBuilder: (context, index) {
                  final item = overviewData[index];

                  return _buildOverviewCard(
                    title: item['title'],
                    value: item['value'],
                    icon: item['icon'],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Insights
              _buildSectionTitle('Insights'),
              const SizedBox(height: 14),

              ...insightsData.map(
                    (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildInsightCard(
                    title: item['title'],
                    description: item['description'],
                    icon: item['icon'],
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

  // Welcome banner
  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kBannerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep the catalog fresh\nand complete!',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your recipes and keep everything organized.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              // Add Recipe navigation will be connected later.
            },
            icon: const Icon(Iconsax.add, size: 18),
            label: const Text('Add recipe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kBannerColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Overview card
  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Centered overview icon
          SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Icon(
                icon,
                color: kprimaryColor,
                size: 23,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Insights card
  Widget _buildInsightCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Centered insight icon
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: kprimaryColor,
              size: 23,
            ),
          ),

          const SizedBox(width: 13),

          // Insight title and description
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right arrow
          Icon(
            Iconsax.arrow_right_3,
            color: Colors.grey.shade500,
            size: 23,
          ),
        ],
      ),
    );
  }
}
