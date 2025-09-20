import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:turni/data/repositories/availability_repository.dart';
import 'package:turni/pages/boss_page.dart';
import 'package:turni/pages/employee_home_page.dart';
import 'package:turni/pages/login_page.dart';
import 'package:turni/state/availability_store.dart';
import 'package:turni/state/session_store.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAvailabilityRepository extends Mock implements AvailabilityRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('it_IT', null);
  });

  setUp(() {
    SessionStore.instance.logout();
    AvailabilityStore.instance.clearAll();
  });

  group('Login navigation', () {
    testWidgets('navigates to BossPage when profile role is boss', (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(1200, 800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        final exception = details.exception;
        if (exception is FlutterError &&
            exception.toString().contains('A RenderFlex overflowed by')) {
          return;
        }
        previousErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousErrorHandler);

      final mockClient = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      final mockRepo = MockAvailabilityRepository();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);

      when(() => mockClient.auth).thenReturn(mockAuth);

      when(() => mockAuth.currentSession).thenReturn(null);
      when(() => mockAuth.onAuthStateChange).thenAnswer((_) => authController.stream);

      when(() => mockRepo.ensureProfileRow()).thenAnswer((_) async {});
      when(() => mockRepo.getAllForBoss()).thenAnswer((_) async => {});
      when(() => mockRepo.getMyDays()).thenAnswer((_) async => []);

      final user = User(
        id: 'boss-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: 'boss@example.com',
        createdAt: '2024-01-01T00:00:00Z',
      );
      when(() => mockAuth.currentUser).thenReturn(user);

      final session = Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: user,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            supabaseClient: mockClient,
            availabilityRepository: mockRepo,
            roleResolver: (_) async => 'boss',
          ),
        ),
      );

      authController.add(AuthState(AuthChangeEvent.signedIn, session));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(BossPage), findsOneWidget);
    });

    testWidgets('navigates to EmployeeHomePage when profile role is employee',(tester) async {
      final view = tester.view;
      view.physicalSize = const Size(1200, 800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        final exception = details.exception;
        if (exception is FlutterError &&
            exception.toString().contains('A RenderFlex overflowed by')) {
          return;
        }
        previousErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousErrorHandler);

      final mockClient = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      final mockRepo = MockAvailabilityRepository();
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);

      when(() => mockClient.auth).thenReturn(mockAuth);

      when(() => mockAuth.currentSession).thenReturn(null);
      when(() => mockAuth.onAuthStateChange).thenAnswer((_) => authController.stream);

      when(() => mockRepo.ensureProfileRow()).thenAnswer((_) async {});
      when(() => mockRepo.getAllForBoss()).thenAnswer((_) async => {});
      when(() => mockRepo.getMyDays()).thenAnswer((_) async => []);

      final user = User(
        id: 'employee-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: 'employee@example.com',
        createdAt: '2024-01-01T00:00:00Z',
      );
      when(() => mockAuth.currentUser).thenReturn(user);

      final session = Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: user,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            supabaseClient: mockClient,
            availabilityRepository: mockRepo,
            roleResolver: (_) async => 'employee',
          ),
        ),
      );

      authController.add(AuthState(AuthChangeEvent.signedIn, session));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(EmployeeHomePage), findsOneWidget);
    });
  });

  testWidgets('BossPage renders availability data returned from repository', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final exception = details.exception;
      if (exception is FlutterError &&
          exception.toString().contains('A RenderFlex overflowed by')) {
        return;
      }
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    final mockRepo = MockAvailabilityRepository();
    when(() => mockRepo.ensureProfileRow()).thenAnswer((_) async {});
    when(() => mockRepo.getAllForBoss()).thenAnswer(
      (_) async => {
        'alice@example.com': [DateTime(2024, 7, 1)],
        'bob@example.com': [DateTime(2024, 7, 2)],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BossPage(availabilityRepository: mockRepo),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('alice@example.com'), findsWidgets);
    expect(find.textContaining('req 0 / avail 1'), findsWidgets);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
  });
}
