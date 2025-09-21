import 'dart:async';

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
  DateTime? _periodStart;
  late final AvailabilityRepository _repository;

  bool _showSummary = true;
  bool _showWeek1 = true;
  bool _showWeek2 = true;
  bool _highlightCoverage = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.availabilityRepository ?? AvailabilityRepository.instance;
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
      final raw = await _repository.getAllForBoss();
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

  List<DateTime> _allPeriodDays(DateTime start) =>
      List.generate(14, (i) => start.add(Duration(days: i)));

  Future<void> _openRidersOverview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RidersOverviewPage()),
    );
    if (!mounted) return;
    await _refreshFromRemote();
  }

  Future<void> _openRequirements() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RequirementsPage()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleLogout() async {
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
  }

  void _clearAllData() {
    store.clearAll();
    setState(() {
      _data.clear();
      _periodStart = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponibilità azzerate.')),
    );
  }

  void _runAfterDrawerClose(BuildContext drawerContext, Future<void> Function() action) {
    Navigator.of(drawerContext).pop();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      unawaited(action());
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _periodStart;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Apri menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Boss — Panoramica'),
        actions: [
          _toolbarAction(
            context: context,
            icon: Icons.refresh,
            tooltip: 'Aggiorna dati',
            background: Theme.of(context).colorScheme.primaryContainer,
            foreground: Theme.of(context).colorScheme.onPrimaryContainer,
            onPressed: () {
              unawaited(_refreshFromRemote());
            },
          ),
          _toolbarAction(
            context: context,
            icon: Icons.people_outline,
            tooltip: 'Disponibilità per rider',
            background: Theme.of(context).colorScheme.secondaryContainer,
            foreground: Theme.of(context).colorScheme.onSecondaryContainer,
            onPressed: () {
              unawaited(_openRidersOverview());
            },
          ),
          _toolbarAction(
            context: context,
            icon: Icons.settings_suggest_outlined,
            tooltip: 'Imposta fabbisogni',
            background: Theme.of(context).colorScheme.tertiaryContainer,
            foreground: Theme.of(context).colorScheme.onTertiaryContainer,
            onPressed: () {
              unawaited(_openRequirements());
            },
          ),
          _toolbarAction(
            context: context,
            icon: Icons.delete_outline,
            tooltip: 'Pulisci tutto',
            background: Theme.of(context).colorScheme.errorContainer,
            foreground: Theme.of(context).colorScheme.onErrorContainer,
            onPressed: _hasData ? () => _clearAllData() : null,
          ),
          _toolbarAction(
            context: context,
            icon: Icons.logout,
            tooltip: 'Logout',
            background: Theme.of(context).colorScheme.primary,
            foreground: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              unawaited(_handleLogout());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Builder(builder: (drawerContext) => _buildDrawer(drawerContext)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildErrorState()
              : _buildContent(start),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              unawaited(_refreshFromRemote());
            },
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DateTime? start) {
    if (start == null || !_hasData) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildActionButtons(),
          const SizedBox(height: 24),
          _buildEmptyStateCard(),
        ],
      );
    }

    final children = <Widget>[
      _buildActionButtons(),
      const SizedBox(height: 16),
      _buildPeriodCard(start),
    ];

    if (_showSummary) {
      children
        ..add(const SizedBox(height: 16))
        ..add(_buildSummaryCard(start));
    }

    final dfShort = DateFormat('EEE dd', 'it_IT');

    if (_showWeek1) {
      children
        ..add(const SizedBox(height: 16))
        ..add(
          _weekTable(
            context: context,
            title: 'Settimana 1',
            days: List.generate(7, (i) => start.add(Duration(days: i))),
            dfShort: dfShort,
          ),
        );
    }

    if (_showWeek2) {
      children
        ..add(const SizedBox(height: 16))
        ..add(
          _weekTable(
            context: context,
            title: 'Settimana 2',
            days: List.generate(7, (i) => start.add(Duration(days: 7 + i))),
            dfShort: dfShort,
          ),
        );
    }

    children.add(const SizedBox(height: 24));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Widget _buildActionButtons() {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () {
            unawaited(_refreshFromRemote());
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Aggiorna dati'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
          ),
          onPressed: () {
            unawaited(_openRidersOverview());
          },
          icon: const Icon(Icons.people_outline),
          label: const Text('Panoramica rider'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.tertiaryContainer,
            foregroundColor: scheme.onTertiaryContainer,
          ),
          onPressed: () {
            unawaited(_openRequirements());
          },
          icon: const Icon(Icons.settings_suggest_outlined),
          label: const Text('Fabbisogni'),
        ),
        OutlinedButton.icon(
          onPressed: _hasData ? () => _clearAllData() : null,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Pulisci tutto'),
        ),
      ],
    );
  }

  Widget _buildPeriodCard(DateTime start) {
    final scheme = Theme.of(context).colorScheme;
    final rangeText =
        '${DateFormat('dd MMM', 'it_IT').format(start)} – '
        '${DateFormat('dd MMM', 'it_IT').format(start.add(const Duration(days: 13)))}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      color: scheme.surfaceVariant.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.calendar_month),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Periodo turni',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    rangeText,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: Icon(
                Icons.groups_rounded,
                color: scheme.onSecondaryContainer,
              ),
              label: Text('${_employees.length} rider'),
              backgroundColor: scheme.secondaryContainer,
              labelStyle: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(DateTime start) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final days = _allPeriodDays(start);
    final coverageDays =
        days.where((d) => store.requirementFor(d) > 0).toList();
    final coveredDays = coverageDays
        .where((d) => _availableCountFor(d) >= store.requirementFor(d))
        .length;
    final shortageDays = coverageDays.length - coveredDays;
    final totalAvailability =
        days.fold<int>(0, (sum, day) => sum + _availableCountFor(day));
    final coverage = coverageDays.isEmpty
        ? 1.0
        : coveredDays / coverageDays.length;
    final coveredLabel = coverageDays.isEmpty
        ? '$coveredDays'
        : '$coveredDays/${coverageDays.length}';

    final shortageList = coverageDays
        .where((d) => _availableCountFor(d) < store.requirementFor(d))
        .toList();
    final surplusList = coverageDays
        .where((d) => _availableCountFor(d) > store.requirementFor(d))
        .toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riepilogo rapido', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatTile(
                  icon: Icons.groups_rounded,
                  title: 'Rider attivi',
                  value: '${_employees.length}',
                  color: scheme.primary,
                  onColor: scheme.onPrimary,
                ),
                _buildStatTile(
                  icon: Icons.event_available,
                  title: 'Giorni coperti',
                  value: coveredLabel,
                  color: scheme.tertiary,
                  onColor: scheme.onTertiary,
                ),
                _buildStatTile(
                  icon: Icons.all_inclusive,
                  title: 'Totale disponibilità',
                  value: '$totalAvailability',
                  color: scheme.secondary,
                  onColor: scheme.onSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Copertura fabbisogni',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: coverage.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: scheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              coverageDays.isEmpty
                  ? 'Nessun fabbisogno impostato.'
                  : shortageDays == 0
                      ? 'Tutti i giorni con fabbisogno sono coperti.'
                      : 'Giorni scoperti: $shortageDays',
              style: textTheme.bodyMedium,
            ),
            if (shortageList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Attenzione su:',
                style:
                    textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: shortageList.map((day) {
                  final req = store.requirementFor(day);
                  final avail = _availableCountFor(day);
                  final diff = req - avail;
                  final label =
                      '${DateFormat('EEE dd', 'it_IT').format(day)} (-$diff)';
                  return Chip(
                    avatar: Icon(
                      Icons.warning_rounded,
                      color: scheme.onErrorContainer,
                    ),
                    label: Text(label),
                    backgroundColor: scheme.errorContainer,
                    labelStyle: TextStyle(color: scheme.onErrorContainer),
                  );
                }).toList(),
              ),
            ],
            if (surplusList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Extra disponibili:',
                style:
                    textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: surplusList.map((day) {
                  final req = store.requirementFor(day);
                  final avail = _availableCountFor(day);
                  final diff = avail - req;
                  final label =
                      '${DateFormat('EEE dd', 'it_IT').format(day)} (+$diff)';
                  return Chip(
                    avatar: Icon(
                      Icons.check_circle,
                      color: scheme.onSecondaryContainer,
                    ),
                    label: Text(label),
                    backgroundColor: scheme.secondaryContainer,
                    labelStyle: TextStyle(color: scheme.onSecondaryContainer),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color onColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color,
            foregroundColor: onColor,
            child: Icon(icon),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: textTheme.bodyMedium?.copyWith(
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna disponibilità ricevuta.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Chiedi ai rider di selezionare i giorni per popolare la panoramica.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext drawerContext) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: const Icon(Icons.badge),
              ),
              title: const Text('Menu BOSS'),
              subtitle: const Text('Personalizza la panoramica'),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Mostra riepilogo'),
              subtitle: const Text('Statistiche e indicatori rapidi'),
              value: _showSummary,
              onChanged: (value) => setState(() => _showSummary = value),
            ),
            SwitchListTile(
              title: const Text('Mostra Settimana 1'),
              value: _showWeek1,
              onChanged: (value) => setState(() => _showWeek1 = value),
            ),
            SwitchListTile(
              title: const Text('Mostra Settimana 2'),
              value: _showWeek2,
              onChanged: (value) => setState(() => _showWeek2 = value),
            ),
            SwitchListTile(
              title: const Text('Evidenzia copertura'),
              subtitle: const Text('Colora giorni con carenza o surplus'),
              value: _highlightCoverage,
              onChanged: (value) => setState(() => _highlightCoverage = value),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.refresh, color: scheme.primary),
              title: const Text('Aggiorna dati'),
              onTap: () => _runAfterDrawerClose(drawerContext, _refreshFromRemote),
            ),
            ListTile(
              leading: Icon(Icons.people_outline, color: scheme.secondary),
              title: const Text('Disponibilità per rider'),
              onTap: () =>
                  _runAfterDrawerClose(drawerContext, _openRidersOverview),
            ),
            ListTile(
              leading:
                  Icon(Icons.settings_suggest_outlined, color: scheme.tertiary),
              title: const Text('Imposta fabbisogni'),
              onTap: () =>
                  _runAfterDrawerClose(drawerContext, _openRequirements),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: const Text('Pulisci tutto'),
              enabled: _hasData,
              onTap: !_hasData
                  ? null
                  : () => _runAfterDrawerClose(drawerContext, () async {
                        _clearAllData();
                      }),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.primary),
              title: const Text('Logout'),
              onTap: () =>
                  _runAfterDrawerClose(drawerContext, _handleLogout),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarAction({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color foreground,
    VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isDisabled ? background.withOpacity(0.4) : background,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                color: isDisabled ? foreground.withOpacity(0.5) : foreground,
              ),
            ),
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;

    Color? headerColorFor(DateTime day) {
      if (!_highlightCoverage) return null;
      final req = store.requirementFor(day);
      final avail = _availableCountFor(day);
      if (req == 0 && avail == 0) {
        return scheme.surfaceVariant;
      }
      if (avail < req) return scheme.errorContainer;
      if (avail == req) return scheme.primaryContainer;
      return scheme.tertiaryContainer;
    }

    Color headerTextColorFor(DateTime day) {
      final background = headerColorFor(day);
      if (background == null) {
        return Theme.of(context).textTheme.bodyMedium?.color ?? scheme.onSurface;
      }
      if (background == scheme.errorContainer) return scheme.onErrorContainer;
      if (background == scheme.primaryContainer) return scheme.onPrimaryContainer;
      if (background == scheme.tertiaryContainer) return scheme.onTertiaryContainer;
      return scheme.onSurfaceVariant;
    }

    final columns = <DataColumn>[
      const DataColumn(label: Text('Rider')),
      ...days.map((d) {
        final req = store.requirementFor(d);
        final avail = _availableCountFor(d);
        final headerColor = headerColorFor(d);
        final headerTextColor = headerTextColorFor(d);
        return DataColumn(
          label: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dfShort.format(d),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: headerTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'req $req / avail $avail',
                  style: TextStyle(
                    fontSize: 11,
                    color: headerTextColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
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
            final req = store.requirementFor(d);
            final avail = _availableCountFor(d);
            Color? background;
            Color iconColor;
            if (picked) {
              background = scheme.primary.withOpacity(0.12);
              iconColor = scheme.primary;
            } else {
              iconColor = Theme.of(context).disabledColor;
            }
            if (_highlightCoverage && !picked && req > 0 && avail < req) {
              background = scheme.error.withOpacity(0.08);
              iconColor = scheme.error;
            }
            return DataCell(
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  picked ? Icons.check_circle : Icons.remove_circle_outline,
                  size: 20,
                  color: iconColor,
                ),
              ),
            );
          }),
        ],
      );
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns,
                rows: rows,
                headingRowHeight: 64,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
