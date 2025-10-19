import 'package:flutter/material.dart';

import '../widgets/brand_assets.dart';

class ShopAddPage extends StatelessWidget {
  const ShopAddPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'Aggiungi shop'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Presto potrai aggiungere uno shop da questa pagina.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
