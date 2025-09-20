import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/availability_repository.dart';
import '../state/availability_store.dart';
import '../state/session_store.dart';
import 'login_page.dart';

/// Vista per il Boss: elenco disponibilità per dipendente, divise in Settimana 1/2.
class RidersOverviewPage extends StatefulWidget {
  const RidersOverviewPage({super.key});

  @override
  State<RidersOverviewPage> createState() => _RidersOverviewPageState();
}

class _RidersOverviewPageState extends State<RidersOverviewPage> {
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

  List<Widget> _buildWeekSection(
    String title,
    List<DateTime> days,
    DateFormat df,
  ) {
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];

    if (days.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Nessun giorno selezionato'),
        ),
      );
    } else {
      widgets.addAll(
        days.map(
          (d) => ListTile(
            leading: const Icon(Icons.event_available),
            title: Text(df.format(d)),
            subtitle: const Text('Turno 19:00 – 23:00'),
          ),
        ),
      );
    }

    widgets.add(const SizedBox(height: 8));
    return widgets;
  }

  List<Widget> _buildEmployeeSection({
    required String label,
    required List<DateTime> all,
    required DateTime week1End,
    required DateFormat df,
  }) {
    final week1 = all.where((d) => !d.isAfter(week1End)).toList()..sort();
    final week2 = all.where((d) => d.isAfter(week1End)).toList()..sort();

    return [
      const Divider(),
      Row(
        children: [
          const Icon(Icons.person_outline),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      ..._buildWeekSection('Settimana 1', week1, df),
      ..._buildWeekSection('Settimana 2', week2, df),
    ];
  }

  bool get _hasData => _data.values.any((list) => list.isNotEmpty);

  List<String> get _employees {
    final list = _data.keys.toList()..sort();
    return list;
  }

  List<DateTime> _selectedFor(String employee) => _data[employee] ?? const [];

  @override
  Widget build(BuildContext context) {
    final start = _periodStart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilità per dipendente'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _refreshFromRemote,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
              SessionStore.instance.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(fromLogout: true),
                ),
                (route) => false,
              );
            },
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
                'Periodo non impostato.\nVai su "Disponibilità" e seleziona il periodo di due settimane.',
                textAlign: TextAlign.center,
              ),
            )
          : _buildContent(context, start),
    );
  }

  Widget _buildContent(BuildContext context, DateTime start) {
    final employees = _employees;
    if (employees.isEmpty) {
      return const Center(
        child: Text('Nessuna disponibilità nel periodo selezionato.'),
      );
    }

    final df = DateFormat('EEE dd MMM', 'it_IT');
    final periodText =
        'Periodo: ${DateFormat('dd MMM', 'it_IT').format(start)} – '
        '${DateFormat('dd MMM', 'it_IT').format(start.add(const Duration(days: 13)))}';
    final week1End = start.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(periodText, style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 8),
        for (final employee in employees)
          ..._buildEmployeeSection(
            label: employee,
            all: _selectedFor(employee),
            week1End: week1End,
            df: df,
          ),
      ],
    );
  }
}
