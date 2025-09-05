import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase bootstrap (client singleton)
///
/// Uses `--dart-define SUPABASE_URL` and `SUPABASE_KEY` when provided at
/// build/run time. Falls back to the in-repo constants below (safe for anon key).
class AppSupabase {
  AppSupabase._();
  static final AppSupabase instance = AppSupabase._();

  // Prefer environment variables when provided
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _envKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: '');

  // Fallback to hardcoded constants (anon public key is OK to commit)
  static const String _constUrl = 'https://skyljinwmetsxvpflark.supabase.co';
  static const String _constKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNreWxqaW53bWV0c3h2cGZsYXJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5ODA1MzgsImV4cCI6MjA3MjU1NjUzOH0.EUCdZo9tcyRxQQ_c56P8e70HKWCeMQrzZI6b-qTaipc';

  String get url => _envUrl.isNotEmpty ? _envUrl : _constUrl;
  String get key => _envKey.isNotEmpty ? _envKey : _constKey;

  SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  bool get isConfigured => url.isNotEmpty && key.isNotEmpty;

  Future<void> init() async {
    if (!isConfigured) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Supabase] Skipped init: missing URL/KEY');
      }
      return;
    }
    await Supabase.initialize(url: url, anonKey: key);
    _client = Supabase.instance.client;
  }
}