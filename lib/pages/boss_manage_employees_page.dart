import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/shop_repository.dart';
import '../models/supabase/profile.dart';

class BossManageEmployeesPage extends StatefulWidget {
  const BossManageEmployeesPage({super.key});

  @override
  State<BossManageEmployeesPage> createState() =>
      _BossManageEmployeesPageState();
}

class _BossManageEmployeesPageState extends State<BossManageEmployeesPage> {
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _addPending() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final shopId = _shopId;
    if (shopId == null) {
      _showSnack('Impossibile aggiungere: shop non trovato.');
      return;
    }

    setState(() => _loading = true);
    try {
      final employee = await ShopRepository.instance.addPendingEmployee(
        shopId: shopId,
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
      _showSnack('Collaboratore aggiunto all\'elenco da registrare.');
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Errore durante l\'aggiunta: $e');
    }
  }

  Future<void> _removePending(PendingEmployee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovere dalla lista?'),
        content: Text(
          'Vuoi rimuovere ${employee.name} dall\'elenco delle persone da registrare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await ShopRepository.instance.deletePendingEmployee(employee.id);
      setState(() {
        _pending = _pending.where((e) => e.id != employee.id).toList();
        _loading = false;
      });
      _showSnack('Collaboratore rimosso dalla lista da registrare.');
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Errore durante la rimozione: $e');
    }
  }

  Future<void> _dissociate(Profile profile) async {
    final shopId = _shopId;
    if (shopId == null) {
      _showSnack('Shop non disponibile.');
      return;
    }
    final display = _labelFor(profile);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovere collaboratore?'),
        content: Text(
          'Questo rimuoverà $display dallo shop $_shopName. Vuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await ShopRepository.instance.removeEmployeeFromShop(
        shopId: shopId,
        profileId: profile.id,
      );
      await _fetchEmployees();
      _showSnack('$display rimosso dallo shop.');
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
        ? 'Gestione collaboratori'
        : 'Gestione — $_shopName';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

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
                    'Errore durante il caricamento: $_error',
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aggiungi collaboratore da registrare',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome collaboratore',
                                  ),
                                  onSubmitted: (_) => _addPending(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: _loading ? null : _addPending,
                                child: const Text('Aggiungi'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dipendenti registrati',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (_registered.isEmpty)
                            Text(
                              'Nessun dipendente registrato al momento.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _registered.length,
                              separatorBuilder: (context, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final profile = _registered[index];
                                final label = _labelFor(profile);
                                final isSelf = profile.id == currentUserId;
                                return ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(label),
                                  subtitle: Text(profile.email),
                                  trailing: isSelf
                                      ? const Chip(label: Text('Tu'))
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.person_remove_alt_1_outlined,
                                          ),
                                          tooltip: 'Rimuovi dallo shop',
                                          onPressed: _loading
                                              ? null
                                              : () => _dissociate(profile),
                                        ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Da registrare',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (_pending.isEmpty)
                            Text(
                              'Nessun collaboratore in attesa di registrazione.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _pending.length,
                              separatorBuilder: (context, _) =>
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
                                    onPressed: _loading
                                        ? null
                                        : () => _removePending(employee),
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
