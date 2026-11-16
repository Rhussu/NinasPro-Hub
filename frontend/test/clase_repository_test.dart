import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/data/offline/cola_sincronizacion.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/clase_repository.dart';
import 'package:ninas_pro_hub/screens/tutora/clase_sesion_controller.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_clase_repository.dart';

var _base = 0;

void main() {
  const json = {'content-type': 'application/json'};

  Map<String, dynamic> fila(String insc, {String? estado, int? ejercicios, int? podio, bool foto = true}) => {
    'inscripcion_id': insc,
    'alumna_id': 'alumna-$insc',
    'nombres': 'Alumna',
    'apellidos': insc.toUpperCase(),
    'rut': '23.456.789-0',
    'autoriza_imagen': foto,
    'estado': estado,
    'registrado_por_nombre': estado == null ? null : 'Daniela Valenzuela',
    'actualizado_en': estado == null ? null : '2026-11-14T13:05:00+00:00',
    'ejercicios': ejercicios,
    'participo_activa': ejercicios == null ? null : true,
    'podio_kahoot': podio,
  };

  SesionClase sesion(int n, DateTime fecha, {String estado = 'programada'}) =>
      SesionClase(id: 'clase-$n', cursoId: 'inst', numeroSesion: n, fecha: fecha, tema: '', estado: estado);

  group('reglas de la clase', () {
    final hoy = DateTime(2026, 11, 14, 11, 30);

    test('la clase actual es la última que ya llegó a su fecha, sin contar las suspendidas', () {
      final sesiones = [
        sesion(1, DateTime(2026, 10, 31), estado: 'realizada'),
        sesion(2, DateTime(2026, 11, 7), estado: 'realizada'),
        sesion(3, DateTime(2026, 11, 14)),
        sesion(4, DateTime(2026, 11, 21)),
      ];
      expect(elegirSesionActual(sesiones, hoy)?.id, 'clase-3');
      expect(
        elegirSesionActual(sesiones, DateTime(2026, 11, 18))?.id,
        'clase-3',
        reason: 'durante la semana sigue la del sábado',
      );
      expect(
        elegirSesionActual(sesiones, DateTime(2026, 10, 1))?.id,
        'clase-1',
        reason: 'antes de empezar, la primera',
      );
      expect(elegirSesionActual(const [], hoy), isNull);

      final conSuspendida = [sesiones[0], sesiones[1], sesiones[2].copyWith(estado: 'suspendida'), sesiones[3]];
      expect(elegirSesionActual(conSuspendida, hoy)?.id, 'clase-2');
    });

    test('solo se pasa lista de clases que ya llegaron y no están suspendidas', () {
      expect(sesionRegistrable(sesion(1, DateTime(2026, 11, 14)), hoy), isTrue);
      expect(sesionRegistrable(sesion(1, DateTime(2026, 11, 7)), hoy), isTrue);
      expect(sesionRegistrable(sesion(1, DateTime(2026, 11, 21)), hoy), isFalse);
      expect(sesionRegistrable(sesion(1, DateTime(2026, 11, 7), estado: 'suspendida'), hoy), isFalse);
    });

    test('la tutora alterna Presente y Ausente, y no toca las justificadas (US-13)', () {
      expect(alternarEstado(EstadoAsistencia.presente), EstadoAsistencia.ausente);
      expect(alternarEstado(EstadoAsistencia.ausente), EstadoAsistencia.presente);
      expect(alternarEstado(EstadoAsistencia.pendiente), EstadoAsistencia.presente);
      expect(alternarEstado(EstadoAsistencia.justificada), isNull);
    });
  });

  group('MapeoClase', () {
    test('la lista trae asistencia, autora, participación y el podio completo', () {
      final lista = MapeoClase.lista('clase-1', [
        fila('i1', estado: 'presente', ejercicios: 4, podio: 2),
        fila('i2', estado: 'justificada', foto: false),
        fila('i3', estado: 'presente', podio: 1, ejercicios: 0),
        fila('i4', estado: 'presente', podio: 3, ejercicios: 1),
      ]);

      expect(lista.tienePaseLista, isTrue);
      expect(lista.registros.first.id, 'i1', reason: 'el id del registro es la inscripción');
      expect(lista.registros.first.alumnaNombre, 'Alumna I1');
      expect(lista.registros.first.editadoPor, 'Daniela Valenzuela');
      expect(lista.registros[1].estado, EstadoAsistencia.justificada);
      expect(lista.registros[1].autorizaImagen, isFalse);
      expect(lista.participaciones.map((p) => p.ejerciciosResueltos), [4, 0, 1]);
      expect(lista.podioAlumnas, ['alumna-i3', 'alumna-i1', 'alumna-i4']);
      expect(lista.podio[1].alumnaNombre, 'Alumna I1');
    });

    test('una clase sin pase de lista trae a las alumnas pendientes y sin podio', () {
      final lista = MapeoClase.lista('clase-1', [fila('i1'), fila('i2')]);
      expect(lista.tienePaseLista, isFalse);
      expect(lista.registros.every((r) => r.estado == EstadoAsistencia.pendiente), isTrue);
      expect(lista.podio, isEmpty);
    });

    test('el podio puede tener menos de tres lugares y se lee en orden', () {
      final una = MapeoClase.lista('clase-1', [fila('i1', estado: 'presente', podio: 1)]);
      expect(una.podioAlumnas, ['alumna-i1']);

      final dos = MapeoClase.lista('clase-1', [
        fila('i1', estado: 'presente', podio: 2),
        fila('i2', estado: 'presente', podio: 1),
      ]);
      expect(dos.podioAlumnas, ['alumna-i2', 'alumna-i1']);

      expect(MapeoClase.datosPodio('c', ['i2', 'i1']), {
        'clase_id': 'c',
        'primero': 'i2',
        'segundo': 'i1',
        'tercero': null,
      });
      expect(lugaresPodio(0), 0);
      expect(lugaresPodio(1), 1);
      expect(lugaresPodio(2), 2);
      expect(lugaresPodio(7), 3);
    });

    test('los cambios guardados sin conexión se ven sobre la lista de la nube', () {
      final base = MapeoClase.lista('clase-1', [
        fila('i1', estado: 'presente'),
        fila('i2', estado: 'presente'),
        fila('i3', estado: 'presente'),
      ]);
      OperacionPendiente pendiente(String tipo, Map<String, dynamic> datos) =>
          OperacionPendiente(clave: tipo, tipo: tipo, datos: datos, guardadoEn: DateTime.now(), perfilId: 'p');
      final registros = [
        for (final r in base.registros) r.id == 'i2' ? r.copyWith(estado: EstadoAsistencia.ausente) : r,
      ];

      final lista = MapeoClase.conPendientes(
        base,
        asistencia: pendiente('a', MapeoClase.datosAsistencia('clase-1', registros)),
        participacion: pendiente('p', {
          'registros': [
            {'inscripcion_id': 'i1', 'ejercicios': 5, 'participo_activa': true},
          ],
        }),
        podio: pendiente('k', {'primero': 'i3', 'segundo': 'i1', 'tercero': 'i2'}),
      );

      expect(lista.conPendientes, isTrue);
      expect(lista.registros[1].estado, EstadoAsistencia.ausente);
      expect(lista.participaciones.single.ejerciciosResueltos, 5);
      expect(lista.podioAlumnas, ['alumna-i3', 'alumna-i1', 'alumna-i2']);
      expect(MapeoClase.conPendientes(base), same(base));
    });

    test('las listas sin estado no se envían y los avisos de la nube se explican', () {
      final datos = MapeoClase.datosAsistencia('c', const [
        RegistroAsistencia(
          id: 'i1',
          sesionId: 'c',
          alumnaId: 'a1',
          alumnaNombre: 'A',
          alumnaRut: '',
          estado: EstadoAsistencia.presente,
          autorizaImagen: true,
        ),
        RegistroAsistencia(
          id: 'i2',
          sesionId: 'c',
          alumnaId: 'a2',
          alumnaNombre: 'B',
          alumnaRut: '',
          estado: EstadoAsistencia.pendiente,
          autorizaImagen: true,
        ),
      ]);
      expect(datos['registros'], [
        {'inscripcion_id': 'i1', 'estado': 'presente'},
      ]);

      expect(MapeoClase.avisoAsistencia({'guardados': 3}), isNull);
      expect(
        MapeoClase.avisoAsistencia({
          'justificadas_conservadas': 2,
          'conservados_por_edicion_posterior': 1,
          'omitidas': 1,
        }),
        '2 inasistencias justificadas se mantienen: las gestiona el Equipo de Gestión. '
        '1 registro ya tenía una corrección más reciente y se conservó. '
        '1 alumna ya no tiene la matrícula activa y no se registró.',
      );
      expect(MapeoClase.avisoParticipacion({'omitidas': 2}), contains('2 alumnas ya no figuran presentes'));
      expect(MapeoClase.estado('otro'), EstadoAsistencia.pendiente);
    });
  });

  group('SupabaseClaseRepository', () {
    late List<http.Request> peticiones;

    SupabaseClaseRepository crear(http.Response Function(http.Request r) responder, {bool sinRed = false}) {
      peticiones = [];
      final cliente = MockClient((r) async {
        peticiones.add(r);
        if (sinRed) throw http.ClientException('XMLHttpRequest error.');
        final resp = responder(r);
        return http.Response(resp.body, resp.statusCode, headers: resp.headers, request: r);
      });
      return SupabaseClaseRepository(
        SupabaseClient('http://localhost:54321', 'anon', httpClient: cliente),
        base: databaseFactoryMemory.openDatabase('repo_clase_${_base++}'),
        perfilActual: () => 'perfil-daniela',
      );
    }

    http.Response ok(Object cuerpo) => http.Response(jsonEncode(cuerpo), 200, headers: json);

    RegistroAsistencia registro(String id, EstadoAsistencia estado) => RegistroAsistencia(
      id: id,
      sesionId: 'clase-1',
      alumnaId: 'a-$id',
      alumnaNombre: id,
      alumnaRut: '',
      estado: estado,
      autorizaImagen: true,
    );

    test('la tutora ve solo los cursos a los que está asignada', () async {
      final repo = crear((_) => ok([]));
      await repo.instancias(tutoraId: 'perfil-daniela');
      final url = peticiones.first.url.toString();
      expect(url, contains('tutores_instancia'));
      expect(peticiones.first.url.queryParameters['tutores_instancia.tutor_id'], 'eq.perfil-daniela');
      expect(peticiones.first.url.queryParameters['activo'], 'eq.true');
      await repo.cola.cerrar();
    });

    test('la lista de la clase sale de la RPC lista_asistencia_clase', () async {
      final repo = crear((_) => ok([fila('i1', estado: 'ausente')]));
      final lista = await repo.lista('clase-1');

      expect(peticiones.single.url.path, endsWith('/rpc/lista_asistencia_clase'));
      expect(jsonDecode(peticiones.single.body), {'p_clase_id': 'clase-1'});
      expect(lista.registros.single.estado, EstadoAsistencia.ausente);
      await repo.cola.cerrar();
    });

    test('guardar la asistencia llama a la RPC con el momento del guardado y trae el aviso', () async {
      final repo = crear((_) => ok({'guardados': 1, 'justificadas_conservadas': 1}));
      final r = await repo.guardarAsistencia('clase-1', [registro('i1', EstadoAsistencia.ausente)]);

      expect(r.guardado, isTrue);
      expect(r.mensaje, contains('1 inasistencia justificada se mantiene'));
      final cuerpo = jsonDecode(peticiones.single.body) as Map<String, dynamic>;
      expect(peticiones.single.url.path, endsWith('/rpc/guardar_asistencia_clase'));
      expect(cuerpo['p_registros'], [
        {'inscripcion_id': 'i1', 'estado': 'ausente'},
      ]);
      expect(DateTime.parse(cuerpo['p_guardado_en'] as String).isUtc, isTrue);
      await repo.cola.cerrar();
    });

    // TC-10 · US-33: pase de lista de tutoras, 8 tutoras con 3 ausentes
    test('la asistencia de tutoras se lee de su RPC y se guarda con autora y hora (TC-10)', () async {
      final tutoras = [
        for (var i = 1; i <= 8; i++)
          {
            'tutor_id': 't$i',
            'nombres': 'Tutora',
            'apellidos': '$i',
            'es_equipo_gestion': i == 1,
            'estado': i <= 3 ? 'ausente' : 'presente',
            'registrado_por_nombre': 'Camila Sepúlveda',
            'actualizado_en': '2026-04-25T14:00:00Z',
          },
      ];
      final repo = crear((r) => r.url.path.endsWith('/rpc/lista_asistencia_tutores')
          ? ok(tutoras)
          : ok({'conservados_por_edicion_posterior': 2}));

      final lista = await repo.asistenciaTutoras('clase-1');
      expect(jsonDecode(peticiones.single.body), {'p_clase_id': 'clase-1'});
      expect(lista, hasLength(8));
      expect(lista.where((t) => t.estado == EstadoAsistencia.ausente), hasLength(3));
      expect(lista.where((t) => t.estado == EstadoAsistencia.presente), hasLength(5));
      expect(lista.first.tutoraNombre, 'Tutora 1');
      expect(lista.first.esEquipoGestion, isTrue);
      expect(lista.first.editadoPor, 'Camila Sepúlveda');
      expect(lista.first.editadoEn, DateTime.utc(2026, 4, 25, 14).toLocal());

      final r = await repo.guardarAsistenciaTutoras('clase-1', lista);
      expect(r.guardado, isTrue);
      expect(r.mensaje, 'Se conservaron las correcciones más recientes de 2 tutoras.');
      final cuerpo = jsonDecode(peticiones.last.body) as Map<String, dynamic>;
      expect(peticiones.last.url.path, endsWith('/rpc/guardar_asistencia_tutores'));
      expect((cuerpo['p_registros'] as List).where((x) => (x as Map)['estado'] == 'ausente'), hasLength(3));
      expect(DateTime.parse(cuerpo['p_guardado_en'] as String).isUtc, isTrue);
      await repo.cola.cerrar();
    });

    test('mi asistencia como tutora filtra por mi perfil y el curso', () async {
      final repo = crear((_) => ok([
            {'clase_id': 'c1', 'estado': 'presente'},
            {'clase_id': 'c2', 'estado': 'ausente'},
          ]));
      final mia = await repo.miAsistencia(instanciaId: 'inst-1', tutoraId: 'perfil-daniela');

      expect(peticiones.single.url.path, endsWith('/asistencia_tutores'));
      expect(peticiones.single.url.queryParameters['tutor_id'], 'eq.perfil-daniela');
      expect(peticiones.single.url.queryParameters['clases.instancia_curso_id'], 'eq.inst-1');
      expect(mia, {'c1': EstadoAsistencia.presente, 'c2': EstadoAsistencia.ausente});
      await repo.cola.cerrar();
    });

    test('las sesiones del curso se leen ordenadas por fecha', () async {
      final repo = crear((_) => ok([]));
      expect(await repo.sesiones('inst-1'), isEmpty);
      expect(peticiones.single.url.path, endsWith('/clases'));
      expect(peticiones.single.url.queryParameters['instancia_curso_id'], 'eq.inst-1');
      expect(peticiones.single.url.queryParameters['order'], 'fecha.asc.nullslast', reason: 'elegirSesionActual toma la última registrable: el orden debe ser ascendente');
      await repo.cola.cerrar();
    });

    test('la participación se envía por su RPC y avisa las alumnas que ya no están presentes', () async {
      final repo = crear((_) => ok({'omitidas': 1}));
      final r = await repo.guardarParticipacion('clase-1', [
        const ParticipacionClase(
          id: 'i1',
          sesionId: 'clase-1',
          alumnaId: 'a1',
          alumnaNombre: 'Ana',
          ejerciciosResueltos: 4,
          participacionActiva: true,
        ),
      ]);

      expect(r.guardado, isTrue);
      expect(r.mensaje, '1 alumna ya no figura presente y no se guardaron sus ejercicios.');
      expect(peticiones.single.url.path, endsWith('/rpc/guardar_participacion_clase'));
      expect(jsonDecode(peticiones.single.body)['p_registros'], [
        {'inscripcion_id': 'i1', 'ejercicios': 4, 'participo_activa': true},
      ]);
      await repo.cola.cerrar();
    });

    test('sin red el pase de lista queda pendiente en el dispositivo', () async {
      final repo = crear((_) => ok({}), sinRed: true);
      final r = await repo.guardarAsistencia('clase-1', [registro('i1', EstadoAsistencia.presente)]);

      expect(r.pendiente, isTrue);
      expect(repo.cambiosPendientes.value, 1);
      expect(repo.estadoSincronizacion.value, EstadoSincronizacion.sinConexion);
      await repo.cola.cerrar();
    });

    test('los rechazos de la base llegan con su mensaje', () async {
      final repo = crear(
        (_) => http.Response(
          jsonEncode({'code': '22023', 'message': 'La clase aún no se realiza.', 'details': null, 'hint': null}),
          400,
          headers: json,
        ),
      );
      final r = await repo.guardarPodio('clase-1', ['i1', 'i2']);
      expect(r.rechazado, isTrue);
      expect(r.mensaje, 'La clase aún no se realiza.');

      final sinPermiso = crear(
        (_) => http.Response(
          jsonEncode({
            'code': '42501',
            'message': 'permission denied for table asistencia_tutores',
            'details': null,
            'hint': null,
          }),
          403,
          headers: json,
        ),
      );
      final r2 = await sinPermiso.guardarAsistenciaTutoras('clase-1', const [
        RegistroAsistenciaTutora(
          sesionId: 'clase-1',
          tutoraId: 't1',
          tutoraNombre: 'T',
          esEquipoGestion: false,
          estado: EstadoAsistencia.presente,
        ),
      ]);
      expect(r2.mensaje, 'No tienes permiso para registrar esta clase.');
      expect(jsonDecode(peticiones.single.body)['p_registros'], [
        {'tutor_id': 't1', 'estado': 'presente'},
      ]);
      await repo.cola.cerrar();
      await sinPermiso.cola.cerrar();
    });

    test('sin sesión no se guarda nada', () async {
      final repo = SupabaseClaseRepository(
        SupabaseClient('http://localhost:54321', 'anon', httpClient: MockClient((_) async => ok({}))),
        base: databaseFactoryMemory.openDatabase('repo_clase_${_base++}'),
        perfilActual: () => null,
      );
      final r = await repo.guardarParticipacion('clase-1', const []);
      expect(r.rechazado, isTrue);
      await repo.cola.cerrar();
    });
  });

  group('ClaseSesionController con la nube en memoria', () {
    late FakeClaseRepository repo;
    late ClaseSesionController clase;

    setUp(() async {
      repo = FakeClaseRepository();
      clase = ClaseSesionController(repository: repo, tutoraId: 'perfil-daniela', hoy: () => repo.hoy);
      await clase.cargar();
    });

    tearDown(() async {
      clase.dispose();
      await repo.cerrar();
    });

    test('abre la clase de hoy con todas presentes y sin pase de lista guardado (US-13)', () {
      expect(clase.curso?.nombre, 'Programación Competitiva Básica (Python)');
      expect(clase.sesionActual?.numeroSesion, 4);
      expect(clase.puedeRegistrar, isTrue);
      expect(clase.tienePaseLista, isFalse);
      expect(clase.totalPresentes, 4);
      expect(clase.alumnasPresentes, isEmpty, reason: 'ejercicios y podio esperan el pase de lista guardado');
    });

    test('guardar marca la clase realizada y habilita ejercicios y podio (US-13, US-28, US-29)', () async {
      expect(clase.ciclarEstado(0), isTrue);
      final r = await clase.guardarAsistencia();

      expect(r.guardado, isTrue);
      expect(repo.estadoAlumna('clase-4', 'insc-1'), EstadoAsistencia.ausente);
      expect(clase.sesionActual?.estado, 'realizada');
      expect(clase.presentesGuardadas, 3);
      expect(clase.alumnasPresentes.map((r) => r.id), ['insc-2', 'insc-3', 'insc-4']);

      clase.actualizarParticipacion(
        clase.participacionDe(clase.alumnasPresentes.first).copyWith(ejerciciosResueltos: 5),
      );
      expect((await clase.guardarParticipacion()).guardado, isTrue);
      expect(repo.participacion('clase-4', 'insc-2'), (5, false));

      final podio = await clase.guardarPodioKahoot(['alumna-insc-4', 'alumna-insc-2', 'alumna-insc-3']);
      expect(podio.guardado, isTrue);
      expect(repo.podio('clase-4'), ['insc-4', 'insc-2', 'insc-3']);

      final repetido = await clase.guardarPodioKahoot(['alumna-insc-4', 'alumna-insc-4', 'alumna-insc-3']);
      expect(repetido.mensaje, 'Elige una alumna distinta para cada lugar del podio.');
      final incompleto = await clase.guardarPodioKahoot(['alumna-insc-4', 'alumna-insc-2']);
      expect(incompleto.rechazado, isTrue, reason: 'con 3 presentes el podio lleva los 3 lugares');
    });

    test('con menos de tres presentes el podio lleva un lugar por presente (US-29)', () async {
      // Solo Catalina y Antonia presentes
      clase.ciclarEstado(0);
      clase.ciclarEstado(2);
      await clase.guardarAsistencia();
      expect(lugaresPodio(clase.alumnasPresentes.length), 2);

      final dos = await clase.guardarPodioKahoot(['alumna-insc-4', 'alumna-insc-2']);
      expect(dos.guardado, isTrue);
      expect(repo.podio('clase-4'), ['insc-4', 'insc-2']);
      expect(clase.podioAlumnas, ['alumna-insc-4', 'alumna-insc-2']);

      // Con una sola presente, queda primera
      clase.ciclarEstado(1);
      await clase.guardarAsistencia();
      expect(clase.alumnasPresentes.map((r) => r.id), ['insc-4']);
      expect((await clase.guardarPodioKahoot(['alumna-insc-4'])).guardado, isTrue);
      expect(repo.podio('clase-4'), ['insc-4']);
      expect((await clase.listaDeSesion('clase-4')).podioAlumnas, ['alumna-insc-4']);
    });

    test('la justificada no se alterna y Gestión la conserva al guardar', () async {
      repo.fijarAsistencia('clase-4', 'insc-2', EstadoAsistencia.justificada);
      await clase.cargarCursoActual();

      expect(clase.registros[1].estado, EstadoAsistencia.justificada);
      expect(clase.ciclarEstado(1), isFalse);
      expect(clase.totalJustificadas, 1);
    });

    test('sin conexión el guardado queda pendiente y al volver la red se sube solo (US-14)', () async {
      repo.simularConexion(false);
      final r = await clase.guardarAsistencia();

      expect(r.pendiente, isTrue);
      expect(clase.pendienteDeEnvio, isTrue);
      expect(clase.tienePaseLista, isTrue);
      expect(repo.estadoAlumna('clase-4', 'insc-1'), isNull);

      repo.simularConexion(true);
      await repo.sincronizar();
      await Future<void>.delayed(Duration.zero);

      expect(repo.estadoAlumna('clase-4', 'insc-1'), EstadoAsistencia.presente);
      expect(clase.pendienteDeEnvio, isFalse);
      expect(repo.envios.where((e) => e == OperacionesClase.asistencia), hasLength(1));
    });

    test('una lista que llega tarde no pisa una corrección posterior (US-15 escenario 2)', () async {
      repo.simularConexion(false);
      clase.ciclarEstado(0); // Valentina ausente, guardado sin red
      await clase.guardarAsistencia();

      // Otra tutora la marca presente con conexión, después
      repo.fijarAsistencia(
        'clase-4',
        'insc-1',
        EstadoAsistencia.presente,
        autora: 'Javiera Muñoz Pizarro',
        en: DateTime.now().add(const Duration(minutes: 1)),
      );
      repo.simularConexion(true);
      await repo.sincronizar();

      expect(repo.estadoAlumna('clase-4', 'insc-1'), EstadoAsistencia.presente);
    });

    test('se corrige la lista de una clase anterior (US-15 escenario 1)', () async {
      final anterior = await clase.listaDeSesion('clase-3');
      expect(anterior.registros.first.estado, EstadoAsistencia.ausente);

      final corregida = [for (final r in anterior.registros) r.copyWith(estado: EstadoAsistencia.presente)];
      final r = await clase.guardarAsistenciaDe('clase-3', corregida);

      expect(r.guardado, isTrue);
      expect(repo.estadoAlumna('clase-3', 'insc-1'), EstadoAsistencia.presente);
      expect((await clase.listaDeSesion('clase-3')).registros.first.editadoPor, 'Daniela Valenzuela Castro');
    });

    test('una tutora sin cursos asignados no ve clases', () async {
      final sinCurso = ClaseSesionController(repository: repo, tutoraId: 'perfil-otra');
      await sinCurso.cargar();
      expect(sinCurso.curso, isNull);
      expect(sinCurso.sesionActual, isNull);
      expect(sinCurso.puedeRegistrar, isFalse);
      sinCurso.dispose();
    });

    test('si no hay conexión al abrir, lo explica', () async {
      repo.simularConexion(false);
      await clase.cargar();
      expect(clase.error, contains('Revisa tu conexión'));
    });
  });
}
