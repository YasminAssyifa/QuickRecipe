import 'package:quick_recipe/services/kitchen_repository.dart';
import 'package:quick_recipe/screens/ai_screen.dart';
import 'package:quick_recipe/services/chat_repository.dart';
import 'package:quick_recipe/services/recipe_guide.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/providers/profile_provider.dart';
import 'package:quick_recipe/providers/favorite_provider.dart';
import 'package:quick_recipe/providers/quantity.dart';

import 'firebase_options.dart';

import 'package:quick_recipe/screens/account_gate.dart';
import 'services/account_repository.dart';
import 'services/recipe_admin_repository.dart';

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
        ProxyProvider2<ProfileProvider, KitchenRepository?, AiRepository?>(
          update: (_, account, kitchen, previous) => account.uid == null || kitchen == null ? null : previous is RecipeGuideRepository && previous.uid == account.uid && previous.kitchen == kitchen ? previous : RecipeGuideRepository(account.uid!, kitchen),
        ),
        ProxyProvider<ProfileProvider, RecipeAdminRepository?>(
          update: (_, account, previous) => account.uid == null ? null : previous is FirebaseRecipeAdminRepository && previous.uid == account.uid ? previous : FirebaseRecipeAdminRepository(account.uid!),
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
