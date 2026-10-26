import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:quick_recipe/services/account_repository.dart';

class FakeAccounts implements AccountRepository {
  final controller = StreamController<Account?>.broadcast(sync: true);
  final users = <String, ({String email, String password, Profile profile})>{};
  @override
  Account? current;
  String savedName = '';
  int calls = 0;
  bool failLoad = false;
  Completer<void>? pending;
  @override
  Stream<Account?> get changes => controller.stream;

  void addUser(
    String username,
    String email,
    String password, {
    String role = 'user',
  }) {
    users[username] = (
      email: email,
      password: password,
      profile: Profile(name: username, username: username, role: role),
    );
  }

  @override
  Future<void> signIn(String login, String password) async {
    calls++;
    if (pending != null) await pending!.future;
    final match = users.entries.where(
      (entry) =>
          (entry.key == normalizeUsername(login) ||
              entry.value.email == login) &&
          entry.value.password == password,
    );
    if (users.isNotEmpty && match.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    final username = match.isEmpty ? 'test-user' : match.first.key;
    current = Account(
      username,
      match.isEmpty ? login : match.first.value.email,
    );
    controller.add(current);
  }

  @override
  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    calls++;
    final handle = normalizeUsername(username);
    if (users.containsKey(handle)) {
      throw FirebaseException(plugin: 'app', code: 'username-taken');
    }
    addUser(handle, email, password);
    savedName = name;
    current = Account(handle, email);
    controller.add(current);
  }

  @override
  Future<Profile> loadProfile(Account account) async {
    if (failLoad) throw StateError('offline');
    final profile = users[account.uid]?.profile;
    return Profile(
      name: savedName.isEmpty ? profile?.name ?? '' : savedName,
      username: profile?.username ?? '',
      role: profile?.role ?? 'user',
    );
  }

  @override
  Future<void> saveName(Account account, String name) async {
    savedName = name;
  }

  @override
  Future<void> signOut() async {
    current = null;
    controller.add(null);
  }
}
