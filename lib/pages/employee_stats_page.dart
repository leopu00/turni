import 'package:flutter/material.dart';

import '../widgets/brand_assets.dart';

class EmployeeStatsPage extends StatelessWidget {
  const EmployeeStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sections = <_StatSection>[
      const _StatSection(
        title: 'Turni assegnati',
        description: 'Totale dei turni in cui sei stato selezionato.',
      ),
      const _StatSection(
        title: 'Disponibilità non assegnate',
        description:
            'Giorni proposti ma non assegnati nella generazione manuale.',
      ),
      const _StatSection(
        title: 'Percentuale di assegnazione',
        description:
            'Rapporto tra disponibilità indicate e turni effettivamente assegnati.',
      ),
      const _StatSection(
        title: 'Giorni con più assegnazioni',
        description:
            'Distribuzione dei turni per giorno della settimana (top 3).',
      ),
      const _StatSection(
        title: 'Giorni con meno assegnazioni',
        description:
            'Giorni in cui vieni scelto raramente rispetto alle disponibilità.',
      ),
      const _StatSection(
        title: 'Ultimo aggiornamento',
        description:
            'Timestap dell’ultima generazione manuale considerata per i dati.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'Statistiche'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surfaceVariant.withAlpha(102),
                    ),
                    child: Text(
                      section.placeholderValue,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatSection {
  const _StatSection({
    required this.title,
    required this.description,
    this.placeholderValue = '--',
  });

  final String title;
  final String description;
  final String placeholderValue;
}
