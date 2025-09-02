import 'package:flutter/foundation.dart';

/// In-memory store: disponibilità per più persone (key = employee)
class AvailabilityStore extends ChangeNotifier {
  AvailabilityStore._();
  static final AvailabilityStore instance = AvailabilityStore._();

  DateTime? _startMonday;
  final Map<String, List<DateTime>> _byEmployee = {}; // ordinato per dipendente

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
    notifyListeners();
  }
}