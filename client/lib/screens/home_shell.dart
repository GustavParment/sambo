import 'package:flutter/material.dart';
import 'package:sambo/models/auth_user.dart';
import 'package:sambo/screens/budget_screen.dart';
import 'package:sambo/screens/calendar_screen.dart';
import 'package:sambo/screens/chores_screen.dart';
import 'package:sambo/screens/settings_screen.dart';

/// Post-login chrome — bottom nav + IndexedStack so each tab keeps its
/// scroll position / loaded data when the user switches around.
class HomeShell extends StatefulWidget {
  final AuthUser user;
  const HomeShell({super.key, required this.user});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1; // Land on Chores by default — that's the most-used tab.

  late final List<Widget> _tabs = [
    const BudgetScreen(),
    const ChoresScreen(),
    const CalendarScreen(),
    SettingsScreen(user: widget.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: SafeArea(
        top: false,
        // Apply safe-area only at the bottom so iPhone home-indicator and
        // Android gesture-bar don't sit under the nav.
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Budget',
            ),
            NavigationDestination(
              icon: Icon(Icons.cleaning_services_outlined),
              selectedIcon: Icon(Icons.cleaning_services),
              label: 'Sysslor',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Kalender',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Inställningar',
            ),
          ],
        ),
      ),
    );
  }
}
