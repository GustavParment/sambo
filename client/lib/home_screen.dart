import 'package:flutter/material.dart';

import 'auth_service.dart';

/// Placeholder post-login screen. Once the budget API is hooked up this is
/// where the monthly overview lands.
class HomeScreen extends StatelessWidget {
  final AuthUser user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sambo'),
        actions: [
          IconButton(
            tooltip: 'Logga ut',
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Role'),
                  subtitle: Text(user.role),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Household ID'),
                  subtitle: Text(user.householdId),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Du är inloggad. Budget-vyn kommer hit härnäst.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
