import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/repositories/alumnas_repository.dart' show ArchivoAdjunto;
import 'package:ninas_pro_hub/repositories/evidencias_repository.dart';
import 'package:ninas_pro_hub/repositories/justificativos_repository.dart';
import 'package:ninas_pro_hub/screens/gestion/justificativos_gestion.dart' show avisoPrivacidadJustificativo;
import 'package:ninas_pro_hub/services/compresion_imagen.dart' as compresion;
import 'package:ninas_pro_hub/services/selector_archivos.dart' as selector;
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/repositories/clase_repository.dart';
import 'package:ninas_pro_hub/screens/alumna/portal_alumna_screen.dart';
import 'package:ninas_pro_hub/screens/directorio/ajustes_directiva_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/ajustes_gestion_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/gestion_mobile_screen.dart';
import 'package:ninas_pro_hub/screens/hub_shell_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/ajustes_tutora_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/clase_sesion_views.dart';
import 'package:ninas_pro_hub/screens/tutora/tutora_mobile_screen.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_mascot.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_planificacion_hoy.dart' show formatearFechaClase;
import 'package:ninas_pro_hub/widgets/ninaspro_stat_card.dart';

import 'fakes/fake_alertas_repository.dart';
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_clase_repository.dart';
import 'fakes/fake_evidencias_repository.dart';
import 'fakes/fake_justificativos_repository.dart';
import 'fakes/fake_portal_repository.dart';
import 'fakes/fake_reportes_repository.dart';
import 'fakes/fake_roles_repository.dart';
import 'fakes/fake_voluntariado_repository.dart';

