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
    final df = DateFormat('EEE dd MMM', 'it_IT');

    Widget buildBody() {
      if (!store.hasSelection) {
        return const Center(
          child: Text(
            'Nessuna disponibilità ricevuta.\nChiedi ai dipendenti di selezionare i giorni.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        );
      }

      final start = store.startMonday!;
      final all = store.selectedDays;
      final week1End = start.add(const Duration(days: 6));
      final isWeek1 = (DateTime d) => !d.isAfter(week1End);

      final w1 = all.where(isWeek1).toList();
      final w2 = all.where((d) => !isWeek1(d)).toList();

      List<Widget> section(String title, List<DateTime> days) {
        if (days.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Text('Nessun giorno selezionato'),
            const SizedBox(height: 12),
          ];
        }
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...days.map((d) => ListTile(
                leading: const Icon(Icons.event_available),
                title: Text(df.format(d)),
                subtitle: const Text('Turno 19:00 – 23:00'),
              )),
          const SizedBox(height: 12),
        ];
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...section('Settimana 1', w1),
          ...section('Settimana 2', w2),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Boss"),
        actions: [
          IconButton(
            tooltip: 'Pulisci selezioni',
            onPressed: store.hasSelection ? store.clear : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: buildBody(),
    );
  }
}