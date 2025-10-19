import 'package:flutter/material.dart';

import '../state/session_store.dart';
import '../widgets/brand_assets.dart';
import 'availability_page.dart';
import 'latest_selection_results_page.dart';
import 'my_availability_page.dart';

class EmployeeOnlinePage extends StatelessWidget {
  const EmployeeOnlinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.instance;
    final identifier = session.employeeIdentifier ?? session.employeeDisplayName ?? 'Dipendente';
    final displayName = session.employeeDisplayName ?? identifier;

    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'Turni online'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Inserisci disponibilità'),
              subtitle: const Text(
                'Seleziona i giorni disponibili per le prossime settimane.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AvailabilityPage(
                      employee: identifier,
                      displayName: displayName,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Disponibilità selezionate'),
              subtitle: const Text(
                'Rivedi i giorni che hai inviato online.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyAvailabilityPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Risultato turni ultima selezione'),
              subtitle: const Text(
                'Controlla l’assegnazione più recente basata sulle disponibilità online.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LatestSelectionResultsPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
