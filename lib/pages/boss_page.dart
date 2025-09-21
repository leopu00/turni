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
  bool _showWeek1 = true;
  bool _showWeek2 = true;
  bool _showRequirementsInfo = true;
  bool _hideEmptyDays = false;

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

  void _clearAllData() {
    store.clearAll();
    setState(() {
      _data.clear();
      _periodStart = null;
    });
  }

  Future<void> _performLogout() async {
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
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.shade600,
                    Colors.teal.shade200,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'Impostazioni BOSS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Scegli quali sezioni visualizzare e accedi alle azioni rapide.',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Visualizzazione',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.looks_one_outlined),
              title: const Text('Mostra settimana 1'),
              value: _showWeek1,
              onChanged: (value) {
                setState(() {
                  _showWeek1 = value;
                });
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.looks_two_outlined),
              title: const Text('Mostra settimana 2'),
              value: _showWeek2,
              onChanged: (value) {
                setState(() {
                  _showWeek2 = value;
                });
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.rule),
              title: const Text('Mostra requisiti e disponibilità'),
              subtitle: const Text('Visualizza il riepilogo req/avail nelle intestazioni'),
              value: _showRequirementsInfo,
              onChanged: (value) {
                setState(() {
                  _showRequirementsInfo = value;
                });
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Nascondi giorni senza disponibilità'),
              value: _hideEmptyDays,
              onChanged: (value) {
                setState(() {
                  _hideEmptyDays = value;
                });
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Azioni rapide',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Aggiorna disponibilità'),
              onTap: () {
                Navigator.of(context).pop();
                _refreshFromRemote();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Panoramica rider'),
              onTap: () async {
                Navigator.of(context).pop();
                await _openRidersOverview();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_suggest_outlined),
              title: const Text('Imposta fabbisogni'),
              onTap: () async {
                Navigator.of(context).pop();
                await _openRequirements();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Pulisci disponibilità'),
              enabled: _hasData,
              onTap: _hasData
                  ? () {
                      Navigator.of(context).pop();
                      _clearAllData();
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: theme.disabledColor.withOpacity(0.12),
        disabledForegroundColor: theme.disabledColor,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _coloredActionButton({
    required BuildContext context,
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    final theme = Theme.of(context);
    final background = disabled
        ? theme.disabledColor.withOpacity(0.2)
        : color;
    final foreground = disabled ? theme.disabledColor : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(
                  icon,
                  color: foreground,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DateTime start) {
    final end = start.add(const Duration(days: 13));
    final df = DateFormat('dd MMM', 'it_IT');
    final employeesCount = _employees.length;
    final uniqueDays = <DateTime>{};
    int totalAvailabilities = 0;
    for (final list in _data.values) {
      totalAvailabilities += list.length;
      for (final day in list) {
        uniqueDays.add(DateTime(day.year, day.month, day.day));
      }
    }
    final theme = Theme.of(context);
    final accentColor = Colors.teal;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.dashboard_customize_outlined,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Panoramica periodo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${df.format(start)} – ${df.format(end)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade700,
                  ) ??
                  TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade700,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.group_outlined,
                  color: Color(0xFF455A64),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$employeesCount rider con disponibilità registrata',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: Color(0xFF455A64),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${uniqueDays.length} giorn${uniqueDays.length == 1 ? 'o' : 'i'} copert${uniqueDays.length == 1 ? 'o' : 'i'} · '
                    '$totalAvailabilities disponibilità totali',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickActionButton(
                  context: context,
                  icon: Icons.refresh,
                  label: 'Aggiorna dati',
                  color: Colors.teal,
                  onPressed: _refreshFromRemote,
                ),
                _buildQuickActionButton(
                  context: context,
                  icon: Icons.people_outline,
                  label: 'Disponibilità rider',
                  color: const Color(0xFF5C6BC0),
                  onPressed: () {
                    _openRidersOverview();
                  },
                ),
                _buildQuickActionButton(
                  context: context,
                  icon: Icons.settings_suggest_outlined,
                  label: 'Imposta fabbisogni',
                  color: Colors.deepOrange,
                  onPressed: () {
                    _openRequirements();
                  },
                ),
                _buildQuickActionButton(
                  context: context,
                  icon: Icons.delete_outline,
                  label: 'Pulisci tutto',
                  color: Colors.redAccent,
                  onPressed: _hasData ? _clearAllData : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 56,
              color: Colors.teal,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nessuna disponibilità ricevuta.\nChiedi ai rider di selezionare i giorni.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refreshFromRemote,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Aggiorna'),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (innerContext) => TextButton.icon(
                onPressed: () {
                  Scaffold.of(innerContext).openDrawer();
                },
                icon: const Icon(Icons.tune),
                label: const Text('Apri impostazioni visualizzazione'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = _periodStart;
    final dfShort = DateFormat('EEE dd', 'it_IT');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Boss — Panoramica"),
        actions: [
          _coloredActionButton(
            context: context,
            tooltip: 'Disponibilità per rider',
            icon: Icons.people_outline,
            color: const Color(0xFF5C6BC0),
            onPressed: () {
              _openRidersOverview();
            },
          ),
          _coloredActionButton(
            context: context,
            tooltip: 'Imposta fabbisogni',
            icon: Icons.settings_suggest_outlined,
            color: Colors.deepOrange,
            onPressed: () {
              _openRequirements();
            },
          ),
          _coloredActionButton(
            context: context,
            tooltip: 'Pulisci tutto',
            icon: Icons.delete_outline,
            color: Colors.redAccent,
            onPressed: _hasData ? _clearAllData : null,
          ),
          _coloredActionButton(
            context: context,
            tooltip: 'Logout',
            icon: Icons.logout,
            color: Colors.blueGrey,
            onPressed: () {
              _performLogout();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _refreshFromRemote,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Riprova'),
                      ),
                    ],
                  ),
                )
              : start == null || !_hasData
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryCard(context, start),
                        if (!_showWeek1 && !_showWeek2)
                          Card(
                            margin: const EdgeInsets.only(top: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.tune,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Seleziona dal menu laterale le settimane da visualizzare.',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_showWeek1)
                          _weekSection(
                            context: context,
                            title: 'Settimana 1',
                            days: List.generate(7, (i) => start.add(Duration(days: i))),
                            dfShort: dfShort,
                          ),
                        if (_showWeek2)
                          _weekSection(
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

  Widget _weekSection({
    required BuildContext context,
    required String title,
    required List<DateTime> days,
    required DateFormat dfShort,
  }) {
    const accentColor = Colors.teal;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final visibleDays = _hideEmptyDays
        ? days.where((d) => _availableCountFor(d) > 0).toList()
        : days;

    if (visibleDays.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(top: 24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nessuna disponibilità per $title con le impostazioni attuali.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final employees = _employees;

    final columns = <DataColumn>[
      const DataColumn(
        label: Text(
          'Rider',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      ...visibleDays.map((d) {
        final req = store.requirementFor(d);
        final avail = _availableCountFor(d);
        final infoColor = !_showRequirementsInfo
            ? theme.hintColor
            : req == 0
                ? theme.hintColor
                : (avail >= req
                    ? accentColor
                    : colorScheme.error);
        return DataColumn(
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dfShort.format(d)),
                if (_showRequirementsInfo)
                  Text(
                    'req $req / avail $avail',
                    style: TextStyle(
                      fontSize: 11,
                      color: infoColor,
                      fontWeight: FontWeight.w600,
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
          ...visibleDays.map((d) {
            final picked = sel.any((x) => sameDay(x, d));
            final iconColor = picked
                ? accentColor
                : colorScheme.error.withOpacity(0.4);
            return DataCell(
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: picked ? accentColor.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
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
      margin: const EdgeInsets.only(top: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.teal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns,
                rows: rows,
                columnSpacing: 32,
                horizontalMargin: 12,
                headingRowHeight: 56,
                dataRowMinHeight: 48,
                showCheckboxColumn: false,
                headingRowColor: MaterialStateProperty.all(
                  accentColor.withOpacity(0.08),
                ),
                dataRowColor: MaterialStateProperty.resolveWith(
                  (states) => Colors.transparent,
                ),
                dividerThickness: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