void main() {
  group('Pantallas y widgets', () {
    late FakePortalRepository portal;
    late FakeAlertasRepository alertas;
    late FakeClaseRepository clase;
    late FakeJustificativosRepository justificativos;
    late FakeEvidenciasRepository evidencias;
    final elegirFotoOriginal = selector.elegirFoto;
    final comprimirOriginal = compresion.comprimirFoto;

    setUp(() {
      portal = FakePortalRepository();
      alertas = FakeAlertasRepository();
      clase = FakeClaseRepository();
      justificativos = FakeJustificativosRepository(clase: clase);
      evidencias = FakeEvidenciasRepository(clasesSinAutorizacion: {'clase-4'});
    });

    tearDown(() {
      selector.elegirFoto = elegirFotoOriginal;
      compresion.comprimirFoto = comprimirOriginal;
      return clase.cerrar();
    });

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

    testWidgets('TutoraMobileScreen main page: mi asistencia, mis roles y sin funciones de gestión (US-33, US-43, US-44)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final roles = FakeRolesRepository()
        ..asignar('clase-4', 'perfil-daniela', ['rol-presentar', 'rol-kahoot'], cumplidos: {'rol-kahoot'})
        ..asignar('clase-4', 'perfil-camila', ['rol-recepcion'])
        ..asignar('clase-3', 'perfil-daniela', ['rol-foto'], cumplidos: {'rol-foto'});
      await tester.pumpWidget(createTestApp(
        TutoraMobileScreen(clase: clase, sesion: SesionesDemo.tutora, roles: roles),
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

      // Sus dos roles de la clase de esta semana: marca el que terminó (US-44 escenario 2)
      expect(find.text('Tus roles · Clase 4'), findsOneWidget);
      expect(find.text('1 de 2 listos'), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Presentar la Clase'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2 listos'), findsOneWidget);
      expect(roles.rolesDe('clase-4', 'perfil-daniela').every((t) => t.completada), isTrue);

      // Ve los roles del equipo, sin poder asignarlos (US-44 escenario 3)
      await tester.tap(find.text('Ver los roles del equipo'));
      await tester.pumpAndSettle();
      expect(find.text('Roles del equipo'), findsOneWidget);
      expect(find.text('Recepción de Alumnas'), findsOneWidget);
      expect(find.text('Daniela Valenzuela Castro (tú)'), findsOneWidget);
      expect(find.byIcon(Icons.edit_calendar_rounded), findsNothing);
      final ajeno = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Recepción de Alumnas'));
      expect(ajeno.onChanged, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();

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
        TutoraMobileScreen(clase: clase, sesion: SesionesDemo.tutora, evidencias: evidencias),
      ));
      await tester.pumpAndSettle();

      Future<void> abrirAccion(String tooltip) async {
        await tester.tap(find.byTooltip('Acciones rápidas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }

      // Antes del pase de lista no hay foto (US-18: se vincula a la clase realizada)
      await abrirAccion('Fotos');
      expect(find.text('Primero el pase de lista'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

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
      final jpeg = img.encodeJpg(img.Image(width: 8, height: 6));
      selector.elegirFoto = () async => ArchivoAdjunto(nombre: 'IMG_0001.HEIC.jpg', bytes: Uint8List(12 * 1000 * 1000));
      compresion.comprimirFoto = (original) async => jpeg;
      await abrirAccion('Fotos');
      expect(find.text('Atención: alumnas sin autorización de imagen'), findsOneWidget);
      expect(find.text('• Josefa Muñoz Vera'), findsOneWidget);
      await tester.tap(find.text('Agregar Foto de Evidencia'));
      await tester.pumpAndSettle();
      expect(find.text('Foto de evidencia'), findsOneWidget);
      expect(find.textContaining('Sin autorización de imagen: Josefa Muñoz Vera'), findsOneWidget);
      // Sin la declaración de censura no se puede marcar apta (US-19 escenario 2)
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('foto-apta'))).onChanged, isNull);
      await tester.tap(find.byKey(const Key('declaracion-censura')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('foto-apta')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir foto'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Foto comprimida'), findsOneWidget);
      final foto = evidencias.fotosPorClase['clase-4']!.single;
      expect((foto.apta, foto.rostrosCensurados, foto.tamanoBytes), (true, true, jpeg.length));
      expect(find.text('APTA · ROSTROS CUBIERTOS'), findsOneWidget);
      expect(find.text('1 foto de esta clase'), findsOneWidget);
      await cerrarAvisos(tester);

      // Sin la declaración, la segunda queda como respaldo interno (US-19 escenario 3)
      await tester.tap(find.text('Agregar Foto de Evidencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir foto'));
      await tester.pumpAndSettle();
      expect(find.textContaining('vinculada a la clase como respaldo interno'), findsOneWidget);
      expect(find.text('RESPALDO INTERNO'), findsOneWidget);
      await cerrarAvisos(tester);

      // Una foto que el navegador no puede leer se informa
      compresion.comprimirFoto = (original) async => null;
      await tester.tap(find.text('Agregar Foto de Evidencia'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos leer la foto. Elige una imagen JPG o PNG.'), findsOneWidget);
    });

    testWidgets('El podio Kahoot lleva un lugar por alumna presente: con una sola, queda primera (US-29)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        TutoraMobileScreen(clase: clase, sesion: SesionesDemo.tutora),
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

      justificativos.clases.addAll([
        claseJustificable(3, asistencia: EstadoAsistencia.ausente),
        claseJustificable(4),
        claseJustificable(5),
      ]);
      await tester.pumpWidget(createTestApp(
        PortalAlumnaScreen(repository: portal, justificativos: justificativos),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('¡Hola, Valentina!'), findsOneWidget);
      expect(find.text('Mi Asistencia Acumulada'), findsOneWidget);
      // Lo que toca hoy en el banner de bienvenida
      expect(find.text('Clase 4 · ${formatearFechaClase(DateTime.now())}'), findsOneWidget);
      expect(find.text('Hoy toca: Funciones y Modularización del Código'), findsOneWidget);
      // 2 de 3 clases: bajo la meta, con un mensaje de motivación y sin hablar de riesgo (US-25 E2, US-40 E4)
      expect(find.text('66.7%'), findsOneWidget);
      expect(find.text('Meta: 80%'), findsOneWidget);
      expect(find.text('2 de 3 clases asistidas (Meta: 80% para certificar)'), findsOneWidget);
      expect(find.textContaining('Asiste a 6 clases más de las 6 que quedan'), findsOneWidget);
      expect(find.textContaining('riesgo'), findsNothing);

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
      await tester.tap(find.text('30'));
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

      // Recursos de la clase en una hoja inferior, con la insignia HTTPS (US-26 E2, E3)
      await tester.tap(find.text('Ver recursos (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Recursos de la clase #1'), findsOneWidget);
      expect(find.text('Diapositivas'), findsOneWidget);
      expect(find.text('Código interactivo'), findsOneWidget);
      expect(find.text('HTTPS'), findsNWidgets(2));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Mis justificativos: aún ninguno
      expect(find.text('Mis Justificativos'), findsOneWidget);
      expect(find.textContaining('Aún no has enviado justificativos'), findsOneWidget);

      // Justificar la próxima clase eligiendo clase y motivo (US-35)
      final justificarButton = find.text('Justificar Falta');
      expect(justificarButton, findsOneWidget);
      await tester.tap(justificarButton);
      await tester.pumpAndSettle();

      expect(find.text('Justificar Inasistencia'), findsOneWidget);
      expect(find.text('¿A qué clase?'), findsOneWidget);
      expect(find.textContaining('Clase #4 · '), findsOneWidget); // por defecto, la de hoy
      expect(find.text('Transporte / Clima'), findsOneWidget);
      expect(find.text(avisoPrivacidadJustificativo), findsOneWidget);
      expect(find.text('Adjuntar respaldo'), findsNothing); // solo texto, sin archivos

      await tester.tap(find.text('Enviar Justificativo'));
      await tester.pumpAndSettle();
      expect(find.text('Elige el motivo de tu inasistencia.'), findsOneWidget);
      await tester.tap(find.text('Transporte / Clima'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar Justificativo'));
      await tester.pumpAndSettle();
      expect(find.text('Cuéntanos brevemente qué pasó.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'No hay micro por el paro');
      await tester.tap(find.text('Enviar Justificativo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Justificativo enviado'), findsOneWidget);
      final enviado = justificativos.lista.single;
      expect((enviado.claseId, enviado.motivo, enviado.estado), ('clase-4', MotivoJustificativo.transporte, EstadoJustificativo.pendiente));
      expect(find.text('PENDIENTE'), findsOneWidget);

      // Una clase suspendida lo indica en el cronograma, sin estado de asistencia
      await tester.scrollUntilVisible(find.textContaining('Suspendida: Feriado'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Suspendida: Feriado'), findsOneWidget);
    });

    testWidgets('GestionMobileScreen main page shows pending justifications and alerts (US-37, US-39)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await justificativos.enviar(
        clase: claseJustificable(3, asistencia: EstadoAsistencia.ausente),
        motivo: MotivoJustificativo.salud,
        explicacion: 'Control médico',
      );
      evidencias.listaPendientes.add(EvidenciaPendiente(
        claseId: 'clase-2',
        cursoNombre: 'Programación Competitiva Básica (Python)',
        sedeNombre: 'Sede Beauchef',
        numeroSesion: 2,
        fecha: DateTime(2026, 11, 7),
        horasSinFoto: 75,
        tutoras: 'Daniela Valenzuela Castro',
      ));
      final roles = FakeRolesRepository(perfilId: 'perfil-camila')
        ..asignar('clase-4', 'perfil-camila', ['rol-foto']);
      await tester.pumpWidget(createTestApp(
        GestionMobileScreen(
          clase: clase,
          sesion: SesionesDemo.gestion,
          justificativos: justificativos,
          evidencias: evidencias,
          roles: roles,
          alertas: alertas,
        ),
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

      // Saludo y sus roles de la clase de esta semana (US-43)
      expect(find.text('¡Hola, Camila!'), findsOneWidget);
      expect(find.text('Tus roles · Clase 4'), findsOneWidget);
      expect(find.text('Foto y Asistencia'), findsOneWidget);
      expect(find.text('Asignar roles del equipo'), findsOneWidget);

      // Recursos del curso (US-26)
      expect(find.text('Recursos del Curso'), findsOneWidget);
      expect(find.text('Google Classroom'), findsOneWidget);
      expect(find.text('Juez Virtual'), findsOneWidget);

      // Evidencias pendientes tras 48 horas, con las tutoras a quienes recordar (US-20)
      expect(find.text('Evidencias pendientes (> 48 h)'), findsOneWidget);
      expect(find.text('Hace 3 días'), findsOneWidget);
      expect(find.text('Recordar a: Daniela Valenzuela Castro'), findsOneWidget);

      // Bandeja de justificativos con filtros (US-37)
      expect(find.text('Justificativos'), findsOneWidget);
      expect(find.text('Pendientes (1)'), findsOneWidget);
      expect(find.text('"Control médico"'), findsOneWidget);
      await tester.tap(find.text('Evaluar Justificativo'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar Justificativo'), findsOneWidget);
      // El rechazo exige la observación (US-37 escenario 3)
      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      expect(find.text('Indica el motivo del rechazo para que la alumna lo sepa.'), findsOneWidget);
      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Justificativo aprobado'), findsOneWidget);
      expect(justificativos.lista.single.estado, EstadoJustificativo.aceptado);
      expect(clase.estadoAlumna('clase-3', 'insc-1'), EstadoAsistencia.justificada);
      expect(find.text('Pendientes (0)'), findsOneWidget);
      await tester.tap(find.text('Aprobados (1)'));
      await tester.pumpAndSettle();
      expect(find.text('APROBADO'), findsOneWidget);
      await cerrarAvisos(tester);

      // Eliminar lo vinculado por error devuelve la asistencia a ausente (US-16 escenario 3)
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('volverá a Ausente'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(justificativos.lista, isEmpty);
      expect(clase.estadoAlumna('clase-3', 'insc-1'), EstadoAsistencia.ausente);

      // Alertas de deserción con el contacto de la apoderada y la nota metodológica (US-39, US-40)
      await cerrarAvisos(tester);
      expect(find.text('Alertas de deserción'), findsOneWidget);
      expect(find.textContaining('3 inasistencias seguidas sin justificar (última: Clase #3'), findsOneWidget);
      expect(find.textContaining('herramienta de acompañamiento'), findsOneWidget);
      expect(find.text('+56 9 7654 3210'), findsOneWidget);
      // Al centro de la pantalla, lejos del botón de acciones rápidas
      await Scrollable.ensureVisible(tester.element(find.text('Registrar contacto')), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar contacto'));
      await tester.pumpAndSettle();
      expect(find.text('Contacto con la familia de Florencia Muñoz Tapia'), findsOneWidget);
      await tester.tap(find.text('Guardar contacto'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta brevemente qué conversaste con la apoderada.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Observaciones del contacto'), 'Problemas de transporte.');
      await tester.tap(find.text('Guardar contacto'));
      await tester.pumpAndSettle();
      expect(find.text('📞 Contacto registrado.'), findsOneWidget);
      expect(alertas.lista.single.atendida, isTrue);
      expect(alertas.lista.single.observacion, 'Problemas de transporte.');
      expect(find.text('Sin alertas por atender'), findsOneWidget);

      // El panel completo muestra las contactadas con lo conversado
      await tester.tap(find.text('Ver todas las alertas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ninguna alumna acumula'), findsOneWidget);
      await tester.tap(find.text('Contactadas'));
      await tester.pumpAndSettle();
      expect(find.text('“Problemas de transporte.”'), findsOneWidget);
      expect(find.text('CONTACTADA'), findsOneWidget);
    });

    testWidgets('GestionMobileScreen speed dial opens tutor and class screens (US-13, US-15, US-29, US-33, US-43)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      clase.perfilId = 'perfil-camila';
      final roles = FakeRolesRepository(perfilId: 'perfil-camila')
        ..asignar('clase-4', 'perfil-daniela', ['rol-presentar'], cumplidos: {'rol-presentar'});
      await tester.pumpWidget(createTestApp(
        GestionMobileScreen(
          clase: clase,
          sesion: SesionesDemo.gestion,
          justificativos: justificativos,
          evidencias: evidencias,
          roles: roles,
          alertas: alertas,
        ),
      ));
      await tester.pumpAndSettle();

      Future<void> abrirAccion(String tooltip) async {
        await tester.tap(find.byTooltip('Acciones rápidas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }

      // Roles de la próxima clase: varios por tutora, sin perder lo cumplido (US-43)
      await abrirAccion('Asignar roles a tutoras');
      expect(find.text('Roles de Tutoras'), findsOneWidget);
      expect(find.textContaining('Clase 4 · '), findsOneWidget);
      expect(find.text('Próxima clase'), findsOneWidget);
      expect(find.textContaining('1 de 3 tutoras con rol'), findsOneWidget);
      expect(find.text('Roles obligatorios sin cubrir: Recepción de Alumnas, Foto y Asistencia.'), findsOneWidget);
      await tester.tap(find.byTooltip('Elegir los roles de Daniela Valenzuela Castro'));
      await tester.pumpAndSettle();
      expect(find.text('Tutora líder · inactivo'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Foto y Asistencia · obligatorio'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Preparar el Kahoot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar (3)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 roles para Daniela Valenzuela Castro en la clase 4'), findsOneWidget);
      expect(roles.rolesDe('clase-4', 'perfil-daniela').map((t) => t.rolId), ['rol-presentar', 'rol-foto', 'rol-kahoot']);
      expect(roles.rolesDe('clase-4', 'perfil-daniela').first.completada, isTrue);
      expect(find.text('Roles obligatorios sin cubrir: Recepción de Alumnas.'), findsOneWidget);
      // Gestión marca el cumplimiento de cualquier tutora (US-44)
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Preparar el Kahoot'));
      await tester.pumpAndSettle();
      expect(roles.rolesDe('clase-4', 'perfil-daniela').last.completada, isTrue);
      // Otra clase: sin roles
      await tester.tap(find.byTooltip('Clase siguiente'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Clase 5 · '), findsOneWidget);
      expect(find.textContaining('0 de 3 tutoras con rol'), findsOneWidget);
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

      // Aviso de la apoderada: queda aprobado y la alumna entra justificada al pase de lista (US-16)
      await abrirAccion('Ingresar justificativo');
      expect(find.text('Ingresar Justificativo'), findsOneWidget);
      expect(find.text('Valentina Soto Morales'), findsOneWidget);
      await tester.tap(find.text('Registrar y Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Elige el motivo de la inasistencia.'), findsOneWidget);
      await tester.tap(find.text('Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar y Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe la descripción del aviso.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Apoderada avisó por WhatsApp.');
      await tester.tap(find.text('Registrar y Aprobar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Justificativo registrado y aprobado'), findsOneWidget);
      expect(justificativos.lista.single.estado, EstadoJustificativo.aceptado);
      await cerrarAvisos(tester);

      await abrirAccion('Asistencia');
      final valentina = find.ancestor(of: find.text('Valentina Soto Morales'), matching: find.byType(TarjetaAsistencia));
      expect(tester.widget<TarjetaAsistencia>(valentina).estado, EstadoAsistencia.justificada);
      expect(find.text('Justificativo aprobado'), findsOneWidget);
      await tester.tap(find.text('Justificativo aprobado'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Motivo: Salud'), findsOneWidget);
      expect(find.text('Aprobar'), findsNothing);
    });

    testWidgets('AjustesGestionScreen muestra perfil de la tutora sin sección de apoderado', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        AjustesGestionScreen(
          sesion: SesionesDemo.gestion,
          voluntariado: FakeVoluntariadoRepository(),
          clase: FakeClaseRepository(perfilId: 'perfil-camila'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Camila Sepúlveda Rivas'), findsOneWidget);
      expect(find.text('MI PERFIL'), findsOneWidget);
      expect(find.text('Sede Beauchef'), findsWidgets);
      expect(find.text('APODERADO/A'), findsNothing);
    });

    testWidgets('AjustesTutoraScreen muestra perfil de la tutora con su rol', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(
        AjustesTutoraScreen(
          sesion: SesionesDemo.tutora,
          voluntariado: FakeVoluntariadoRepository(),
          clase: FakeClaseRepository(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Daniela Valenzuela Castro'), findsOneWidget);
      expect(find.textContaining('Tutora'), findsWidgets);
      expect(find.text('MI PERFIL'), findsOneWidget);
      // Su ficha del voluntariado: adhesión, institución e ingreso (US-31, US-32)
      expect(find.text('Declaración de adhesión'), findsOneWidget);
      expect(find.text('Firmada el 14/03/2026'), findsOneWidget);
      expect(find.text('Programación Competitiva Básica (Python)'), findsOneWidget);
      expect(find.text('03/03/2023'), findsOneWidget);
      expect(find.text('APODERADO/A'), findsNothing);
    });

    testWidgets('AjustesDirectivaScreen muestra el perfil de la Directiva y la apariencia', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final themeNotifier = ValueNotifier(ThemeMode.dark);
      await tester.pumpWidget(createTestApp(
        AjustesDirectivaScreen(themeNotifier: themeNotifier),
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
          sesion: sesion,
          themeNotifier: themeNotifier,
          onCerrarSesion: onCerrarSesion,
          claseRepository: clase,
          portalRepository: portal,
          alertasRepository: alertas,
          reportesRepository: FakeReportesRepository(),
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

      await tester.pumpWidget(createTestApp(const HubShellScreen(sesion: SesionesDemo.tutora)));
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
