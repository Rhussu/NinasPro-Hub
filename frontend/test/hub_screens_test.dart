import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/screens/alumna/portal_alumna_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_desktop_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/gestion_mobile_screen.dart';
import 'package:ninas_pro_hub/screens/hub_shell_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/pase_lista_screen.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_mascot.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_stat_card.dart';

void main() {
  group('Mockup Screens & Widgets Tests', () {
    late MockHubRepository repository;

    setUp(() {
      repository = MockHubRepository();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        theme: NinasProTheme.light,
        darkTheme: NinasProTheme.dark,
        themeMode: ThemeMode.dark,
        home: child,
      );
    }

    testWidgets('NinasProMascot renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        const Scaffold(body: Center(child: NinasProMascot(size: 80))),
      ));
      expect(find.byType(NinasProMascot), findsOneWidget);
    });

    testWidgets('NinasProStatCard renders and responds to tap', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestApp(
        Scaffold(
          body: NinasProStatCard(
            title: 'Alumnas',
            value: '78',
            subtitle: 'En sede',
            icon: Icons.school,
            onTap: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('Alumnas'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
      expect(find.text('En sede'), findsOneWidget);

      await tester.tap(find.byType(NinasProStatCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('PaseListaScreen toggles P ↔ A, opens Kahoot podium modal and saves (US-13, US-28, US-29)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        PaseListaScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PCB-2026'), findsOneWidget);
      expect(find.text('Clase 04 · Python'), findsOneWidget);
      expect(find.textContaining('Presentes'), findsWidgets);
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);

      // Toggle first student (should cycle from Presente to Ausente)
      final presentButtons = find.text('Presente');
      expect(presentButtons, findsWidgets);
      await tester.tap(presentButtons.first);
      await tester.pumpAndSettle();

      // Tap Guardar Asistencia
      final guardarButton = find.text('Guardar Asistencia de la Clase');
      await tester.tap(guardarButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Asistencia guardada'), findsOneWidget);

      // Open Kahoot podium registration from FloatingActionButton (US-29)
      final kahootFab = find.byType(FloatingActionButton);
      expect(kahootFab, findsOneWidget);
      await tester.tap(kahootFab);
      await tester.pumpAndSettle();
      expect(find.text('Registrar Podio Kahoot (US-29)'), findsOneWidget);
      expect(find.text('Guardar Podio de la Sesión'), findsOneWidget);

      await tester.tap(find.text('Guardar Podio de la Sesión'));
      await tester.pumpAndSettle();

      // Switch to Ejercicios tab
      await tester.tap(find.text('Ejercicios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mostrando únicamente a las alumnas Presentes'), findsOneWidget);

      // Switch to Fotos tab
      await tester.tap(find.text('Fotos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Restricción de Imagen'), findsOneWidget);

      await tester.drag(find.byType(TabBarView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final tomarFotoBtn = find.textContaining('Tomar / Seleccionar Foto');
      await tester.tap(tomarFotoBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Reemplazar Foto'), findsOneWidget);
    });

    testWidgets('PortalAlumnaScreen renders student dashboard, podio history, resources and justification (US-25, US-26, US-29, US-35)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        PortalAlumnaScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('¡Hola, Valentina!'), findsOneWidget);
      expect(find.text('Mi Asistencia Acumulada'), findsOneWidget);
      expect(find.textContaining('Cumple meta'), findsOneWidget);
      expect(find.text('Recuperación por Ejercicios'), findsOneWidget);

      // Scroll down to reveal Cronograma
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Cronograma de Clases y Recursos (Sábados)'), findsOneWidget);

      // Open educational resources bottom sheet (US-26)
      final verRecursosButton = find.text('Ver Recursos (US-26)').first;
      await tester.tap(verRecursosButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Recursos: Clase #1'), findsOneWidget);
      expect(find.text('HTTPS'), findsWidgets);

      // Close bottom sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Open justification bottom sheet (US-35)
      final justificarButton = find.text('Justificar Falta');
      expect(justificarButton, findsOneWidget);
      await tester.tap(justificarButton);
      await tester.pumpAndSettle();

      expect(find.text('Justificar Inasistencia (US-35)'), findsOneWidget);
      expect(find.text('¿A qué clase faltarás? (Fecha del Sábado):'), findsOneWidget);
      expect(find.text('Motivo tipificado:'), findsOneWidget);

      // Fill and submit
      await tester.enterText(find.byType(TextField), 'Motivo verificado por la alumna');
      await tester.tap(find.text('Enviar Justificativo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Justificativo enviado'), findsOneWidget);
    });

    testWidgets('GestionMobileScreen renders justifications, role assignments, tutors and alerts (US-37, US-43, US-33)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        GestionMobileScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('GESTIÓN SEDE'), findsOneWidget);
      expect(find.text('Coordinación de Aula'), findsOneWidget);
      expect(find.text('Justificativos'), findsOneWidget);
      expect(find.text('Roles Tutores'), findsOneWidget);

      // Switch to Roles Tutores tab (US-43)
      await tester.tap(find.text('Roles Tutores'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Asignación semanal de roles a tutoras'), findsOneWidget);

      // Switch to Tutoras Sede tab (US-33)
      await tester.tap(find.text('Tutoras Sede'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Supervisión y Asistencia de Tutoras'), findsOneWidget);

      // Switch to Alertas tab
      await tester.tap(find.text('Alertas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('inasistencias consecutivas'), findsWidgets);
    });

    testWidgets('DirectorioDesktopScreen renders executive dashboard, sedes, roster, alerts and dynamic roles (US-01, US-09, US-40, US-43)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        DirectorioDesktopScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard de Operaciones y Métricas'), findsOneWidget);
      expect(find.text('Alumnas Activas'), findsOneWidget);
      expect(find.text('Asistencia Global'), findsOneWidget);
      expect(find.text('Estado Operativo por Sede'), findsOneWidget);

      // Switch to Sedes y Cursos
      await tester.tap(find.text('Sedes y Cursos'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo de Sedes Territoriales (US-01)'), findsOneWidget);

      // Switch to Nómina y Ficha Única
      await tester.tap(find.text('Nómina y Ficha Única'));
      await tester.pumpAndSettle();
      expect(find.text('Valentina Soto Morales'), findsOneWidget);

      // Switch to Alertas Deserción
      await tester.tap(find.text('Alertas Deserción'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Monitoreo Confidencial de Riesgo de Deserción'), findsOneWidget);

      // Switch to Roles Dinámicos (US-43)
      await tester.tap(find.text('Roles Dinámicos'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo de Roles Dinámicos de Tutoras (US-43)'), findsOneWidget);
      expect(find.text('Crear Nuevo Rol'), findsOneWidget);
    });

    testWidgets('HubShellScreen navigates between 4 roles and toggles theme', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final themeNotifier = ValueNotifier(ThemeMode.dark);

      await tester.pumpWidget(MaterialApp(
        theme: NinasProTheme.light,
        darkTheme: NinasProTheme.dark,
        themeMode: ThemeMode.dark,
        home: HubShellScreen(
          repository: repository,
          themeNotifier: themeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('NiñasPro Hub'), findsOneWidget);

      // Bottom bar has Gestión, Tutora, Alumna
      expect(find.widgetWithText(NavigationDestination, 'Gestión'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Tutora'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Alumna'), findsOneWidget);

      // Switch to Gestión
      await tester.tap(find.widgetWithText(NavigationDestination, 'Gestión'));
      await tester.pumpAndSettle();
      expect(find.text('GESTIÓN SEDE'), findsOneWidget);

      // Switch to Alumna
      await tester.tap(find.widgetWithText(NavigationDestination, 'Alumna'));
      await tester.pumpAndSettle();
      expect(find.text('Portal de la Alumna'), findsOneWidget);

      // Switch to Directiva Desktop using Popup Menu
      final roleDropdown = find.byType(PopupMenuButton<int>);
      await tester.tap(roleDropdown);
      await tester.pumpAndSettle();

      final directivaItem = find.text('Directiva (Desktop)');
      expect(directivaItem, findsOneWidget);
      await tester.tap(directivaItem);
      await tester.pumpAndSettle();

      // Now we should be in Desktop mode (DirectorioDesktopScreen)
      expect(find.text('NiñasPro Hub · Directiva Desktop'), findsOneWidget);
      expect(find.text('Dashboard Global'), findsOneWidget);

      // Toggle Theme
      final themeButton = find.byTooltip('Cambiar a Modo Claro');
      expect(themeButton, findsOneWidget);
      await tester.tap(themeButton);
      expect(themeNotifier.value, ThemeMode.light);
    });
  });
}
