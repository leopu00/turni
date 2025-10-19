import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/manual_shift_repository.dart';
import '../data/repositories/shop_repository.dart';
import '../data/repositories/weekly_requirements_repository.dart';
import '../models/supabase/profile.dart';
import 'manual_shift_results_page.dart';
import 'shift_generation_config_page.dart';

class ShiftGenerationPage extends StatefulWidget {
  const ShiftGenerationPage({super.key});

  @override
  State<ShiftGenerationPage> createState() => _ShiftGenerationPageState();
}

class _ShiftGenerationPageState extends State<ShiftGenerationPage> {
  static final DateFormat _dayFmt = DateFormat('EEEE dd MMM', 'it_IT');
  static final DateFormat _keyFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat _fullDayLabelFmt = DateFormat('EEEE d MMMM', 'it_IT');
  static final DateFormat _buttonDayFmt = DateFormat('EEEE d', 'it_IT');
  static const List<int> _defaultWeeklyRequirements = [4, 4, 4, 5, 5, 6, 6];

  final List<int> _availableWeeks = [1, 2, 3, 4];

  late DateTime _startDate;
  List<DateTime> _days = const [];
  late List<int> _weeklyRequirements;
  final Map<String, int> _requirementsByDay = {};
  bool _requirementsLoading = false;
  bool _requirementsSaving = false;
  String? _requirementsError;

  int _weeks = 2;
  int _currentDayIndex = 0;
  bool _planningStarted = false;

  List<Profile> _colleagues = const [];
  List<PendingEmployee> _pendingManual = const [];
  bool _loadingColleagues = false;
  String? _colleaguesError;
  String? _shopId;
  bool _saving = false;
  String? _saveError;
  final Map<String, Set<String>> _dailySelections = {};

  @override
  void initState() {
    super.initState();
    _startDate = _nextWeekMonday(DateTime.now());
    _weeklyRequirements = List<int>.from(_defaultWeeklyRequirements);
    _loadColleagues();
  }

