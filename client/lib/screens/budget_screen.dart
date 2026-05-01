import 'package:flutter/material.dart';

/// Placeholder. Hooked up to `/api/households/{id}/budget/{yearMonth}` later.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Budget-vyn kommer hit härnäst — kategorier, kvar att spendera och Tink-transaktioner.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }
}
