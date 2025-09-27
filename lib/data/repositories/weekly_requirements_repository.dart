import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklyRequirementsRepository {
  WeeklyRequirementsRepository._();

  static final WeeklyRequirementsRepository instance =
      WeeklyRequirementsRepository._();

  static const List<String> _weekdayColumns = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<int>?> fetchForShop(String shopId) async {
    final row = await _db
        .from('shop_weekly_requirements')
        .select(_weekdayColumns.join(', '))
        .eq('shop_id', shopId)
        .maybeSingle();

    if (row == null) return null;
    return _weekdayColumns
        .map<int>((column) {
          final value = row[column];
          if (value is num) {
            return value.clamp(0, 99).toInt();
          }
          return 0;
        })
        .toList(growable: false);
  }

  Future<void> upsertForShop({
    required String shopId,
    required List<int> requirements,
  }) async {
    if (requirements.length != _weekdayColumns.length) {
      throw ArgumentError(
        'Expected ${_weekdayColumns.length} values, received ${requirements.length}.',
      );
    }

    final payload = <String, dynamic>{'shop_id': shopId};
    for (var i = 0; i < _weekdayColumns.length; i++) {
      final value = requirements[i].clamp(0, 99).toInt();
      payload[_weekdayColumns[i]] = value;
    }

    await _db.from('shop_weekly_requirements').upsert(payload);
  }
}
