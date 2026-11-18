import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:quick_recipe/providers/profile_provider.dart';
import 'package:quick_recipe/utils/constants.dart';
import 'package:quick_recipe/screens/admin_main_screen.dart';
import 'package:quick_recipe/screens/app_main_screen.dart';
import 'package:quick_recipe/screens/signin_screen.dart';

class AccountGate extends StatelessWidget {
  const AccountGate({super.key});
  @override
  Widget build(BuildContext context) {
    final account = context.watch<ProfileProvider>();
    if (!account.initializing && account.uid == null) {
      return const SigninScreen();
    }
    if (account.ready) {
      return account.isAdmin
          ? AdminMainScreen(key: ValueKey(account.uid))
          : AppMainScreen(key: ValueKey(account.uid));
    }
    return Scaffold(
      backgroundColor: kbackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: account.error == null || account.busy
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your account is signed in, but the profile could not be loaded.\n${account.error}',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: account.load,
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: account.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
