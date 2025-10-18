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
  static final DateFormat _weekdayFmt = DateFormat('EEEE', 'it_IT');
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
  String? _shopName;
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
        _shopName = result.shopName;
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

  Future<void> _openRequirementEditor() async {
    if (_requirementsLoading || _requirementsSaving) return;
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final edited = List<int>.from(_weeklyRequirements);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Imposta fabbisogno',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              for (var i = 0; i < edited.length; i++) {
                                edited[i] = _defaultWeeklyRequirements[i];
                              }
                            });
                          },
                          child: const Text('Ripristina default'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Definisci quanti rider servono in ciascun giorno della settimana. I valori si applicano a tutte le settimane del periodo.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: 7,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final label = _weekdayLabelForIndex(index);
                          final value = edited[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              label,
                              style: theme.textTheme.titleMedium,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Diminuisci',
                                  onPressed: value > 0
                                      ? () {
                                          setModalState(() {
                                            edited[index] = value - 1;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '$value',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Aumenta',
                                  onPressed: () {
                                    setModalState(() {
                                      final next = value + 1;
                                      edited[index] = next > 99 ? 99 : next;
                                    });
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Annulla'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context, List<int>.from(edited));
                          },
                          child: const Text('Salva'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      if (result.length != 7) return;
      final previous = List<int>.from(_weeklyRequirements);
      setState(() {
        _weeklyRequirements = List<int>.from(result);
        _requirementsError = null;
        _applyRequirementsToDays();
      });
      await _saveWeeklyRequirements(
        newValues: List<int>.from(result),
        previousValues: previous,
      );
    }
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

  String _weekdayLabelForIndex(int index) {
    final base = DateTime(2024, 1, 1).add(Duration(days: index));
    final raw = _weekdayFmt.format(base);
    return toBeginningOfSentenceCase(raw)!;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generazione turni manuale')),
      body: SafeArea(
        child: _planningStarted
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: _buildPlanningContent(context),
              )
            : _buildPlanningSummary(context),
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
    final hasShop = _shopId != null;
    final storeLabel = _shopName ?? 'Shop senza nome';
    final canEditRequirements =
        hasShop && !_requirementsLoading && !_requirementsSaving && !_saving;
    final selectedCount = _dailySelections[_dayKey(currentDay)]?.length ?? 0;
    final requirement = _requirementFor(currentDay);
    final defaultTextColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    final bool requirementMet =
        requirement == 0 || selectedCount >= requirement;
    final Color highlightColor = requirement == 0
        ? defaultTextColor
        : requirementMet
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final Color backgroundColor = requirement == 0
        ? theme.colorScheme.surfaceVariant.withOpacity(0.25)
        : requirementMet
        ? theme.colorScheme.primary.withOpacity(0.1)
        : theme.colorScheme.error.withOpacity(0.1);
    final int missing = requirement > selectedCount
        ? requirement - selectedCount
        : 0;

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 16 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_saving) const LinearProgressIndicator(),
          if (_saving) const SizedBox(height: 12),
          if (hasShop)
            Row(
              children: [
                Icon(Icons.store_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(storeLabel, style: theme.textTheme.titleMedium),
                ),
              ],
            )
          else
            Text(
              'Nessuno shop associato: non è possibile salvare i turni.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openConfiguration,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica periodo'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: canEditRequirements ? _openRequirementEditor : null,
              icon: const Icon(Icons.tune),
              label: const Text('Modifica fabbisogno'),
            ),
          ),
          const SizedBox(height: 16),
          _DayNavigator(
            days: _days,
            currentIndex: _currentDayIndex,
            onDaySelected: _setDayIndex,
            enabled: !_saving,
            satisfiedIndexes: _satisfiedDayIndexes(),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group_outlined, color: highlightColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                requirement == 0
                                    ? 'Fabbisogno non impostato · Selezionati $selectedCount rider'
                                    : 'Fabbisogno: $selectedCount / $requirement rider',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: highlightColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Visibility(
                          visible: !requirementMet && requirement > 0,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: Text(
                            'Ne mancano $missing.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: highlightColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildEmployeeChecklist(currentDay),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back_ios_new),
                label: const Text('Indietro'),
                onPressed: !_saving && _currentDayIndex > 0
                    ? _goToPreviousDay
                    : null,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward_ios),
                label: const Text('Avanti'),
                onPressed: !_saving && _currentDayIndex < _days.length - 1
                    ? _goToNextDay
                    : null,
              ),
            ],
          ),
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

    final requirementBadges = List<Widget>.generate(7, (index) {
      final label = _weekdayLabelForIndex(index);
      final value = _weeklyRequirements[index];
      return _RequirementBadge(text: '$label: $value');
    });

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
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: requirementBadges),
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

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Text(
          'Dipendenti registrati',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_colleagues.isEmpty)
          Text(
            'Nessun dipendente ha ancora effettuato l\'accesso.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ..._colleagues.map((profile) {
            final label = _labelFor(profile);
            final checked = selected.contains(profile.id);
            return CheckboxListTile(
              value: checked,
              title: Text(label),
              subtitle: Text(profile.email),
              onChanged: _saving
                  ? null
                  : (_) => _toggleEmployeeForDay(key, profile.id),
            );
          }),
        const SizedBox(height: 16),
        Text(
          'Dipendenti da registrare',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_pendingManual.isEmpty)
          Text(
            'Nessun nominativo manuale.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ..._pendingManual.map((employee) {
            final checked = selected.contains(employee.id);
            return CheckboxListTile(
              value: checked,
              title: Text(employee.name),
              subtitle: const Text('Da registrare'),
              onChanged: _saving
                  ? null
                  : (_) => _toggleEmployeeForDay(key, employee.id),
            );
          }),
      ],
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

