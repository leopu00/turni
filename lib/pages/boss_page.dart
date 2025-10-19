import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/availability_repository.dart';
import '../models/supabase/profile.dart';
import '../state/availability_store.dart';
import '../state/session_store.dart';
import '../widgets/brand_assets.dart';
import 'login_page.dart';
import 'requirements_page.dart';
import 'riders_overview_page.dart';
import 'boss_employees_page.dart';
import 'manual_shift_results_page.dart';
import 'shift_generation_page.dart';
import 'shift_online_generation_page.dart';

class BossPage extends StatefulWidget {
  const BossPage({super.key, this.availabilityRepository});

  final AvailabilityRepository? availabilityRepository;

  @override
  State<BossPage> createState() => _BossPageState();
}

class _BossPageState extends State<BossPage> {
  final store = AvailabilityStore.instance;
  bool _loading = false;
  String? _loadError;
  Map<String, List<DateTime>> _data = {};
  Map<String, Profile> _profiles = {};
  DateTime? _periodStart;
  late final AvailabilityRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.availabilityRepository ?? AvailabilityRepository.instance;
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
      await _repository.ensureProfileRow();
      final result = await _repository.getAllForBoss();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'Boss'),
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
          : _buildMainContent(context),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final totalRiders = _employees.length;
    final totalSelections = _data.values.fold<int>(
      0,
      (sum, days) => sum + days.length,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.meeting_room_outlined),
          label: const Text('Genera turni in presenza'),
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShiftGenerationPage()),
            );
            if (!mounted) return;
            await _refreshFromRemote();
          },
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.cloud_sync_outlined),
          label: const Text('Genera turni da disponibilità online'),
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ShiftOnlineGenerationPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Turni manuali salvati'),
          style: OutlinedButton.styleFrom(
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualShiftResultsPage()),
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('I miei dipendenti'),
            subtitle: const Text(
              'Gestisci l\'elenco dei dipendenti registrati e da registrare',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BossEmployeesPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (_hasData)
          _SummaryCard(
            periodStart: _periodStart,
            riderCount: totalRiders,
            totalSelections: totalSelections,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Ancora nessuna disponibilità registrata. Invita i rider a compilare la loro agenda.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.periodStart,
    required this.riderCount,
    required this.totalSelections,
  });

  final DateTime? periodStart;
  final int riderCount;
  final int totalSelections;

  @override
  Widget build(BuildContext context) {
    final periodText = periodStart == null
        ? 'Periodo non impostato'
        : 'Periodo attivo: ${DateFormat('dd MMM', 'it_IT').format(periodStart!)} – '
              '${DateFormat('dd MMM', 'it_IT').format(periodStart!.add(const Duration(days: 13)))}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riepilogo disponibilità',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(periodText),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _StatChip(
                  icon: Icons.people_outline,
                  label: '$riderCount rider',
                ),
                _StatChip(
                  icon: Icons.event_available_outlined,
                  label: '$totalSelections disponibilità registrate',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
