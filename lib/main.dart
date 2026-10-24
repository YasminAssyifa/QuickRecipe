import 'additions/kitchen_repository.dart';
import 'additions/ai_access.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/Provider/profile_provider.dart';
import 'package:quick_recipe/Provider/favorite_provider.dart';
import 'package:quick_recipe/Provider/quantity.dart';

import 'firebase_options.dart';

import 'views/account_gate.dart';
import 'services/account_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider(repository: FirebaseAccountRepository())),
        ProxyProvider<ProfileProvider, KitchenRepository?>(
          update: (_, account, previous) => account.uid == null ? null : previous is FirebaseKitchenRepository && previous.uid == account.uid ? previous : FirebaseKitchenRepository(account.uid!),
        ),
        ChangeNotifierProvider(create: (_)=>FavoriteProvider()), //favorite provider
        ChangeNotifierProvider(create: (_)=>QuantityProvider()), // quantity provider
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        navigatorObservers: [aiRouteObserver],
        builder: (context, child) => AiShortcutLayer(child: child ?? const SizedBox.shrink()),
        home: const AccountGate(),
      ),
    );
  }
}
