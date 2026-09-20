import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoriteProvider extends ChangeNotifier {
  List<String> _favoriteIds = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> get favorites => _favoriteIds;

  FavoriteProvider() {
    loadFavorites();
  }

  // toggle favorites states
  void toggleFavorite(DocumentSnapshot product) async {
    String productId = product.id;
    if (_favoriteIds.contains(productId)) {
      _favoriteIds.remove(productId);
      await _removeFavorite(productId); // remove from favorite
    } else {
      _favoriteIds.add(productId);
      await _addFavorite(productId); // add to favorite
    }
    notifyListeners();
  }

  // check if product is favorited
  bool isExist(DocumentSnapshot product) {
    return _favoriteIds.contains(product.id);
  }

  // add favorite to firestore
  Future<void> _addFavorite(String productId) async {
    try {
      await _firestore.collection("userFavorite").doc(productId).set({
        'isFavorite': true, //create the userFavorite collection and add items as favorites in firestore
      });
    } catch (e) {
      print(e.toString());
    }
  }

  // remove favorite from firestore
  Future<void> _removeFavorite(String productId) async {
    try {
      await _firestore.collection("userFavorite").doc(productId).delete();
    } catch (e) {
      print(e.toString());
    }
  }

  // load favorite from firestore (store the favorite or not)
  Future<void> loadFavorites() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("userFavorite")
          .get();
      _favoriteIds = snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print(e.toString());
    }
    notifyListeners();
  }
  // static method to access the provider from any context
  static FavoriteProvider of(BuildContext context, {bool listen = true}){
    return Provider.of<FavoriteProvider>(context, listen: listen,);
  }
}
