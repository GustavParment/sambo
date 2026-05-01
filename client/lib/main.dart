import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.initialize();
  runApp(const SamboApp());
}

class SamboApp extends StatelessWidget {
  const SamboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sambo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: ValueListenableBuilder<AuthUser?>(
        valueListenable: AuthService.instance.user,
        builder: (context, user, _) =>
            user == null ? const LoginScreen() : HomeScreen(user: user),
      ),
    );
  }
}
