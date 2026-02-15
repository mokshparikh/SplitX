import 'package:flutter/material.dart';

class BalanceScreen extends StatelessWidget {
  final Map<String, double> balances;

  const BalanceScreen({super.key, required this.balances});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      body: ListView(
        children: balances.entries.map((entry) {
          final name = entry.key;
          final amount = entry.value;

          return ListTile(
            title: Text(name),
            trailing: Text(
              amount == 0
                  ? 'Settled'
                  : amount > 0
                  ? 'Gets ₹${amount.toStringAsFixed(0)}'
                  : 'Owes ₹${amount.abs().toStringAsFixed(0)}',
              style: TextStyle(
                color: amount > 0
                    ? Colors.green
                    : amount < 0
                    ? Colors.red
                    : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
