import 'package:flutter/material.dart';

import '../widgets/brand_assets.dart';

class MyShiftsPage extends StatelessWidget {
  const MyShiftsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(text: 'I miei turni attuali'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Presto potrai consultare qui i tuoi turni assegnati.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
