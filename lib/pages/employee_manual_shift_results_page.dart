import 'package:flutter/material.dart';

import 'manual_shift_results_page.dart';

class EmployeeManualShiftResultsPage extends StatelessWidget {
  const EmployeeManualShiftResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ManualShiftResultsPage(
      title: 'Turni manuali salvati',
      headerSubtitle: 'Ultima generazione manuale del tuo shop',
    );
  }
}
