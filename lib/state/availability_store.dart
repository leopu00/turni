import 'package:flutter/foundation.dart';

String _key(DateTime d) {
  final dd = DateTime(d.year, d.month, d.day);
  final mm = dd.month.toString().padLeft(2, '0');
  final day = dd.day.toString().padLeft(2, '0');
  return '${dd.year}-$mm-$day';
}

/// In-memory store: disponibilità per più persone (key = employee)
/// + fabbisogni per giorno (quanti rider servono).
class AvailabilityStore extends ChangeNotifier {
  AvailabilityStore._();
  static final AvailabilityStore instance = AvailabilityStore._();

  DateTime? _startMonday;
  final Map<String, List<DateTime>> _byEmployee = {}; // ordinato per dipendente
  final Map<String, int> _requirements = {}; // yyyy-MM-dd -> required riders

  DateTime? get startMonday => _startMonday;
  List<String> get employees => _byEmployee.keys.toList()..sort();

  List<DateTime> selectedFor(String employee) =>
      List.unmodifiable(_byEmployee[employee] ?? const []);

  bool get hasAnySelection => _byEmployee.values.any((l) => l.isNotEmpty);

  void setSelection({
    required String employee,
    required DateTime startMonday,
    required List<DateTime> selectedDays,
  }) {
    _startMonday = DateTime(startMonday.year, startMonday.month, startMonday.day);
    selectedDays.sort();
    _byEmployee[employee] = List<DateTime>.from(selectedDays);
    notifyListeners();
  }

  void clearEmployee(String employee) {
    _byEmployee.remove(employee);
    notifyListeners();
  }

  void clearAll() {
    _startMonday = null;
    _byEmployee.clear();
    _requirements.clear();
    notifyListeners();
  }

  // --- Fabbisogni (Boss) ---
  void setRequirement(DateTime day, int count) {
    _requirements[_key(day)] = count.clamp(0, 99);
    notifyListeners();
  }

  int requirementFor(DateTime day) => _requirements[_key(day)] ?? 0;

  /// Quanti rider risultano disponibili in quella data (contando le selezioni).
  int availableCountFor(DateTime day) {
    final k = _key(day);
    int c = 0;
    for (final list in _byEmployee.values) {
      if (list.any((d) => _key(d) == k)) c++;
    }
    return c;
  }

  /// Restituisce una mappa (data -> req) per un range di `days` giorni dal `start`.
  Map<DateTime, int> requirementsForRange(DateTime start, int days) {
    final out = <DateTime, int>{};
    for (int i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      out[d] = requirementFor(d);
    }
    return out;
  }
}