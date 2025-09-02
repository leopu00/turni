import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/availability_store.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  late final DateTime _startMonday; // prossimo lunedì
  late final List<DateTime> _days;  // 14 giorni da _startMonday
  final Set<String> _selected = {}; // yyyy-MM-dd dei giorni selezionati

  static String _keyForDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    _startMonday = _computeNextMonday(DateTime.now());
    _days = List.generate(14, (i) => _startMonday.add(Duration(days: i)));
  }

  DateTime _computeNextMonday(DateTime from) {
    // weekday: Mon=1 ... Sun=7
    final int wd = from.weekday;
    final int daysUntilNextMonday = 8 - wd; // se oggi è lunedì -> 7; se domenica -> 1
    final DateTime nextMonday = DateTime(from.year, from.month, from.day)
        .add(Duration(days: daysUntilNextMonday));
    return nextMonday;
  }

  void _toggle(DateTime day) {
    final k = _keyForDate(day);
    setState(() {
      if (_selected.contains(k)) {
        _selected.remove(k);
      } else {
        _selected.add(k);
      }
    });
  }

  void _save() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun giorno selezionato')),
      );
      return;
    }

    // Costruisci la lista di DateTime selezionate
    final selectedDates = _days
        .where((d) => _selected.contains(_keyForDate(d)))
        .toList();

    // Salva nello store in memoria
    AvailabilityStore.instance.setSelection(
      startMonday: _startMonday,
      selectedDays: selectedDates,
    );

    // Feedback a schermo
    final df = DateFormat('EEE dd MMM', 'it_IT');
    final chosen = selectedDates.map((d) => df.format(d)).join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disponibilità 19:00–23:00 per: $chosen')),
    );

    // Torna alla pagina precedente (opzionale ma comodo)
    Future.microtask(() {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dfHeader = DateFormat('EEE dd MMM', 'it_IT');
    final dfRange = DateFormat('dd MMM', 'it_IT');

    // Suddivisione in due settimane (7 + 7 giorni)
    final week1 = _days.take(7).toList();
    final week2 = _days.skip(7).take(7).toList();

    Widget weekSection(String title, List<DateTime> days) {
      final start = days.first;
      final end = days.last;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header settimana con range date
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${dfRange.format(start)} – ${dfRange.format(end)})',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: days.map((d) {
              final k = _keyForDate(d);
              final selected = _selected.contains(k);
              return FilterChip(
                label: Text(dfHeader.format(d)),
                selected: selected,
                onSelected: (_) => _toggle(d),
                selectedColor: Colors.teal.withOpacity(0.2),
                checkmarkColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? Colors.teal : Theme.of(context).dividerColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilità — prossime 2 settimane')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Banner informativo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.teal, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Seleziona i giorni in cui vuoi lavorare (19:00–23:00)\n'
                'Periodo: ${dfRange.format(week1.first)} – ${dfRange.format(week2.last)} (da lunedì)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // Contenuto scrollabile: settimana 1 e settimana 2 una sotto l'altra
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    weekSection('Settimana 1', week1),
                    const SizedBox(height: 16),
                    weekSection('Settimana 2', week2),
                  ],
                ),
              ),
            ),

            // Azioni
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(_selected.clear),
                    icon: const Icon(Icons.clear),
                    label: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: Text('Salva (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}