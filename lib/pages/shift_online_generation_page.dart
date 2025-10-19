import 'package:flutter/material.dart';

import '../widgets/brand_assets.dart';
import 'boss_overview_page.dart';

class ShiftOnlineGenerationPage extends StatelessWidget {
  const ShiftOnlineGenerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'Genera da disponibilità online'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
              'Stiamo costruendo la generazione automatica specifica per le disponibilità online. Nel frattempo puoi verificare le disponibilità aggiornate e pianificare manualmente.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Panoramica disponibilità'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BossOverviewPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
