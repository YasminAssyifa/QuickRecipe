import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/Provider/favorite_provider.dart';
import 'package:quick_recipe/Provider/quantity.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'package:quick_recipe/Widgets/my_icon_button.dart';
import 'package:quick_recipe/Widgets/quantity_increment_decrement.dart';

class RecipeDetailScreen extends StatefulWidget {
  final DocumentSnapshot<Object?> documentSnapshot;
  const RecipeDetailScreen({super.key, required this.documentSnapshot});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _initialized = false;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      List<double> baseAmounts = widget.documentSnapshot['ingredientsAmount']
          .map<double>((amount) => double.parse(amount.toString()))
          .toList();

      Provider.of<QuantityProvider>(
        context,
        listen: false,
      ).setBaseIngredientsAmount(baseAmounts);

      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = FavoriteProvider.of(context);
    final quantityProvider = Provider.of<QuantityProvider>(context);
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: startCookingandFavoriteButton(provider),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ini fixed image
          Positioned(
            top: -(_scrollOffset * 0.3),
            left: 0,
            right: 0,
            child: Hero(
              tag: widget.documentSnapshot['image'],
              child: Container(
                height:
                    MediaQuery.of(context).size.height /
                    2.2, // ini tergantung ukuran hp kah
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: NetworkImage(widget.documentSnapshot['image']),
                  ),
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height / 2.4),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Recipe name
                      Text(
                        widget.documentSnapshot['name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Calories and time
                      Row(
                        children: [
                          Icon(Iconsax.flash_1, size: 16, color: Colors.grey),

                          Text(
                            "${widget.documentSnapshot['cal']} Cal",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),

                          const Text(
                            " • ",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                            ),
                          ),

                          Icon(Iconsax.clock, size: 16, color: Colors.grey),

                          const SizedBox(width: 5),

                          Text(
                            "${widget.documentSnapshot['time']} Minutes",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ingredients",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "How many servings?",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          QuantityIncrementDecrement(
                            currentNumber: quantityProvider.currentnumber,
                            onAdd: () => quantityProvider.increaseQuantity(),
                            onRemove: () => quantityProvider.decreaseQuantity(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      //list of ingredients
                      Column(
                        children: [
                          Row(
                            children: [
                              // //ing images
                              // Column(
                              //   children: widget
                              //       .documentSnapshot['ingredientsImage']
                              //       .map<Widget>(
                              //         (imageUrl) => Container(
                              //           height: 60,
                              //           width: 60,
                              //           margin: EdgeInsets.only(bottom: 10),
                              //           decoration: BoxDecoration(
                              //             borderRadius: BorderRadius.circular(
                              //               20,
                              //             ),
                              //             image: DecorationImage(
                              //               fit: BoxFit.cover,
                              //               image: NetworkImage(imageUrl),
                              //             ),
                              //           ),
                              //         ),
                              //       )
                              //       .toList(),
                              // ),
                              // ing name
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: widget
                                    .documentSnapshot['ingredientsName']
                                    .map<Widget>(
                                      (ingredient) => SizedBox(
                                        height: 60,
                                        child: Center(
                                          child: Text(
                                            ingredient,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),

                              // ing amount
                              const Spacer(),
                              Column(
                                children: quantityProvider
                                    .updateIngredientAmounts
                                    .map<Widget>(
                                      (amount) => SizedBox(
                                        height: 60,
                                        child: Center(
                                          child: Text(
                                            "$amount gm",
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // for back button and notification
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Row(
              children: [
                MyIconButton(
                  icon: Icons.arrow_back_ios_new,
                  pressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  FloatingActionButton startCookingandFavoriteButton(
    FavoriteProvider provider,
  ) {
    return FloatingActionButton.extended(
      backgroundColor: Colors.white.withOpacity(0.8),
      elevation: 0,
      onPressed: () {},
      label: Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kprimaryColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 100,
                vertical: 13,
              ),
              foregroundColor: Colors.white,
            ),
            onPressed: () {},
            child: Text(
              "Start Cooking",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0),
              shape: CircleBorder(
                side: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
            ),
            onPressed: () {
              provider.toggleFavorite(widget.documentSnapshot);
            },
            icon: Icon(
              provider.isExist(widget.documentSnapshot)
                  ? Iconsax.heart5
                  : Iconsax.heart,
              color: provider.isExist(widget.documentSnapshot)
                  ? Colors.red
                  : Colors.black,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
