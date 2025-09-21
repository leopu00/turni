import 'package:flutter/material.dart';

import '../data/repositories/shop_repository.dart';
import '../models/supabase/profile.dart';

class BossEmployeesPage extends StatefulWidget {
  const BossEmployeesPage({super.key});

  @override
  State<BossEmployeesPage> createState() => _BossEmployeesPageState();
}

class _BossEmployeesPageState extends State<BossEmployeesPage> {
  bool _loading = false;
  String? _error;
  String? _shopId;
  String? _shopName;
  List<Profile> _registered = const [];
  List<PendingEmployee> _pending = const [];
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ShopRepository.instance
          .fetchColleaguesForCurrentUser();
      setState(() {
        _shopId = result.shopId;
        _shopName = result.shopName;
        _registered = result.colleagues;
        _pending = result.pending;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addPending() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_shopId == null) {
      _showSnack('Impossibile aggiungere: shop non trovato.');
      return;
    }

    setState(() => _loading = true);
    try {
      final employee = await ShopRepository.instance.addPendingEmployee(
        shopId: _shopId!,
        name: name,
      );
      setState(() {
        _pending = [
          ..._pending,
          employee,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _nameController.clear();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Errore durante l\'aggiunta: $e');
    }
  }

  Future<void> _removePending(PendingEmployee employee) async {
    setState(() => _loading = true);
    try {
      await ShopRepository.instance.deletePendingEmployee(employee.id);
      setState(() {
        _pending = _pending.where((e) => e.id != employee.id).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Errore durante la rimozione: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = _shopName == null
        ? 'Dipendenti dello shop'
        : '$_shopName — Dipendenti';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _fetchEmployees,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Errore nel caricamento dei dipendenti: $_error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _fetchEmployees,
                    child: const Text('Riprova'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionTitle(
                    title: 'Dipendenti registrati',
                    subtitle:
                        'Questi utenti hanno effettuato l\'accesso e sono collegati allo shop.',
                  ),
                  if (_registered.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Nessun dipendente ha ancora effettuato l\'accesso.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _registered.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final profile = _registered[index];
                          final display = _labelFor(profile);
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(display),
                            subtitle: Text(profile.email),
                            trailing: profile.role == 'boss'
                                ? const Chip(label: Text('Boss'))
                                : null,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Dipendenti da registrare',
                    subtitle:
                        'Aggiungi qui i nomi dei collaboratori che ancora non usano l\'app.',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome dipendente',
                                  ),
                                  onSubmitted: (_) => _addPending(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: _addPending,
                                child: const Text('Aggiungi'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_pending.isEmpty)
                            Text(
                              'Nessun dipendente da registrare ancora.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _pending.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final employee = _pending[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.person_add_alt_1_outlined,
                                  ),
                                  title: Text(employee.name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Rimuovi',
                                    onPressed: () => _removePending(employee),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _labelFor(Profile profile) {
    final display = profile.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final username = profile.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    return profile.email;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
      ],
    );
  }
}
