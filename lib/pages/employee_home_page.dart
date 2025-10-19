import 'package:flutter/material.dart';
import '../state/session_store.dart';
import '../state/availability_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/brand_assets.dart';
import 'employee_manual_shift_results_page.dart';
import 'employee_online_page.dart';
import 'login_page.dart';
import 'my_shops_page.dart';
import 'my_shifts_page.dart';
import 'employee_stats_page.dart';
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
        title: BrandAppBarTitle(text: 'Ciao, $displayName'),
        actions: [
          IconButton(
            tooltip: 'Colleghi del mio negozio',
            icon: const Icon(Icons.group_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ShopColleaguesPage(),
                ),
              );
            },
          ),
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
      drawer: _EmployeeDrawer(
        displayName: displayName,
        email: identifier,
        onShopsTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MyShopsPage(),
            ),
          );
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Invia disponibilità online'),
              subtitle: Text(
                count > 0
                    ? 'Hai inviato $count giorni disponibili.'
                    : 'Invia le tue disponibilità per essere selezionato.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmployeeOnlinePage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('I miei turni'),
              subtitle: const Text(
                'Panoramica dei giorni assegnati nell’ultima generazione manuale.',
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
              leading: const Icon(Icons.query_stats_outlined),
              title: const Text('Statistiche'),
              subtitle: const Text(
                'Analisi delle assegnazioni e delle disponibilità inviate.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmployeeStatsPage(),
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
                'Consulta l’ultima pianificazione manuale del tuo shop.',
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
        ],
      ),
    );
  }
}

class _EmployeeDrawer extends StatelessWidget {
  const _EmployeeDrawer({
    required this.displayName,
    required this.onShopsTap,
    this.email,
  });

  final String displayName;
  final String? email;
  final VoidCallback onShopsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.primary;
    final onHeaderColor = theme.colorScheme.onPrimary;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: headerColor,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onHeaderColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onHeaderColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Shop'),
              subtitle: const Text('Vedi gli shop a cui appartieni'),
              onTap: onShopsTap,
            ),
          ],
        ),
      ),
    );
  }
}
