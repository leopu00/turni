# turni

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Turni

Applicazione Flutter per la gestione dei turni di lavoro.  
Il progetto nasce come esercizio personale e come base per un'app più completa che potrà essere pubblicata sugli store.

## Funzionalità (MVP)
- Home con scelta ruolo (Dipendente o Boss)
- Dipendente: inserimento disponibilità
- Boss: generazione turni a partire dalle disponibilità

## Roadmap
1. MVP locale con SQLite
2. Gestione multi-utente
3. Sincronizzazione con database remoto (es. Supabase/Postgres)
4. Autenticazione e notifiche push
5. Pubblicazione su App Store / Play Store

## Getting Started
Per avviare il progetto in modalità web:
```bash
flutter run -d chrome
```

## Risorse utili
- [Flutter Docs](https://docs.flutter.dev/)
- [Riverpod](https://riverpod.dev/)
- [Sqflite](https://pub.dev/packages/sqflite)
- [Supabase Flutter](https://pub.dev/packages/supabase_flutter)