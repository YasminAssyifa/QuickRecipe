import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/Provider/profile_provider.dart';
import 'package:quick_recipe/views/account_gate.dart';
import 'package:quick_recipe/views/admin_main_screen.dart';
import 'package:quick_recipe/views/profile_screen.dart';
import 'package:quick_recipe/views/signin_screen.dart';
import 'package:quick_recipe/views/signup_screen.dart';

import 'support/fake_accounts.dart';

void main() {
  test(
    'Sign up enters as user and username sign in works after logout',
    () async {
      final repo = FakeAccounts();
      final profile = ProfileProvider(repository: repo);
      expect(
        await profile.register(
          name: 'Edric',
          username: 'Edric_01',
          email: 'edric@example.com',
          password: 'secret123',
        ),
        true,
      );
      expect(profile.ready, true);
      expect(profile.username, 'edric_01');
      expect(profile.isAdmin, false);
      final uid = profile.uid;
      await profile.signOut();
      expect(profile.uid, isNull);
      expect(
        await profile.authenticate(login: 'edric_01', password: 'wrong'),
        false,
      );
      expect(profile.error, 'Email or password is incorrect.');
      expect(
        await profile.authenticate(login: 'Edric_01', password: 'secret123'),
        true,
      );
      expect(profile.uid, uid);
      await profile.signOut();
      expect(
        await profile.authenticate(
          login: 'edric@example.com',
          password: 'secret123',
        ),
        true,
      );
      expect(profile.uid, uid);
      profile.dispose();
      await repo.controller.close();
    },
  );

  test('Taken username is rejected', () async {
    final repo = FakeAccounts()..addUser('user', 'user@example.com', 'user123');
    final profile = ProfileProvider(repository: repo);
    expect(
      await profile.register(
        name: 'Another',
        username: 'user',
        email: 'other@example.com',
        password: 'secret123',
      ),
      false,
    );
    expect(profile.error, 'This username is already taken.');
    expect(profile.uid, isNull);
    profile.dispose();
    await repo.controller.close();
  });

  testWidgets('Admin account opens the admin screen', (tester) async {
    final repo = FakeAccounts()
      ..addUser('admin', 'admin@example.com', 'admin123', role: 'admin');
    final profile = ProfileProvider(repository: repo);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profile,
        child: const MaterialApp(home: AccountGate()),
      ),
    );
    repo.controller.add(null);
    await tester.pump();
    expect(find.byType(SigninScreen), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(profile.isAdmin, true);
    expect(find.byType(AdminMainScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    profile.dispose();
    await repo.controller.close();
  });

  testWidgets(
    'Sign up rejects mismatched passwords without creating an account',
    (tester) async {
      final repo = FakeAccounts();
      final profile = ProfileProvider(repository: repo);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: profile,
          child: const MaterialApp(home: SignupScreen()),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Edric');
      await tester.enterText(fields.at(1), 'edric');
      await tester.enterText(fields.at(2), 'edric@example.com');
      await tester.enterText(fields.at(3), 'secret123');
      await tester.enterText(fields.at(4), 'different123');
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Sign Up'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(repo.calls, 0);
      await tester.pumpWidget(const SizedBox());
      profile.dispose();
      await repo.controller.close();
    },
  );

  test('Double submit creates only one request', () async {
    final repo = FakeAccounts()..pending = Completer<void>();
    final profile = ProfileProvider(repository: repo);
    final first = profile.authenticate(
      login: 'a@example.com',
      password: 'secret123',
    );
    expect(
      await profile.authenticate(login: 'a@example.com', password: 'secret123'),
      false,
    );
    expect(repo.calls, 1);
    repo.pending!.complete();
    expect(await first, true);
    expect(profile.ready, true);
    await profile.signOut();
    expect(profile.uid, isNull);
    expect(profile.name, isEmpty);
    profile.dispose();
    await repo.controller.close();
  });
  test('Profile failure can retry without registering account again', () async {
    final repo = FakeAccounts()..failLoad = true;
    final profile = ProfileProvider(repository: repo);
    expect(
      await profile.authenticate(login: 'a@example.com', password: 'secret123'),
      true,
    );
    expect(profile.ready, false);
    expect(profile.error, isNotNull);
    repo.failLoad = false;
    await profile.load();
    expect(profile.name, '');
    expect(profile.ready, true);
    expect(repo.calls, 1);
    profile.dispose();
    await repo.controller.close();
  });
  testWidgets('Sign in requires login and password', (tester) async {
    final repo = FakeAccounts();
    final profile = ProfileProvider(repository: repo);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profile,
        child: const MaterialApp(home: SigninScreen()),
      ),
    );
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();
    expect(find.text('Enter your email or username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repo.calls, 0);
    await tester.pumpWidget(const SizedBox());
    profile.dispose();
    await repo.controller.close();
  });
  testWidgets('Profile validates name and writes through repository', (
    tester,
  ) async {
    final repo = FakeAccounts();
    final profile = ProfileProvider(repository: repo);
    await profile.authenticate(
      login: 'edric@example.com',
      password: 'secret123',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: profile,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pump();
    expect(
      find.text('Enter a name with at least 2 characters.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, 'Edric');
    await tester.ensureVisible(find.text('Save profile'));
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(repo.savedName, 'Edric');
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    profile.dispose();
    await repo.controller.close();
  });
}
