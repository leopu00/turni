import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/manual_shift_repository.dart';
import '../data/repositories/shop_repository.dart';
import '../models/supabase/profile.dart';
import 'manual_shift_results_page.dart';

class ShiftGenerationPage extends StatefulWidget {
  const ShiftGenerationPage({super.key});

  @override
  State<ShiftGenerationPage> createState() => _ShiftGenerationPageState();
}

class _ShiftGenerationPageState extends State<ShiftGenerationPage> {
  static final DateFormat _weekFmt = DateFormat('dd MMM', 'it_IT');
  static final DateFormat _dayFmt = DateFormat('EEEE dd MMM', 'it_IT');
  static final DateFormat _keyFmt = DateFormat('yyyy-MM-dd');

  final List<int> _availableWeeks = [1, 2, 3, 4];

  late DateTime _startDate;
  List<DateTime> _days = const [];

  int _weeks = 2;
  int _currentDayIndex = 0;
  bool _configured = false;

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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('it'),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _startPlanning() {
    setState(() {
      _days = List.generate(
        _weeks * 7,
        (i) => _startDate.add(Duration(days: i)),
      );
      _currentDayIndex = 0;
      _configured = true;
      for (final day in _days) {
        _ensureDayEntry(day);
      }
    });
  }

  void _ensureDayEntry(DateTime day) {
    final key = _dayKey(day);
    _dailySelections.putIfAbsent(key, () => <String>{});
  }

  String _dayKey(DateTime day) => _keyFmt.format(day);

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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ManualShiftResultsPage(),
        ),
      );
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
      body: _configured
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPlanningContent(context),
            )
          : _buildConfigurationForm(context),
    );
  }

  Widget _buildPlanningContent(BuildContext context) {
    if (_days.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () => setState(() => _configured = false),
          icon: const Icon(Icons.settings),
          label: const Text('Configura periodo'),
        ),
      );
    }

    final periodEnd = _days.last;
    final currentDay = _days[_currentDayIndex];
    final weeksLabel = _weeks == 1 ? '1 settimana' : '$_weeks settimane';
    final currentWeek = _currentDayIndex ~/ 7;
    final theme = Theme.of(context);
    final hasShop = _shopId != null;
    final storeLabel = _shopName ?? 'Shop senza nome';

    return Column(
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
                child: Text(
                  storeLabel,
                  style: theme.textTheme.titleMedium,
                ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Periodo: ${_weekFmt.format(_startDate)} – ${_weekFmt.format(periodEnd)}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$weeksLabel · Settimana attuale: ${currentWeek + 1}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _configured = false),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica periodo'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DayNavigator(
          days: _days,
          currentIndex: _currentDayIndex,
          onDaySelected: _setDayIndex,
          enabled: !_saving,
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayFmt.format(currentDay),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Seleziona i dipendenti che copriranno questo giorno. La logica definitiva sarà aggiunta in seguito.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildEmployeeChecklist(currentDay)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back_ios_new),
              label: const Text('Indietro'),
              onPressed:
                  !_saving && _currentDayIndex > 0 ? _goToPreviousDay : null,
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
    );
  }

  Widget _buildConfigurationForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Configura periodo di pianificazione',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _weeks,
          decoration: const InputDecoration(
            labelText: 'Numero di settimane',
            border: OutlineInputBorder(),
          ),
          items: _availableWeeks
              .map(
                (w) => DropdownMenuItem(
                  value: w,
                  child: Text('$w settimana${w > 1 ? 'e' : ''}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _weeks = value);
            }
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Data di inizio'),
            subtitle: Text(_dayFmt.format(_startDate)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _pickStartDate,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Suggerimento: scegli un lunedì per allineare le settimane (default: prossimo lunedì).',
          style: Theme.of(context).textTheme.bodySmall,
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
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

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.days,
    required this.currentIndex,
    required this.onDaySelected,
    this.enabled = true,
  });

  final List<DateTime> days;
  final int currentIndex;
  final ValueChanged<int> onDaySelected;
  final bool enabled;

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
              final baseColor = theme.colorScheme.primary;
              return ChoiceChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayFormatter.format(day).toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      dateFormatter.format(day),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                selected: selected,
                onSelected:
                    enabled ? (_) => onDaySelected(globalIndex) : null,
                selectedColor: baseColor.withAlpha(
                  (baseColor.a * 255 * 0.2).round(),
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
