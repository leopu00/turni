import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftGenerationConfigResult {
  const ShiftGenerationConfigResult({
    required this.weeks,
    required this.startDate,
    required this.weeklyRequirements,
  });

  final int weeks;
  final DateTime startDate;
  final List<int> weeklyRequirements;
}

class ShiftGenerationConfigPage extends StatefulWidget {
  const ShiftGenerationConfigPage({
    super.key,
    required this.initialWeeks,
    required this.initialStartDate,
    required this.initialWeeklyRequirements,
    required this.availableWeeks,
  });

  final int initialWeeks;
  final DateTime initialStartDate;
  final List<int> initialWeeklyRequirements;
  final List<int> availableWeeks;

  @override
  State<ShiftGenerationConfigPage> createState() =>
      _ShiftGenerationConfigPageState();
}

class _ShiftGenerationConfigPageState extends State<ShiftGenerationConfigPage> {
  static final DateFormat _dayFmt = DateFormat('EEEE dd MMM', 'it_IT');
  static final DateFormat _weekdayFmt = DateFormat('EEEE', 'it_IT');

  late int _weeks;
  late DateTime _startDate;
  late List<int> _weeklyRequirements;

  bool get _hasChanges =>
      _weeks != widget.initialWeeks ||
      !_sameDate(_startDate, widget.initialStartDate) ||
      !_requirementsEqual(
        _weeklyRequirements,
        widget.initialWeeklyRequirements,
      );

  @override
  void initState() {
    super.initState();
    _weeks = widget.initialWeeks;
    _startDate = widget.initialStartDate;
    _weeklyRequirements = List<int>.from(widget.initialWeeklyRequirements);
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _requirementsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

  void _updateRequirement(int index, int delta) {
    setState(() {
      final next = (_weeklyRequirements[index] + delta).clamp(0, 99);
      _weeklyRequirements[index] = next;
    });
  }

  String _weekdayLabelForIndex(int index) {
    final base = DateTime(2024, 1, 1).add(Duration(days: index));
    final raw = _weekdayFmt.format(base);
    return toBeginningOfSentenceCase(raw)!;
  }

  void _submit() {
    Navigator.pop(
      context,
      ShiftGenerationConfigResult(
        weeks: _weeks,
        startDate: _startDate,
        weeklyRequirements: List<int>.from(_weeklyRequirements),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Configura periodo')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          bottomSafe > 0 ? bottomSafe + 16 : 16,
        ),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _weeks,
            decoration: const InputDecoration(
              labelText: 'Numero di settimane',
              border: OutlineInputBorder(),
            ),
            items: widget.availableWeeks
                .map(
                  (w) => DropdownMenuItem(
                    value: w,
                    child: Text('$w settimana${w > 1 ? 'e' : ''}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _weeks = value);
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
            'Suggerimento: scegli un lunedì per allineare le settimane con il planning.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fabbisogno per giorno',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(7, (index) {
                    final label = _weekdayLabelForIndex(index);
                    final value = _weeklyRequirements[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Diminuisci',
                            onPressed: value > 0
                                ? () => _updateRequirement(index, -1)
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
                            onPressed: value < 99
                                ? () => _updateRequirement(index, 1)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _hasChanges ? _submit : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salva configurazione'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
