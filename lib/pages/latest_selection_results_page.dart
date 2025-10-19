import 'package:flutter/material.dart';

import '../widgets/brand_assets.dart';

class LatestSelectionResultsPage extends StatelessWidget {
  const LatestSelectionResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'Risultato turni ultima selezione'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'La visualizzazione dei turni sarà disponibile a breve.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
