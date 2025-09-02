import 'package:flutter/material.dart';

class BossPage extends StatelessWidget {
  const BossPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Boss")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.manage_accounts, size: 80, color: Colors.teal),
            SizedBox(height: 20),
            Text(
              "Sezione Boss",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Qui potrai generare e gestire i turni.",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}