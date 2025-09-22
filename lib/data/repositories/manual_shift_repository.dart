import 'package:supabase_flutter/supabase_flutter.dart';

class ManualShiftAssignment {
  const ManualShiftAssignment({
    required this.shopId,
    required this.day,
    required this.employeeId,
  });

  final String shopId;
  final DateTime day;
  final String employeeId;
}

class ManualShiftRepository {
  ManualShiftRepository._();

  static final ManualShiftRepository instance = ManualShiftRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> replaceAssignments({
    required String shopId,
    required Map<DateTime, Set<String>> selections,
  }) async {
    await _db.from('manual_shift_assignments').delete().eq('shop_id', shopId);

    final rows = <Map<String, dynamic>>[];
    selections.forEach((day, employees) {
      if (employees.isEmpty) return;
      final normalized = DateTime(day.year, day.month, day.day)
          .toIso8601String()
          .substring(0, 10);
      for (final employeeId in employees) {
        rows.add({
          'shop_id': shopId,
          'employee_id': employeeId,
          'day': normalized,
        });
      }
    });

    if (rows.isNotEmpty) {
      await _db.from('manual_shift_assignments').insert(rows);
    }
  }

  Future<List<ManualShiftAssignment>> fetchAssignmentsForShop(
    String shopId,
  ) async {
    final rows = await _db
        .from('manual_shift_assignments')
        .select('day, employee_id')
        .eq('shop_id', shopId)
        .order('day')
        .order('employee_id');

    return rows
        .map<ManualShiftAssignment>(
          (row) => ManualShiftAssignment(
            shopId: shopId,
            day: DateTime.parse(row['day'] as String),
            employeeId: row['employee_id'] as String,
          ),
        )
        .toList();
  }
}
