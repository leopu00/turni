import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../data/repositories/availability_repository.dart';
import '../state/availability_store.dart';
import '../state/session_store.dart';
import 'boss_page.dart';

import 'employee_home_page.dart';
import 'sign_up_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.fromLogout = false});
  final bool fromLogout;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final session = SessionStore.instance;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  StreamSubscription<AuthState>? _authSub;

  Future<void> _hydrateAvailability(String employeeIdentifier) async {
    if (employeeIdentifier.isEmpty) return;
    try {
      await AvailabilityRepository.instance.ensureProfileRow();
      final days = await AvailabilityRepository.instance.getMyDays();
      AvailabilityStore.instance.hydrateFromRemote(
        employee: employeeIdentifier,
        days: days,
      );
    } catch (_) {}
  }

  Future<void> _hydrateBossAvailability() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      await AvailabilityRepository.instance.ensureProfileRow();
      final all = await AvailabilityRepository.instance.getAllForBoss();
      AvailabilityStore.instance.hydrateAllForBoss(all);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // If already signed-in (e.g., after Google OAuth on web), route immediately
    final current = Supabase.instance.client.auth.currentSession;
    if (current != null && !widget.fromLogout) {
      _navigateByRole(current);
    }
    // Listen for future auth state changes (e.g., OAuth callback)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final authSession = data.session;
      if (authSession != null) {
        _navigateByRole(authSession);
      }
    });
  }

  Future<void> _signUpEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final email = _userCtrl.text.trim();
    final password = _passCtrl.text;
    try {
      // Se Supabase non è inizializzato lancerà/mostrerà errore
      final client = Supabase.instance.client;
      await client.auth.signUp(email: email, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign up successful. Check your email to verify your account.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _navigateByRole(Session authSession) async {
    var role = 'employee';
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', authSession.user.id)
          .limit(1);
      if (res.isNotEmpty) {
        role = (res.first['role'] as String?) ?? 'employee';
      }
    } catch (_) {
      // If profiles table/policies not ready, default to employee
    }

    if (!mounted) return;
    if (role == 'boss') {
      await _hydrateBossAvailability();
      if (!mounted) return;
      session.loginBoss();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BossPage()),
      );
    } else {
      final email = authSession.user.email ?? '';
      await _hydrateAvailability(email);
      if (!mounted) return;
      session.loginEmployee(email);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmployeeHomePage()),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _submitting = true);
    try {
      final client = Supabase.instance.client;
      // Su Web forziamo il redirect all'origin corrente (es. http://localhost:<porta>)
      final redirectUrl = kIsWeb ? Uri.base.origin : null;
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      // Su Web: dopo l'OAuth si torna all'origin e Supabase ripristina la sessione.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Sign-In error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final userInput = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (!userInput.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un indirizzo email valido.')),
      );
      setState(() => _submitting = false);
      return;
    }

    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(
        email: userInput,
        password: password,
      );

      // Leggi ruolo dal profilo (se non c'è, default employee)
      var role = 'employee';
      try {
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          final res = await client
              .from('profiles')
              .select()
              .eq('id', uid)
              .limit(1);
          if (res.isNotEmpty)
            role = (res.first['role'] as String?) ?? 'employee';
        }
      } catch (_) {}

      if (!mounted) return;
      if (role == 'boss') {
        await _hydrateBossAvailability();
        if (!mounted) return;
        session.loginBoss();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BossPage()),
        );
      } else {
        final email = client.auth.currentUser?.email ?? userInput;
        await _hydrateAvailability(email);
        if (!mounted) return;
        session.loginEmployee(email);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeHomePage()),
        );
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credenziali non valide o errore di rete.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turni')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sign in',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email or username',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Inserisci email o username'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _PasswordField(
                            controller: _passCtrl,
                            onSubmit: _handleLogin,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _handleLogin,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text('Accedi'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SignUpPage(),
                                        ),
                                      ),
                                child: const Text('Create account'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : _signInWithGoogle,
                                icon: const Icon(Icons.g_mobiledata),
                                label: const Text('Continue with Google'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final Future<void> Function() onSubmit;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: 'Password',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      obscureText: _obscure,
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Inserisci la password' : null,
      onFieldSubmitted: (_) => widget.onSubmit(),
    );
  }
}
