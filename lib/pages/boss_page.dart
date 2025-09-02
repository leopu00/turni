import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/availability_store.dart';

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

  @override
  Widget build(BuildContext context) {
    final dfLong = DateFormat('EEE dd MMM', 'it_IT');
    final dfShort = DateFormat('EEE dd', 'it_IT');

    if (!store.hasAnySelection) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Boss"),
          actions: [
            IconButton(
              tooltip: 'Pulisci tutto',
              onPressed: null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: const Center(
          child: Text(
            'Nessuna disponibilità ricevuta.\nChiedi ai dipendenti di selezionare i giorni.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final start = store.startMonday!;
    final allEmployees = store.employees;

    // Costruisci le date per settimana 1 e 2
    final week1Dates = List.generate(7, (i) => start.add(Duration(days: i)));
    final week2Dates = List.generate(7, (i) => start.add(Duration(days: 7 + i)));

    // Helper per costruire una DataTable settimana
    Widget weekTable(String title, List<DateTime> days) {
      final columns = <DataColumn>[
        const DataColumn(label: Text('Rider')),
        ...days.map((d) => DataColumn(label: Text(dfShort.format(d))))
      ];

      final rows = allEmployees.map((e) {
        final sel = store.selectedFor(e);
        return DataRow(cells: [
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
        ]);
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          // Scroll orizzontale nel caso la tabella sfori lo schermo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: columns, rows: rows),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Boss"),
        actions: [
          IconButton(
            tooltip: 'Pulisci tutto',
            onPressed: store.hasAnySelection ? store.clearAll : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Periodo: ${DateFormat('dd MMM', 'it_IT').format(start)} – '
            '${DateFormat('dd MMM', 'it_IT').format(start.add(const Duration(days: 13)))}',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),

          // --- Panoramica per dipendente (lista) ---
          for (final e in allEmployees) ...{
            const Divider(),
            Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Text(e, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Pulisci ' + e,
                  onPressed: () => setState(() => store.clearEmployee(e)),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
            // Settimane come lista
            ...store
                .selectedFor(e)
                .where((d) => d.isBefore(start.add(const Duration(days: 7))))
                .map((d) => ListTile(
                      leading: const Icon(Icons.event_available),
                      title: Text(dfLong.format(d)),
                      subtitle: const Text('Turno 19:00 – 23:00'),
                    )),
            ...store
                .selectedFor(e)
                .where((d) => !d.isBefore(start.add(const Duration(days: 7))))
                .map((d) => ListTile(
                      leading: const Icon(Icons.event_available),
                      title: Text(dfLong.format(d)),
                      subtitle: const Text('Turno 19:00 – 23:00'),
                    )),
          },

          const SizedBox(height: 16),
          const Divider(thickness: 1.2),
          const SizedBox(height: 8),
          const Text('Panoramica (tabella)', style: TextStyle(fontWeight: FontWeight.bold)),

          // --- Tabelle per settimana ---
          weekTable('Settimana 1', week1Dates),
          weekTable('Settimana 2', week2Dates),
        ],
      ),
    );
  }
}