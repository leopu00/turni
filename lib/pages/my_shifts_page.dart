import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/manual_shift_repository.dart';
import '../data/repositories/shop_repository.dart';
import '../widgets/brand_assets.dart';

class MyShiftsPage extends StatefulWidget {
  const MyShiftsPage({super.key});

  @override
  State<MyShiftsPage> createState() => _MyShiftsPageState();
}

class _MyShiftsPageState extends State<MyShiftsPage> {
  static final DateFormat _dayLabelFormat = DateFormat('EEEE dd MMM', 'it_IT');
  static final DateFormat _rangeFormat = DateFormat('dd MMM', 'it_IT');

  bool _loading = false;
  bool _hasShop = true;
  String? _error;
  String? _shopName;
  List<_ShiftWeek> _weeks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error =
              'Per visualizzare i turni assegnati devi effettuare il login.';
          _hasShop = true;
          _weeks = const [];
          _shopName = null;
        });
        return;
      }

      final shopResult =
          await ShopRepository.instance.fetchColleaguesForCurrentUser();
      if (!mounted) return;

      if (!shopResult.hasShop) {
        setState(() {
          _loading = false;
          _hasShop = false;
          _weeks = const [];
          _shopName = null;
        });
        return;
      }

      final assignments = await ManualShiftRepository.instance
          .fetchAssignmentsForShop(shopResult.shopId!);

      final myDays = <DateTime>{};
      for (final assignment in assignments) {
        if (assignment.employeeId != user.id) continue;
        final normalized = DateTime(
          assignment.day.year,
          assignment.day.month,
          assignment.day.day,
        );
        myDays.add(normalized);
      }

      final weekMap = <DateTime, List<DateTime>>{};
      final sortedDays = myDays.toList()..sort();
      for (final day in sortedDays) {
        final start = _startOfWeek(day);
        final bucket = weekMap.putIfAbsent(start, () => <DateTime>[]);
        bucket.add(day);
      }

      final weeks = weekMap.entries.map((entry) {
        final days = entry.value..sort();
        return _ShiftWeek(
          start: entry.key,
          days: List<DateTime>.from(days),
        );
      }).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasShop = true;
        _shopName = shopResult.shopName;
        _weeks = weeks;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Errore nel caricamento: $e';
      });
    }
  }

  DateTime _startOfWeek(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final delta = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: delta));
  }

  String _labelForDay(DateTime day) {
    final raw = _dayLabelFormat.format(day);
    if (raw.isEmpty) return raw;
    final first = raw[0].toUpperCase();
    return '$first${raw.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'I miei turni'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _weeks.isEmpty && _error == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return _message(
        context,
        icon: Icons.error_outline,
        title: 'Ops…',
        subtitle: _error!,
        action: FilledButton(
          onPressed: _load,
          child: const Text('Riprova'),
        ),
      );
    }

    if (!_hasShop) {
      return _message(
        context,
        icon: Icons.store_outlined,
        title: 'Nessun negozio associato',
        subtitle:
            'Non risulti assegnato a nessuno shop, quindi non ci sono turni da mostrare.',
      );
    }

    if (_weeks.isEmpty) {
      return _message(
        context,
        icon: Icons.event_busy_outlined,
        title: 'Nessun turno pianificato',
        subtitle:
            'Non sei stato assegnato all’ultima generazione manuale del tuo shop.',
      );
    }

    final theme = Theme.of(context);
    final hintColor = theme.hintColor;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _weeks.length,
      itemBuilder: (context, index) {
        final week = _weeks[index];
        final weekEnd = week.start.add(const Duration(days: 6));
        final range =
            '${_rangeFormat.format(week.start)} – ${_rangeFormat.format(weekEnd)}';
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settimana ${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shopName != null
                      ? '${_shopName!} · $range'
                      : range,
                  style: theme.textTheme.bodySmall?.copyWith(color: hintColor),
                ),
                const Divider(height: 24),
                ...week.days.map(
                  (day) {
                    final label = _labelForDay(day);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(label),
                      subtitle: const Text('Turno 19:00 – 23:00'),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }
}

class _ShiftWeek {
  const _ShiftWeek({required this.start, required this.days});

  final DateTime start;
  final List<DateTime> days;
}
