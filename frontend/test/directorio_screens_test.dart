import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes_directiva_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_desktop_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_grafico_asistencia.dart';

import 'fakes/fake_catalogo_repository.dart';
import 'fakes/fake_roles_repository.dart';

/// Vista de escritorio de la Directiva Nacional y sus Ajustes
void main() {
  late MockHubRepository repository;

  setUp(() {
    repository = MockHubRepository();
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

  testWidgets('el dashboard muestra los indicadores nacionales y por sede, sin alertas ni justificativos', (tester) async {
    await abrir(tester, DirectorioDesktopScreen(repository: repository));

    expect(find.text('Dashboard nacional'), findsOneWidget);
    expect(find.text('Alumnas activas'), findsOneWidget);
    // 8 de Beauchef + 3 de San Joaquín + 3 de Valparaíso
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Sede San Joaquín'), findsOneWidget);
    expect(find.text('Sede Valparaíso'), findsWidgets);
    // Alertas y justificativos son del Equipo de Gestión, no de la Directiva
    expect(find.text('Sofía Araya Bravo'), findsNothing);
    expect(find.text('Justificativos pendientes'), findsNothing);
  });

  testWidgets('el gráfico de asistencia cambia entre nacional y por sede y muestra el detalle', (tester) async {
    await abrir(tester, DirectorioDesktopScreen(repository: repository));

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
    await abrir(tester, DirectorioDesktopScreen(repository: repository));

    // Sin la base de datos, la nómina de alumnas no se muestra (ver alumnas_screens_test.dart)
    await irA(tester, 'Alumnas');
    expect(find.textContaining('necesita la conexión con la base de datos'), findsOneWidget);

    // Igual el voluntariado (ver voluntariado_roles_screens_test.dart)
    await irA(tester, 'Voluntariado');
    expect(find.text('El voluntariado necesita la conexión con la base de datos.'), findsOneWidget);

    await irA(tester, 'Exportar');
    expect(find.text('Exportar reportes'), findsOneWidget);
    expect(find.textContaining('Vista previa'), findsOneWidget);

    await irA(tester, 'Auditoría');
    expect(find.text('16 eventos'), findsOneWidget);
  });

  testWidgets('exportar registra la descarga en la auditoría (US-22)', (tester) async {
    await abrir(tester, DirectorioDesktopScreen(repository: repository));
    await irA(tester, 'Exportar');

    await tester.tap(find.text('Exportar con datos disociados (anonimizado)'));
    await tester.pumpAndSettle();
    expect(find.text('ALUMNA-001'), findsWidgets);

    await tester.tap(find.text('Exportar XLSX'));
    await tester.pumpAndSettle();
    expect(find.textContaining('registrada en la auditoría'), findsOneWidget);

    await irA(tester, 'Auditoría');
    expect(find.text('17 eventos'), findsOneWidget);
  });

  testWidgets('Ajustes de la Directiva: menú lateral y creación de una sede (US-01)', (tester) async {
    final themeNotifier = ValueNotifier(ThemeMode.light);
    final catalogo = FakeCatalogoRepository();
    await abrir(
      tester,
      AjustesDirectivaScreen(
        repository: repository,
        themeNotifier: themeNotifier,
        catalogoRepository: catalogo,
        rolesRepository: FakeRolesRepository(),
      ),
    );

    expect(find.text('Directiva Nacional'), findsOneWidget);
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
