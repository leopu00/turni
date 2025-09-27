import 'package:flutter/material.dart';
import '../state/session_store.dart';
import '../state/availability_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'availability_page.dart';
import 'employee_manual_shift_results_page.dart';
import 'latest_selection_results_page.dart';
import 'login_page.dart';
import 'my_availability_page.dart';
import 'my_shifts_page.dart';
import 'shop_colleagues_page.dart';

class EmployeeHomePage extends StatelessWidget {
  const EmployeeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.instance;
    final identifier = session.employeeIdentifier;
    final displayName = session.employeeDisplayName ?? 'Dipendente';
    final store = AvailabilityStore.instance;
    final count = identifier == null ? 0 : store.selectedFor(identifier).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ciao, $displayName'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              SessionStore.instance.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(fromLogout: true),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Inserisci disponibilità'),
                subtitle: const Text(
                  'Seleziona i giorni disponibili (prossime 2 settimane)',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvailabilityPage(
                        employee: identifier ?? displayName,
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
                subtitle: Text(
                  count > 0
                      ? 'Hai selezionato $count giorni'
                      : 'Nessuna selezione ancora',
                ),
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
                  'Controlla l\'assegnazione più recente dei turni',
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
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('I miei turni attuali'),
                subtitle: const Text(
                  'Visualizza i turni della selezione corrente',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyShiftsPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Turni manuali salvati'),
                subtitle: const Text(
                  'Consulta l\'ultima pianificazione manuale del tuo shop',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeManualShiftResultsPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Colleghi del mio negozio'),
                subtitle: const Text(
                  'Visualizza i rider associati al tuo shop',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShopColleaguesPage(),
                    ),
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
