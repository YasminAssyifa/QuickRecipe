import 'package:flutter/material.dart';
import 'package:quick_recipe/Utils/constants.dart';

class BannerToExplore extends StatelessWidget {
  const BannerToExplore({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: kBannerColor,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 32,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Find the best\nrecipes for you!",
                  style: TextStyle(
                    height: 1.1,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 33),
                    backgroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () {},
                  child: Text(
                    "Explore",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -30,
            bottom: -20,
            right: -20,
            child: Image.network(
              "https://images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com/f/23acc42a-3c70-48c5-b1a8-dbb1c8aa93bc/dhj38ju-e0da1442-3406-4557-996a-39bfb9857ff1.png/v1/fill/w_894,h_894/chef_cat_2_by_pizzroll_dhj38ju-pre.png?token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1cm46YXBwOjdlMGQxODg5ODIyNjQzNzNhNWYwZDQxNWVhMGQyNmUwIiwiaXNzIjoidXJuOmFwcDo3ZTBkMTg4OTgyMjY0MzczYTVmMGQ0MTVlYTBkMjZlMCIsIm9iaiI6W1t7ImhlaWdodCI6Ijw9OTYwIiwicGF0aCI6Ii9mLzIzYWNjNDJhLTNjNzAtNDhjNS1iMWE4LWRiYjFjOGFhOTNiYy9kaGozOGp1LWUwZGExNDQyLTM0MDYtNDU1Ny05OTZhLTM5YmZiOTg1N2ZmMS5wbmciLCJ3aWR0aCI6Ijw9OTYwIn1dXSwiYXVkIjpbInVybjpzZXJ2aWNlOmltYWdlLm9wZXJhdGlvbnMiXX0.3kWk_3EHnismL0Pt5IUdS5ivnkT5975I0gU6bpr6CC0",
            ),
          ),
        ],
      ),
    );
  }
}
