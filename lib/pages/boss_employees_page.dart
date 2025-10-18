import 'package:flutter/material.dart';

import '../data/repositories/shop_repository.dart';
import '../models/supabase/profile.dart';
import 'boss_manage_employees_page.dart';

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
  Widget build(BuildContext context) {
    final title = _shopName == null
        ? 'Dipendenti dello shop'
        : '$_shopName — Dipendenti';
    final employees = _employeeItems;

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
                  Card(
                    child: employees.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _shopId == null
                                  ? 'Collega questo account ad uno shop per iniziare a gestire i collaboratori.'
                                  : 'Nessun collaboratore presente al momento.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: employees.length,
                            separatorBuilder: (context, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) =>
                                _buildEmployeeTile(context, employees[index]),
                          ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Gestisci collaboratori'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BossManageEmployeesPage(),
                        ),
                      );
                      if (!mounted) return;
                      await _fetchEmployees();
                    },
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

  List<_EmployeeListItem> get _employeeItems {
    final items = <_EmployeeListItem>[
      for (final profile in _registered)
        _EmployeeListItem(
          id: profile.id,
          name: _labelFor(profile),
          isRegistered: true,
          isBoss: profile.role == 'boss',
          pending: null,
        ),
      for (final pending in _pending)
        _EmployeeListItem(
          id: pending.id,
          name: pending.name,
          isRegistered: false,
          isBoss: false,
          pending: pending,
        ),
    ];
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Widget _buildEmployeeTile(BuildContext context, _EmployeeListItem item) {
    final subtitle = item.isRegistered
        ? 'Registrato tramite app iTurni'
        : 'Da registrare';
    Widget? trailing;
    if (item.isRegistered && item.isBoss) {
      trailing = const Chip(label: Text('Boss'));
    } else if (!item.isRegistered) {
      trailing = const Chip(label: Text('Da registrare'));
    }

    return ListTile(
      leading: Icon(
        item.isRegistered
            ? Icons.person_outline
            : Icons.person_add_alt_1_outlined,
      ),
      title: Text(item.name),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

class _EmployeeListItem {
  const _EmployeeListItem({
    required this.id,
    required this.name,
    required this.isRegistered,
    required this.isBoss,
    this.pending,
  });

  final String id;
  final String name;
  final bool isRegistered;
  final bool isBoss;
  final PendingEmployee? pending;
}
