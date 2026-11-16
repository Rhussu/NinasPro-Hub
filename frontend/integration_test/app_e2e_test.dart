// Pruebas extremo a extremo (E2E): la app real, compilada para web, contra un
// Supabase con supabase/seed.sql (local o la beta). Recorre la interfaz como lo
// haría cada perfil: UI → repositorios → API → Postgres con RLS.
//
// Ejecutar (ver docs/pruebas/plan-de-pruebas.md):
//   chromedriver --port=4444 &
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_e2e_test.dart -d web-server --browser-name=chrome \
//     --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=E2E_CLAVE=NinasPro2026
//
// Los tiempos de cada tarea quedan en build/integration_response_data.json
// (proxy automatizado de RNF-U-2; no reemplaza la prueba con tutoras, TC-36).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ninas_pro_hub/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

const _clave = String.fromEnvironment('E2E_CLAVE', defaultValue: 'NinasPro2026');

Future<void> _esperar(WidgetTester tester, Finder finder, {Duration max = const Duration(seconds: 30)}) async {
  final fin = DateTime.now().add(max);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció a tiempo: $finder');
}

Future<void> _ingresar(WidgetTester tester, String correo) async {
  await _esperar(tester, find.text('Ingresar'));
  await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), correo);
  await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), _clave);
  await tester.tap(find.text('Ingresar'));
}

Future<void> _salir(WidgetTester tester) async {
  await Supabase.instance.client.auth.signOut();
  await _esperar(tester, find.text('Te damos la bienvenida'));
}

Future<void> _abrirAccion(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip('Acciones rápidas'));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(find.byTooltip(tooltip));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final tiempos = <String, int>{};

  testWidgets('E2E: tutora, alumna y Directiva sobre la base real', (tester) async {
    await app.main();

    // --- E2E-01 · TC-07 / AT-1: la tutora pasa lista desde su celular ---
    final tarea = Stopwatch()..start();
    await _ingresar(tester, 'daniela.valenzuela@ninaspro.cl');
    await _esperar(tester, find.textContaining('¡Hola, Daniela!'));
    tiempos['login_tutora_ms'] = tarea.elapsedMilliseconds;

    await _abrirAccion(tester, 'Asistencia');
    await _esperar(tester, find.text('Guardar Asistencia de la Clase'));
    tiempos['abrir_lista_ms'] = tarea.elapsedMilliseconds - tiempos['login_tutora_ms']!;

    // Parte de todas presentes aunque una corrida anterior haya guardado ausentes,
    // y marca 3 ausentes (cada toque alterna la primera "Presente" que queda)
    var vueltas = 0;
    while (find.text('Ausente').evaluate().isNotEmpty && vueltas++ < 60) {
      await tester.tap(find.text('Ausente').first);
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Presente').first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    final guardado = Stopwatch()..start();
    await tester.tap(find.text('Guardar Asistencia de la Clase'));
    await _esperar(tester, find.textContaining('Asistencia guardada:'));
    tiempos['guardar_asistencia_ms'] = guardado.elapsedMilliseconds;
    expect(find.textContaining('3 ausentes'), findsOneWidget);
    expect(find.textContaining('Última edición: Daniela Valenzuela Castro'), findsOneWidget);
    tiempos['tarea_tutora_total_ms'] = tarea.elapsedMilliseconds;

    // La lista quedó en la base, con autora (RB-7), y en la clase de HOY: la
    // última que ya llegó a su fecha y no está suspendida (DEF-01).
    final db = Supabase.instance.client;
    final perfil = db.auth.currentUser!.id;
    final hoy = await db.rpc('hoy_chile') as String;
    final ultima = await db
        .from('clases')
        .select('id, numero_sesion')
        .lte('fecha', hoy)
        .neq('estado', 'suspendida')
        .order('fecha', ascending: false)
        .limit(1)
        .single();
    final filas = await db
        .from('asistencia_alumnas')
        .select('estado')
        .eq('clase_id', ultima['id'] as String)
        .eq('registrado_por', perfil)
        .eq('estado', 'ausente');
    expect(filas, hasLength(3), reason: 'Los 3 ausentes deben quedar en la clase ${ultima['numero_sesion']}');
    await _salir(tester);

    // --- E2E-02 · TC-17 / AT-8: la alumna ve solo su portal ---
    final portal = Stopwatch()..start();
    await _ingresar(tester, 'valentina.soto@correo.cl');
    await _esperar(tester, find.textContaining('¡Hola, Valentina!'));
    tiempos['portal_alumna_ms'] = portal.elapsedMilliseconds;
    // Cambiar el ID por el de otra alumna del seed: 403 y el intento queda registrado
    await expectLater(
      Supabase.instance.client.rpc('portal_alumna', params: {'p_alumna_id': '3ebf929d-448b-5114-bd81-344eae48f6da'}),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await _salir(tester);

    // --- E2E-03 · TC-31: la Directiva no entra a la consola sin segundo factor ---
    await _ingresar(tester, 'directiva@ninaspro.cl');
    await _esperar(tester, find.text('Verificar'));
    expect(find.text('Dashboard'), findsNothing);
    final nomina = await Supabase.instance.client.from('nomina_alumnas').select('alumna_id').limit(1);
    expect(nomina, isEmpty, reason: 'Sin aal2 la Directiva no lee datos de alumnas');
    await _salir(tester);

    binding.reportData = {'tiempos': tiempos};
  });
}
