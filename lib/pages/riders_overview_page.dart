import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/availability_store.dart';
import '../state/session_store.dart';
import 'login_page.dart';
import '../data/repositories/availability_repository.dart';

/// Vista per il Boss: elenco disponibilità per dipendente, divise in Settimana 1/2.
class RidersOverviewPage extends StatelessWidget {
  const RidersOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AvailabilityStore.instance;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final start = store.startMonday;
        if (start == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Disponibilità per dipendente'),
              actions: [
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
                    SessionStore.instance.logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage(fromLogout: true)),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
            body: const Center(
              child: Text(
                'Periodo non impostato.\nVai su "Disponibilità" e seleziona il periodo di due settimane.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final df = DateFormat('EEE dd MMM', 'it_IT');
        final week1End = start.add(const Duration(days: 6));
        bool isWeek1(DateTime d) => !d.isAfter(week1End);

        List<Widget> employeeSection(String employee) {
          final all = store.selectedFor(employee);
          final w1 = all.where(isWeek1).toList()..sort();
          final w2 = all.where((d) => !isWeek1(d)).toList()..sort();

          List<Widget> week(String title, List<DateTime> days) {
            return [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Nessun giorno selezionato'),
                )
              else
                ...days.map((d) => ListTile(
                      leading: const Icon(Icons.event_available),
                      title: Text(df.format(d)),
                      subtitle: const Text('Turno 19:00 – 23:00'),
                    )),
              const SizedBox(height: 8),
            ];
          }

          return [
            const Divider(),
            Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Text(employee, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Pulisci $employee',
                  onPressed: () => store.clearEmployee(employee),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
            ...week('Settimana 1', w1),
            ...week('Settimana 2', w2),
          ];
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Disponibilità per dipendente'),
            actions: [
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
                  SessionStore.instance.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage(fromLogout: true)),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          body: FutureBuilder<Map<String, List<DateTime>>>(
            future: AvailabilityRepository.instance.getAllForBoss(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Errore nel caricamento: ${snap.error}'));
              }
              final data = snap.data ?? {};
              // Filtro il range di due settimane a partire da `start`
              final periodStart = start;
              final periodEnd = start.add(const Duration(days: 13));

              final filtered = <String, List<DateTime>>{};
              data.forEach((email, days) {
                final kept = days
                    .where((d) => !d.isBefore(periodStart) && !d.isAfter(periodEnd))
                    .toList()
                  ..sort();
                if (kept.isNotEmpty) filtered[email] = kept;
              });

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Nessuna disponibilità nel periodo selezionato.'),
                );
              }

              final df = DateFormat('EEE dd MMM', 'it_IT');
              final week1End = start.add(const Duration(days: 6));
              bool isWeek1(DateTime d) => !d.isAfter(week1End);

              List<Widget> employeeSection(String email, List<DateTime> all) {
                final w1 = all.where(isWeek1).toList();
                final w2 = all.where((d) => !isWeek1(d)).toList();

                List<Widget> week(String title, List<DateTime> days) {
                  return [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    if (days.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Nessun giorno selezionato'),
                      )
                    else
                      ...days.map((d) => ListTile(
                            leading: const Icon(Icons.event_available),
                            title: Text(df.format(d)),
                            subtitle: const Text('Turno 19:00 – 23:00'),
                          )),
                    const SizedBox(height: 8),
                  ];
                }

                return [
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Text(email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  ...week('Settimana 1', w1),
                  ...week('Settimana 2', w2),
                ];
              }

              final periodText =
                  'Periodo: ${DateFormat('dd MMM', 'it_IT').format(start)} – '
                  '${DateFormat('dd MMM', 'it_IT').format(start.add(const Duration(days: 13)))}';

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    periodText,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in filtered.entries)
                    ...employeeSection(entry.key, entry.value),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
