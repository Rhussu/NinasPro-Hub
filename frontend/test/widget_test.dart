import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/main.dart';
import 'package:ninas_pro_hub/services/health_service.dart';
import 'package:ninas_pro_hub/widgets/db_health_checker.dart';

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
  testWidgets('Renders development screen and db health checker connected', (WidgetTester tester) async {
    final mockService = MockHealthService();

    await tester.pumpWidget(NinasProApp(healthService: mockService));
    await tester.pumpAndSettle();

    expect(find.text('NiñasPro Hub'), findsOneWidget);
    expect(find.text('EN DESARROLLO'), findsOneWidget);
    expect(find.text('Plataforma en Construcción'), findsOneWidget);
    expect(find.byType(DbHealthChecker), findsOneWidget);
    expect(find.textContaining('DB: Conectada'), findsOneWidget);
    expect(supabaseClient, isNull);

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
}
