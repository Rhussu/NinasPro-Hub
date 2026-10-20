import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/screens/alumna/portal_alumna_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes_directiva_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/ajustes_gestion_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/gestion_mobile_screen.dart';
import 'package:ninas_pro_hub/screens/hub_shell_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/ajustes_tutora_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/tutora_mobile_screen.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_mascot.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_skeleton.dart';
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

    testWidgets('TutoraMobileScreen main page: mi asistencia, rol de solo lectura y sin funciones de gestión (US-33, US-43)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        TutoraMobileScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      // Sin barra superior propia: la planificación de hoy va en el banner
      expect(find.text('TUTORA'), findsNothing);
      expect(find.byTooltip('Actualizar'), findsNothing);
      expect(find.text('Clase 4 · Sábado 25 de Abril'), findsOneWidget);
      expect(find.text('Hoy toca: Funciones y Modularización del Código'), findsOneWidget);
      expect(find.text('Programación Competitiva Básica (Python) · Sede Beauchef'), findsOneWidget);

      // Recargar deslizando hacia abajo: ~1 s descargando datos con esqueleto de carga
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await tester.pump(); // Termina el arrastre
      await tester.pump(const Duration(milliseconds: 300)); // Indicador en posición: inicia la recarga
      expect(find.byType(NinasProSkeletonInicio), findsOneWidget);
      expect(find.text('¡Hola, Daniela!'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(NinasProSkeletonInicio), findsNothing);
      expect(find.text('¡Hola, Daniela!'), findsOneWidget);
      expect(find.text('¡Hola, Daniela!'), findsOneWidget);
      expect(find.text('Alumnas presentes'), findsOneWidget);
      expect(find.text('Recursos del Curso'), findsOneWidget);

      // Rol de la semana: visible pero no editable
      expect(find.text('Tu rol esta semana · Semana 4'), findsOneWidget);
      expect(find.text('Presentar el Kahoot'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // Sin funciones exclusivas de Gestión
      expect(find.text('Justificativos pendientes'), findsNothing);
      expect(find.text('Alertas de deserción'), findsNothing);
      await tester.tap(find.byTooltip('Acciones rápidas'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ingresar justificativo'), findsNothing);
      expect(find.byTooltip('Asignar roles a tutoras'), findsNothing);
      expect(find.byTooltip('Asistencia de tutoras'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNWidgets(5)); // rayito + 4 acciones
      await tester.tap(find.byTooltip('Cerrar acciones rápidas'));
      await tester.pumpAndSettle();

      // Mi asistencia: registro individual de clases y roles
      final tarjetaMiAsistencia = find.ancestor(of: find.text('Mi asistencia'), matching: find.byType(Card));
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('8/8')), findsOneWidget);
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('100%')), findsOneWidget);
      await tester.tap(find.text('Mi asistencia'));
      await tester.pumpAndSettle();
      expect(find.text('Mi Asistencia'), findsOneWidget);
      expect(find.text('Semana 3 · 18/04'), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('Programada'), findsNWidgets(2)); // semanas 9 y 10
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('TutoraMobileScreen speed dial: asistencia P/A, Kahoot, ejercicios y fotos (US-13, US-18, US-28, US-29)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        TutoraMobileScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      Future<void> abrirAccion(String tooltip) async {
        await tester.tap(find.byTooltip('Acciones rápidas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }

      // Asistencia: alternar P ↔ A y guardar (US-13)
      await abrirAccion('Asistencia');
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);
      await tester.tap(find.text('Presente').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar Asistencia de la Clase'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Asistencia guardada'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Podio Kahoot (US-29)
      await abrirAccion('Registrar Kahoot');
      expect(find.text('Registrar Podio Kahoot (US-29)'), findsOneWidget);
      await tester.tap(find.text('Guardar Podio de la Sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar Podio Kahoot (US-29)'), findsNothing);
      final sesiones = await repository.getSesiones(cursoId: 'curso-pcb-stgo');
      expect(sesiones.firstWhere((s) => s.id == 'sesion-4').podioKahoot, isNotNull);

      // Ejercicios (US-28)
      await abrirAccion('Ejercicios');
      expect(find.textContaining('Mostrando únicamente a las alumnas Presentes'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Fotos (US-18, US-19)
      await abrirAccion('Fotos');
      expect(find.textContaining('Restricción de Imagen'), findsOneWidget);
      await tester.tap(find.textContaining('Tomar / Seleccionar Foto'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reemplazar Foto'), findsOneWidget);
    });

    testWidgets('PortalAlumnaScreen renders student dashboard, podio history, resources and justification (US-25, US-26, US-29, US-35)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        PortalAlumnaScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('¡Hola, Valentina!'), findsOneWidget);
      expect(find.text('Mi Asistencia Acumulada'), findsOneWidget);
      // Lo que toca hoy en el banner de bienvenida
      expect(find.text('Clase 4 · Sábado 25 de Abril'), findsOneWidget);
      expect(find.text('Hoy toca: Funciones y Modularización del Código'), findsOneWidget);
      expect(find.textContaining('Cumple meta'), findsOneWidget);

      // Course-wide resources: one Classroom and one Virtual Judge link (US-26)
      expect(find.text('Recursos del Curso'), findsOneWidget);
      expect(find.text('Google Classroom'), findsOneWidget);
      expect(find.text('Juez Virtual'), findsOneWidget);
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.tap(find.byTooltip('Copiar enlace').first);
      await tester.pumpAndSettle();
      expect(copiado, startsWith('https://classroom.google.com/'));
      expect(find.textContaining('Enlace copiado'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(ListView))).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Compact exercises card opens its detail bottom sheet
      await tester.tap(find.text('48'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperación por Ejercicios'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Compact podium card opens its detail bottom sheet (US-29)
      await tester.tap(find.text('🥇'));
      await tester.pumpAndSettle();
      expect(find.text('Historial de Podios Kahoot'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Scroll down to reveal Cronograma
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Cronograma de Clases (Sábados)'), findsOneWidget);
      expect(find.textContaining('Ver Recursos'), findsNothing);

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

    testWidgets('GestionMobileScreen main page shows pending justifications and alerts (US-37, US-39)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        GestionMobileScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('GESTIÓN SEDE'), findsNothing);
      expect(find.text('Hoy toca: Funciones y Modularización del Código'), findsOneWidget);
      expect(find.text('Alumnas presentes'), findsOneWidget);
      // Mi asistencia como tutora (US-33): Camila asistió a 7 de 8 clases
      expect(find.text('Mi asistencia'), findsOneWidget);
      final tarjetaMiAsistencia = find.ancestor(of: find.text('Mi asistencia'), matching: find.byType(Card));
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('7/8')), findsOneWidget);
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('88%')), findsOneWidget);
      // Abre mi registro individual (no la asistencia de todas las tutoras)
      await tester.tap(find.text('Mi asistencia'));
      await tester.pumpAndSettle();
      expect(find.text('Mi Asistencia'), findsOneWidget);
      expect(find.text('Asistencia de Tutoras'), findsNothing);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('Ausente'), findsOneWidget); // Camila faltó en la semana 5
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Saludo y rol semanal de la tutora de Gestión que usa la app (tutora-1)
      expect(find.text('¡Hola, Camila!'), findsOneWidget);
      expect(find.text('Tu rol esta semana · Semana 4'), findsOneWidget);
      expect(find.text('Foto y Asistencia'), findsOneWidget);

      // Recursos del curso (US-26)
      expect(find.text('Recursos del Curso'), findsOneWidget);
      expect(find.text('Google Classroom'), findsOneWidget);
      expect(find.text('Juez Virtual'), findsOneWidget);

      // Justificativos pendientes (US-37)
      expect(find.text('Justificativos pendientes'), findsOneWidget);
      expect(find.text('Evaluar Justificativo'), findsWidgets);
      await tester.tap(find.text('Evaluar Justificativo').first);
      await tester.pumpAndSettle();
      expect(find.text('Revisar Justificativo (US-37)'), findsOneWidget);
      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Justificativo aprobado'), findsOneWidget);

      // Alertas de deserción activas (US-39)
      expect(find.text('Alertas de deserción'), findsOneWidget);
      expect(find.textContaining('inasistencias consecutivas'), findsWidgets);
    });

    testWidgets('GestionMobileScreen speed dial opens tutor and class screens (US-13, US-29, US-33, US-43)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        GestionMobileScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      Future<void> abrirAccion(String tooltip) async {
        await tester.tap(find.byTooltip('Acciones rápidas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }

      // Roles semanales de tutoras (US-43)
      await abrirAccion('Asignar roles a tutoras');
      expect(find.text('Roles de Tutoras'), findsOneWidget);
      expect(find.text('Semana 4'), findsOneWidget);
      expect(find.text('Semana actual'), findsOneWidget);
      expect(find.textContaining('Roles obligatorios sin cubrir'), findsOneWidget);
      await tester.tap(find.byTooltip('Semana siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Semana 5'), findsOneWidget);
      expect(find.textContaining('0 de 8 tutoras con rol asignado'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Asistencia de tutoras con rol semanal (US-33, US-43)
      await abrirAccion('Asistencia de tutoras');
      expect(find.text('Semana 4 · 25/04'), findsOneWidget);
      expect(find.text('Clase actual'), findsOneWidget);
      expect(find.text('Guardar Asistencia de Tutoras'), findsOneWidget);
      expect(find.text('Foto y Asistencia'), findsOneWidget); // rol de Camila en semana 4
      expect(find.text('Sin rol asignado'), findsWidgets);
      // Historial: semana 3 (solo lectura, con el rol que tuvo cada tutora)
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Semana 3 · 18/04'), findsOneWidget);
      expect(find.text('Historial · solo lectura'), findsOneWidget);
      expect(find.text('Guardar Asistencia de Tutoras'), findsNothing);
      expect(find.text('7 Presentes'), findsOneWidget);
      expect(find.text('1 Ausentes'), findsOneWidget);
      expect(find.text('Coordinar Actividad Práctica'), findsOneWidget); // rol de Camila en semana 3
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Asistencia de alumnas compartida con Tutora (US-13) con historial
      await abrirAccion('Asistencia');
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Historial · solo lectura'), findsOneWidget);
      expect(find.text('Guardar Asistencia de la Clase'), findsNothing);
      expect(find.text('1 Ausentes'), findsOneWidget); // Valentina faltó en la semana 3
      // Volver a la clase actual
      await tester.tap(find.byTooltip('Volver a la clase actual'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Podio Kahoot (US-29)
      await abrirAccion('Registrar Kahoot');
      expect(find.text('Registrar Podio Kahoot (US-29)'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // cerrar modal
      await tester.pumpAndSettle();

      // Justificativo manual aprobado de inmediato (US-37)
      await abrirAccion('Ingresar justificativo');
      expect(find.text('Ingresar Justificativo'), findsOneWidget);
      await tester.tap(find.text('Registrar y Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Debes ingresar la descripción del justificativo.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Apoderada avisó por WhatsApp.');
      await tester.tap(find.text('Registrar y Aprobar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Justificativo registrado y aprobado'), findsOneWidget);
    });

    testWidgets('AjustesGestionScreen muestra perfil de la tutora sin sección de apoderado', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        AjustesGestionScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Camila Sepúlveda Rivas'), findsOneWidget);
      expect(find.text('MI PERFIL'), findsOneWidget);
      expect(find.text('Adhesión voluntaria'), findsOneWidget);
      expect(find.text('APODERADO/A'), findsNothing);
    });

    testWidgets('AjustesTutoraScreen muestra perfil de la tutora con su rol', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        AjustesTutoraScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Daniela Valenzuela Castro'), findsOneWidget);
      expect(find.textContaining('Tutora'), findsWidgets);
      expect(find.text('MI PERFIL'), findsOneWidget);
      expect(find.text('Adhesión voluntaria'), findsOneWidget);
      expect(find.text('APODERADO/A'), findsNothing);
    });

    testWidgets('AjustesDirectivaScreen muestra el perfil de la Directiva y la apariencia', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final themeNotifier = ValueNotifier(ThemeMode.dark);
      await tester.pumpWidget(createTestApp(
        AjustesDirectivaScreen(repository: repository, themeNotifier: themeNotifier),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Directiva Nacional'), findsOneWidget);
      expect(find.text('APARIENCIA'), findsOneWidget);
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(themeNotifier.value, ThemeMode.light);
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

      // Nubecita junto a Ajustes: conexión y cambios pendientes
      Future<void> guardarPodio() => repository.guardarPodioKahoot(
            sesionId: 'sesion-4',
            primerLugarAlumnaId: 'alumna-1',
            segundoLugarAlumnaId: 'alumna-2',
            tercerLugarAlumnaId: 'alumna-3',
          );
      expect(find.byTooltip('Conectado · todo guardado en la nube'), findsOneWidget);
      await guardarPodio();
      await tester.pump();
      expect(find.byTooltip('Conectado · todo guardado en la nube'), findsOneWidget);

      // Mockup: se simula que se cae internet desde el menú de la nube
      await tester.tap(find.byTooltip('Conectado · todo guardado en la nube'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simular sin conexión'));
      await tester.pumpAndSettle();
      await guardarPodio();
      await tester.pump();
      expect(find.byTooltip('Sin conexión · 1 cambio pendiente'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(HubShellScreen))).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      // Vuelve la conexión: se suben los pendientes solos
      await tester.tap(find.byTooltip('Sin conexión · 1 cambio pendiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recuperar conexión'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Subiendo 1 cambio pendiente…'), findsOneWidget);
      await tester.pump(MockHubRepository.demoraSincronizacion);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Conectado · todo guardado en la nube'), findsOneWidget);
      expect(find.text('☁️ Volvió la conexión: 1 cambio subido a la nube.'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(HubShellScreen))).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      // Rol inicial: Gestión
      expect(find.text('¡Hola, Camila!').hitTestable(), findsOneWidget);

      // Cambio de rol mediante el selector (PopupMenuButton) del AppBar
      Future<void> cambiarRol(String item) async {
        await tester.tap(find.byType(PopupMenuButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
      }

      // Switch to Tutora
      await cambiarRol('Tutora (Móvil)');
      expect(find.text('¡Hola, Daniela!').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Daniela Valenzuela Castro'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Switch to Alumna
      await cambiarRol('Alumna (Móvil)');
      expect(find.text('Mi Asistencia Acumulada').hitTestable(), findsOneWidget);

      // Switch to Directiva Desktop
      await cambiarRol('Directiva (Desktop)');

      // Now we should be in Desktop mode (DirectorioDesktopScreen)
      expect(find.text('NiñasPro Hub · Directiva Desktop'), findsOneWidget);
      expect(find.text('Dashboard nacional'), findsOneWidget);
      expect(find.byTooltip('Conectado · todo guardado en la nube'), findsOneWidget);

      // Toggle Theme desde Ajustes
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Directiva Nacional'), findsOneWidget);
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(themeNotifier.value, ThemeMode.light);
    });
  });
}
