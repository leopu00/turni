import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repositories/availability_repository.dart';
import '../models/supabase/profile.dart';
import '../state/availability_store.dart';

class BossOverviewPage extends StatefulWidget {
  const BossOverviewPage({super.key});

  @override
  State<BossOverviewPage> createState() => _BossOverviewPageState();
}

class _BossOverviewPageState extends State<BossOverviewPage> {
  final store = AvailabilityStore.instance;
  bool _loading = false;
  String? _loadError;
  Map<String, List<DateTime>> _data = {};
  Map<String, Profile> _profiles = {};
  DateTime? _periodStart;

  @override
  void initState() {
    super.initState();
    store.addListener(_onChanged);
    _refreshFromRemote();
  }

  @override
  void dispose() {
    store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshFromRemote() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await AvailabilityRepository.instance.ensureProfileRow();
      final result = await AvailabilityRepository.instance.getAllForBoss();
      final raw = result.byEmployee;
      final normalized = <String, List<DateTime>>{};
      DateTime? earliest;
      raw.forEach((email, days) {
        final normalizedDays =
            days.map((d) => DateTime(d.year, d.month, d.day)).toList()..sort();
        if (normalizedDays.isEmpty) return;
        normalized[email] = normalizedDays;
        final first = normalizedDays.first;
        if (earliest == null || first.isBefore(earliest!)) {
          earliest = first;
        }
      });

      final monday = earliest == null
          ? null
          : DateTime(
              earliest!.year,
              earliest!.month,
              earliest!.day,
            ).subtract(Duration(days: earliest!.weekday - DateTime.monday));

      AvailabilityStore.instance.hydrateAllForBoss(normalized);
      if (!mounted) return;
      setState(() {
        _data = normalized;
        _profiles = result.profiles;
        _periodStart = monday;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _hasData => _data.values.any((list) => list.isNotEmpty);

  List<String> get _employees {
    final list = _data.keys.toList()
      ..sort((a, b) => _labelFor(a).compareTo(_labelFor(b)));
    return list;
  }

  String _labelFor(String email) {
    final profile = _profiles[email];
    final display = profile?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final username = profile?.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    return email;
  }

  int _availableCountFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    int count = 0;
    for (final list in _data.values) {
      if (list.any((d) => sameDay(d, normalized))) count++;
    }
    return count;
  }

  List<DateTime> _selectedFor(String employee) => _data[employee] ?? const [];

  @override
  Widget build(BuildContext context) {
    final start = _periodStart;
    final dfShort = DateFormat('EEE dd', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panoramica disponibilità'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _refreshFromRemote,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refreshFromRemote,
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            )
          : start == null || !_hasData
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
                _weekTable(
                  context: context,
                  title: 'Settimana 1',
                  days: List.generate(7, (i) => start.add(Duration(days: i))),
                  dfShort: dfShort,
                ),
                _weekTable(
                  context: context,
                  title: 'Settimana 2',
                  days: List.generate(
                    7,
                    (i) => start.add(Duration(days: 7 + i)),
                  ),
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
    final employees = _employees;

    final columns = <DataColumn>[
      const DataColumn(label: Text('Rider')),
      ...days.map((d) {
        final req = store.requirementFor(d);
        final avail = _availableCountFor(d);
        return DataColumn(
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dfShort.format(d)),
              Text(
                'req $req / avail $avail',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        );
      }),
    ];

    final rows = employees.map((e) {
      final sel = _selectedFor(e);
      return DataRow(
        cells: [
          DataCell(Text(_labelFor(e))),
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
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(columns: columns, rows: rows),
        ),
      ],
    );
  }
}
