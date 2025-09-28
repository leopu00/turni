import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../remote/supabase_client.dart';
import '../../models/supabase/profile.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();
  SupabaseClient get _sb => AppSupabase.instance.client;

  Future<AuthResponse> signUpEmail({
    required String email,
    required String password,
    String? username,
    String role = 'employee', // default
  }) async {
    final res = await _sb.auth.signUp(email: email, password: password,
      data: {'username': username, 'role': role});
    // Crea/aggiorna profilo (id = auth.user.id)
    final user = res.user;
    if (user != null) {
      await upsertProfile(Profile(
        id: user.id,
        email: user.email ?? email,
        username: username ?? user.userMetadata?['username'],
        role: (user.userMetadata?['role'] as String?) ?? role,
      ));
    }
    return res; // email verifica inviata se configurata in Supabase
  }

  Future<AuthResponse> signInEmail({
    required String email,
    required String password,
  }) => _sb.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _sb.auth.signOut();

  Future<void> signInWithGoogle() async {
    final redirect =
        kIsWeb ? Uri.base.origin : 'me.iturni.app://login-callback';
    await _sb.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirect,
    );
  }

  User? get currentUser => _sb.auth.currentUser;

  Future<Profile?> getProfile() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return null;
    final res = await _sb.from('profiles').select().eq('id', uid).limit(1);
    if (res.isEmpty) return null;
    return Profile.fromMap(res.first as Map<String, dynamic>);
  }

  Future<void> upsertProfile(Profile p) async {
    await _sb.from('profiles').upsert(p.toMap()).select().limit(1);
  }
}