class _RequirementBadge extends StatelessWidget {
  const _RequirementBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
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

    final theme = Theme.of(context);
    final locale = const Locale('it');
    final dayFormatter = DateFormat('EEE', locale.toLanguageTag());
    final dateFormatter = DateFormat('dd', locale.toLanguageTag());
    final rangeFormatter = DateFormat('dd MMM', locale.toLanguageTag());

    final List<Widget> sections = [];
    final weekCount = (days.length / 7).ceil();
    for (int week = 0; week < weekCount; week++) {
      final start = week * 7;
      final end = ((week + 1) * 7).clamp(0, days.length);
      final weekDays = days.sublist(start, end);

      sections
        ..add(
          Text(
            'Settimana ${week + 1} · ${rangeFormatter.format(weekDays.first)} – ${rangeFormatter.format(weekDays.last)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        ..add(const SizedBox(height: 6))
        ..add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(weekDays.length, (index) {
              final day = weekDays[index];
              final globalIndex = start + index;
              final selected = currentIndex == globalIndex;
              final satisfied = satisfiedIndexes.contains(globalIndex);
              final circleDiameter = 60.0;
              final Color baseBackground;
              final Color baseBorder;
              if (selected) {
                baseBackground = theme.colorScheme.primary;
                baseBorder = theme.colorScheme.primary;
              } else if (satisfied) {
                baseBackground = theme.colorScheme.primary;
                baseBorder = theme.colorScheme.primary;
              } else {
                baseBackground = theme.colorScheme.surfaceVariant;
                baseBorder = theme.dividerColor;
              }
              final Color resolvedTextColor = (selected || satisfied)
                  ? Colors.white
                  : (theme.textTheme.bodyMedium?.color ??
                        theme.colorScheme.onSurface);

              return Tooltip(
                message: DateFormat('EEEE dd MMMM', 'it_IT').format(day),
                child: Material(
                  color: baseBackground,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: baseBorder,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? () => onDaySelected(globalIndex) : null,
                    child: SizedBox(
                      width: circleDiameter,
                      height: circleDiameter,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dayFormatter.format(day).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: resolvedTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormatter.format(day),
                              style: TextStyle(
                                fontSize: 12,
                                color: resolvedTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        )
        ..add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}
