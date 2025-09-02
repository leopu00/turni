import 'package:flutter/foundation.dart';

/// Simple in-memory store to share selected availability
/// between the Employee and Boss pages (no DB for now).
class AvailabilityStore extends ChangeNotifier {
  AvailabilityStore._();
  static final AvailabilityStore instance = AvailabilityStore._();

  DateTime? _startMonday;
  final List<DateTime> _selectedDays = []; // sorted

  DateTime? get startMonday => _startMonday;
  List<DateTime> get selectedDays => List.unmodifiable(_selectedDays);

  /// Set the period (next Monday) and the selected days
  void setSelection({
    required DateTime startMonday,
    required List<DateTime> selectedDays,
  }) {
    _startMonday = DateTime(startMonday.year, startMonday.month, startMonday.day);
    _selectedDays
      ..clear()
      ..addAll(selectedDays..sort());
    notifyListeners();
  }

  void clear() {
    _startMonday = null;
    _selectedDays.clear();
    notifyListeners();
  }

  bool get hasSelection => _selectedDays.isNotEmpty;
}