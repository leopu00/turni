import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/supabase/profile.dart';

class PendingEmployee {
  const PendingEmployee({
    required this.id,
    required this.shopId,
    required this.name,
  });

  final String id;
  final String shopId;
  final String name;
}

class ShopColleaguesResult {
  const ShopColleaguesResult({
    required this.shopId,
    required this.shopName,
    required this.colleagues,
    required this.pending,
  });

  final String? shopId;
  final String? shopName;
  final List<Profile> colleagues;
  final List<PendingEmployee> pending;

  bool get hasShop => shopId != null;
}

class ShopRepository {
  ShopRepository._();
  static final ShopRepository instance = ShopRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<ShopColleaguesResult> fetchColleaguesForCurrentUser() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      return const ShopColleaguesResult(
        shopId: null,
        shopName: null,
        colleagues: [],
        pending: [],
      );
    }

    final assignment = await _db
        .from('profile_shops')
        .select('shop_id')
        .eq('profile_id', user.id)
        .maybeSingle();

    final shopId = assignment == null ? null : assignment['shop_id'] as String?;
    if (shopId == null) {
      return const ShopColleaguesResult(
        shopId: null,
        shopName: null,
        colleagues: [],
        pending: [],
      );
    }

    final shopRow = await _db
        .from('shops')
        .select('name')
        .eq('id', shopId)
        .maybeSingle();
    final shopName = shopRow == null ? null : shopRow['name'] as String?;

    final data = await _db
        .from('profile_shops')
        .select('profiles(id,email,username,display_name,role)')
        .eq('shop_id', shopId);

    final colleagues = <Profile>[];
    for (final row in data) {
      final profileMap = row['profiles'] as Map<String, dynamic>?;
      if (profileMap == null) continue;
      colleagues.add(Profile.fromMap(profileMap));
    }

    // Ordina per display name (fallback email) per una lista prevedibile.
    colleagues.sort(
      (a, b) => (a.displayName ?? a.email).toLowerCase().compareTo(
        (b.displayName ?? b.email).toLowerCase(),
      ),
    );
    final pendingRows = await _db
        .from('shop_pending_employees')
        .select('id, name, shop_id')
        .eq('shop_id', shopId)
        .order('created_at');

    final pending = pendingRows
        .map<PendingEmployee>(
          (row) => PendingEmployee(
            id: row['id'] as String,
            shopId: row['shop_id'] as String,
            name: row['name'] as String,
          ),
        )
        .toList();

    return ShopColleaguesResult(
      shopId: shopId,
      shopName: shopName,
      colleagues: colleagues,
      pending: pending,
    );
  }

  Future<PendingEmployee> addPendingEmployee({
    required String shopId,
    required String name,
  }) async {
    final rows = await _db
        .from('shop_pending_employees')
        .insert({'shop_id': shopId, 'name': name})
        .select('id, name, shop_id')
        .single();

    return PendingEmployee(
      id: rows['id'] as String,
      shopId: rows['shop_id'] as String,
      name: rows['name'] as String,
    );
  }

  Future<void> deletePendingEmployee(String id) async {
    await _db.from('shop_pending_employees').delete().eq('id', id);
  }

  Future<void> removeEmployeeFromShop({
    required String shopId,
    required String profileId,
  }) async {
    await _db
        .from('profile_shops')
        .delete()
        .eq('shop_id', shopId)
        .eq('profile_id', profileId);
  }
}
