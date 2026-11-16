import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart' show Curso;
import 'package:ninas_pro_hub/repositories/reportes_repository.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes_directiva_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_auditoria_view.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_dashboard_view.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_desktop_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_exportar_view.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_grafico_asistencia.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_widgets.dart' show FiltroDesplegable;
import 'package:ninas_pro_hub/services/descargas.dart';

import 'fakes/fake_catalogo_repository.dart';
import 'fakes/fake_roles_repository.dart';
import 'fakes/fake_reportes_repository.dart';

/// Vista de escritorio de la Directiva Nacional: dashboard, exportación,
/// auditoría (US-21..US-25) y sus Ajustes
void main() {
  late FakeReportesRepository reportes;
  late FakeCatalogoRepository catalogo;

  setUp(() {
    reportes = FakeReportesRepository();
    catalogo = FakeCatalogoRepository(instancias: [
      const Curso(
        id: 'inst-pcb',
        codigo: 'PCB',
        nombre: 'Programación Competitiva Básica (Python)',
        sedeId: 'sede-a',
        sedeNombre: 'Sede Beauchef',
        anio: 2026,
        semestre: 2,
        totalSesiones: 10,
      ),
    ]);
    ultimaDescarga = null;
  });

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: NinasProTheme.light,
      home: Scaffold(body: pantalla),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> irA(WidgetTester tester, String seccion) async {
    await tester.tap(find.text(seccion).first);
    await tester.pumpAndSettle();
  }

  Widget consola() => DirectorioDesktopScreen(reportesRepository: reportes, catalogoRepository: catalogo);

  testWidgets('el dashboard muestra los indicadores nacionales y por sede, sin alertas ni justificativos', (tester) async {
    await abrir(tester, consola());

    expect(find.text('Dashboard nacional'), findsOneWidget);
    expect(find.textContaining('2 sedes activas'), findsOneWidget);
    expect(find.text('Alumnas activas'), findsOneWidget);
    // 8 de Beauchef + 3 de San Joaquín; 9 + 3 voluntarias
    expect(find.text('11'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Sede San Joaquín'), findsWidgets);
    expect(find.text('78.6%'), findsOneWidget);
    // Sin clases realizadas, la sede inactiva no tiene porcentaje
    expect(find.text('Inactiva'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    // Alertas y justificativos son del Equipo de Gestión, no del dashboard
    expect(find.text('Justificativos pendientes'), findsNothing);
  });

  testWidgets('el dashboard sin conexión ofrece reintentar', (tester) async {
    reportes.sinConexion = true;
    await abrir(tester, DirectorioDashboardView(repository: reportes, onNavegar: (_) {}));
    expect(find.textContaining('No pudimos cargar los indicadores'), findsOneWidget);

    reportes.sinConexion = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard nacional'), findsOneWidget);
  });

  testWidgets('sin clases realizadas el gráfico lo explica', (tester) async {
    await abrir(
      tester,
      DirectorioDashboardView(repository: FakeReportesRepository(series: const []), onNavegar: (_) {}),
    );
    expect(find.text('Aún no hay clases realizadas con asistencia registrada.'), findsOneWidget);
  });

  testWidgets('el gráfico de asistencia cambia entre nacional y por sede y muestra el detalle', (tester) async {
    await abrir(tester, consola());

    expect(find.text('Asistencia por clase'), findsOneWidget);
    expect(find.byType(GraficoAsistencia), findsOneWidget);

    // Detalle de una clase al tocar el gráfico
    final lienzo = find.descendant(of: find.byType(GraficoAsistencia), matching: find.byType(CustomPaint)).last;
    await tester.tapAt(tester.getCenter(lienzo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Clase del'), findsOneWidget);
    expect(find.text('Nacional'), findsWidgets);

    await tester.tap(find.text('Por sede'));
    await tester.pumpAndSettle();
    expect(find.text('Sede Beauchef'), findsWidgets);
    expect(find.text('Sede San Joaquín'), findsWidgets);
  });

  testWidgets('la barra lateral navega por todas las secciones', (tester) async {
    await abrir(tester, consola());

    // Sin su repositorio, la nómina de alumnas no se muestra (ver alumnas_screens_test.dart)
    await irA(tester, 'Alumnas');
    expect(find.textContaining('necesita la conexión con la base de datos'), findsOneWidget);

    // Igual el voluntariado (ver voluntariado_roles_screens_test.dart)
    await irA(tester, 'Voluntariado');
    expect(find.text('El voluntariado necesita la conexión con la base de datos.'), findsOneWidget);

    await irA(tester, 'Exportar');
    expect(find.text('Exportar reportes'), findsOneWidget);
    expect(find.text('Vista previa'), findsOneWidget);

    await irA(tester, 'Auditoría');
    expect(find.text('3 eventos'), findsOneWidget);
  });

  testWidgets('sin la base, cada sección lo explica', (tester) async {
    await abrir(tester, const DirectorioDesktopScreen());
    expect(find.text('El dashboard necesita la conexión con la base de datos.'), findsOneWidget);
    await irA(tester, 'Exportar');
    expect(find.text('La exportación necesita la conexión con la base de datos.'), findsOneWidget);
    await irA(tester, 'Auditoría');
    expect(find.text('La auditoría necesita la conexión con la base de datos.'), findsOneWidget);
  });

  testWidgets('exportar descarga el archivo disociado y registra la descarga en la auditoría (US-21, US-22)', (tester) async {
    await abrir(tester, consola());
    await irA(tester, 'Exportar');

    expect(find.text('Mostrando 10 de 12 filas'), findsOneWidget);
    expect(find.text('22.341.890-2'), findsWidgets);

    await tester.tap(find.text('Exportar con datos disociados (anonimizado)'));
    await tester.pumpAndSettle();
    expect(find.text('ALUMNA-001'), findsWidgets);
    expect(find.text('22.341.890-2'), findsNothing);
    expect(reportes.vistasPrevias.last.disociado, isTrue);

    // Filtra por curso: la vista previa se pide con la instancia
    await tester.tap(find.byWidgetPredicate((w) => w is FiltroDesplegable && w.etiqueta == 'Curso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PCB · 2026-2 · Sede Beauchef').last);
    await tester.pumpAndSettle();
    expect(reportes.vistasPrevias.last.instanciaId, 'inst-pcb');

    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(find.textContaining('se descargó con 12 filas'), findsOneWidget);
    expect(reportes.exportaciones.single.$2, FormatoExportacion.csv);
    expect(ultimaDescarga!.nombre, startsWith('asistencia_disociado_'));
    expect(ultimaDescarga!.nombre, endsWith('.csv'));
    // CSV en UTF-8 con BOM: Excel respeta tildes y eñes (US-21 E2)
    expect(ultimaDescarga!.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(ultimaDescarga!.bytes.sublist(3)), startsWith('Sede,Curso,Alumna,Estado'));

    await irA(tester, 'Auditoría');
    expect(find.text('4 eventos'), findsOneWidget);
    expect(find.textContaining('Exportó asistencia en CSV'), findsOneWidget);
  });

  testWidgets('un filtro sin datos descarga solo los encabezados (US-22 E3)', (tester) async {
    reportes.vacio = true;
    await abrir(tester, DirectorioExportarView(repository: reportes, catalogo: catalogo));
    await tester.tap(find.text('Participación y ejercicios'));
    await tester.pumpAndSettle();
    expect(reportes.vistasPrevias.last.tipo, TipoReporte.participacion);
    expect(find.textContaining('No hay registros con estos filtros'), findsOneWidget);

    await tester.tap(find.text('Exportar XLSX'));
    await tester.pumpAndSettle();
    expect(find.textContaining('se descargó solo con los encabezados'), findsOneWidget);
    expect(ultimaDescarga!.nombre, endsWith('.xlsx'));
  });

  testWidgets('Gestión exporta con su sede fija y sin la nómina (US-21 E3)', (tester) async {
    await abrir(
      tester,
      DirectorioExportarView(repository: reportes, catalogo: catalogo, sedeFijaId: 'sede-a', permiteNomina: false),
    );
    expect(find.text('Nómina de alumnas'), findsNothing);
    expect(find.widgetWithText(Chip, 'Sede Beauchef'), findsOneWidget);
    expect(reportes.vistasPrevias.last.sedeId, 'sede-a');
  });

  testWidgets('si la base rechaza el reporte se muestra el motivo', (tester) async {
    reportes.rechazo = 'Solo puedes exportar datos de tu sede. El intento quedó registrado.';
    await abrir(tester, DirectorioExportarView(repository: reportes, catalogo: catalogo));
    expect(find.text('Solo puedes exportar datos de tu sede. El intento quedó registrado.'), findsOneWidget);
  });

  testWidgets('la auditoría filtra por tipo, usuaria y RUT, y muestra el detalle del cambio (US-24)', (tester) async {
    await abrir(tester, DirectorioAuditoriaView(repository: reportes));
    expect(find.text('3 eventos'), findsOneWidget);
    expect(find.text('Acceso denegado'), findsOneWidget);

    // ARCO: los eventos de una alumna por su RUT (E1)
    await tester.enterText(find.widgetWithText(TextField, 'RUT de alumna'), '223418902');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('1 evento'), findsOneWidget);

    // Detalle con el valor anterior y el nuevo (US-23 E1)
    await tester.tap(find.textContaining('estado: ausente → presente'));
    await tester.pumpAndSettle();
    expect(find.text('Valor anterior'), findsOneWidget);
    expect(find.text('Valor nuevo'), findsOneWidget);
    expect(find.textContaining('"presente"'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('3 eventos'), findsOneWidget);

    // Por usuaria o voluntaria (E2)
    await tester.enterText(find.widgetWithText(TextField, 'Usuaria (nombre o correo)'), 'fernanda');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('1 evento'), findsOneWidget);
    expect(find.text('Fernanda Pizarro León'), findsOneWidget);
  });

  testWidgets('la auditoría sin conexión lo explica', (tester) async {
    reportes.sinConexion = true;
    await abrir(tester, DirectorioAuditoriaView(repository: reportes));
    expect(find.textContaining('No pudimos consultar la auditoría'), findsOneWidget);
  });

  testWidgets('Ajustes de la Directiva: menú lateral y creación de una sede (US-01)', (tester) async {
    final themeNotifier = ValueNotifier(ThemeMode.light);
    final catalogo = FakeCatalogoRepository();
    await abrir(
      tester,
      AjustesDirectivaScreen(
        themeNotifier: themeNotifier,
        catalogoRepository: catalogo,
        rolesRepository: FakeRolesRepository(),
      ),
    );

    expect(find.text('Directiva Nacional'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Oscuro'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(themeNotifier.value, ThemeMode.dark);

    await irA(tester, 'Sedes');
    await tester.tap(find.text('Nueva sede'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la sede'), 'sede beauchéf');
    await tester.enterText(find.widgetWithText(TextFormField, 'Institución anfitriona'), 'U. de Concepción');
    await tester.enterText(find.widgetWithText(TextFormField, 'Región'), 'Biobío');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ya existe la sede "Sede Beauchef". Los nombres no distinguen tildes, mayúsculas ni signos.'),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la sede'), 'Sede Concepción');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Sede Concepción'), findsOneWidget);
    expect(find.text('Sin líder asignada'), findsOneWidget);

    await irA(tester, 'Cursos');
    await tester.tap(find.text('Nuevo curso'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Código institucional'), 'pcb');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Otro curso');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El código "PCB" ya está en uso.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Código institucional'), 'web');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('WEB'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar Otro curso'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Desarrollo Web Inicial');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Desarrollo Web Inicial'), findsOneWidget);

    await irA(tester, 'Instancias y sesiones');
    await tester.tap(find.text('Nueva instancia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sesiones con estado "programada"'), findsOneWidget);
    await tester.tap(find.text('Crear instancia'));
    await tester.pumpAndSettle();
    final creada = catalogo.listaInstancias.single;
    expect(creada.codigo, startsWith('PCB-'));
    expect(creada.codigo, endsWith('-BEAUCHEF'));
    expect(find.text(creada.codigo), findsOneWidget);

    // US-02 E3: la misma instancia pide confirmación y se crea como sección paralela
    await tester.tap(find.text('Nueva instancia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear instancia'));
    await tester.pumpAndSettle();
    expect(find.text('Esta instancia ya existe'), findsOneWidget);
    await tester.tap(find.text('Crear sección paralela'));
    await tester.pumpAndSettle();
    expect(catalogo.listaInstancias, hasLength(2));
    expect(find.text('${creada.codigo}-B'), findsOneWidget);
    expect(find.textContaining('Sección B'), findsOneWidget);

    await irA(tester, 'Roles de tutoras');
    expect(find.text('Presentar la Clase'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar Preparar el Kahoot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Preparar el Kahoot'), findsNothing);
  });
}

