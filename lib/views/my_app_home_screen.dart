import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'package:iconsax/iconsax.dart';
import 'package:quick_recipe/Widgets/Banner.dart';
import 'package:quick_recipe/Widgets/food_items_display.dart';
import 'package:quick_recipe/Widgets/my_icon_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quick_recipe/views/view_all_items.dart';

class MyAppHomeScreen extends StatefulWidget {
  const MyAppHomeScreen({super.key});

  @override
  State<MyAppHomeScreen> createState() => _MyAppHomeScreenState();
}

class _MyAppHomeScreenState extends State<MyAppHomeScreen> {
  String category = "All";

  // for category
  final CollectionReference categoriesItems = FirebaseFirestore.instance
      .collection("App-Category");
  // for all items display
  Query get filteredRecipes => FirebaseFirestore.instance
      .collection("Complete-Flutter-App")
      .where('category', isEqualTo: category);
  Query get allRecipes =>
      FirebaseFirestore.instance.collection("Complete-Flutter-App");
  Query get selectedRecipes => category == "All" ? allRecipes : filteredRecipes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerParts(),
                    mySearchBar(),
                    const BannerToExplore(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "Categories",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    selectedCategory(),
                    // temporary text, note
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Quick & Easy",
                          style: TextStyle(
                            fontSize: 20,
                            letterSpacing: 0.1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ViewAllItems()),
                            );
                          },
                          child: Text(
                            "View all",
                            style: TextStyle(
                              color: kBannerColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              StreamBuilder(
                stream: selectedRecipes.snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasData) {
                    final List<DocumentSnapshot> recipes =
                        snapshot.data?.docs ?? [];
                    return Padding(
                      padding: EdgeInsetsGeometry.only(top: 5, left: 15),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: recipes
                              .map((e) => FoodItemsDisplay(documentSnapshot: e))
                              .toList(),
                        ),
                      ),
                    );
                  }
                  return Center(child: CircularProgressIndicator());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  StreamBuilder<QuerySnapshot<Object?>> selectedCategory() {
    return StreamBuilder(
      stream: categoriesItems.snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> streamSnapshot) {
        if (streamSnapshot.hasData) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                streamSnapshot.data!.docs.length,
                (index) => GestureDetector(
                  onTap: () {
                    setState(() {
                      category = streamSnapshot.data!.docs[index]["name"];
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color:
                          category == streamSnapshot.data!.docs[index]["name"]
                          ? kprimaryColor
                          : Colors.white,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    margin: EdgeInsets.only(right: 20),
                    child: Text(
                      streamSnapshot.data!.docs[index]["name"],
                      style: TextStyle(
                        color:
                            category == streamSnapshot.data!.docs[index]["name"]
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }

  Padding mySearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: TextField(
        decoration: InputDecoration(
          filled: true,
          prefixIcon: Icon(Iconsax.search_normal),
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

// ini untuk development aja, kalo yg aseli yang atas ya

// StreamBuilder(
//   stream: categoriesItems.snapshots(),
//   builder:
//       (
//         context,
//         AsyncSnapshot<QuerySnapshot> streamSnapshot,
//       ) {
//         // 1. Check for errors (This will print security rule or connection blocks)
//         if (streamSnapshot.hasError) {
//           return Center(
//             child: Text('Error: ${streamSnapshot.error}'),
//           );
//         }

//         // 2. Show loading only while waiting for the first connection
//         if (streamSnapshot.connectionState ==
//             ConnectionState.waiting) {
//           return const Center(
//             child: CircularProgressIndicator(),
//           );
//         }

//         // 3. Handle when connection works but collection has 0 items
//         if (!streamSnapshot.hasData ||
//             streamSnapshot.data!.docs.isEmpty) {
//           return const Center(
//             child: Text(
//               'No categories found in App-Category.',
//             ),
//           );
//         }

//         // 4. Render data if everything is successful
//         return SingleChildScrollView(
//           scrollDirection: Axis.horizontal,
//           child: Row(
//             children: List.generate(
//               streamSnapshot.data!.docs.length,
//               (index) {
//                 // Extract the document data safely as a map
//                 final doc =
//                     streamSnapshot.data!.docs[index];
//                 final data =
//                     doc.data() as Map<String, dynamic>?;

//                 // Crash defense: Fallback name if the "name" field is missing or misspelled
//                 final String categoryName =
//                     (data != null &&
//                         data.containsKey('name'))
//                     ? data['name'].toString()
//                     : 'Missing "name" field';

//                 return GestureDetector(
//                   onTap: () {
//                     setState(() {
//                       category = categoryName;
//                     });
//                   },
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: category == categoryName
//                           ? Colors.orange
//                           : Colors.white,
//                       borderRadius: BorderRadius.circular(
//                         24,
//                       ),
//                       border: Border.all(
//                         color: Colors.grey.shade300,
//                       ),
//                     ),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 20,
//                       vertical: 10,
//                     ),
//                     margin: const EdgeInsets.only(
//                       right: 12,
//                     ),
//                     child: Text(
//                       categoryName,
//                       style: TextStyle(
//                         fontWeight: FontWeight.w600,
//                         color: category == categoryName
//                             ? Colors.white
//                             : Colors.black,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     ),
