import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/shop_repository.dart';
import '../models/supabase/profile.dart';

class ShopColleaguesPage extends StatefulWidget {
  const ShopColleaguesPage({super.key});

  @override
  State<ShopColleaguesPage> createState() => _ShopColleaguesPageState();
}

class _ShopColleaguesPageState extends State<ShopColleaguesPage> {
  late Future<ShopColleaguesResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ShopRepository.instance.fetchColleaguesForCurrentUser();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ShopRepository.instance.fetchColleaguesForCurrentUser();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Colleghi del mio negozio')),
      body: FutureBuilder<ShopColleaguesResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Impossibile caricare i colleghi. Riprova più tardi.',
              onRetry: _reload,
            );
          }
          final result = snapshot.data;
          if (result == null || !result.hasShop) {
            return _InfoView(
              message: 'Non risulti associato ad alcun negozio.',
              onRefresh: _reload,
            );
          }
          if (result.colleagues.isEmpty) {
            return _InfoView(
              message:
                  'Non ci sono altri rider associati a ${result.shopName ?? 'questo shop'}.',
              onRefresh: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: result.colleagues.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: Text(result.shopName ?? 'Shop sconosciuto'),
                    subtitle: const Text('Rider associati al tuo negozio'),
                    leading: const Icon(Icons.storefront_outlined),
                  );
                }
                final Profile profile = result.colleagues[index - 1];
                final currentId = Supabase.instance.client.auth.currentUser?.id;
                final isMe = profile.id == currentId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (profile.username ?? profile.email).trim().isEmpty
                          ? '?'
                          : (profile.username ?? profile.email)[0]
                                .toUpperCase(),
                    ),
                  ),
                  title: Text(
                    profile.username?.isNotEmpty == true
                        ? profile.username!
                        : profile.email,
                  ),
                  subtitle: Text(
                    isMe ? '${profile.email} (sei tu)' : profile.email,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _InfoView extends StatelessWidget {
  const _InfoView({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Text(message, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => onRefresh(),
              child: const Text('Aggiorna'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
