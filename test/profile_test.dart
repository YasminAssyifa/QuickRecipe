import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/Provider/profile_provider.dart';
import 'package:quick_recipe/views/profile_screen.dart';
import 'package:quick_recipe/views/signin_screen.dart';
import 'package:quick_recipe/views/signup_screen.dart';

import 'support/fake_accounts.dart';

void main() {
  test('Demo signup stays signed out and sign in works after logout', () async {
    final repo = FakeAccounts();
    final profile = ProfileProvider(repository: repo);
    expect(
      await profile.authenticate(
        name: 'Demo User',
        email: 'demo@example.com',
        password: 'example123',
      ),
      true,
    );
    expect(profile.uid, isNull);
    expect(profile.ready, false);
    expect(await profile.authenticate(email: '', password: ''), true);
    expect(profile.ready, true);
    final uid = profile.uid;
    await profile.signOut();
    expect(profile.uid, isNull);
    expect(await profile.authenticate(email: '', password: ''), true);
    expect(profile.uid, uid);
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
      await tester.enterText(fields.at(1), 'edric@example.com');
      await tester.enterText(fields.at(2), 'secret123');
      await tester.enterText(fields.at(3), 'different123');
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
      email: 'a@example.com',
      password: 'secret123',
    );
    expect(
      await profile.authenticate(email: 'a@example.com', password: 'secret123'),
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
      await profile.authenticate(email: 'a@example.com', password: 'secret123'),
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
  testWidgets('Demo sign in accepts empty input', (tester) async {
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
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(find.text('Enter your password.'), findsNothing);
    expect(repo.calls, 1);
    expect(profile.ready, true);
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
      email: 'edric@example.com',
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
