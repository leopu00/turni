import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftGenerationPage extends StatefulWidget {
  const ShiftGenerationPage({super.key});

  @override
  State<ShiftGenerationPage> createState() => _ShiftGenerationPageState();
}

class _ShiftGenerationPageState extends State<ShiftGenerationPage> {
  static final DateFormat _weekFmt = DateFormat('dd MMM', 'it_IT');
  static final DateFormat _dayFmt = DateFormat('EEEE dd MMM', 'it_IT');

  final List<int> _availableWeeks = [1, 2, 3, 4];

  late DateTime _startDate;
  List<DateTime> _days = const [];

  int _weeks = 2;
  int _currentWeek = 0;
  int _currentDayIndex = 0;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _startDate = _nextWeekMonday(DateTime.now());
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
      _currentWeek = _currentDayIndex ~/ 7;
    });
  }

  void _goToNextDay() {
    if (_currentDayIndex >= _days.length - 1) return;
    setState(() {
      _currentDayIndex++;
      _currentWeek = _currentDayIndex ~/ 7;
    });
  }

  void _onWeekTapped(int step) {
    setState(() {
      _currentWeek = step;
      _currentDayIndex = step * 7;
    });
  }

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
      _currentWeek = 0;
      _currentDayIndex = 0;
      _configured = true;
    });
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Periodo: ${_weekFmt.format(_startDate)} – ${_weekFmt.format(periodEnd)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weeksLabel,
                    style: Theme.of(context).textTheme.bodySmall,
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
        Expanded(
          child: Stepper(
            type: StepperType.horizontal,
            currentStep: _currentWeek,
            onStepTapped: _onWeekTapped,
            controlsBuilder: (_, __) => const SizedBox.shrink(),
            steps: List.generate(_weeks, (index) {
              final start = _days[index * 7];
              final end = _days[(index + 1) * 7 - 1];
              return Step(
                title: Text('Settimana ${index + 1}'),
                content: _WeekContent(
                  weekLabel: 'Settimana ${index + 1}',
                  start: start,
                  end: end,
                  isActive: _currentWeek == index,
                ),
                isActive: _currentWeek == index,
                state: _currentWeek == index
                    ? StepState.editing
                    : StepState.indexed,
              );
            }),
          ),
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
                  'Qui potrai assegnare manualmente i rider al turno della giornata selezionata. La logica operativa sarà aggiunta in seguito.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back_ios_new),
              label: const Text('Indietro'),
              onPressed: _currentDayIndex > 0 ? _goToPreviousDay : null,
            ),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward_ios),
              label: const Text('Avanti'),
              onPressed: _currentDayIndex < _days.length - 1
                  ? _goToNextDay
                  : null,
            ),
          ],
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
          value: _weeks,
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
          onPressed: _startPlanning,
        ),
      ],
    );
  }
}

class _WeekContent extends StatelessWidget {
  const _WeekContent({
    required this.weekLabel,
    required this.start,
    required this.end,
    required this.isActive,
  });

  final String weekLabel;
  final DateTime start;
  final DateTime end;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final range =
        '${DateFormat('dd MMM', 'it_IT').format(start)} – '
        '${DateFormat('dd MMM', 'it_IT').format(end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(weekLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(range, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(
          isActive
              ? 'Seleziona il giorno da pianificare usando i pulsanti sotto.'
              : 'Tocca lo step per passare a questa settimana.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
