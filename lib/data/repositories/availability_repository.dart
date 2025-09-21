import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/supabase/profile.dart';

class BossAvailabilityResult {
  BossAvailabilityResult({required this.byEmployee, required this.profiles});

  final Map<String, List<DateTime>> byEmployee;
  final Map<String, Profile> profiles;
}

class AvailabilityRepository {
  AvailabilityRepository._();
  static final AvailabilityRepository instance = AvailabilityRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Assicura che esista una riga in `profiles` per l’utente corrente.
  Future<void> ensureProfileRow() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final email = user.email;
    final displayName =
        (user.userMetadata?['full_name'] as String?) ??
        (user.userMetadata?['name'] as String?);
    final existing = await _db
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing == null) {
      await _db.from('profiles').insert({
        'id': user.id,
        if (email != null) 'email': email,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      });
    } else {
      final updateData = <String, dynamic>{};
      if (email != null) updateData['email'] = email;
      if (displayName != null && displayName.trim().isNotEmpty) {
        updateData['display_name'] = displayName.trim();
      }
      if (updateData.isNotEmpty) {
        await _db.from('profiles').update(updateData).eq('id', user.id);
      }
    }
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
    final existingSet = existing
        .map((d) => DateTime.utc(d.year, d.month, d.day))
        .toSet();
    final desiredSet = days
        .map((d) => DateTime.utc(d.year, d.month, d.day))
        .toSet();

    final toInsert = desiredSet.difference(existingSet).toList();
    final toDelete = existingSet.difference(desiredSet).toList();

    // Inserimenti
    if (toInsert.isNotEmpty) {
      final rows = toInsert
          .map(
            (d) => {
              'rider_id': user.id,
              'day': d.toIso8601String().substring(0, 10), // YYYY-MM-DD
            },
          )
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

  /// Per il Boss: disponibilità (email->giorni) + info profilo.
  Future<BossAvailabilityResult> getAllForBoss() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      return BossAvailabilityResult(byEmployee: {}, profiles: {});
    }
    final rows = await _db
        .from('availabilities')
        .select('day, profiles!inner(id,email,username,display_name,role)')
        .order('day');

    final Map<String, List<DateTime>> out = {};
    final Map<String, Profile> profiles = {};
    for (final r in rows) {
      final profileMap = r['profiles'] as Map<String, dynamic>?;
      final email = (profileMap?['email'] as String?) ?? 'unknown';
      final day = DateTime.parse(r['day'] as String);
      out.putIfAbsent(email, () => []).add(day);
      if (profileMap != null && !profiles.containsKey(email)) {
        profiles[email] = Profile.fromMap(profileMap);
      }
    }
    return BossAvailabilityResult(byEmployee: out, profiles: profiles);
  }
}
