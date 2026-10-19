import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/screens/alumna/portal_alumna_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_mobile_screen.dart';
import 'package:ninas_pro_hub/screens/hub_shell_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/pase_lista_screen.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_mascot.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_mobile_shell.dart';
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

    testWidgets('PaseListaScreen allows fast roll call, tab switching and saving (US-13, US-28)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        PaseListaScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PCB-2026'), findsOneWidget);
      expect(find.text('Clase 04 · Python'), findsOneWidget);
      expect(find.textContaining('Presentes'), findsWidgets);
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);

      // Cycle attendance on first student
      final presentButtons = find.text('Presente');
      expect(presentButtons, findsWidgets);
      await tester.tap(presentButtons.first);
      await tester.pumpAndSettle();

      // Tap Guardar Asistencia
      final guardarButton = find.text('Guardar Asistencia de la Clase');
      await tester.tap(guardarButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Asistencia guardada'), findsOneWidget);

      // Switch to Ejercicios tab
      await tester.tap(find.text('Ejercicios'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mostrando únicamente a las alumnas Presentes'), findsOneWidget);

      // Switch to Fotos tab
      await tester.tap(find.text('Fotos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Restricción de Imagen'), findsOneWidget);
      expect(find.textContaining('Tomar / Seleccionar Foto'), findsOneWidget);

      await tester.tap(find.textContaining('Tomar / Seleccionar Foto'));
      await tester.pump();
      expect(find.textContaining('Reemplazar Foto'), findsOneWidget);
      await tester.pumpAndSettle();

      // Switch to Tutoras tab
      await tester.tap(find.text('Tutoras'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pase de Lista de Tutoras'), findsOneWidget);
      expect(find.text('Camila Sepúlveda Rivas'), findsOneWidget);
    });

    testWidgets('PortalAlumnaScreen renders student dashboard and justifications (US-25, US-35)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        PortalAlumnaScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('¡Hola, Valentina!'), findsOneWidget);
      expect(find.text('Mi Asistencia Acumulada'), findsOneWidget);
      expect(find.textContaining('Cumple meta'), findsOneWidget);
      expect(find.text('🏆 Kahoot'), findsOneWidget);
      expect(find.text('Cronograma de Clases (Sábados)'), findsOneWidget);

      // Open justification bottom sheet
      final justificarButton = find.text('Justificar Falta');
      expect(justificarButton, findsOneWidget);
      await tester.tap(justificarButton);
      await tester.pumpAndSettle();

      expect(find.text('Justificar Inasistencia (US-35)'), findsOneWidget);
      expect(find.text('Motivo tipificado:'), findsOneWidget);

      // Fill and submit
      await tester.enterText(find.byType(TextField), 'Motivo de salud verificado');
      await tester.tap(find.text('Enviar Justificativo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Justificativo enviado'), findsOneWidget);
    });

    testWidgets('DirectorioMobileScreen renders KPIs, roster, alerts and justifications (US-01, US-09, US-40)', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(
        DirectorioMobileScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Panel de Gestión y Sedes'), findsOneWidget);
      expect(find.text('Alumnas Activas'), findsOneWidget);
      expect(find.text('Santiago - Beauchef'), findsOneWidget);

      // Switch to Nómina tab
      await tester.tap(find.text('Nómina'));
      await tester.pumpAndSettle();
      expect(find.text('Valentina Soto Morales'), findsOneWidget);

      // Search student
      await tester.enterText(find.byType(TextField), 'Florencia');
      await tester.pumpAndSettle();
      expect(find.text('Florencia Muñoz Tapia'), findsOneWidget);

      // Open Ficha Única Bottom Sheet (US-09)
      await tester.tap(find.text('Florencia Muñoz Tapia'));
      await tester.pumpAndSettle();
      expect(find.text('RUT: 21.904.331-K'), findsOneWidget);
      expect(find.text('Datos del Apoderado (Contacto)'), findsOneWidget);

      // Close bottom sheet by dragging down or tapping barrier
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Switch to Alertas tab (US-40)
      await tester.tap(find.text('Alertas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Acompañamiento sin estigmatizar'), findsOneWidget);
      expect(find.text('Contactar Apoderado y Resolver Alerta'), findsOneWidget);

      // Resolve alert
      await tester.tap(find.text('Contactar Apoderado y Resolver Alerta'));
      await tester.pumpAndSettle();
      expect(find.text('Contacto Preventivo (US-40)'), findsOneWidget);

      await tester.tap(find.text('Marcar Atendida'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Alerta resuelta'), findsOneWidget);

      // Switch to Justificativos tab (US-37)
      await tester.tap(find.text('Justificativos'));
      await tester.pumpAndSettle();
      expect(find.text('Catalina Reyes Navarrete'), findsOneWidget);
      expect(find.text('Aprobar'), findsOneWidget);
      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
    });

    testWidgets('HubShellScreen navigates between roles and toggles theme and shell frame', (WidgetTester tester) async {
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
      expect(find.text('MOCKUP'), findsOneWidget);

      // Bottom bar has Gestión, Tutora, Alumna
      expect(find.text('Gestión'), findsOneWidget);
      expect(find.text('Tutora'), findsOneWidget);
      expect(find.text('Alumna'), findsOneWidget);

      // Switch to Gestión
      await tester.tap(find.text('Gestión'));
      await tester.pumpAndSettle();
      expect(find.text('Panel de Gestión y Sedes'), findsOneWidget);

      // Switch to Alumna
      await tester.tap(find.text('Alumna'));
      await tester.pumpAndSettle();
      expect(find.text('Portal de la Alumna'), findsOneWidget);

      // Toggle Theme
      final themeButton = find.byTooltip('Cambiar a Modo Claro');
      expect(themeButton, findsOneWidget);
      await tester.tap(themeButton);
      expect(themeNotifier.value, ThemeMode.light);

      // Toggle Desktop/Mobile frame
      final frameButton = find.byTooltip('Alternar vista completa / teléfono');
      if (frameButton.evaluate().isNotEmpty) {
        await tester.tap(frameButton);
        await tester.pumpAndSettle();
      }
    });
  });
}
