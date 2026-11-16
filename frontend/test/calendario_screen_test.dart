import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/screens/calendario/calendario_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/ajustes_gestion_screen.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_catalogo_repository.dart';

/// Calendario de clases de la sede (US-03)
void main() {
  final hoy = DateTime(2026, 11, 14); // sábado

  Curso instancia({String id = 'inst-1', int anio = 2026, int semestre = 2, DateTime? termino}) => Curso(
        id: id,
        codigo: 'PCB-$anio-S$semestre-BEAUCHEF',
        nombre: 'Programación Competitiva Básica (Python)',
        sedeId: 'sede-a',
        sedeNombre: 'Sede Beauchef',
        anio: anio,
        semestre: semestre,
        totalSesiones: 3,
        catalogoId: 'cat-pcb',
        fechaInicio: DateTime(anio, semestre == 2 ? 8 : 3, 1),
        fechaTermino: termino ?? DateTime(anio, 11, 28),
        horaInicio: '10:00',
        horaFin: '13:00',
      );

  SesionClase sesion(int n, DateTime fecha, String estado) => SesionClase(
        id: 'inst-1-s$n',
        cursoId: 'inst-1',
        numeroSesion: n,
        fecha: fecha,
        tema: n == 1 ? 'Variables y tipos' : '',
        estado: estado,
        horaInicio: '10:00',
        horaFin: '13:00',
      );

  FakeCatalogoRepository repositorio() => FakeCatalogoRepository(
        instancias: [
          instancia(),
          // De un período anterior que ya terminó: Gestión no la ve
          instancia(id: 'inst-vieja', anio: 2025, semestre: 1, termino: DateTime(2025, 6, 28)),
        ],
        sesiones: {
          'inst-1': [
            sesion(1, DateTime(2026, 11, 7), 'realizada'),
            sesion(2, DateTime(2026, 11, 21), 'programada'),
            sesion(3, DateTime(2026, 11, 28), 'programada'),
          ],
        },
      );

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    await tester.pumpWidget(MaterialApp(theme: NinasProTheme.light, home: pantalla));
    await tester.pumpAndSettle();
  }

  testWidgets('Gestión ve solo los cursos vigentes y suspende y reanuda una sesión', (tester) async {
    final repo = repositorio();
    await abrir(tester, CalendarioScreen(repository: repo, hoy: hoy));

    expect(find.text('Programación Competitiva Básica (Python)'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing, reason: 'la instancia antigua no está vigente');
    expect(find.text('3 sesiones'), findsOneWidget);
    expect(find.text('1 realizadas'), findsOneWidget);
    expect(find.text('Variables y tipos'), findsOneWidget);
    expect(find.byTooltip('Acciones de la sesión 1'), findsNothing, reason: 'una clase realizada no se suspende');

    await tester.tap(find.byTooltip('Acciones de la sesión 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspender'));
    await tester.pumpAndSettle();
    expect(find.text('Suspender la sesión 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Suspender'));
    await tester.pumpAndSettle();
    expect(find.text('Este campo es obligatorio'), findsOneWidget);

    await tester.tap(find.text('Feriado'));
    await tester.tap(find.widgetWithText(FilledButton, 'Suspender'));
    await tester.pumpAndSettle();

    expect(repo.sesionesPorInstancia['inst-1']![1].estado, 'suspendida');
    expect(find.text('Motivo: Feriado'), findsOneWidget);
    expect(find.text('1 suspendidas'), findsOneWidget);
    expect(find.textContaining('No se tomará asistencia ese día'), findsOneWidget);

    await tester.tap(find.byTooltip('Acciones de la sesión 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reanudar'));
    await tester.pumpAndSettle();
    expect(repo.sesionesPorInstancia['inst-1']![1].estado, 'programada');
    expect(find.text('Motivo: Feriado'), findsNothing);
  });

  testWidgets('Gestión agrega una sesión especial que queda programada a continuación de la última', (tester) async {
    final repo = repositorio();
    await abrir(tester, CalendarioScreen(repository: repo, hoy: hoy));

    await tester.tap(find.text('Sesión especial'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar sesión especial'), findsOneWidget);
    expect(find.text('Sábado 14/11/2026'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    final especial = repo.sesionesPorInstancia['inst-1']!.last;
    expect(especial.numeroSesion, 4);
    expect(especial.esEspecial, isTrue);
    expect(find.text('Especial'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.textContaining('Sesión especial del 14/11/2026 programada'), findsOneWidget);

    // Dos sesiones el mismo día se rechazan con el mensaje en el diálogo
    await tester.tap(find.text('Sesión especial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ya tiene una sesión'), findsOneWidget);
  });

  testWidgets('los errores de la base se muestran sin cambiar la sesión', (tester) async {
    final repo = repositorio()..errorEscritura = 'Solo el Equipo de Gestión de la sede suspende o reanuda clases.';
    await abrir(tester, CalendarioScreen(repository: repo, hoy: hoy));

    await tester.tap(find.byTooltip('Acciones de la sesión 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspender'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Paro');
    await tester.tap(find.widgetWithText(FilledButton, 'Suspender'));
    await tester.pumpAndSettle();

    expect(find.text('Solo el Equipo de Gestión de la sede suspende o reanuda clases.'), findsOneWidget);
    expect(repo.sesionesPorInstancia['inst-1']![2].estado, 'programada');
  });

  testWidgets('sin cursos vigentes muestra un aviso', (tester) async {
    await abrir(tester, CalendarioScreen(repository: FakeCatalogoRepository(), hoy: hoy));
    expect(find.text('Tu sede no tiene cursos vigentes en este período.'), findsOneWidget);
    expect(find.text('Sesión especial'), findsNothing);
  });

  testWidgets('con varios cursos vigentes se elige cuál ver', (tester) async {
    final repo = repositorio();
    repo.listaInstancias.add(instancia(id: 'inst-2').copyWith(nombre: 'Desarrollo Web Inicial'));
    await abrir(tester, CalendarioScreen(repository: repo, hoy: hoy));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Desarrollo Web Inicial').last);
    await tester.pumpAndSettle();
    expect(find.text('0 sesiones'), findsOneWidget);
  });

  testWidgets('Ajustes de Gestión abre el calendario de clases', (tester) async {
    await abrir(
      tester,
      AjustesGestionScreen(sesion: SesionesDemo.gestion, catalogoRepository: repositorio()),
    );

    await tester.scrollUntilVisible(find.text('Calendario de clases'), 200);
    await tester.tap(find.text('Calendario de clases'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Calendario de clases'), findsOneWidget);
  });
}
