import 'package:flutter/material.dart';
import 'session_store.dart';
import '../pages/boss_page.dart';
import '../pages/employee_home_page.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final session = SessionStore.instance;
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _goEmployee() {
    if (_formKey.currentState!.validate()) {
      final name = _nameCtrl.text;
      session.loginEmployee(name);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmployeeHomePage()),
      );
    }
  }

  void _goBoss() {
    session.loginBoss();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BossPage()),
    );
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
                  'Accedi come…',
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
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Dipendente', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nome e cognome (o nickname)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Inserisci un nome' : null,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _goEmployee,
                            icon: const Icon(Icons.login),
                            label: const Text('Entra come dipendente'),
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
                              Text('Boss', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('Panoramica, requisiti e gestione turni.'),
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