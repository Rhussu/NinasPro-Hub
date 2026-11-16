import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart' show Curso;
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/repositories/justificativos_repository.dart';
import 'package:ninas_pro_hub/screens/ajustes/accesos_rol.dart';
import 'package:ninas_pro_hub/screens/directorio/directorio_widgets.dart';
import 'package:ninas_pro_hub/screens/hub_shell_screen.dart';
import 'package:ninas_pro_hub/screens/tutora/inicio_tutora_widgets.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_recursos_curso.dart';
import 'package:ninas_pro_hub/widgets/ninaspro_speed_dial.dart';

import 'fakes/fake_alertas_repository.dart';
import 'fakes/fake_alumnas_repository.dart';
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_catalogo_repository.dart';
import 'fakes/fake_clase_repository.dart';
import 'fakes/fake_evidencias_repository.dart';
import 'fakes/fake_justificativos_repository.dart';
import 'fakes/fake_portal_repository.dart';
import 'fakes/fake_reportes_repository.dart';
import 'fakes/fake_roles_repository.dart';
import 'fakes/fake_voluntariado_repository.dart';

/// Ajustes como acceso a todo lo de cada perfil (PR 8): cada entrada abre la
/// misma vista que su tarjeta o su Speed Dial, y un rol no ve lo de otro.
void main() {
  late FakeClaseRepository clase;
  late FakeJustificativosRepository justificativos;

  setUp(() {
    clase = FakeClaseRepository();
    justificativos = FakeJustificativosRepository(clase: clase);
  });

  tearDown(() => clase.cerrar());

  Future<void> abrirShell(
    WidgetTester tester,
    SesionUsuario sesion, {
    Size tamano = const Size(420, 2600),
    bool conectado = true,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final catalogo = FakeCatalogoRepository(instancias: [clase.curso], sesiones: {clase.curso.id: clase.listaSesiones});
    await tester.pumpWidget(
      MaterialApp(
        theme: NinasProTheme.light,
        home: HubShellScreen(
          sesion: sesion,
          themeNotifier: ValueNotifier(ThemeMode.light),
          claseRepository: clase,
          justificativosRepository: justificativos,
          evidenciasRepository: FakeEvidenciasRepository(),
          alertasRepository: FakeAlertasRepository(),
          portalRepository: FakePortalRepository(),
          reportesRepository: FakeReportesRepository(),
          alumnasRepository: FakeAlumnasRepository(),
          rolesRepository: conectado ? FakeRolesRepository(perfilId: sesion.perfilId) : null,
          voluntariadoRepository: conectado ? FakeVoluntariadoRepository() : null,
          catalogoRepository: conectado ? catalogo : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirAjustes(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
  }

  // La lista de Ajustes es la última que se dibuja (la consola de la Directiva tiene su propio menú)
  Finder listaAjustes() => find.byType(Scrollable).last;

  // Una entrada de Ajustes (no el menú lateral ni otra parte de la pantalla)
  Finder entrada(String titulo) => find.descendant(of: find.byType(ListTile), matching: find.text(titulo));

  Future<void> tocar(WidgetTester tester, String titulo) async {
    await tester.scrollUntilVisible(entrada(titulo), 200, scrollable: listaAjustes());
    await tester.tap(entrada(titulo));
    await tester.pumpAndSettle();
  }

  // Abre la entrada, comprueba su vista y vuelve a Ajustes
  Future<void> abrirYVolver(WidgetTester tester, String titulo, Finder vista) async {
    await tocar(tester, titulo);
    expect(vista, findsWidgets, reason: 'la entrada "$titulo" abre su vista');
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  // Cierra una hoja inferior tocando fuera de ella
  Future<void> cerrarHoja(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  Finder barra(String titulo) => find.widgetWithText(AppBar, titulo);

  /// Las secciones aparecen en este orden
  void enOrden(WidgetTester tester, List<String> titulos) {
    final ys = [for (final t in titulos) tester.getTopLeft(find.text(t)).dy];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]), reason: '${titulos[i - 1]} va antes que ${titulos[i]}');
    }
  }

  /// Los tooltips del Speed Dial de la pantalla principal
  List<String> accionesSpeedDial(WidgetTester tester) => [
    for (final a in tester.widget<NinasProSpeedDial>(find.byType(NinasProSpeedDial)).acciones) a.tooltip,
  ];

  group('RegistroAccesos', () {
    test('entrega las secciones de quien se registró y avisa los cambios', () {
      final registro = RegistroAccesos();
      expect(registro.secciones, isEmpty);
      var avisos = 0;
      registro.addListener(() => avisos++);
      List<SeccionAccesos> construir() => const [
        SeccionAccesos('La clase de hoy', [AccesoRol(icono: Icons.fact_check_rounded, titulo: 'Asistencia')]),
      ];
      registro.registrar(construir);
      expect(registro.secciones.single.accesos.single.titulo, 'Asistencia');
      registro.avisar();
      expect(avisos, 1);
      // Solo retira quien se registró
      registro.retirar(() => const []);
      expect(registro.secciones, hasLength(1));
      registro.retirar(construir);
      expect(registro.secciones, isEmpty);
      registro.dispose();
    });
  });

  group('Tutora', () {
    testWidgets('Ajustes llega a la clase de hoy y a su trabajo, en ese orden y sin lo de Gestión', (tester) async {
      await abrirShell(tester, SesionesDemo.tutora);

      // Cada acción del Speed Dial y cada tarjeta tiene su entrada
      const entradaDeAccion = {
        'Asistencia': 'Asistencia',
        'Ejercicios': 'Ejercicios',
        'Fotos': 'Fotos',
        'Registrar Kahoot': 'Podio Kahoot',
      };
      final acciones = accionesSpeedDial(tester);
      expect(acciones.toSet(), entradaDeAccion.keys.toSet());
      expect(find.byType(TarjetaPresentesClase), findsOneWidget);
      expect(find.byType(TarjetaMiAsistencia), findsOneWidget);
      expect(find.byType(TarjetaMisRoles), findsOneWidget);
      expect(find.byType(NinasProRecursosCursoCard), findsOneWidget);

      await abrirAjustes(tester);
      enOrden(tester, ['LA CLASE DE HOY', 'MI TRABAJO COMO TUTORA', 'MI PERFIL', 'APARIENCIA', 'CUENTA']);
      for (final entrada in [
        ...entradaDeAccion.values,
        'Mi asistencia', // TarjetaMiAsistencia
        'Roles de la clase', // TarjetaMisRoles
        'Recursos del curso', // NinasProRecursosCursoCard
        'Cronograma',
      ]) {
        expect(find.widgetWithText(ListTile, entrada), findsOneWidget, reason: 'falta la entrada $entrada');
      }
      // Con un solo curso no se elige curso (queda solo el de Mi perfil)
      expect(find.widgetWithText(ListTile, 'Curso'), findsOneWidget);
      // La tutora no ve lo de Gestión ni de la Directiva
      for (final ajena in [
        'GESTIÓN DE LA SEDE',
        'Justificativos',
        'Alertas de deserción',
        'Asistencia de tutoras',
        'Calendario de clases',
        'Exportar',
        'Auditoría',
      ]) {
        expect(find.widgetWithText(ListTile, ajena), findsNothing, reason: 'la tutora no ve $ajena');
        expect(find.text(ajena), findsNothing, reason: 'la tutora no ve $ajena');
      }
    });

    testWidgets('cada entrada abre la misma vista que su tarjeta o su Speed Dial', (tester) async {
      await abrirShell(tester, SesionesDemo.tutora);
      await abrirAjustes(tester);

      await abrirYVolver(tester, 'Asistencia', find.text('Guardar Asistencia de la Clase'));
      await abrirYVolver(tester, 'Ejercicios', barra('Ejercicios'));
      await abrirYVolver(tester, 'Fotos', barra('Fotos'));
      await abrirYVolver(tester, 'Mi asistencia', barra('Mi Asistencia'));
      await abrirYVolver(tester, 'Roles de la clase', barra('Roles del equipo'));
      await abrirYVolver(tester, 'Recursos del curso', find.text('Google Classroom'));

      // El cronograma, en solo lectura
      await tocar(tester, 'Cronograma');
      expect(barra('Cronograma'), findsOneWidget);
      expect(find.text('Sesión especial'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Podio Kahoot: el mismo aviso que el Speed Dial sin pase de lista
      await tocar(tester, 'Podio Kahoot');
      expect(find.textContaining('Guarda primero el pase de lista'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('LA CLASE DE HOY'), findsOneWidget);
    });

    testWidgets('con más de un curso elige el curso desde Ajustes y la entrada se actualiza', (tester) async {
      clase = FakeClaseRepository(
        otrosCursos: [
          const Curso(
            id: 'inst-web',
            codigo: 'DWI-2026-S2-VALPO',
            nombre: 'Desarrollo Web Inicial',
            sedeId: 'sede-valpo',
            sedeNombre: 'Sede Valparaíso',
            anio: 2026,
            semestre: 2,
            totalSesiones: 10,
          ),
        ],
      );
      await abrirShell(tester, SesionesDemo.tutora);
      await abrirAjustes(tester);

      expect(find.text('Programación Competitiva Básica (Python) · Sede Beauchef'), findsOneWidget);
      await tocar(tester, 'Curso');
      expect(find.text('Elige el curso'), findsOneWidget);
      await tester.tap(find.text('Desarrollo Web Inicial · Sede Valparaíso'));
      await tester.pumpAndSettle();
      // La pantalla principal cambió de curso y Ajustes lo muestra sin volver a abrirse
      expect(find.text('Desarrollo Web Inicial · Sede Valparaíso'), findsOneWidget);
      expect(find.text('Programación Competitiva Básica (Python) · Sede Beauchef'), findsNothing);
    });

    testWidgets('sin conexión la entrada se explica en vez de esconderse', (tester) async {
      await abrirShell(tester, SesionesDemo.tutora, conectado: false);
      await abrirAjustes(tester);

      final cronograma = find.ancestor(of: find.text('Cronograma'), matching: find.byType(ListTile));
      expect(
        find.descendant(of: cronograma, matching: find.text('Necesita la conexión con la base de datos.')),
        findsOneWidget,
      );
      await tester.tap(cronograma);
      await tester.pumpAndSettle();
      expect(barra('Cronograma'), findsNothing);
      expect(find.text('MI TRABAJO COMO TUTORA'), findsOneWidget);
    });
  });

  group('Equipo de Gestión', () {
    setUp(() {
      clase = FakeClaseRepository(perfilId: 'perfil-camila');
      justificativos = FakeJustificativosRepository(clase: clase);
    });

    testWidgets('Ajustes llega a la clase, a la gestión de la sede y a su trabajo, sin reportes', (tester) async {
      await abrirShell(tester, SesionesDemo.gestion);

      const entradaDeAccion = {
        'Ingresar justificativo': 'Ingresar justificativo',
        'Asignar roles a tutoras': 'Roles de la clase',
        'Asistencia de tutoras': 'Asistencia de tutoras',
        'Registrar Kahoot': 'Podio Kahoot',
        'Fotos': 'Fotos',
        'Ejercicios': 'Ejercicios',
        'Asistencia': 'Asistencia',
      };
      expect(accionesSpeedDial(tester).toSet(), entradaDeAccion.keys.toSet());
      // Secciones de la pantalla principal: justificativos, evidencias y alertas
      expect(find.text('Justificativos'), findsOneWidget);
      expect(find.text('Evidencias pendientes (> 48 h)'), findsOneWidget);
      expect(find.text('Alertas de deserción'), findsOneWidget);

      await abrirAjustes(tester);
      enOrden(tester, ['LA CLASE DE HOY', 'GESTIÓN DE LA SEDE', 'MI TRABAJO COMO TUTORA', 'MI PERFIL', 'CUENTA']);
      for (final entrada in [
        ...entradaDeAccion.values,
        'Justificativos',
        'Evidencias pendientes (> 48 h)',
        'Alertas de deserción',
        'Calendario de clases',
        'Voluntariado de la sede',
        'Mi asistencia',
        'Recursos del curso',
      ]) {
        expect(find.widgetWithText(ListTile, entrada), findsOneWidget, reason: 'falta la entrada $entrada');
      }
      expect(find.text('1 por contactar'), findsOneWidget);
      // Exportar, auditoría, accesos y alumnas son de la Directiva (decidido el 2026-11-16)
      for (final ajena in ['Exportar', 'Auditoría', 'Accesos', 'Nómina de alumnas', 'Gestión en todas las sedes']) {
        expect(find.text(ajena), findsNothing, reason: 'Gestión no ve $ajena');
      }
    });

    testWidgets('cada entrada abre la misma vista de Gestión', (tester) async {
      await abrirShell(tester, SesionesDemo.gestion);
      await abrirAjustes(tester);

      await abrirYVolver(tester, 'Asistencia', find.text('Guardar Asistencia de la Clase'));
      await abrirYVolver(tester, 'Asistencia de tutoras', find.text('Guardar Asistencia de Tutoras'));
      await abrirYVolver(tester, 'Roles de la clase', barra('Roles de Tutoras'));
      await abrirYVolver(tester, 'Alertas de deserción', find.text('Florencia Muñoz Tapia'));
      await abrirYVolver(
        tester,
        'Evidencias pendientes (> 48 h)',
        find.text('Todas las clases realizadas tienen su foto de evidencia.'),
      );
      await abrirYVolver(tester, 'Calendario de clases', barra('Calendario de clases'));
      await abrirYVolver(tester, 'Mi asistencia', barra('Mi Asistencia'));

      // La bandeja completa, con sus filtros y el botón para ingresar el aviso de una apoderada
      await tocar(tester, 'Justificativos');
      expect(barra('Justificativos'), findsOneWidget);
      expect(find.text('Pendientes (0)'), findsOneWidget);
      expect(find.text('Todas las sedes'), findsNothing, reason: 'Gestión ve una sola sede');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar justificativo'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresar Justificativo'), findsOneWidget);
      await cerrarHoja(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // El voluntariado de su sede, en solo lectura
      await tocar(tester, 'Voluntariado de la sede');
      expect(barra('Voluntariado'), findsOneWidget);
      expect(find.textContaining('solo lectura'), findsOneWidget);
      for (final accion in ['Carga masiva', 'Nueva voluntaria', 'Exportar']) {
        expect(find.text(accion), findsNothing, reason: 'Gestión no ve $accion en el voluntariado');
      }
    });
  });

  group('Alumna', () {
    testWidgets('Ajustes llega a todo su portal y no ve lo de las tutoras', (tester) async {
      justificativos.clases.addAll([claseJustificable(3, asistencia: EstadoAsistencia.ausente), claseJustificable(4)]);
      await abrirShell(tester, SesionesDemo.alumna);
      expect(find.text('Justificar Falta'), findsOneWidget);

      await abrirAjustes(tester);
      enOrden(tester, ['MI ASISTENCIA', 'MI PROGRESO', 'MI CURSO', 'MI PERFIL', 'APODERADO/A', 'CUENTA']);
      for (final ajena in ['LA CLASE DE HOY', 'Asistencia de tutoras', 'Justificativos', 'Roles de la clase']) {
        expect(find.text(ajena), findsNothing, reason: 'la alumna no ve $ajena');
      }

      await tocar(tester, 'Asistencia y cronograma');
      expect(barra('Mi asistencia'), findsOneWidget);
      expect(find.text('Mi Asistencia Acumulada'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cronograma de Clases (Sábados)'), 200, scrollable: listaAjustes());
      expect(find.text('Cronograma de Clases (Sábados)'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await abrirYVolver(tester, 'Mis justificativos', find.text('Mis Justificativos'));
      await abrirYVolver(tester, 'Recursos del curso', find.text('Google Classroom'));

      // Las mismas hojas que sus tarjetas y el botón del portal
      await tocar(tester, 'Mis ejercicios');
      expect(find.text('Recuperación por Ejercicios'), findsOneWidget);
      await cerrarHoja(tester);
      await tocar(tester, 'Mis podios Kahoot');
      expect(find.text('Historial de Podios Kahoot'), findsOneWidget);
      await cerrarHoja(tester);
      await tocar(tester, 'Justificar falta');
      expect(find.text('Justificar Inasistencia'), findsOneWidget);
      await cerrarHoja(tester);
      expect(find.text('MI ASISTENCIA'), findsOneWidget);
    });
  });

  group('Directiva', () {
    const tamanoEscritorio = Size(1280, 2200);

    JustificativoDetalle justificativo(String id, String alumna, String sede) => JustificativoDetalle(
      id: id,
      claseId: 'clase-3',
      inscripcionId: 'insc-$id',
      alumnaId: 'alumna-$id',
      alumnaNombre: alumna,
      alumnaRut: '',
      numeroSesion: 3,
      claseFecha: DateTime(2026, 11, 14),
      cursoNombre: 'Programación Competitiva Básica (Python)',
      sedeNombre: sede,
      motivo: MotivoJustificativo.salud,
      explicacion: 'Estuvo con fiebre.',
      estado: EstadoJustificativo.pendiente,
      enviadoPorAlumna: true,
      creadoEn: DateTime(2026, 11, 14),
    );

    testWidgets('Ajustes llega a la consola, al catálogo y, aparte, a lo de Gestión en todas las sedes', (
      tester,
    ) async {
      await abrirShell(tester, SesionesDemo.directiva, tamano: tamanoEscritorio);
      await abrirAjustes(tester);

      enOrden(tester, [
        'CONSOLA',
        'ALUMNAS',
        'VOLUNTARIADO',
        'CATÁLOGO Y EQUIPO',
        'GESTIÓN EN TODAS LAS SEDES',
        'APARIENCIA',
      ]);
      // Cada sección del menú de la consola tiene su entrada
      for (final entrada in ['Dashboard', 'Exportar', 'Auditoría', 'Nómina de alumnas', 'Fichas del voluntariado']) {
        expect(find.widgetWithText(ListTile, entrada), findsOneWidget, reason: 'falta la entrada $entrada');
      }
      // La clase de hoy es de las tutoras
      expect(find.text('LA CLASE DE HOY'), findsNothing);
    });

    testWidgets('las entradas de la consola cierran Ajustes y abren la sección con su acción', (tester) async {
      await abrirShell(tester, SesionesDemo.directiva, tamano: tamanoEscritorio);

      await abrirAjustes(tester);
      await tocar(tester, 'Carga masiva de alumnas');
      expect(barra('Ajustes'), findsNothing);
      expect(find.text('Carga masiva de nómina'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Carga masiva'), findsWidgets, reason: 'queda en la nómina de alumnas');

      await abrirAjustes(tester);
      await tocar(tester, 'Nueva voluntaria');
      expect(find.widgetWithText(AlertDialog, 'Nueva voluntaria'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await abrirAjustes(tester);
      await tocar(tester, 'Auditoría');
      expect(barra('Ajustes'), findsNothing);
      expect(find.text('Auditoría'), findsWidgets);
      expect(find.textContaining('Cambios, descargas'), findsNothing);

      // El catálogo cambia la sección del menú lateral de Ajustes
      await abrirAjustes(tester);
      await tocar(tester, 'Sedes');
      expect(find.text('Nueva sede'), findsOneWidget);
      final menu = tester.widget<DirectorioMenuLateral>(find.byType(DirectorioMenuLateral));
      expect(menu.opciones[menu.seleccionada].etiqueta, 'Sedes');
    });

    testWidgets('lo de Gestión parte en todas las sedes y se filtra dentro de la vista', (tester) async {
      justificativos.lista.addAll([
        justificativo('j1', 'Valentina Soto Morales', 'Sede Beauchef'),
        justificativo('j2', 'Isidora Fuentes Lagos', 'Sede Valparaíso'),
      ]);
      await abrirShell(tester, SesionesDemo.directiva, tamano: tamanoEscritorio);
      await abrirAjustes(tester);

      await tocar(tester, 'Justificativos');
      expect(barra('Justificativos'), findsOneWidget);
      expect(find.text('Pendientes (2)'), findsOneWidget);
      expect(find.textContaining('· Sede Valparaíso'), findsOneWidget, reason: 'cada justificativo muestra su sede');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sede Valparaíso'));
      await tester.pumpAndSettle();
      expect(find.text('Pendientes (1)'), findsOneWidget);
      expect(find.text('Valentina Soto Morales'), findsNothing);
      expect(find.text('Isidora Fuentes Lagos'), findsOneWidget);
      // Ingresar el aviso de una apoderada: con un solo curso, va directo al formulario
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar justificativo'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresar Justificativo'), findsOneWidget);
      await cerrarHoja(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await abrirYVolver(tester, 'Alertas de deserción', find.text('Florencia Muñoz Tapia'));

      await tocar(tester, 'Roles de la clase');
      expect(find.byType(SelectorCursoClase), findsOneWidget);
      expect(find.textContaining('Programación Competitiva Básica (Python) · Sede Beauchef'), findsOneWidget);
      expect(find.textContaining('tutoras con rol'), findsOneWidget);
    });
  });
}
