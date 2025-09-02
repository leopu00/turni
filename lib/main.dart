import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/session_store.dart';
import 'data/login_page.dart';
import 'pages/availability_page.dart';
import 'pages/boss_page.dart';
import 'pages/employee_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  runApp(const TurniApp());
}

class TurniApp extends StatelessWidget {
  const TurniApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.instance;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return MaterialApp(
          title: 'Turni',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.teal,
          ),
          locale: const Locale('it', 'IT'),
          supportedLocales: const [
            Locale('it', 'IT'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: _homeFor(session),
        );
      },
    );
  }

  Widget _homeFor(SessionStore session) {
    // Not logged in → Login page
    if (!session.isLoggedIn) {
      return const LoginPage();
    }

    // Boss → Boss page (panoramica)
    if (session.isBoss) {
      return const BossPage();
    }

    // Employee → Employee home
    return const EmployeeHomePage();
  }
}