  Future<void> _loadColleagues() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    setState(() {
      _loadingColleagues = true;
      _colleaguesError = null;
    });
    try {
      final result = await ShopRepository.instance
          .fetchColleaguesForCurrentUser();
      final filtered = result.colleagues
          .where((p) => p.role != 'boss' || p.id == currentUserId)
          .toList();
      final pendingManual = [...result.pending]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _colleagues = filtered;
        _pendingManual = pendingManual;
        _shopId = result.shopId;
        _loadingColleagues = false;
      });
      if (!mounted) return;
      final shopId = result.shopId;
      if (shopId != null) {
        await _loadWeeklyRequirements(shopId);
      } else {
        setState(() {
          _requirementsError = null;
          _requirementsByDay.clear();
        });
      }
    } catch (e) {
      setState(() {
        _colleaguesError = e.toString();
        _loadingColleagues = false;
      });
    }
  }

  DateTime _nextWeekMonday(DateTime from) {
    final normalized = DateTime(from.year, from.month, from.day);
    final diff = (DateTime.monday - normalized.weekday + 7) % 7;
    final delta = diff == 0 ? 7 : diff;
    return normalized.add(Duration(days: delta));
  }

  void _goToPreviousDay() {
    if (_currentDayIndex == 0) return;
    setState(() {
      _currentDayIndex--;
    });
  }

  void _goToNextDay() {
    if (_currentDayIndex >= _days.length - 1) return;
    setState(() {
      _currentDayIndex++;
    });
  }

  void _setDayIndex(int index) => setState(() => _currentDayIndex = index);

  Future<void> _loadWeeklyRequirements(String shopId) async {
    setState(() {
      _requirementsLoading = true;
      _requirementsError = null;
    });
    try {
      final values = await WeeklyRequirementsRepository.instance.fetchForShop(
        shopId,
      );
      if (!mounted) return;
      setState(() {
        _requirementsLoading = false;
        if (values != null && values.length == 7) {
          _weeklyRequirements = List<int>.from(values);
        }
        _applyRequirementsToDays();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requirementsLoading = false;
        _requirementsError = 'Errore nel caricamento del fabbisogno: $e';
      });
    }
  }

  Future<void> _saveWeeklyRequirements({
    required List<int> newValues,
    required List<int> previousValues,
  }) async {
    final shopId = _shopId;
    if (shopId == null) return;
    setState(() {
      _requirementsSaving = true;
      _requirementsError = null;
    });
    try {
      await WeeklyRequirementsRepository.instance.upsertForShop(
        shopId: shopId,
        requirements: newValues,
      );
      if (!mounted) return;
      setState(() {
        _requirementsSaving = false;
      });
      _showSnack('Fabbisogno salvato');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requirementsSaving = false;
        _weeklyRequirements = List<int>.from(previousValues);
        _applyRequirementsToDays();
        _requirementsError = 'Errore nel salvataggio del fabbisogno: $e';
      });
      _showSnack('Salvataggio del fabbisogno non riuscito');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startPlanning() {
    final weeks = _weeks <= 0 ? 1 : _weeks;
    final totalDays = weeks * 7;
    final startLocal = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final startUtc = DateTime.utc(
      startLocal.year,
      startLocal.month,
      startLocal.day,
    );
    final generatedDays = List.generate(totalDays, (i) {
      final utcDay = startUtc.add(Duration(days: i));
      return DateTime(utcDay.year, utcDay.month, utcDay.day);
    });
    final validKeys = generatedDays.map(_dayKey).toSet();

    setState(() {
      _days = generatedDays;
      _currentDayIndex = 0;
      _planningStarted = true;
      _dailySelections.removeWhere((key, _) => !validKeys.contains(key));
      for (final day in generatedDays) {
        _ensureDayEntry(day);
      }
      _applyRequirementsToDays();
    });
  }

  Future<void> _openConfiguration() async {
    final result = await Navigator.push<ShiftGenerationConfigResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftGenerationConfigPage(
          initialWeeks: _weeks,
          initialStartDate: _startDate,
          initialWeeklyRequirements: List<int>.from(_weeklyRequirements),
          availableWeeks: _availableWeeks,
        ),
      ),
    );

    if (result == null) return;

    final previousRequirements = List<int>.from(_weeklyRequirements);

    setState(() {
      _weeks = result.weeks;
      _startDate = result.startDate;
      _weeklyRequirements = List<int>.from(result.weeklyRequirements);
      _planningStarted = false;
      _days = const [];
      _currentDayIndex = 0;
      _requirementsError = null;
      _applyRequirementsToDays();
    });

    if (!_weeklyRequirementsEquals(
      previousRequirements,
      result.weeklyRequirements,
    )) {
      await _saveWeeklyRequirements(
        newValues: List<int>.from(result.weeklyRequirements),
        previousValues: previousRequirements,
      );
    }
  }

  bool _weeklyRequirementsEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _ensureDayEntry(DateTime day) {
    final key = _dayKey(day);
    _dailySelections.putIfAbsent(key, () => <String>{});
  }

  String _dayKey(DateTime day) => _keyFmt.format(day);

  int _weekdayIndex(int weekday) => (weekday - DateTime.monday) % 7;

  void _applyRequirementsToDays() {
    if (_days.isEmpty) {
      _requirementsByDay.clear();
      return;
    }
    final updated = <String, int>{};
    for (final day in _days) {
      final key = _dayKey(day);
      updated[key] = _weeklyRequirements[_weekdayIndex(day.weekday)];
    }
    _requirementsByDay
      ..clear()
      ..addAll(updated);
  }

  int _requirementFor(DateTime day) {
    final key = _dayKey(day);
    return _requirementsByDay[key] ??
        _weeklyRequirements[_weekdayIndex(day.weekday)];
  }

  String _selectionSummaryLabel(int selectedCount, int requirement) {
    if (requirement <= 0) {
      return selectedCount == 1 ? '1 rider' : '$selectedCount rider';
    }
    final String selectedLabel = selectedCount == 1 ? '1' : '$selectedCount';
    final String requirementLabel = requirement == 1
        ? '1 rider'
        : '$requirement rider';
    return '$selectedLabel su $requirementLabel';
  }

  Future<void> _generateShifts() async {
    if (_days.isEmpty) {
      setState(() {
        _saveError = 'Configura un periodo prima di generare i turni.';
      });
      return;
    }

    final shopId = _shopId;
    if (shopId == null) {
      setState(() {
        _saveError =
            'Per generare i turni devi essere associato ad almeno uno shop.';
      });
      return;
    }

    final selections = <DateTime, Set<String>>{};
    for (final day in _days) {
      final employees = _dailySelections[_dayKey(day)];
      if (employees == null || employees.isEmpty) continue;
      selections[DateTime(day.year, day.month, day.day)] = Set.of(employees);
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await ManualShiftRepository.instance.replaceAssignments(
        shopId: shopId,
        selections: selections,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      if (!mounted) return;
      final result = await Navigator.push<ManualShiftResultsExit>(
        context,
        MaterialPageRoute(
          builder: (_) => const ManualShiftResultsPage(allowModify: true),
        ),
      );
      if (!mounted) return;
      if (result == ManualShiftResultsExit.goHome) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Errore nel salvataggio: $e';
      });
    }
  }

  bool _handleInPageBack() {
    if (_planningStarted) {
      setState(() {
        _planningStarted = false;
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_handleInPageBack()) {
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!_handleInPageBack()) {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: const Text('Generazione turni manuale'),
        ),
        body: SafeArea(
          child: _planningStarted
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPlanningContent(context),
                )
              : _buildPlanningSummary(context),
        ),
      ),
    );
  }

  Widget _buildPlanningContent(BuildContext context) {
    if (_days.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () => setState(() {
            _planningStarted = false;
          }),
          icon: const Icon(Icons.settings),
          label: const Text('Configura periodo'),
        ),
      );
    }

    final currentDay = _days[_currentDayIndex];
    final theme = Theme.of(context);
    final selectedCount = _dailySelections[_dayKey(currentDay)]?.length ?? 0;
    final requirement = _requirementFor(currentDay);
    final defaultTextColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    final bool requirementMatched =
        requirement > 0 && selectedCount == requirement;
    final Color highlightColor = requirementMatched
        ? theme.colorScheme.primary
        : defaultTextColor;
    final Color bannerColor = requirementMatched
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final IconData statusIcon = requirementMatched
        ? Icons.check_circle_outline
        : Icons.timelapse_outlined;
    final double statusOpacity = requirementMatched ? 1 : 0.15;
    final String dayLabel =
        toBeginningOfSentenceCase(_fullDayLabelFmt.format(currentDay)) ??
        _fullDayLabelFmt.format(currentDay);
    final String selectionSummary = _selectionSummaryLabel(
      selectedCount,
      requirement,
    );
    final String infoText = '$dayLabel · $selectionSummary';

    final bool hasPreviousDay = _currentDayIndex > 0;
    final bool hasNextDay = _currentDayIndex < _days.length - 1;
    final String? previousDayLabel = hasPreviousDay
        ? _formatButtonDay(_days[_currentDayIndex - 1])
        : null;
    final String? nextDayLabel = hasNextDay
        ? _formatButtonDay(_days[_currentDayIndex + 1])
        : null;

    final weeks = _weeks <= 0 ? 1 : _weeks;
    final totalDays = weeks * 7;
    final periodStart = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final periodEndUtc = DateTime.utc(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    ).add(Duration(days: totalDays - 1));
    final periodEnd = DateTime(
      periodEndUtc.year,
      periodEndUtc.month,
      periodEndUtc.day,
    );
    final displayStart = _days.isNotEmpty ? _days.first : periodStart;
    final displayEnd = _days.isNotEmpty ? _days.last : periodEnd;
    final periodLabel =
        '${DateFormat('dd MMM', 'it_IT').format(displayStart)} – '
        '${DateFormat('dd MMM', 'it_IT').format(displayEnd)}';

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_saving || _requirementsLoading || _requirementsSaving) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(Icons.group_outlined, color: highlightColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      infoText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: highlightColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: statusOpacity,
                    child: Icon(statusIcon, color: highlightColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: (bottomInset > 0 ? bottomInset : 0) + 112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            periodLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openConfiguration,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Modifica'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DayNavigator(
                      days: _days,
                      currentIndex: _currentDayIndex,
                      onDaySelected: _setDayIndex,
                      enabled: !_saving,
                      satisfiedIndexes: _satisfiedDayIndexes(),
                    ),
                    const SizedBox(height: 16),
                    _buildEmployeeChecklist(currentDay),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.task_alt_outlined),
                        label: const Text('Genera turni'),
                        onPressed: _saving || _shopId == null
                            ? null
                            : () {
                                _generateShifts();
                              },
                      ),
                    ),
                    if (_saveError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _saveError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: !_saving && hasPreviousDay
                                    ? _goToPreviousDay
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Text(
                                          previousDayLabel ?? '—',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: !_saving && hasNextDay
                                    ? _goToNextDay
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Text(
                                          nextDayLabel ?? '—',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontSize: 13,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanningSummary(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final weeks = _weeks <= 0 ? 1 : _weeks;
    final totalDays = weeks * 7;

    final startLocal = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final utcStart = DateTime.utc(
      startLocal.year,
      startLocal.month,
      startLocal.day,
    );
    final utcEnd = utcStart.add(Duration(days: totalDays - 1));
    final endLocal = DateTime(utcEnd.year, utcEnd.month, utcEnd.day);

    final rangeFormatter = DateFormat('EEE dd MMM', 'it_IT');
    final periodText =
        '${rangeFormatter.format(startLocal)} – ${rangeFormatter.format(endLocal)}';

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        bottomSafe > 0 ? bottomSafe + 16 : 16,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Periodo di pianificazione',
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Modifica configurazione',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _openConfiguration,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Numero settimane',
                  value: '$weeks',
                ),
                _SummaryRow(
                  icon: Icons.event_outlined,
                  label: 'Data di inizio',
                  value: _dayFmt.format(startLocal),
                ),
                _SummaryRow(
                  icon: Icons.flag_outlined,
                  label: 'Data di fine',
                  value: _dayFmt.format(endLocal),
                ),
                _SummaryRow(
                  icon: Icons.schedule_outlined,
                  label: 'Range coperto',
                  value: periodText,
                ),
                const SizedBox(height: 16),
                Text(
                  'Fabbisogno settimanale',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _WeeklyRequirementPreview(requirements: _weeklyRequirements),
                if (_requirementsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _requirementsError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Inizia pianificazione'),
          onPressed: _loadingColleagues ? null : _startPlanning,
        ),
        if (_loadingColleagues)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_colleaguesError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Errore caricando i dipendenti: $_colleaguesError',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  Set<int> _satisfiedDayIndexes() {
    final indexes = <int>{};
    for (var i = 0; i < _days.length; i++) {
      final day = _days[i];
      final requirement = _requirementFor(day);
      if (requirement <= 0) continue;
      final selected = _dailySelections[_dayKey(day)]?.length ?? 0;
      if (selected >= requirement) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  Widget _buildEmployeeChecklist(DateTime day) {
    if (_loadingColleagues) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_colleaguesError != null) {
      return Center(
        child: Text(
          'Errore nel recupero dei dipendenti: $_colleaguesError',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_colleagues.isEmpty) {
      return Center(
        child: Text(
          'Nessun dipendente associato al tuo shop.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final key = _dayKey(day);
    final selected = _dailySelections[key] ?? <String>{};

    final combinedEmployees = <_EmployeeOption>[
      ..._colleagues.map(
        (profile) => _EmployeeOption(id: profile.id, name: _labelFor(profile)),
      ),
      ..._pendingManual.map(
        (employee) =>
            _EmployeeOption(id: employee.id, name: _pendingLabelFor(employee)),
      ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (combinedEmployees.isEmpty) {
      return Center(
        child: Text(
          'Nessun dipendente associato al tuo shop.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: combinedEmployees.map((employee) {
        final checked = selected.contains(employee.id);
        return CheckboxListTile(
          value: checked,
          title: Text(employee.name),
          onChanged: _saving
              ? null
              : (_) => _toggleEmployeeForDay(key, employee.id),
        );
      }).toList(),
    );
  }

  void _toggleEmployeeForDay(String key, String employeeId) {
    if (_saving) return;
    setState(() {
      final set = _dailySelections.putIfAbsent(key, () => <String>{});
      if (!set.add(employeeId)) {
        set.remove(employeeId);
      }
    });
  }

  String _labelFor(Profile profile) {
    final display = profile.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final username = profile.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    return profile.email;
  }

  String _pendingLabelFor(PendingEmployee employee) {
    final name = employee.name.trim();
    if (name.isNotEmpty) return name;
    return employee.name;
  }

  String _formatButtonDay(DateTime day) {
    final raw = _buttonDayFmt.format(day);
    return toBeginningOfSentenceCase(raw) ?? raw;
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyRequirementPreview extends StatelessWidget {
  const _WeeklyRequirementPreview({required this.requirements});

  final List<int> requirements;

  @override
  Widget build(BuildContext context) {
    if (requirements.isEmpty) return const SizedBox.shrink();

    const locale = Locale('it');
    final dayFormatter = DateFormat('EEE', locale.toLanguageTag());
    final baseMonday = DateTime(2024, 1, 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 8.0;
        final count = requirements.length;
        final availableWidth = constraints.maxWidth;
        final totalSpacing = spacing * (count - 1);
        double diameter = (availableWidth - totalSpacing) / count;
        if (!diameter.isFinite) {
          diameter = 0;
        }

        final double maxDiameter;
        if (availableWidth >= 720) {
          maxDiameter = 70;
        } else if (availableWidth >= 520) {
          maxDiameter = 62;
        } else {
          maxDiameter = 55;
        }
        if (diameter > maxDiameter) {
          diameter = maxDiameter;
        }
        if (diameter <= 0) {
          final fallback = count == 0 ? 0 : (availableWidth / count);
          diameter = fallback.clamp(32.0, maxDiameter).toDouble();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(count, (index) {
            final label = dayFormatter
                .format(baseMonday.add(Duration(days: index)))
                .toUpperCase();
            final requirement = requirements[index];
            return Padding(
              padding: EdgeInsets.only(right: index == count - 1 ? 0 : spacing),
              child: _RequirementCircle(
                dayLabel: label,
                requirement: requirement,
                diameter: diameter,
              ),
            );
          }),
        );
      },
    );
  }
}

class _RequirementCircle extends StatelessWidget {
  const _RequirementCircle({
    required this.dayLabel,
    required this.requirement,
    required this.diameter,
  });

  final String dayLabel;
  final int requirement;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ridersText = requirement == 1 ? '1 rider' : '$requirement rider';
    final tooltipLabel =
        '${toBeginningOfSentenceCase(dayLabel.toLowerCase())}: $ridersText';

    return Tooltip(
      message: tooltipLabel,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: scheme.outline.withOpacity(0.5), width: 1),
        ),
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: scheme.surfaceContainerHighest,
              shadows: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: diameter * 0.2,
                      color:
                          theme.textTheme.bodyMedium?.color ??
                          scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: diameter * 0.22,
                      vertical: diameter * 0.06,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: scheme.primary.withOpacity(0.12),
                    ),
                    child: Text(
                      '$requirement',
                      style: TextStyle(
                        fontSize: diameter * 0.22,
                        letterSpacing: 0.3,
                        color:
                            theme.textTheme.bodyMedium?.color ??
                            scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeOption {
  const _EmployeeOption({required this.id, required this.name});

  final String id;
  final String name;
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.days,
    required this.currentIndex,
    required this.onDaySelected,
    this.enabled = true,
    this.satisfiedIndexes = const <int>{},
  });

  final List<DateTime> days;
  final int currentIndex;
  final ValueChanged<int> onDaySelected;
  final bool enabled;
  final Set<int> satisfiedIndexes;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final locale = const Locale('it');
    final dayFormatter = DateFormat('EEE', locale.toLanguageTag());
    final dateFormatter = DateFormat('dd', locale.toLanguageTag());

    final List<Widget> sections = [];
    final weekCount = (days.length / 7).ceil();
    for (int week = 0; week < weekCount; week++) {
      final start = week * 7;
      final end = ((week + 1) * 7).clamp(0, days.length);
      final weekDays = days.sublist(start, end);

      sections.add(
        Padding(
          padding: EdgeInsets.only(bottom: week == weekCount - 1 ? 0 : 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double baseSpacing = 8.0;
              final count = weekDays.length;
              if (count == 0) return const SizedBox.shrink();

              final availableWidth = constraints.maxWidth;
              final totalSpacing = baseSpacing * (count - 1);
              double itemSize = (availableWidth - totalSpacing) / count;

              if (!itemSize.isFinite) {
                itemSize = 0;
              }

              // Cap the circle diameter on wider layouts to keep a consistent look.
              final double maxDiameter;
              if (availableWidth >= 720) {
                maxDiameter = 70;
              } else if (availableWidth >= 520) {
                maxDiameter = 62;
              } else {
                maxDiameter = 55;
              }

              double diameter = itemSize;
              if (diameter > maxDiameter) {
                diameter = maxDiameter;
              }

              if (diameter <= 0) {
                final fallback = count == 0 ? 0 : (availableWidth / count);
                diameter = fallback.clamp(0, maxDiameter).toDouble();
              }

              final children = <Widget>[];
              for (var index = 0; index < count; index++) {
                final day = weekDays[index];
                final globalIndex = start + index;
                final selected = currentIndex == globalIndex;
                final satisfied = satisfiedIndexes.contains(globalIndex);
                if (index > 0) {
                  children.add(SizedBox(width: baseSpacing));
                }
                children.add(
                  _buildDayCircle(
                    context: context,
                    dayFormatter: dayFormatter,
                    dateFormatter: dateFormatter,
                    day: day,
                    diameter: diameter,
                    selected: selected,
                    satisfied: satisfied,
                    enabled: enabled,
                    onTap: () => onDaySelected(globalIndex),
                  ),
                );
              }

              return Align(
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: children),
              );
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}

Widget _buildDayCircle({
  required BuildContext context,
  required DateFormat dayFormatter,
  required DateFormat dateFormatter,
  required DateTime day,
  required double diameter,
  required bool selected,
  required bool satisfied,
  required bool enabled,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final ColorScheme scheme = theme.colorScheme;

  final BorderSide borderSide;
  final Gradient? gradient;
  final Color textColor;

  if (selected) {
    borderSide = BorderSide(color: scheme.primary, width: 2);
    gradient = LinearGradient(
      colors: [scheme.primary, scheme.primary.withOpacity(0.75)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    textColor = scheme.onPrimary;
  } else if (satisfied) {
    borderSide = BorderSide(color: scheme.secondary, width: 1.4);
    gradient = LinearGradient(
      colors: [
        scheme.secondaryContainer,
        scheme.secondaryContainer.withOpacity(0.9),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    textColor = scheme.onSecondaryContainer;
  } else {
    borderSide = BorderSide(color: scheme.outline.withOpacity(0.5), width: 1);
    gradient = null;
    textColor = theme.textTheme.bodyMedium?.color ?? scheme.onSurfaceVariant;
  }

  return Tooltip(
    message: DateFormat('EEEE dd MMMM', 'it_IT').format(day),
    child: Material(
      color: Colors.transparent,
      shape: CircleBorder(side: borderSide),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              gradient: gradient,
              color: gradient == null ? scheme.surfaceVariant : null,
              shadows: selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : satisfied
                  ? [
                      BoxShadow(
                        color: scheme.secondary.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayFormatter.format(day).toUpperCase(),
                    style: TextStyle(
                      fontSize: diameter * 0.2,
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: diameter * 0.22,
                      vertical: diameter * 0.06,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: textColor.withOpacity(selected ? 0.22 : 0.14),
                    ),
                    child: Text(
                      dateFormatter.format(day),
                      style: TextStyle(
                        fontSize: diameter * 0.22,
                        letterSpacing: 0.3,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
