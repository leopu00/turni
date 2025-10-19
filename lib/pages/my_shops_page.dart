import 'package:flutter/material.dart';

import '../data/repositories/shop_repository.dart';
import '../widgets/brand_assets.dart';
import 'shop_add_page.dart';

class MyShopsPage extends StatefulWidget {
  const MyShopsPage({super.key});

  @override
  State<MyShopsPage> createState() => _MyShopsPageState();
}

class _MyShopsPageState extends State<MyShopsPage> {
  late Future<List<ShopMembership>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShopRepository.instance.fetchShopsForCurrentUser();
  }

  Future<void> _reload() async {
    final future = ShopRepository.instance.fetchShopsForCurrentUser();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'I miei shop'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ShopAddPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<ShopMembership>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading();
            }
            if (snapshot.hasError) {
              return _buildMessage(
                context,
                icon: Icons.error_outline,
                title: 'Errore',
                subtitle: 'Impossibile caricare gli shop: ${snapshot.error}',
                action: FilledButton(
                  onPressed: _reload,
                  child: const Text('Riprova'),
                ),
              );
            }

            final data = snapshot.data ?? const <ShopMembership>[];
            if (data.isEmpty) {
              return _buildMessage(
                context,
                icon: Icons.store_mall_directory_outlined,
                title: 'Nessuno shop',
                subtitle:
                    'Non risulti associato ad alcun shop in questo momento.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final membership = data[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: Text(membership.name),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildMessage(
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
