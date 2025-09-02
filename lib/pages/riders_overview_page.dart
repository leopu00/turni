import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/availability_store.dart';

class RidersOverviewPage extends StatefulWidget {
  const RidersOverviewPage({super.key});

  @override
  State<RidersOverviewPage> createState() => _RidersOverviewPageState();
}

class _RidersOverviewPageState extends State<RidersOverviewPage> {
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
    final start = store.startMonday;
    if (start == null || !store.hasAnySelection) {
      return Scaffold(
        appBar: AppBar(title: const Text('Disponibilità per rider')),
        body: const Center(
          child: Text(
            'Nessuna disponibilità ricevuta.\nChiedi ai rider di selezionare i giorni.',
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
            Text(employee, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              tooltip: 'Pulisci $employee',
              onPressed: () => setState(() => store.clearEmployee(employee)),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        ...week('Settimana 1', w1),
        ...week('Settimana 2', w2),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilità per rider')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Periodo: ${DateFormat('dd MMM', 'it_IT').format(start)} – '
            '${DateFormat('dd MMM', 'it_IT').format(start.add(const Duration(days: 13)))}',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),
          for (final e in store.employees) ...employeeSection(e),
        ],
      ),
    );
  }
}