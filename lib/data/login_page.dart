import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'session_store.dart';
import 'auth_dao.dart';
import '../pages/boss_page.dart';

import '../pages/employee_home_page.dart';

enum _Role { boss, employee }



class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final session = SessionStore.instance;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  Future<_Role?> _authenticate(String username, String password) async {
    if (kIsWeb) {
      // Fallback per Web/Chrome: sqflite non è supportato su web.
      const users = <String, Map<String, String>>{
        'boss': {'password': 'admin', 'role': 'boss'},
        'mario': {'password': '1234', 'role': 'employee'},
        'anna': {'password': 'abcd', 'role': 'employee'},
      };
      await Future.delayed(const Duration(milliseconds: 150));
      final u = users[username.trim().toLowerCase()];
      if (u == null) return null;
      if (u['password'] != password) return null;
      return u['role'] == 'boss' ? _Role.boss : _Role.employee;
    }

    // Mobile/desktop native: usa SQLite tramite AuthDao
    final u = await AuthDao.instance.verifyLogin(username, password);
    if (u == null) return null;
    return u.role == 'boss' ? _Role.boss : _Role.employee;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    try {
      final role = await _authenticate(username, password)
          .timeout(const Duration(seconds: 6));

      if (!mounted) return;
      setState(() => _submitting = false);

      if (role == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(kIsWeb
              ? 'Credenziali non valide (Web)'
              : 'Credenziali non valide')),
        );
        return;
      }

      if (role == _Role.boss) {
        session.loginBoss();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BossPage()),
        );
      } else {
        session.loginEmployee(username);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeHomePage()),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timeout durante l\'accesso. Riprova.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore login: $e')),
      );
    }
  }

  // Quick testing fallback entry point
  void _goBoss() {
    session.loginBoss();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BossPage()),
    );
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turni — Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Accedi',
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
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Inserisci lo username' : null,
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
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text('Accedi'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Accesso rapido Boss (test)', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('Utile mentre implementiamo il DB.'),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _goBoss,
                          icon: const Icon(Icons.manage_accounts),
                          label: const Text('Entra come boss'),
                        ),
                      ],
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
      validator: (v) => (v == null || v.isEmpty) ? 'Inserisci la password' : null,
      onFieldSubmitted: (_) => widget.onSubmit(),
    );
  }
}