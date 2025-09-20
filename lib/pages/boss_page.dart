import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/availability_repository.dart';
import '../state/availability_store.dart';
import '../state/session_store.dart';
import 'login_page.dart';
import 'requirements_page.dart';
import 'riders_overview_page.dart';

class BossPage extends StatefulWidget {
  const BossPage({super.key});

  @override
  State<BossPage> createState() => _BossPageState();
}

class _BossPageState extends State<BossPage> {
  final store = AvailabilityStore.instance;
  bool _loading = false;
  String? _loadError;
  Map<String, List<DateTime>> _data = {};
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
      final raw = await AvailabilityRepository.instance.getAllForBoss();
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
    final list = _data.keys.toList()..sort();
    return list;
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
        title: const Text("Boss — Panoramica"),
        actions: [
          IconButton(
            tooltip: 'Disponibilità per rider',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RidersOverviewPage()),
              );
              if (!mounted) return;
              await _refreshFromRemote();
            },
            icon: const Icon(Icons.people_outline),
          ),
          IconButton(
            tooltip: 'Imposta fabbisogni',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequirementsPage()),
              );
              if (!mounted) return;
              setState(() {});
            },
            icon: const Icon(Icons.settings_suggest_outlined),
          ),
          IconButton(
            tooltip: 'Pulisci tutto',
            onPressed: _hasData
                ? () {
                    store.clearAll();
                    setState(() {
                      _data.clear();
                      _periodStart = null;
                    });
                  }
                : null,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              SessionStore.instance.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(fromLogout: true),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
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
