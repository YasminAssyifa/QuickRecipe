import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Account {
  const Account(this.uid, this.email);
  final String uid;
  final String email;
}

class Profile {
  const Profile({
    required this.name,
    required this.username,
    required this.role,
  });
  final String name;
  final String username;
  final String role;
}

final usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
String normalizeUsername(String value) => value.trim().toLowerCase();

abstract class AccountRepository {
  Account? get current;
  Stream<Account?> get changes;
  Future<void> signIn(String login, String password);
  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<Profile> loadProfile(Account account);
  Future<void> saveName(Account account, String name);
  Future<void> signOut();
}

class FirebaseAccountRepository implements AccountRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Account? _from(User? user) => user == null || user.isAnonymous
      ? null
      : Account(user.uid, user.email ?? '');

  @override
  Account? get current => _from(_auth.currentUser);

  @override
  Stream<Account?> get changes async* {
    if (_auth.currentUser?.isAnonymous ?? false) await _auth.signOut();
    yield* _auth.authStateChanges().map(_from);
  }

  @override
  Future<void> signIn(String login, String password) async {
    var email = login.trim();
    if (!email.contains('@')) {
      final doc = await _db
          .collection('usernames')
          .doc(normalizeUsername(email))
          .get(const GetOptions(source: Source.server));
      final stored = doc.data()?['email'];
      if (stored is! String) {
        throw FirebaseAuthException(code: 'invalid-credential');
      }
      email = stored;
    }
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final handle = normalizeUsername(username);
    final taken = await _db
        .collection('usernames')
        .doc(handle)
        .get(const GetOptions(source: Source.server));
    if (taken.exists) {
      throw FirebaseException(plugin: 'app', code: 'username-taken');
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    final batch = _db.batch()
      ..set(_db.collection('users').doc(user.uid), {
        'name': name.trim(),
        'email': user.email,
        'username': handle,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_db.collection('usernames').doc(handle), {
        'uid': user.uid,
        'email': user.email,
      });
    try {
      await batch.commit();
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  @override
  Future<Profile> loadProfile(Account account) async {
    final doc = await _db
        .collection('users')
        .doc(account.uid)
        .get(const GetOptions(source: Source.server));
    final data = doc.data() ?? const <String, dynamic>{};
    return Profile(
      name: data['name'] as String? ?? '',
      username: data['username'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
    );
  }

  @override
  Future<void> saveName(Account account, String name) => _db
      .collection('users')
      .doc(account.uid)
      .update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> signOut() => _auth.signOut();
}
