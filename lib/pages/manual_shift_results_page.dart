import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repositories/manual_shift_repository.dart';
import '../data/repositories/shop_repository.dart';
import '../models/supabase/profile.dart';
import '../widgets/brand_assets.dart';

enum ManualShiftResultsExit { modify, goHome }

class ManualShiftResultsPage extends StatefulWidget {
  const ManualShiftResultsPage({
    super.key,
    this.title = 'Turni manuali generati',
    this.headerSubtitle = 'Riepilogo turni manuali',
    this.allowModify = false,
  });

  final String title;
  final String headerSubtitle;
  final bool allowModify;

  @override
  State<ManualShiftResultsPage> createState() => _ManualShiftResultsPageState();
}

class _ManualShiftResultsPageState extends State<ManualShiftResultsPage> {
  static final DateFormat _weekdayFormat = DateFormat('EEEE', 'it_IT');
  static final DateFormat _dayMonthFormat = DateFormat('dd MMMM', 'it_IT');
  static final DateFormat _weekRangeFormat = DateFormat('dd MMMM', 'it_IT');

  bool _loading = false;
  String? _error;
  String? _shopId;
  String? _shopName;
  List<_ManualShiftWeekGroup> _weeks = const [];

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
      final shopResult = await ShopRepository.instance
          .fetchColleaguesForCurrentUser();
      if (!mounted) return;

      if (!shopResult.hasShop) {
        setState(() {
          _shopId = null;
          _shopName = null;
          _weeks = const [];
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
        final employees = grouped.putIfAbsent(
          normalizedDay,
          () => <_ManualShiftEmployeeView>[],
        );
        final label = _labelFor(assignment.employeeId, profileMap, pendingMap);
        final detail = _detailFor(
          assignment.employeeId,
          profileMap,
          pendingMap,
        );
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
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
        return _ManualShiftDayGroup(
          day: entry.key,
          employees: List<_ManualShiftEmployeeView>.from(employees),
        );
      }).toList()..sort((a, b) => a.day.compareTo(b.day));

      final weekMap = <DateTime, Map<int, _ManualShiftDayGroup>>{};
      for (final group in dayGroups) {
        final weekStart = _startOfWeek(group.day);
        final map = weekMap.putIfAbsent(
          weekStart,
          () => <int, _ManualShiftDayGroup>{},
        );
        map[group.day.weekday] = group;
      }

      final weeks = weekMap.entries.map((entry) {
        final start = entry.key;
        final values = entry.value;
        final days = List<_ManualShiftDayGroup>.generate(7, (index) {
          final weekday = DateTime.monday + index;
          final date = start.add(Duration(days: index));
          final existing = values[weekday];
          if (existing != null) {
            return _ManualShiftDayGroup(
              day: existing.day,
              employees: List<_ManualShiftEmployeeView>.from(
                existing.employees,
              ),
            );
          }
          return _ManualShiftDayGroup(day: date, employees: const []);
        });
        return _ManualShiftWeekGroup(start: start, days: days);
      }).toList()..sort((a, b) => a.start.compareTo(b.start));

      if (!mounted) return;
      setState(() {
        _shopId = shopResult.shopId;
        _shopName = shopResult.shopName;
        _weeks = weeks;
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

  DateTime _startOfWeek(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final delta = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: delta));
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
            FilledButton(onPressed: _load, child: const Text('Riprova')),
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
            if (_weeks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Non ci sono turni manuali salvati per questo shop.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ..._weeks.map((week) => _buildWeekCard(context, week)),
            if (_weeks.isNotEmpty && widget.allowModify) ...[
              const SizedBox(height: 24),
              _buildActions(context),
            ],
            SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(ManualShiftResultsExit.goHome);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(ManualShiftResultsExit.goHome);
              }
            },
          ),
          title: BrandAppBarTitle(text: widget.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Aggiorna',
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.store_outlined, color: theme.colorScheme.primary, size: 40),
        const SizedBox(height: 8),
        Text(
          _shopName ?? 'Shop senza nome',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.headerSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildWeekCard(BuildContext context, _ManualShiftWeekGroup week) {
    final theme = Theme.of(context);
    final startLabel = _titleCase(_weekRangeFormat.format(week.start));
    final endLabel = _titleCase(_weekRangeFormat.format(week.days.last.day));
    final header = 'Settimana $startLabel – $endLabel';
    final maxRows = week.days.fold<int>(
      0,
      (value, day) => math.max(value, day.employees.length),
    );
    final rowCount = maxRows == 0 ? 1 : maxRows;
    final availableWidth = MediaQuery.of(context).size.width - 64;
    final constrainedWidth = availableWidth > 0
        ? availableWidth
        : MediaQuery.of(context).size.width;

    final columns = week.days.map((day) {
      final dayName = _titleCase(_weekdayFormat.format(day.day));
      final dateLabel = _titleCase(_dayMonthFormat.format(day.day));
      return DataColumn(
        label: SizedBox(
          width: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dayName,
                textAlign: TextAlign.center,
                softWrap: false,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                textAlign: TextAlign.center,
                softWrap: false,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    final rows = List<DataRow>.generate(rowCount, (rowIndex) {
      final isStriped = rowIndex.isOdd;
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (states) => isStriped
              ? theme.colorScheme.primary.withValues(alpha: 0.03)
              : Colors.transparent,
        ),
        cells: week.days.map((day) {
          final employees = day.employees;
          final label = rowIndex < employees.length
              ? employees[rowIndex].label
              : '';
          return DataCell(
            SizedBox(
              width: 120,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }).toList(),
      );
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              header,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constrainedWidth + 1),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                  ),
                  columns: columns,
                  rows: rows,
                  dataRowHeight: 48,
                  headingRowHeight: 64,
                  dividerThickness: 0.8,
                  horizontalMargin: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () =>
            Navigator.of(context).pop(ManualShiftResultsExit.modify),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Modifica'),
      ),
    );
  }

  String _titleCase(String input) {
    final parts = input.split(' ');
    return parts
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1) : ''}',
        )
        .join(' ');
  }
}

class _ManualShiftDayGroup {
  const _ManualShiftDayGroup({required this.day, required this.employees});

  final DateTime day;
  final List<_ManualShiftEmployeeView> employees;
}

class _ManualShiftWeekGroup {
  const _ManualShiftWeekGroup({required this.start, required this.days});

  final DateTime start;
  final List<_ManualShiftDayGroup> days;
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
