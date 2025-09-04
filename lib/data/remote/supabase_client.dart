import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  AppSupabase._();
  static final AppSupabase instance = AppSupabase._();

  // TODO: replace with your real project values from Supabase > Project Settings > API
  static const String supabaseUrl = 'TODO_SUPABASE_URL';
  static const String supabaseAnonKey = 'TODO_SUPABASE_ANON_KEY';

  late final SupabaseClient client;

  Future<void> init() async {
    // Guard: avoid crashing until real keys are configured
    if (supabaseUrl.startsWith('TODO_') || supabaseAnonKey.startsWith('TODO_')) {
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    client = Supabase.instance.client;
  }
}