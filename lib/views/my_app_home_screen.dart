import 'package:flutter/material.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'package:iconsax/iconsax.dart';
import 'package:quick_recipe/Widgets/Banner.dart';
import 'package:quick_recipe/Widgets/my_icon_button.dart';

class MyAppHomeScreen extends StatefulWidget {
  const MyAppHomeScreen({super.key});

  @override
  State<MyAppHomeScreen> createState() => _MyAppHomeScreenState();
}

class _MyAppHomeScreenState extends State<MyAppHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: [
                    headerParts(),
                    mySearchBar(),
                    BannerToExplore(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Padding mySearchBar() {
    return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: TextField(
                      decoration: InputDecoration(
                        filled: true,
                        prefixIcon: Icon(Iconsax.search_normal  ),
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        hintText: "Search any recipes",
                        hintStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  );
  }

  Row headerParts() {
    return Row(
      children: [
        const Text(
          "What are you\ncooking today?",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        const Spacer(),
        // ini kt gw ga kepake
        MyIconButton(icon: Iconsax.notification, pressed: () {}),
      ],
    );
  }
}
