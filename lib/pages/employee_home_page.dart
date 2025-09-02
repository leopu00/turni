import 'package:flutter/material.dart';
import '../data/session_store.dart';
import '../data/availability_store.dart';
import '../data/login_page.dart';
import 'availability_page.dart';
import 'my_availability_page.dart';


class EmployeeHomePage extends StatelessWidget {
  const EmployeeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.instance;
    final name = session.employeeName ?? 'Dipendente';
    final store = AvailabilityStore.instance;
    final count = store.selectedFor(name).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ciao, $name'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
            SessionStore.instance.logout();
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
            );
            },
            icon: const Icon(Icons.logout),
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
                subtitle: const Text('Seleziona i giorni disponibili (prossime 2 settimane)'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvailabilityPage(employee: name),
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
                  count > 0 ? 'Hai selezionato $count giorni' : 'Nessuna selezione ancora',
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
          ],
        ),
      ),
    );
  }
}