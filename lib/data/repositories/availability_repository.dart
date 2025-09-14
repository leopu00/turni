import 'package:supabase_flutter/supabase_flutter.dart';

class AvailabilityRepository {
  AvailabilityRepository._();
  static final AvailabilityRepository instance = AvailabilityRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Assicura che esista una riga in `profiles` per l’utente corrente.
  Future<void> ensureProfileRow() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
    }, onConflict: 'id');
  }

  /// Ritorna tutti i giorni (solo data) per l’utente loggato.
  Future<List<DateTime>> getMyDays() async {
    final user = _db.auth.currentUser;
    if (user == null) return [];
    final rows = await _db
        .from('availabilities')
        .select('day')
        .eq('rider_id', user.id)
        .order('day');
    return rows
        .map<DateTime>((r) => DateTime.parse(r['day'] as String))
        .toList();
  }

  /// Salva l’insieme di giorni: inserisce le nuove e cancella quelle rimosse.
  Future<void> setMyDays(Set<DateTime> days) async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    // Giorni già a DB
    final existing = await getMyDays();
    final existingSet =
        existing.map((d) => DateTime.utc(d.year, d.month, d.day)).toSet();
    final desiredSet =
        days.map((d) => DateTime.utc(d.year, d.month, d.day)).toSet();

    final toInsert = desiredSet.difference(existingSet).toList();
    final toDelete = existingSet.difference(desiredSet).toList();

    // Inserimenti
    if (toInsert.isNotEmpty) {
      final rows = toInsert
          .map((d) => {
                'rider_id': user.id,
                'day': d.toIso8601String().substring(0, 10), // YYYY-MM-DD
              })
          .toList();
      await _db.from('availabilities').insert(rows);
    }

    // Cancellazioni
    for (final d in toDelete) {
      await _db
          .from('availabilities')
          .delete()
          .eq('rider_id', user.id)
          .eq('day', d.toIso8601String().substring(0, 10));
    }
  }

  /// Per il Boss: mappa email -> lista di giorni disponibili.
  Future<Map<String, List<DateTime>>> getAllForBoss() async {
    // Join profiles + availabilities
    final rows = await _db
        .from('availabilities')
        .select('day, profiles!inner(email)')
        .order('day');

    final Map<String, List<DateTime>> out = {};
    for (final r in rows) {
      final email = (r['profiles']?['email'] as String?) ?? 'unknown';
      final day = DateTime.parse(r['day'] as String);
      out.putIfAbsent(email, () => []).add(day);
    }
    return out;
  }
}