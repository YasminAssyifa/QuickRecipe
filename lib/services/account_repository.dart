import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Account {
  const Account(this.uid, this.email, this.name);
  final String uid;
  final String email;
  final String name;
}

abstract class AccountRepository {
  Account? get current;
  Stream<Account?> get changes;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String name, String email, String password);
  Future<String> loadProfile(Account account);
  Future<void> saveName(Account account, String name);
  Future<void> signOut();
}

class FirebaseAccountRepository implements AccountRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _sessions = StreamController<Account?>.broadcast(sync: true);
  bool _entered = false;
  String _demoName = 'Demo User';
  @override
  Account? get current {
    final u = _auth.currentUser;
    return u == null || !_entered ? null : Account(u.uid, '', _demoName);
  }

  @override
  Stream<Account?> get changes async* {
    yield current;
    yield* _sessions.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    if (_auth.currentUser != null && !_auth.currentUser!.isAnonymous) {
      await _auth.signOut();
    }
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    _entered = true;
    _sessions.add(current);
  }

  @override
  Future<void> signUp(String name, String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _demoName = name;
  }

  @override
  Future<String> loadProfile(Account account) async {
    final ref = _db.collection('users').doc(account.uid);
    final doc = await ref.get(const GetOptions(source: Source.server));
    if (doc.exists) return doc.data()?['name'] as String? ?? account.name;
    final name = account.name;
    await ref.set({
      'name': name,
      'email': account.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return name;
  }

  @override
  Future<void> saveName(Account account, String name) => _db
      .collection('users')
      .doc(account.uid)
      .update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});
  @override
  Future<void> signOut() async {
    _entered = false;
    _sessions.add(null);
  }
}
