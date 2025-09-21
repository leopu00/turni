import 'package:flutter/material.dart';

class ShiftGenerationPage extends StatelessWidget {
  const ShiftGenerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generazione turni')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Generazione manuale in arrivo',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Qui potrai creare i turni partendo dalle disponibilità raccolte. Funzionalità in fase di progettazione.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
