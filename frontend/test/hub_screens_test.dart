import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/repositories/clase_repository.dart';
import 'package:ninas_pro_hub/repositories/mock_hub_repository.dart';
import 'package:ninas_pro_hub/screens/alumna/portal_alumna_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes_directiva_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/ajustes_gestion_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/gestion_mobile_screen.dart';
import 'package:ninas_pro_hub/screens/hub_shell_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/ajustes_tutora_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/clase_sesion_views.dart';
import 'package:ninas_pro_hub/screens/tutora/tutora_mobile_screen.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_mascot.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_stat_card.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_clase_repository.dart';

void main() {
  group('Mockup Screens & Widgets Tests', () {
    late MockHubRepository repository;
    late FakeClaseRepository clase;

    setUp(() {
      repository = MockHubRepository();
      clase = FakeClaseRepository();
    });

    tearDown(() => clase.cerrar());

    // Deja pasar los avisos (SnackBar) para que no tapen la barra inferior de la siguiente pantalla
    Future<void> cerrarAvisos(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    }

    // Espera un Future de la app avanzando el tiempo simulado (sembast usa timers)
    Future<T> esperar<T>(WidgetTester tester, Future<T> futuro) async {
      var listo = false;
      futuro.whenComplete(() => listo = true).ignore();
      for (var i = 0; i < 50 && !listo; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return futuro;
    }

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
        TutoraMobileScreen(repository: repository, clase: clase, sesion: SesionesDemo.tutora),
      ));
      await tester.pumpAndSettle();

      // Sin barra superior propia: la planificación de hoy va en el banner
      expect(find.text('TUTORA'), findsNothing);
      expect(find.byTooltip('Actualizar'), findsNothing);
      expect(find.textContaining('Clase 4 · '), findsOneWidget);
      expect(find.text('Hoy toca: Funciones y Modularización del Código'), findsOneWidget);
      expect(find.text('Programación Competitiva Básica (Python) · Sede Beauchef'), findsOneWidget);

      // Recargar deslizando hacia abajo vuelve a traer la clase
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('¡Hola, Daniela!'), findsOneWidget);
      expect(find.text('Alumnas presentes'), findsOneWidget);
      expect(find.text('—/4'), findsOneWidget); // aún sin pase de lista
      expect(find.text('Sin pase de lista'), findsOneWidget);
      expect(find.text('Recursos del Curso'), findsOneWidget);

      // Rol de la semana (aún del mockup): visible pero no editable
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

      // Mi asistencia: Daniela asistió a las 3 clases realizadas
      final tarjetaMiAsistencia = find.ancestor(of: find.text('Mi asistencia'), matching: find.byType(Card));
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('3/3')), findsOneWidget);
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('100%')), findsOneWidget);
      await tester.tap(find.text('Mi asistencia'));
      await tester.pumpAndSettle();
      expect(find.text('Mi Asistencia'), findsOneWidget);
      expect(find.textContaining('Semana 3 · '), findsOneWidget);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('Programada'), findsNWidgets(7)); // semanas 4 a 10
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('TutoraMobileScreen speed dial: asistencia P/A, Kahoot, ejercicios y fotos (US-13, US-18, US-28, US-29)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        TutoraMobileScreen(repository: repository, clase: clase, sesion: SesionesDemo.tutora),
      ));
      await tester.pumpAndSettle();

      Future<void> abrirAccion(String tooltip) async {
        await tester.tap(find.byTooltip('Acciones rápidas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }

      // Antes del pase de lista no hay podio ni ejercicios
      await abrirAccion('Registrar Kahoot');
      expect(find.textContaining('Guarda primero el pase de lista: el podio Kahoot'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Asistencia: todas parten presentes; alternar P ↔ A y guardar (US-13)
      await abrirAccion('Asistencia');
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);
      expect(find.text('4 Presentes'), findsOneWidget);
      await tester.tap(find.text('Presente').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar Asistencia de la Clase'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Asistencia guardada: 3 presentes, 1 ausentes'), findsOneWidget);
      expect(find.textContaining('Última edición: Daniela Valenzuela Castro'), findsOneWidget);
      expect(clase.estadoAlumna('clase-4', 'insc-1'), EstadoAsistencia.ausente);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('3/4'), findsOneWidget);

      // Podio Kahoot con las presentes (US-29)
      await abrirAccion('Registrar Kahoot');
      expect(find.text('Registrar Podio Kahoot (US-29)'), findsOneWidget);
      await tester.tap(find.text('Guardar Podio de la Sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar Podio Kahoot (US-29)'), findsNothing);
      expect(clase.podio('clase-4'), ['insc-2', 'insc-3', 'insc-4']);
      await cerrarAvisos(tester);

      // Ejercicios solo de las presentes, y se guardan (US-28)
      await abrirAccion('Ejercicios');
      expect(find.textContaining('Mostrando únicamente a las alumnas Presentes'), findsOneWidget);
      expect(find.text('Valentina Soto Morales'), findsNothing);
      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar Ejercicios y Participación'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ejercicios y participación guardados'), findsOneWidget);
      expect(clase.participacion('clase-4', 'insc-2'), (1, false));
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Fotos (US-18, US-19): Josefa está presente y no autoriza fotos
      await abrirAccion('Fotos');
      expect(find.textContaining('Restricción de Imagen'), findsOneWidget);
      expect(find.textContaining('Josefa Muñoz Vera'), findsOneWidget);
      await tester.tap(find.textContaining('Tomar / Seleccionar Foto'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reemplazar Foto'), findsOneWidget);
    });

    testWidgets('El podio Kahoot lleva un lugar por alumna presente: con una sola, queda primera (US-29)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        TutoraMobileScreen(repository: repository, clase: clase, sesion: SesionesDemo.tutora),
      ));
      await tester.pumpAndSettle();

      Future<void> abrirAccion(String tooltip) async {
        await tester.tap(find.byTooltip('Acciones rápidas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }

      // Alterna el estado de cada alumna nombrada y guarda
      Future<void> pasarLista(List<String> alternar) async {
        await abrirAccion('Asistencia');
        for (final nombre in alternar) {
          final tarjeta = find.ancestor(of: find.text(nombre), matching: find.byType(TarjetaAsistencia));
          await tester.tap(find.descendant(of: tarjeta, matching: find.byType(InkWell)));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Guardar Asistencia de la Clase'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await cerrarAvisos(tester);
      }

      // Dos presentes (Catalina y Antonia): se elige el 1° y el 2° lugar
      await pasarLista(['Valentina Soto Morales', 'Josefa Muñoz Vera']);
      await abrirAccion('Registrar Kahoot');
      expect(find.text('Asigna las 2 alumnas ganadoras del desafío de hoy. Se actualizará su historial.'), findsOneWidget);
      expect(find.text('🥈 2° Lugar (Medalla de Plata):'), findsOneWidget);
      expect(find.text('🥉 3° Lugar (Medalla de Bronce):'), findsNothing);
      await tester.tap(find.text('Guardar Podio de la Sesión'));
      await tester.pumpAndSettle();
      expect(clase.podio('clase-4'), ['insc-2', 'insc-4']);
      await cerrarAvisos(tester);

      // Una sola presente (Antonia): queda primera
      await pasarLista(['Catalina Rojas Díaz']);
      await abrirAccion('Registrar Kahoot');
      expect(find.textContaining('Hoy hay una sola alumna presente: queda en el 1° lugar.'), findsOneWidget);
      expect(find.text('🥈 2° Lugar (Medalla de Plata):'), findsNothing);
      await tester.tap(find.text('Guardar Podio de la Sesión'));
      await tester.pumpAndSettle();
      expect(clase.podio('clase-4'), ['insc-4']);
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
        GestionMobileScreen(repository: repository, clase: clase, sesion: SesionesDemo.gestion),
      ));
      await tester.pumpAndSettle();

      expect(find.text('GESTIÓN SEDE'), findsNothing);
      expect(find.text('Hoy toca: Funciones y Modularización del Código'), findsOneWidget);
      expect(find.text('Alumnas presentes'), findsOneWidget);
      // Mi asistencia como tutora (US-33): Camila asistió a 2 de 3 clases
      expect(find.text('Mi asistencia'), findsOneWidget);
      final tarjetaMiAsistencia = find.ancestor(of: find.text('Mi asistencia'), matching: find.byType(Card));
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('2/3')), findsOneWidget);
      expect(find.descendant(of: tarjetaMiAsistencia, matching: find.text('67%')), findsOneWidget);
      // Abre mi registro individual (no la asistencia de todas las tutoras)
      await tester.tap(find.text('Mi asistencia'));
      await tester.pumpAndSettle();
      expect(find.text('Mi Asistencia'), findsOneWidget);
      expect(find.text('Asistencia de Tutoras'), findsNothing);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('Ausente'), findsOneWidget); // Camila faltó en la semana 2
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Saludo y rol semanal (aún del mockup: tutora-1)
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

    testWidgets('GestionMobileScreen speed dial opens tutor and class screens (US-13, US-15, US-29, US-33, US-43)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      clase.perfilId = 'perfil-camila';
      await tester.pumpWidget(createTestApp(
        GestionMobileScreen(repository: repository, clase: clase, sesion: SesionesDemo.gestion),
      ));
      await tester.pumpAndSettle();

      Future<void> abrirAccion(String tooltip) async {
        await tester.tap(find.byTooltip('Acciones rápidas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }

      // Roles semanales de tutoras (US-43, aún del mockup)
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

      // Asistencia de tutoras: el equipo parte presente y se guarda (US-33)
      await abrirAccion('Asistencia de tutoras');
      expect(find.textContaining('Semana 4 · '), findsOneWidget);
      expect(find.text('Clase actual'), findsOneWidget);
      expect(find.text('3 Presentes'), findsOneWidget);
      await tester.tap(find.text('Presente').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar Asistencia de Tutoras'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Asistencia de tutoras guardada: 2 de 3 presentes'), findsOneWidget);
      expect(clase.estadoTutora('clase-4', 'perfil-javiera'), EstadoAsistencia.ausente);
      // Historial: semana 2 (Camila faltó) y corrección posterior (US-33 escenario 3)
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Semana 2 · '), findsOneWidget);
      expect(find.text('Historial · solo lectura'), findsOneWidget);
      expect(find.text('2 Presentes'), findsOneWidget);
      expect(find.text('1 Ausentes'), findsOneWidget);
      await cerrarAvisos(tester);
      await tester.tap(find.text('Corregir lista'));
      await tester.pumpAndSettle();
      expect(find.text('Historial · corrigiendo'), findsOneWidget);
      await tester.tap(find.text('Ausente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar Corrección'));
      await tester.pumpAndSettle();
      expect(clase.estadoTutora('clase-2', 'perfil-camila'), EstadoAsistencia.presente);
      expect(find.text('3 Presentes'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Asistencia de alumnas compartida con Tutora (US-13) con historial y corrección (US-15)
      await abrirAccion('Asistencia');
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);
      await tester.tap(find.byTooltip('Semana anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Historial · solo lectura'), findsOneWidget);
      expect(find.text('Guardar Asistencia de la Clase'), findsNothing);
      expect(find.text('1 Ausentes'), findsOneWidget); // Valentina faltó en la semana 3
      await tester.tap(find.text('Corregir lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ausente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar Corrección'));
      await tester.pumpAndSettle();
      expect(clase.estadoAlumna('clase-3', 'insc-1'), EstadoAsistencia.presente);
      expect(find.textContaining('Última edición: Camila Sepúlveda Rivas'), findsOneWidget);
      // Volver a la clase actual
      await tester.tap(find.byTooltip('Volver a la clase actual'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar Asistencia de la Clase'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Podio Kahoot (US-29): sin pase de lista de hoy aún no se registra
      await abrirAccion('Registrar Kahoot');
      expect(find.textContaining('Guarda primero el pase de lista: el podio Kahoot'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Justificativo manual aprobado de inmediato (US-37, aún del mockup)
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

    Future<ValueNotifier<ThemeMode>> pumpShell(
      WidgetTester tester,
      SesionUsuario sesion, {
      VoidCallback? onCerrarSesion,
    }) async {
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
          sesion: sesion,
          themeNotifier: themeNotifier,
          onCerrarSesion: onCerrarSesion,
          claseRepository: clase,
        ),
      ));
      await tester.pumpAndSettle();
      return themeNotifier;
    }

    testWidgets('HubShellScreen muestra la nube de conexión y sincroniza los cambios pendientes', (WidgetTester tester) async {
      await pumpShell(tester, SesionesDemo.gestion);

      expect(find.text('NiñasPro Hub'), findsOneWidget);

      // Nubecita junto a Ajustes: conexión y cambios de la clase pendientes
      final lista = await esperar(tester, clase.lista('clase-4'));
      Future<ResultadoGuardado> guardar() => clase.guardarAsistencia('clase-4', [
            for (final r in lista.registros) r.copyWith(estado: EstadoAsistencia.presente),
          ]);
      expect(find.byTooltip('Conectado · todo guardado en la nube'), findsOneWidget);

      // Se cae internet: el pase de lista queda pendiente en el dispositivo (US-14)
      clase.simularConexion(false);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sin conexión'), findsOneWidget);
      expect((await esperar(tester, guardar())).pendiente, isTrue);
      await tester.pump();
      expect(find.byTooltip('Sin conexión · 1 cambio pendiente'), findsOneWidget);

      // Vuelve la conexión: se suben los pendientes solos y sin duplicar
      clase.simularConexion(true);
      await tester.pumpAndSettle();
      await esperar(tester, clase.sincronizar());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Conectado · todo guardado en la nube'), findsOneWidget);
      expect(find.text('☁️ Volvió la conexión: 1 cambio subido a la nube.'), findsOneWidget);
      expect(clase.envios, [OperacionesClase.asistencia]);

      // Un cambio guardado sin conexión que la nube rechaza al subirlo se avisa
      clase.simularConexion(false);
      await tester.pumpAndSettle();
      await esperar(tester, guardar());
      clase.rechazo = 'La clase ya está cerrada para edición.';
      clase.simularConexion(true);
      await esperar(tester, clase.sincronizar());
      await tester.pumpAndSettle();
      expect(find.textContaining('no se pudo subir: La clase ya está cerrada para edición.'), findsOneWidget);
    });

    testWidgets('HubShellScreen sin la clase conectada lo explica a Tutora y Gestión', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(HubShellScreen(repository: repository, sesion: SesionesDemo.tutora)));
      await tester.pumpAndSettle();
      expect(find.text('La clase necesita la conexión con la base de datos.'), findsOneWidget);
    });

    testWidgets('HubShellScreen abre la vista de Gestión según la sesión', (WidgetTester tester) async {
      await pumpShell(tester, SesionesDemo.gestion);

      expect(find.text('¡Hola, Camila!').hitTestable(), findsOneWidget);
      expect(find.text('Gestión'), findsWidgets);
      // Ya no existe el selector de roles del mockup
      expect(find.byType(PopupMenuButton<int>), findsNothing);
    });

    testWidgets('HubShellScreen abre la vista y los ajustes de la Tutora', (WidgetTester tester) async {
      await pumpShell(tester, SesionesDemo.tutora);

      expect(find.text('¡Hola, Daniela!').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Daniela Valenzuela Castro'), findsOneWidget);
    });

    testWidgets('HubShellScreen abre el portal de la Alumna', (WidgetTester tester) async {
      await pumpShell(tester, SesionesDemo.alumna);

      expect(find.text('Mi Asistencia Acumulada').hitTestable(), findsOneWidget);
    });

    testWidgets('HubShellScreen abre la consola de la Directiva y cambia el tema desde Ajustes', (WidgetTester tester) async {
      final themeNotifier = await pumpShell(tester, SesionesDemo.directiva);

      expect(find.text('NiñasPro Hub · Directiva'), findsOneWidget);
      expect(find.text('Dashboard nacional'), findsOneWidget);
      expect(find.byTooltip('Conectado · todo guardado en la nube'), findsOneWidget);

      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Directiva Nacional'), findsOneWidget);
      expect(find.text('directiva@ninaspro.cl'), findsOneWidget);
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(themeNotifier.value, ThemeMode.light);
    });

    testWidgets('HubShellScreen cierra sesión desde Ajustes', (WidgetTester tester) async {
      var cerro = false;
      await pumpShell(tester, SesionesDemo.directiva, onCerrarSesion: () => cerro = true);

      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(cerro, isTrue);
    });

    testWidgets('HubShellScreen avisa cuando el rol aún no tiene vista', (WidgetTester tester) async {
      var cerro = false;
      await pumpShell(tester, SesionesDemo.comunicacion, onCerrarSesion: () => cerro = true);

      expect(find.textContaining('aún no tiene una vista'), findsOneWidget);
      expect(find.byTooltip('Ajustes'), findsNothing);
      await tester.tap(find.text('Cerrar sesión'));
      expect(cerro, isTrue);
    });
  });
}
