import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/models/hub_models.dart' show SinCambiosPendientes, EstadoSincronizacion;
import 'package:ninas_pro_hub/repositories/alertas_repository.dart';
import 'package:ninas_pro_hub/repositories/portal_repository.dart';
import 'package:ninas_pro_hub/repositories/reportes_repository.dart';
import 'package:ninas_pro_hub/screens/alumna/ajustes_alumna_screen.dart';
import 'package:ninas_pro_hub/screens/alumna/portal_alumna_screen.dart';
import 'package:ninas_pro_hub/screens/gestion/alertas_desercion_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_alertas_repository.dart';
import 'fakes/fake_portal_repository.dart';

/// Repositorios de reportes, alertas y portal sobre Supabase (US-21..US-27,
/// US-39, US-40) y los estados de sus vistas
void main() {
  const json = {'content-type': 'application/json'};
  http.Response ok(Object? cuerpo) => http.Response(jsonEncode(cuerpo), 200, headers: json);
  http.Response error(int status, String code, String message) => http.Response(
    jsonEncode({'code': code, 'message': message, 'details': null, 'hint': null}),
    status,
    headers: json,
  );

  late List<http.Request> pedidos;
  SupabaseClient cliente(http.Response Function(http.Request r) responder) {
    pedidos = [];
    return SupabaseClient(
      'http://localhost:54321',
      'anon',
      httpClient: MockClient((r) async {
        pedidos.add(r);
        final resp = responder(r);
        return http.Response(resp.body, resp.statusCode, headers: resp.headers, request: r);
      }),
    );
  }

  Map<String, dynamic> cuerpo(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

  group('Reportes (US-21..US-25)', () {
    test('el resumen y la asistencia por clase se agrupan por sede', () async {
      final repo = SupabaseReportesRepository(
        cliente((r) {
          if (r.url.path.endsWith('resumen_sedes')) {
            return ok([
              {
                'sede_id': 's1',
                'nombre': 'Sede Beauchef',
                'institucion': 'U. de Chile',
                'activa': true,
                'cursos': 1,
                'alumnas_activas': 8,
                'asistencia_promedio': 78.6,
                'voluntarias_activas': 9,
              },
              {'sede_id': 's2', 'nombre': 'Sede Nueva', 'activa': false, 'asistencia_promedio': null},
            ]);
          }
          return ok([
            {'sede_id': 's1', 'sede_nombre': 'Sede Beauchef', 'fecha': '2026-10-03', 'presentes': 6, 'total': 8},
            {'sede_id': 's2', 'sede_nombre': 'Sede Nueva', 'fecha': '2026-10-03', 'presentes': 1, 'total': 2},
            {'sede_id': 's1', 'sede_nombre': 'Sede Beauchef', 'fecha': '2026-10-10', 'presentes': 8, 'total': 8},
          ]);
        }),
      );

      final resumen = await repo.resumenSedes();
      expect(resumen.first.asistenciaPromedio, 78.6);
      expect((resumen.last.activa, resumen.last.asistenciaPromedio, resumen.last.cursos), (false, null, 0));

      final series = await repo.asistenciaPorClase();
      expect(series.map((s) => s.sedeNombre), ['Sede Beauchef', 'Sede Nueva']);
      expect(series.first.puntos.map((p) => p.porcentaje), [75.0, 100.0]);
    });

    test('la vista previa no registra la descarga y exportar envía el formato y los filtros', () async {
      final repo = SupabaseReportesRepository(
        cliente(
          (r) => ok({
            'encabezados': ['Sede', 'Alumna', 'Estado'],
            'filas': [
              ['Sede Beauchef', 'ALUMNA-001', null],
            ],
            'total': 25,
          }),
        ),
      );
      final filtro = FiltroReporte(
        tipo: TipoReporte.asistencia,
        sedeId: 's1',
        instanciaId: 'i1',
        desde: DateTime(2026, 3, 1),
        hasta: DateTime(2026, 6, 30),
        disociado: true,
      );

      final previa = await repo.vistaPrevia(filtro);
      expect(previa.valor!.total, 25);
      expect(previa.valor!.filas.single, ['Sede Beauchef', 'ALUMNA-001', '']);
      expect(pedidos.single.url.path, endsWith('/rpc/exportar_reporte'));
      expect(cuerpo(pedidos.single), {
        'p_tipo': 'asistencia',
        'p_sede_id': 's1',
        'p_instancia_id': 'i1',
        'p_desde': '2026-03-01',
        'p_hasta': '2026-06-30',
        'p_disociado': true,
        'p_formato': 'CSV',
        'p_vista_previa': true,
      });

      await repo.exportar(filtro, FormatoExportacion.xlsx);
      expect(cuerpo(pedidos.last)['p_formato'], 'XLSX');
      expect(cuerpo(pedidos.last)['p_vista_previa'], false);
      expect(filtro.nombreArchivo(DateTime(2026, 11, 6)), 'asistencia_disociado_2026-11-06');
    });

    test('un reporte rechazado devuelve el motivo de la base', () async {
      final fuera = SupabaseReportesRepository(
        cliente((_) => error(403, '42501', 'Solo puedes exportar datos de tu sede. El intento quedó registrado.')),
      );
      expect((await fuera.vistaPrevia(const FiltroReporte(tipo: TipoReporte.nomina))).error, contains('tu sede'));

      final caida = SupabaseReportesRepository(cliente((_) => error(500, 'XX000', 'boom')));
      expect(
        (await caida.exportar(const FiltroReporte(tipo: TipoReporte.nomina), FormatoExportacion.csv)).error,
        'No pudimos armar el reporte. Inténtalo nuevamente.',
      );

      // La respuesta con code (sin excepción) también es un rechazo
      expect(MapeoReportes.reporte({'code': '42501', 'message': 'No tienes permiso.'}).error, 'No tienes permiso.');
    });

    test('la auditoría envía los filtros y traduce cada evento', () async {
      final repo = SupabaseReportesRepository(
        cliente(
          (_) => ok([
            {
              'id': 'ev-1',
              'fecha_hora': '2026-11-14T15:30:00+00:00',
              'tipo': 'acceso_denegado',
              'usuaria_nombre': 'Tutora B',
              'usuaria_correo': 'tutora.b@ninaspro.cl',
              'sede_nombre': null,
              'descripcion': 'Acceso denegado: portal de otra alumna',
              'alumna_rut': '22.341.890-2',
              'alumna_nombre': 'Valentina Soto Morales',
              'detalle': {'recurso': 'portal_alumna'},
            },
            {'id': 'ev-2', 'fecha_hora': '2026-11-14T10:00:00+00:00', 'tipo': 'desconocido', 'descripcion': null},
          ]),
        ),
      );

      final eventos = await repo.auditoria(
        desde: DateTime(2026, 11, 1),
        usuaria: '  tutora ',
        tipo: TipoEventoAuditoria.accesoDenegado,
        rutAlumna: ' ',
      );
      expect(cuerpo(pedidos.single), {
        'p_desde': '2026-11-01',
        'p_hasta': null,
        'p_usuaria': 'tutora',
        'p_tipo': 'acceso_denegado',
        'p_rut': null,
      });
      expect(eventos.first.tipo, TipoEventoAuditoria.accesoDenegado);
      expect(eventos.first.detalle['recurso'], 'portal_alumna');
      expect(
        (eventos.last.tipo, eventos.last.usuariaNombre, eventos.last.descripcion),
        (TipoEventoAuditoria.modificacion, 'Sistema', ''),
      );
    });
  });

  group('Alertas de deserción (US-39, US-40)', () {
    final fila = {
      'id': 'al-1',
      'inscripcion_id': 'insc-1',
      'alumna_id': 'alumna-1',
      'alumna_nombres': 'Florencia',
      'alumna_apellidos': 'Muñoz Tapia',
      'alumna_rut': '21.904.331-7',
      'curso_codigo': 'PCB',
      'curso_nombre': 'Programación Competitiva Básica',
      'sede_id': 's1',
      'sede_nombre': 'Sede Beauchef',
      'numero_sesion': 7,
      'clase_fecha': '2026-11-14',
      'inasistencias_consecutivas': 4,
      'atendida': true,
      'fecha_contacto': '2026-11-16',
      'observacion_gestion': 'Transporte',
      'atendida_por_nombre': 'Camila Sepúlveda',
      'apoderado_nombre': 'Claudio Muñoz',
      'apoderado_telefono': '+56 9 7654 3210',
      'apoderado_correo': 'claudio@correo.cl',
      'apoderado_parentesco': 'Padre',
      'created_at': '2026-11-14T13:00:00+00:00',
    };

    test('lee la vista con la apoderada y registra el contacto por RPC', () async {
      final repo = SupabaseAlertasRepository(cliente((r) => r.method == 'GET' ? ok([fila]) : ok(null)));
      final alerta = (await repo.alertas()).single;
      expect(pedidos.single.url.path, endsWith('/alertas_detalle'));
      expect(pedidos.single.url.query, contains('order=atendida.asc'));
      expect(
        (alerta.alumnaNombre, alerta.inasistenciasConsecutivas, alerta.atendida, alerta.ultimaClase),
        ('Florencia Muñoz Tapia', 4, true, 'Clase #7 · 14/11/2026'),
      );
      expect(
        (alerta.apoderadoNombre, alerta.fechaContacto, alerta.atendidaPor),
        ('Claudio Muñoz', DateTime(2026, 11, 16), 'Camila Sepúlveda'),
      );

      expect((await repo.registrarContacto('al-1', '  Llamé a la apoderada ')).ok, isTrue);
      expect(pedidos.last.url.path, endsWith('/rpc/registrar_contacto_alerta'));
      expect(cuerpo(pedidos.last), {'p_id': 'al-1', 'p_observacion': 'Llamé a la apoderada'});
    });

    test('un contacto rechazado devuelve el motivo', () async {
      final repo = SupabaseAlertasRepository(
        cliente((_) => error(400, '22023', 'Esta alerta ya tiene un contacto registrado.')),
      );
      expect((await repo.registrarContacto('al-1', 'x')).error, 'Esta alerta ya tiene un contacto registrado.');
      final caida = SupabaseAlertasRepository(cliente((_) => error(500, 'XX000', 'boom')));
      expect((await caida.registrarContacto('al-1', 'x')).error, startsWith('No pudimos registrar el contacto'));
    });
  });

  group('Portal de la alumna (US-25..US-27)', () {
    final respuesta = {
      'alumna': {'id': 'a1', 'nombres': 'Valentina', 'apellidos': 'Soto Morales', 'rut': '22.341.890-2'},
      'apoderado': {'nombre': 'Marcela Morales', 'telefono': '+56 9 8765 4321'},
      'inscripcion': {'id': 'i1', 'estado': 'activa'},
      'curso': {
        'instancia_id': 'inst-1',
        'codigo': 'PCB',
        'nombre': 'Programación Competitiva Básica',
        'periodo': '2026-2',
        'seccion': 1,
        'sede_nombre': 'Sede Beauchef',
        'classroom_url': 'https://classroom.google.com/c/x',
        'juez_virtual_url': null,
        'porcentaje_minimo': 80,
      },
      'hoy': '2026-11-21',
      'sesiones': [
        {
          'id': 'c1',
          'numero_sesion': 1,
          'fecha': '2026-11-14',
          'estado': 'realizada',
          'tema': 'Variables',
          'asistencia': 'justificada',
          'recursos': [
            {'id': 'r1', 'titulo': 'Guía', 'tipo': 'guia', 'url': 'https://recursos.ninaspro.cl/g.pdf'},
          ],
        },
        {'id': 'c2', 'numero_sesion': 2, 'fecha': '2026-11-21', 'estado': 'programada', 'tema': null},
      ],
      'asistencia': {
        'realizadas': 1,
        'presentes': 0,
        'justificadas': 1,
        'recuperadas': 1,
        'asistidas': 1,
        'porcentaje': 100.0,
        'umbral': 70,
        'umbral_reducido': true,
        'justificativos_aceptados': 1,
        'total_clases': 2,
        'restantes': 1,
        'clases_necesarias': 1,
      },
      'ejercicios': {'total': 26, 'hitos': 1},
      'podios': {'primero': 1, 'segundo': 0, 'tercero': 0},
    };

    test('traduce el portal con su curso, cronograma, recursos y meta', () async {
      final repo = SupabasePortalRepository(cliente((_) => ok(respuesta)));
      final p = await repo.portal();
      expect(pedidos.single.url.path, endsWith('/rpc/portal_alumna'));
      expect(
        (p.nombreCompleto, p.curso!.nombre, p.curso!.anio, p.curso!.semestre),
        ('Valentina Soto Morales', 'Programación Competitiva Básica', 2026, 2),
      );
      expect(p.sesiones.first.recursos.single.esSeguraHttps, isTrue);
      expect(p.sesiones.last.tema, 'Tema por publicar');
      expect(p.estadoDe(p.sesiones.first), EstadoAsistencia.justificada);
      expect(p.estadoDe(p.sesiones.last), EstadoAsistencia.pendiente);
      expect(p.sesionHoy?.id, 'c2');
      expect((p.asistencia.umbral, p.asistencia.umbralReducido, p.asistencia.cumpleMeta), (70, true, true));
      expect((p.ejercicios, p.hitosEjercicios, p.podiosPrimero), (26, 1, 1));
    });

    test('sin curso, el portal trae solo la ficha', () {
      final p = MapeoPortal.portal({
        'alumna': {'id': 'a1', 'nombres': 'Ana', 'apellidos': 'Sin Curso', 'rut': '1-9'},
        'apoderado': {'nombre': 'Apoderada', 'telefono': '1'},
        'inscripcion': null,
      });
      expect((p.curso, p.inscripcionEstado, p.asistencia.cumpleMeta), (null, null, true));
      expect(p.sesiones, isEmpty);
    });

    test('el 403 de otra alumna llega como PortalDenegado con el motivo (US-27 E2)', () async {
      final repo = SupabasePortalRepository(
        cliente((_) => error(403, '42501', 'Solo puedes ver tu propio portal. El intento quedó registrado.')),
      );
      await expectLater(
        repo.portal(),
        throwsA(isA<PortalDenegado>().having((e) => e.toString(), 'mensaje', contains('propio portal'))),
      );
      expect(() => MapeoPortal.portal({'code': '42501', 'message': 'No.'}), throwsA(isA<PortalDenegado>()));

      final caida = SupabasePortalRepository(cliente((_) => error(500, 'XX000', 'boom')));
      await expectLater(caida.portal(), throwsA(isA<PostgrestException>()));
    });
  });

  group('Vistas', () {
    Future<void> abrir(WidgetTester tester, Widget pantalla) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: NinasProTheme.light, home: pantalla));
      await tester.pumpAndSettle();
    }

    testWidgets('el portal denegado muestra el motivo y permite reintentar', (tester) async {
      final repo = FakePortalRepository(rechazo: 'Solo puedes ver tu propio portal. El intento quedó registrado.');
      await abrir(tester, PortalAlumnaScreen(repository: repo));
      expect(find.text('Solo puedes ver tu propio portal. El intento quedó registrado.'), findsOneWidget);

      repo.rechazo = null;
      unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
      await tester.pumpAndSettle();
      expect(find.text('Mi Asistencia Acumulada'), findsOneWidget);
      expect(repo.consultas, 2);
    });

    testWidgets('el portal sin conexión lo explica', (tester) async {
      final repo = FakePortalRepository()..sinConexion = true;
      await abrir(tester, PortalAlumnaScreen(repository: repo));
      expect(find.textContaining('No pudimos cargar tu portal'), findsOneWidget);
    });

    testWidgets('con un justificativo aceptado la meta baja y se celebra la clase recuperada (US-25 E1, E3)', (
      tester,
    ) async {
      final repo = FakePortalRepository(
        valor: FakePortalRepository.portalDemo(
          asistencia: const AsistenciaPortal(
            realizadas: 3,
            presentes: 2,
            justificadas: 1,
            recuperadas: 1,
            asistidas: 3,
            porcentaje: 100,
            umbral: 70,
            umbralReducido: true,
            justificativosAceptados: 1,
            totalClases: 9,
            restantes: 6,
          ),
        ),
      );
      await abrir(tester, PortalAlumnaScreen(repository: repo));
      expect(find.text('Cumple meta para certificar'), findsOneWidget);
      expect(find.textContaining('Meta reducida al 70%'), findsOneWidget);
      expect(find.text('¡Tus ejercicios recuperaron 1 clase justificada! 🎉'), findsOneWidget);
    });

    testWidgets('cuando ya no alcanzan las clases, el mensaje sigue siendo de motivación', (tester) async {
      final repo = FakePortalRepository(
        valor: FakePortalRepository.portalDemo(
          asistencia: const AsistenciaPortal(
            realizadas: 8,
            presentes: 3,
            asistidas: 3,
            porcentaje: 37.5,
            umbral: 80,
            totalClases: 10,
            restantes: 2,
            clasesNecesarias: 5,
          ),
        ),
      );
      await abrir(tester, PortalAlumnaScreen(repository: repo));
      expect(find.textContaining('conversa con tu tutora'), findsOneWidget);
      expect(find.textContaining('riesgo'), findsNothing);
    });

    testWidgets('sin curso asignado el portal lo dice', (tester) async {
      final repo = FakePortalRepository(valor: FakePortalRepository.portalDemo(conCurso: false));
      await abrir(tester, PortalAlumnaScreen(repository: repo));
      expect(find.text('Aún no tienes un curso asignado'), findsOneWidget);
      expect(find.text('Tu cronograma aparecerá cuando tengas un curso asignado.'), findsOneWidget);
    });

    testWidgets('los Ajustes de la alumna muestran su ficha y su apoderada', (tester) async {
      await abrir(tester, AjustesAlumnaScreen(repository: FakePortalRepository()));
      expect(find.text('Valentina Soto Morales'), findsOneWidget);
      expect(find.text('22.341.890-2'), findsOneWidget);
      expect(find.text('Marcela Morales Gómez'), findsOneWidget);
    });

    testWidgets('los Ajustes de la alumna sin conexión lo explican', (tester) async {
      await abrir(tester, AjustesAlumnaScreen(repository: FakePortalRepository()..sinConexion = true));
      expect(find.text('No pudimos cargar tu ficha. Revisa tu conexión.'), findsOneWidget);
      expect(find.text('Mi perfil'), findsNothing);
    });

    testWidgets('el panel de alertas filtra por estado y por sede (US-40 E1, E2)', (tester) async {
      final repo = FakeAlertasRepository(
        lista: [
          FakeAlertasRepository.alertaDemo(),
          FakeAlertasRepository.alertaDemo(
            id: 'alerta-2',
            alumnaNombre: 'Renata Ibáñez Cortés',
            sedeId: 'sede-sj',
            sedeNombre: 'Sede San Joaquín',
          ),
          FakeAlertasRepository.alertaDemo(
            id: 'alerta-3',
            alumnaNombre: 'Ignacia Muñoz',
            atendida: true,
            observacion: 'Salud',
          ),
        ],
      );
      var cambios = 0;
      await abrir(
        tester,
        Scaffold(
          body: AlertasDesercionView(repository: repo, alCambiar: () => cambios++),
        ),
      );

      expect(find.textContaining('herramienta de acompañamiento'), findsOneWidget);
      expect(find.text('Florencia Muñoz Tapia'), findsOneWidget);
      expect(find.text('Renata Ibáñez Cortés'), findsOneWidget);
      expect(find.text('Ignacia Muñoz'), findsNothing);

      // La Directiva ve varias sedes y filtra por una
      await tester.tap(find.text('Sede San Joaquín').first);
      await tester.pumpAndSettle();
      expect(find.text('Florencia Muñoz Tapia'), findsNothing);
      await tester.tap(find.text('Todas las sedes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contactadas'));
      await tester.pumpAndSettle();
      expect(find.text('Ignacia Muñoz'), findsOneWidget);
      expect(find.text('“Salud”'), findsOneWidget);
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar contacto'), findsNWidgets(2));

      await tester.tap(find.text('Registrar contacto').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Conversé con el padre.');
      await tester.tap(find.text('Guardar contacto'));
      await tester.pumpAndSettle();
      expect(cambios, 1);
      expect(repo.porId('alerta-1').atendida, isTrue);
      expect(find.text('Registrar contacto'), findsOneWidget);
    });

    testWidgets('el panel de alertas sin conexión lo explica', (tester) async {
      final repo = FakeAlertasRepository()..sinConexion = true;
      await abrir(tester, Scaffold(body: AlertasDesercionView(repository: repo)));
      expect(find.textContaining('No pudimos cargar las alertas'), findsOneWidget);
    });
  });

  test('sin cola de la clase, la nubecita siempre está al día', () {
    const fuente = SinCambiosPendientes();
    expect(fuente.estadoSincronizacion.value, EstadoSincronizacion.sincronizado);
    expect(fuente.cambiosPendientes.value, 0);
    expect(fuente.ultimoRechazo.value, isNull);
  });
}
