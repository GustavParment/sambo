import 'package:flutter/material.dart';
import 'package:sambo/app/router.dart';
import 'package:sambo/theme/sambo_theme.dart';

class SamboApp extends StatelessWidget {
  const SamboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sambo',
      debugShowCheckedModeBanner: false,
      theme: SamboTheme.dark,
      darkTheme: SamboTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: SamboRouter.config,
    );
  }
}
