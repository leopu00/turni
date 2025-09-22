import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repositories/manual_shift_repository.dart';
import '../data/repositories/shop_repository.dart';
import '../models/supabase/profile.dart';

class ManualShiftResultsPage extends StatefulWidget {
  const ManualShiftResultsPage({super.key});

  @override
  State<ManualShiftResultsPage> createState() =>
      _ManualShiftResultsPageState();
}

class _ManualShiftResultsPageState extends State<ManualShiftResultsPage> {
  static final DateFormat _dayFormat = DateFormat('EEEE dd MMMM', 'it_IT');

  bool _loading = false;
  String? _error;
  String? _shopId;
  String? _shopName;
  List<_ManualShiftDayGroup> _days = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shopResult =
          await ShopRepository.instance.fetchColleaguesForCurrentUser();
      if (!mounted) return;

      if (!shopResult.hasShop) {
        setState(() {
          _shopId = null;
          _shopName = null;
          _days = const [];
          _loading = false;
        });
        return;
      }

      final assignments = await ManualShiftRepository.instance
          .fetchAssignmentsForShop(shopResult.shopId!);

      final profileMap = <String, Profile>{
        for (final profile in shopResult.colleagues) profile.id: profile,
      };
      final pendingMap = <String, PendingEmployee>{
        for (final pending in shopResult.pending) pending.id: pending,
      };

      final grouped = <DateTime, List<_ManualShiftEmployeeView>>{};
      for (final assignment in assignments) {
        final normalizedDay = DateTime(
          assignment.day.year,
          assignment.day.month,
          assignment.day.day,
        );
        final employees =
            grouped.putIfAbsent(normalizedDay, () => <_ManualShiftEmployeeView>[]);
        final label = _labelFor(assignment.employeeId, profileMap, pendingMap);
        final detail =
            _detailFor(assignment.employeeId, profileMap, pendingMap);
        employees.add(
          _ManualShiftEmployeeView(
            id: assignment.employeeId,
            label: label,
            detail: detail,
          ),
        );
      }

      final dayGroups = grouped.entries.map((entry) {
        final employees = entry.value
          ..sort((a, b) => a.label.toLowerCase().compareTo(
                b.label.toLowerCase(),
              ));
        return _ManualShiftDayGroup(
          day: entry.key,
          employees: employees,
        );
      }).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

      if (!mounted) return;
      setState(() {
        _shopId = shopResult.shopId;
        _shopName = shopResult.shopName;
        _days = dayGroups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore nel caricamento: $e';
        _loading = false;
      });
    }
  }

  String _labelFor(
    String id,
    Map<String, Profile> profiles,
    Map<String, PendingEmployee> pending,
  ) {
    final profile = profiles[id];
    if (profile != null) {
      final display = profile.displayName?.trim();
      if (display != null && display.isNotEmpty) return display;
      final username = profile.username?.trim();
      if (username != null && username.isNotEmpty) return username;
      return profile.email;
    }
    final manual = pending[id];
    if (manual != null) {
      return manual.name;
    }
    return 'ID $id';
  }

  String? _detailFor(
    String id,
    Map<String, Profile> profiles,
    Map<String, PendingEmployee> pending,
  ) {
    final profile = profiles[id];
    if (profile != null) return profile.email;
    final manual = pending[id];
    if (manual != null) return 'Da registrare';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _load,
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    } else if (_shopId == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Non sei associato a nessuno shop, impossibile mostrare i turni.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            if (_days.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Non ci sono turni manuali salvati per questo shop.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ..._days.map((day) => _buildDayCard(context, day)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turni manuali generati'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.store_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _shopName ?? 'Shop senza nome',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Riepilogo turni manuali',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildDayCard(BuildContext context, _ManualShiftDayGroup day) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dayFormat.format(day.day),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (day.employees.isEmpty)
              Text(
                'Nessun dipendente assegnato.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...day.employees.map(
                (employee) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text(employee.label),
                  subtitle:
                      employee.detail != null ? Text(employee.detail!) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManualShiftDayGroup {
  const _ManualShiftDayGroup({
    required this.day,
    required this.employees,
  });

  final DateTime day;
  final List<_ManualShiftEmployeeView> employees;
}

class _ManualShiftEmployeeView {
  const _ManualShiftEmployeeView({
    required this.id,
    required this.label,
    this.detail,
  });

  final String id;
  final String label;
  final String? detail;
}
