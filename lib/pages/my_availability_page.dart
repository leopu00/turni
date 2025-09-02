import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/session_store.dart';
import '../data/availability_store.dart';

class MyAvailabilityPage extends StatelessWidget {
  const MyAvailabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.instance;
    final name = session.employeeName ?? 'Dipendente';
    final store = AvailabilityStore.instance;

    final start = store.startMonday;
    final selections = store.selectedFor(name);

    return Scaffold(
      appBar: AppBar(title: const Text('Le mie disponibilità')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: start == null || selections.isEmpty
            ? const Center(
                child: Text('Non hai ancora selezionato alcun giorno.'),
              )
            : _body(context, start, selections),
      ),
    );
  }

  Widget _body(BuildContext context, DateTime start, List<DateTime> selections) {
    final df = DateFormat('EEE dd MMM', 'it_IT');
    final week1End = start.add(const Duration(days: 6));
    bool isWeek1(DateTime d) => !d.isAfter(week1End);

    final week1 = selections.where(isWeek1).toList()..sort();
    final week2 = selections.where((d) => !isWeek1(d)).toList()..sort();

    Widget section(String title, List<DateTime> days) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              ...days.map(
                (d) => ListTile(
                  leading: const Icon(Icons.event_available),
                  title: Text(df.format(d)),
                  subtitle: const Text('Turno 19:00 – 23:00'),
                ),
              ),
          ],
        );

    return ListView(
      children: [
        Text(
          'Periodo: ${DateFormat('dd MMM', 'it_IT').format(start)} – '
          '${DateFormat('dd MMM', 'it_IT').format(start.add(const Duration(days: 13)))}',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 8),
        section('Settimana 1', week1),
        const Divider(),
        section('Settimana 2', week2),
      ],
    );
  }
}