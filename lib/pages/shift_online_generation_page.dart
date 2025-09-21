import 'package:flutter/material.dart';

class ShiftOnlineGenerationPage extends StatelessWidget {
  const ShiftOnlineGenerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Genera da disponibilità online')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_sync_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Automazione in arrivo',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Qui potrai generare i turni sfruttando le disponibilità inviate dall’app. Funzionalità in lavorazione.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
