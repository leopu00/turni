import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/availability_store.dart';

class RequirementsPage extends StatefulWidget {
  const RequirementsPage({super.key});

  @override
  State<RequirementsPage> createState() => _RequirementsPageState();
}

class _RequirementsPageState extends State<RequirementsPage> {
  final store = AvailabilityStore.instance;

  @override
  Widget build(BuildContext context) {
    final start = store.startMonday;
    if (start == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fabbisogno')),
        body: const Center(
          child: Text('Nessun periodo attivo. Chiedi ai rider di inviare disponibilità.'),
        ),
      );
    }

    final df = DateFormat('EEE dd MMM', 'it_IT');
    final week1 = List.generate(7, (i) => start.add(Duration(days: i)));
    final week2 = List.generate(7, (i) => start.add(Duration(days: 7 + i)));

    Widget week(String title, List<DateTime> days) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...days.map((d) {
            final avail = store.availableCountFor(d);
            final req = store.requirementFor(d);
            return ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(df.format(d)),
              subtitle: Text('Disponibili: $avail'),
              trailing: SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Diminuire',
                      onPressed: req > 0 ? () => setState(() => store.setRequirement(d, req - 1)) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$req', style: const TextStyle(fontSize: 16)),
                    IconButton(
                      tooltip: 'Aumentare',
                      onPressed: () => setState(() => store.setRequirement(d, req + 1)),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fabbisogno (2 settimane)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          week('Settimana 1', week1),
          const Divider(),
          week('Settimana 2', week2),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Fatto'),
          ),
        ],
      ),
    );
  }
}