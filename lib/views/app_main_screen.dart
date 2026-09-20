import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'package:quick_recipe/views/favorite_screen.dart';
import 'package:quick_recipe/views/my_app_home_screen.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  int selectedIndex = 0;
  late final List<Widget> page;
  @override
  void initState() {
    page = [
      const MyAppHomeScreen(),
      const FavoriteScreen(),
      navBarPage(Iconsax.direct5),
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconSize: 28,
        currentIndex: selectedIndex,
        selectedItemColor: kprimaryColor, //ubah ke orange atau kuning nnti
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          color: kprimaryColor,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        onTap: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(selectedIndex == 0 ? Iconsax.home5 : Iconsax.home_1),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(selectedIndex == 1 ? Iconsax.heart5 : Iconsax.heart),
            label: "Favorite",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              selectedIndex == 2
                  ? Iconsax.direct5
                  : Iconsax.direct, //bag, direct
            ),
            label: "Fridge", //dalam fridge ada fitur ai
          ),
        ],
      ),
      body: page[selectedIndex],
    );
  }

  Center navBarPage(iconName) {
    return Center(child: Icon(iconName, size: 100, color: kprimaryColor));
  }
}
