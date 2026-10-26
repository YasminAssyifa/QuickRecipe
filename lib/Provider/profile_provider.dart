import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import '../services/account_repository.dart';

String accountError(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'email-already-in-use' =>
        'This email already has an account. Please sign in.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Use a stronger password with at least 6 characters.',
      'username-taken' => 'This username is already taken.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'network-request-failed' ||
      'unavailable' => 'Connection failed. Check your internet and try again.',
      'too-many-requests' =>
        'Too many attempts. Please wait before trying again.',
      'operation-not-allowed' || 'configuration-not-found' =>
        'Sign-in is unavailable. Enable Email/Password sign-in in Firebase.',
      'permission-denied' =>
        'Your account cannot access this data. Check the Firestore rules.',
      'user-disabled' => 'This account has been disabled.',
      _ => 'The request failed. Please try again.',
    };
  }
  return 'The request failed. Please try again.';
}

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({required AccountRepository repository})
    : _repository = repository {
    _subscription = repository.changes.listen(
      (account) {
        _account = account;
        _name = '';
        _username = '';
        _role = 'user';
        ready = false;
        initializing = false;
        if (!busy) unawaited(load());
      },
      onError: (Object failure) {
        initializing = false;
        error = accountError(failure);
        _notify();
      },
    );
  }
  final AccountRepository _repository;
  late final StreamSubscription<Account?> _subscription;
  Account? _account;
  String _name = '';
  String _username = '';
  String _role = 'user';
  bool initializing = true;
  bool busy = false;
  bool ready = false;
  bool _disposed = false;
  int _generation = 0;
  String? error;
  String? get uid => _account?.uid;
  String get name => _name;
  String get username => _username;
  String get role => _role;
  bool get isAdmin => _role == 'admin';
  String get email => _account?.email ?? '';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final account = _account;
    error = null;
    if (account == null) {
      ready = false;
      _notify();
      return;
    }
    _notify();
    try {
      final result = await _repository.loadProfile(account);
      if (generation != _generation ||
          _disposed ||
          _account?.uid != account.uid) {
        return;
      }
      _name = result.name;
      _username = result.username;
      _role = result.role;
      ready = true;
    } catch (failure) {
      if (generation == _generation && !_disposed) {
        error = accountError(failure);
      }
    }
    _notify();
  }

  Future<bool> authenticate({
    required String login,
    required String password,
  }) => _enter(() => _repository.signIn(login.trim(), password));

  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) => _enter(
    () => _repository.signUp(
      name: name,
      username: username,
      email: email,
      password: password,
    ),
  );

  Future<bool> _enter(Future<void> Function() request) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await request();
      _account = _repository.current;
      await load();
      return uid != null;
    } catch (failure) {
      _account = _repository.current;
      error = accountError(failure);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> save({required String name}) async {
    if (busy ||
        _account == null ||
        name.trim().length < 2 ||
        name.trim().length > 60) {
      return false;
    }
    busy = true;
    error = null;
    _notify();
    try {
      await _repository.saveName(_account!, name.trim());
      _name = name.trim();
      return true;
    } catch (failure) {
      error = accountError(failure);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _repository.signOut();
      _account = _repository.current;
      if (_account == null) {
        _generation++;
        _name = "";
        _username = '';
        _role = 'user';
        ready = false;
        error = null;
      }
    } catch (failure) {
      error = accountError(failure);
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription.cancel();
    super.dispose();
  }
}
