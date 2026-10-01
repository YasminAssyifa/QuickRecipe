import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'profile_provider.dart';

class FavoriteProvider extends ChangeNotifier {
  FavoriteProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_bind);
  }
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _favoritesSubscription;
  String? _uid;
  List<String> _ids = [];
  final Set<String> _pending = {};
  String? error;
  bool loading = true;
  bool _disposed = false;
  List<String> get favorites => List.unmodifiable(_ids);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _bind(User? user) {
    _favoritesSubscription?.cancel();
    _uid = user?.uid;
    _ids = [];
    _pending.clear();
    error = null;
    loading = user != null;
    if (user != null) {
      final uid = user.uid;
      _favoritesSubscription = _db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .snapshots()
          .listen(
            (snapshot) {
              if (_uid != uid) return;
              _ids = snapshot.docs.map((doc) => doc.id).toList();
              loading = false;
              error = null;
              _notify();
            },
            onError: (Object failure) {
              if (_uid != uid) return;
              loading = false;
              error = accountError(failure);
              _notify();
            },
          );
    }
    _notify();
  }

  Future<void> toggleFavorite(DocumentSnapshot product) async {
    final uid = _uid;
    if (uid == null || _pending.contains(product.id)) return;
    _pending.add(product.id);
    error = null;
    _notify();
    try {
      final ref = _db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(product.id);
      if (_ids.contains(product.id)) {
        await ref.delete();
      } else {
        await ref.set({
          'recipeId': product.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (failure) {
      if (_uid == uid) error = accountError(failure);
    } finally {
      if (_uid == uid) _pending.remove(product.id);
      _notify();
    }
  }

  bool isExist(DocumentSnapshot product) => _ids.contains(product.id);
  void loadFavorites() => _bind(FirebaseAuth.instance.currentUser);
  static FavoriteProvider of(BuildContext context, {bool listen = true}) =>
      Provider.of<FavoriteProvider>(context, listen: listen);
  @override
  void dispose() {
    _disposed = true;
    _authSubscription.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}
