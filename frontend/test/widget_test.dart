import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/main.dart';
import 'package:ninas_pro_hub/services/health_service.dart';
import 'package:ninas_pro_hub/widgets/db_health_checker.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_clase_repository.dart';

class MockHealthService extends HealthService {
  final DbHealthResult Function(String? url, String? key)? onCheck;

  MockHealthService({this.onCheck});

  @override
  Future<DbHealthResult> checkDatabaseHealth({
    String? supabaseUrl,
    String? anonKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (onCheck != null) {
      return onCheck!(supabaseUrl, anonKey);
    }
    return DbHealthResult(
      state: DbHealthState.connected,
      latencyMs: 35,
      statusCode: 200,
      timestamp: DateTime.now(),
      message: 'Base de datos conectada',
      endpoint: 'https://mock.supabase.co/rest/v1/',
      details: 'Mock details',
    );
  }
}

void main() {
  testWidgets('DbHealthChecker renders connected state with details and config', (WidgetTester tester) async {
    final mockService = MockHealthService();

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: DbHealthChecker(healthService: mockService)))));
    await tester.pumpAndSettle();

    expect(find.byType(DbHealthChecker), findsOneWidget);
    expect(find.textContaining('DB: Conectada'), findsOneWidget);

    // Expand details
    final expandButton = find.byTooltip('Ver detalles');
    expect(expandButton, findsOneWidget);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('Servicio'), findsOneWidget);
    expect(find.text('35 ms'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('Mock details'), findsOneWidget);

    // Open Config dialog
    final configButton = find.text('Configurar');
    expect(configButton, findsOneWidget);
    await tester.tap(configButton);
    await tester.pumpAndSettle();

    expect(find.text('Configurar Conexión DB'), findsOneWidget);

    // Save dialog
    final saveButton = find.text('Guardar y Probar');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Re-check button
    final refreshButton = find.byTooltip('Reintentar chequeo');
    expect(refreshButton, findsOneWidget);
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();

    // Collapse
    final collapseButton = find.byTooltip('Contraer');
    expect(collapseButton, findsOneWidget);
    await tester.tap(collapseButton);
    await tester.pumpAndSettle();
  });

  testWidgets('DbHealthChecker renders unauthenticated state', (WidgetTester tester) async {
    final mockService = MockHealthService(
      onCheck: (url, key) => DbHealthResult(
        state: DbHealthState.unauthenticated,
        latencyMs: 40,
        statusCode: 401,
        timestamp: DateTime.now(),
        message: 'En línea (Requiere SUPABASE_ANON_KEY)',
        endpoint: 'https://mock.supabase.co/rest/v1/',
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DbHealthChecker(healthService: mockService),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('DB: En línea (falta clave)'), findsOneWidget);
  });

  testWidgets('DbHealthChecker renders error state', (WidgetTester tester) async {
    final mockService = MockHealthService(
      onCheck: (url, key) => DbHealthResult(
        state: DbHealthState.error,
        latencyMs: 120,
        statusCode: 500,
        timestamp: DateTime.now(),
        message: 'Error HTTP 500',
        endpoint: 'https://mock.supabase.co/rest/v1/',
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DbHealthChecker(healthService: mockService),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('DB: Error (120ms)'), findsOneWidget);
  });

  testWidgets('NinasProApp sin sesión guardada muestra el acceso', (WidgetTester tester) async {
    final auth = FakeAuthService();

    await tester.pumpWidget(NinasProApp(authService: auth, healthService: MockHealthService()));
    await tester.pumpAndSettle();

    expect(find.text('Te damos la bienvenida'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('La franja BETA solo aparece en la compilación de la beta', (WidgetTester tester) async {
    await tester.pumpWidget(NinasProApp(authService: FakeAuthService(), healthService: MockHealthService()));
    await tester.pumpAndSettle();
    expect(find.text('BETA · datos de prueba'), findsNothing);

    await tester.pumpWidget(NinasProApp(key: UniqueKey(), authService: FakeAuthService(), healthService: MockHealthService(), esBeta: true));
    await tester.pumpAndSettle();
    expect(find.text('BETA · datos de prueba'), findsOneWidget);
    expect(find.text('Te damos la bienvenida'), findsOneWidget);
  });

  testWidgets('NinasProApp con sesión de Gestión abre su vista y al cerrar sesión vuelve al acceso', (WidgetTester tester) async {
    final auth = FakeAuthService(sesionGuardada: SesionesDemo.gestion);
    final clase = FakeClaseRepository();
    addTearDown(clase.cerrar);

    await tester.pumpWidget(NinasProApp(authService: auth, healthService: MockHealthService(), claseRepository: clase));
    await tester.pumpAndSettle();

    expect(find.text('NiñasPro Hub'), findsOneWidget);
    expect(find.text('¡Hola, Camila!').hitTestable(), findsOneWidget);

    // Se abre Ajustes encima: al cerrar sesión no debe quedar a la vista
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await auth.cerrarSesion();
    await tester.pumpAndSettle();

    expect(find.text('Te damos la bienvenida'), findsOneWidget);
    expect(find.text('Ajustes'), findsNothing);
  });
}
