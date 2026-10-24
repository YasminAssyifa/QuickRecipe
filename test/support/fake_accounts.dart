import 'dart:async';

import 'package:quick_recipe/services/account_repository.dart';

class FakeAccounts implements AccountRepository {
  final controller = StreamController<Account?>.broadcast(sync: true);
  @override
  Account? current;
  String savedName = '';
  int calls = 0;
  bool failLoad = false;
  Completer<void>? pending;
  @override
  Stream<Account?> get changes => controller.stream;
  @override
  Future<void> signIn(String email, String password) async {
    calls++;
    if (pending != null) await pending!.future;
    current = Account('test-user', email, savedName);
    controller.add(current);
  }

  @override
  Future<void> signUp(String name, String email, String password) async {
    calls++;
    savedName = name;
  }

  @override
  Future<String> loadProfile(Account account) async {
    if (failLoad) throw StateError('offline');
    return savedName;
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
