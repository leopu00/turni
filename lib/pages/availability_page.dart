import 'package:flutter/material.dart';

class AvailabilityPage extends StatelessWidget {
  const AvailabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Titolo principale
    final titleWidget = Container(
      alignment: Alignment.center,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        "Disponibilità",
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );

    // Domanda
    final questionWidget = const Text(
      "In quale fascia oraria sei disponibile?",
      style: TextStyle(fontSize: 18),
      textAlign: TextAlign.center,
    );

    // Icone orari (solo UI)
    final slotsWidget = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.wb_sunny, color: Colors.orange, size: 48), // mattina
        SizedBox(width: 40),
        Icon(Icons.nightlight_round, color: Colors.blue, size: 48), // sera
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Disponibilità")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          titleWidget,
          questionWidget,
          slotsWidget,
          const Text(
            "Seleziona una fascia per continuare...",
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}