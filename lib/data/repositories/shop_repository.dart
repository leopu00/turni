import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/supabase/profile.dart';

class ShopColleaguesResult {
  const ShopColleaguesResult({
    required this.shopId,
    required this.shopName,
    required this.colleagues,
  });

  final String? shopId;
  final String? shopName;
  final List<Profile> colleagues;

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
    return ShopColleaguesResult(
      shopId: shopId,
      shopName: shopName,
      colleagues: colleagues,
    );
  }
}
