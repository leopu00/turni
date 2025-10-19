import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repositories/availability_repository.dart';
import '../state/availability_store.dart';
import '../widgets/brand_assets.dart';

class AvailabilityPage extends StatefulWidget {
  final String employee; // identifier (es. email)
  final String? displayName;
  const AvailabilityPage({super.key, required this.employee, this.displayName});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  late final DateTime _startMonday; // prossimo lunedì
  late final List<DateTime> _days; // 14 giorni da _startMonday
  final Set<String> _selected = {}; // yyyy-MM-dd dei giorni selezionati

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  static String _keyForDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static bool _sameYMD(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _startMonday = _computeNextMonday(DateTime.now());
    _days = _generateDays(_startMonday, 14);
    // Precarica eventuali selezioni salvate per questo dipendente
    final store = AvailabilityStore.instance;
    final storedStart = store.startMonday;
    if (storedStart != null && _sameYMD(storedStart, _startMonday)) {
      final already = store.selectedFor(widget.employee);
      final allowedKeys = _days.map(_keyForDate).toSet();
      _selected
        ..clear()
        ..addAll(already.map(_keyForDate).where(allowedKeys.contains));
    }
    // Carica anche le selezioni dal DB per l'utente corrente
    _preloadFromDb();
  }

  DateTime _computeNextMonday(DateTime from) {
    final normalized = DateTime(from.year, from.month, from.day);
    final diff = (DateTime.monday - normalized.weekday + 7) % 7;
    final delta = diff == 0 ? 7 : diff;
    return normalized.add(Duration(days: delta));
  }

  List<DateTime> _generateDays(DateTime start, int totalDays) {
    final startLocal = DateTime(start.year, start.month, start.day);
    final startUtc = DateTime.utc(
      startLocal.year,
      startLocal.month,
      startLocal.day,
    );
    return List.generate(totalDays, (index) {
      final utcDay = startUtc.add(Duration(days: index));
      return DateTime(utcDay.year, utcDay.month, utcDay.day);
    });
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

  Future<void> _preloadFromDb() async {
    try {
      await AvailabilityRepository.instance.ensureProfileRow();
      final fromDb = await AvailabilityRepository.instance.getMyDays();
      final allowedKeys = _days.map(_keyForDate).toSet();
      setState(() {
        _selected
          ..clear()
          ..addAll(
            fromDb
                .where((d) => _days.any((x) => _sameYMD(x, d)))
                .map(_keyForDate)
                .where(allowedKeys.contains),
          );
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Errore caricamento disponibilità: $e';
      });
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun giorno selezionato')),
      );
      return;
    }

    final displayName = (widget.displayName?.trim().isNotEmpty ?? false)
        ? widget.displayName!.trim()
        : widget.employee;

    final selectedDates = _days
        .where((d) => _selected.contains(_keyForDate(d)))
        .toList();

    setState(() => _saving = true);
    try {
      // Salva su DB per l'utente corrente
      await AvailabilityRepository.instance.setMyDays(selectedDates.toSet());

      // Mantieni anche lo store in sync per la UI corrente
      AvailabilityStore.instance.setSelection(
        employee: widget.employee,
        startMonday: _startMonday,
        selectedDays: selectedDates,
      );

      final df = DateFormat('EEE dd MMM', 'it_IT');
      final chosen = selectedDates.map((d) => df.format(d)).join(', ');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName: 19:00–23:00 per: $chosen')),
      );

      Future.microtask(() {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                    color: selected
                        ? Colors.teal
                        : Theme.of(context).dividerColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    final displayLabel = (widget.displayName?.trim().isNotEmpty ?? false)
        ? widget.displayName!.trim()
        : widget.employee;
    final titleText = 'Disponibilità — $displayLabel';

    return Scaffold(
      appBar: AppBar(
        title: BrandAppBarTitle(text: titleText),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _preloadFromDb();
                      },
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              )
            : Column(
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
                      'Seleziona i giorni per ${widget.employee} (19:00–23:00)\n'
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
                          onPressed: _saving
                              ? null
                              : () => setState(_selected.clear),
                          icon: const Icon(Icons.clear),
                          label: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
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
