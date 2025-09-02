import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/availability_store.dart';
import '../data/session_store.dart';
import '../data/login_page.dart';
import 'requirements_page.dart';
import 'riders_overview_page.dart';

class BossPage extends StatefulWidget {
  const BossPage({super.key});

  @override
  State<BossPage> createState() => _BossPageState();
}

class _BossPageState extends State<BossPage> {
  final store = AvailabilityStore.instance;

  @override
  void initState() {
    super.initState();
    store.addListener(_onChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final start = store.startMonday;
    final dfShort = DateFormat('EEE dd', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Boss — Panoramica"),
        actions: [
          IconButton(
            tooltip: 'Disponibilità per rider',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RidersOverviewPage()),
              );
            },
            icon: const Icon(Icons.people_outline),
          ),
          IconButton(
            tooltip: 'Imposta fabbisogni',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequirementsPage()),
              );
            },
            icon: const Icon(Icons.settings_suggest_outlined),
          ),
          IconButton(
            tooltip: 'Pulisci tutto',
            onPressed: store.hasAnySelection ? store.clearAll : null,
            icon: const Icon(Icons.delete_outline),
          ),
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
      body: start == null || !store.hasAnySelection
          ? const Center(
              child: Text(
                'Nessuna disponibilità ricevuta.\nChiedi ai rider di selezionare i giorni.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Periodo: ${DateFormat('dd MMM', 'it_IT').format(start)} – '
                  '${DateFormat('dd MMM', 'it_IT').format(start.add(const Duration(days: 13)))}',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 12),

                // Tabelle per Settimana 1 e 2
                _weekTable(
                  context: context,
                  title: 'Settimana 1',
                  days: List.generate(7, (i) => start.add(Duration(days: i))),
                  dfShort: dfShort,
                ),
                _weekTable(
                  context: context,
                  title: 'Settimana 2',
                  days: List.generate(7, (i) => start.add(Duration(days: 7 + i))),
                  dfShort: dfShort,
                ),
              ],
            ),
    );
  }

  Widget _weekTable({
    required BuildContext context,
    required String title,
    required List<DateTime> days,
    required DateFormat dfShort,
  }) {
    final employees = store.employees;

    final columns = <DataColumn>[
      const DataColumn(label: Text('Rider')),
      ...days.map((d) {
        final req = store.requirementFor(d);
        final avail = store.availableCountFor(d);
        return DataColumn(
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dfShort.format(d)),
              Text(
                'req $req / avail $avail',
                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
              ),
            ],
          ),
        );
      }),
    ];

    final rows = employees.map((e) {
      final sel = store.selectedFor(e);
      return DataRow(
        cells: [
          DataCell(Text(e)),
          ...days.map((d) {
            final picked = sel.any((x) => sameDay(x, d));
            return DataCell(
              Icon(
                picked ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: picked ? Colors.teal : Theme.of(context).disabledColor,
              ),
            );
          }),
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(columns: columns, rows: rows),
        ),
      ],
    );
  }
}