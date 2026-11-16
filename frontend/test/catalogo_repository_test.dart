import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/repositories/catalogo_repository.dart';
import 'package:ninas_pro_hub/utils/calendario.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const json = {'content-type': 'application/json'};

  final filaInstancia = {
    'id': 'inst-1',
    'curso_id': 'cat-pcb',
    'sede_id': 'sede-a',
    'periodo_academico': '2026-2',
    'seccion': 2,
    'fecha_inicio': '2026-08-01',
    'fecha_termino': '2026-11-28',
    'dia_semana': 'Sábado',
    'hora_inicio': '10:00:00',
    'hora_fin': '13:00:00',
    'classroom_url': null,
    'juez_virtual_url': null,
    'cursos': {'codigo': 'PCB', 'nombre': 'Programación Competitiva Básica'},
    'sedes': {'nombre': 'Sede San Joaquín'},
    'clases': [
      {'count': 18},
    ],
  };

  group('calendario', () {
    test('entre el 1 de agosto y el 28 de noviembre de 2026 hay 18 sábados', () {
      final fechas = fechasSesiones(DateTime(2026, 8, 1), DateTime(2026, 11, 28), DateTime.saturday);
      expect(fechas, hasLength(18));
      expect(fechas.first, DateTime(2026, 8, 1));
      expect(fechas.last, DateTime(2026, 11, 28));
      expect(fechas.every((f) => f.weekday == DateTime.saturday), isTrue);
    });

    test('si el inicio no cae en el día elegido parte desde el siguiente', () {
      expect(fechasSesiones(DateTime(2026, 8, 3), DateTime(2026, 8, 28), DateTime.saturday), [
        DateTime(2026, 8, 8),
        DateTime(2026, 8, 15),
        DateTime(2026, 8, 22),
      ]);
      expect(fechasSesiones(DateTime(2026, 8, 3), DateTime(2026, 8, 7), DateTime.saturday), isEmpty);
    });

    test('el período académico se divide en julio', () {
      expect(periodoAcademico(DateTime(2026, 6, 30)), '2026-1');
      expect(periodoAcademico(DateTime(2026, 7, 1)), '2026-2');
      expect(partesPeriodo('2026-2', DateTime(2000)), (anio: 2026, semestre: 2));
      expect(partesPeriodo('2026-S1', DateTime(2000)), (anio: 2026, semestre: 1));
      expect(partesPeriodo('otoño', DateTime(2025, 9, 1)), (anio: 2025, semestre: 2));
      expect(horaCorta('10:00:00'), '10:00');
      expect(horaCorta(null), isNull);
    });

    test('el código de la instancia quita "Sede", tildes y espacios', () {
      expect(
        codigoInstancia(codigoCurso: 'PCB', sedeNombre: 'Sede San Joaquín', anio: 2026, semestre: 2),
        'PCB-2026-S2-SANJOAQUIN',
      );
      expect(
        codigoInstancia(codigoCurso: 'WEB', sedeNombre: 'Valparaíso', anio: 2027, semestre: 1, seccion: 3),
        'WEB-2027-S1-VALPARAISO-C',
      );
    });
  });

  group('MapeoCatalogo', () {
    test('la coordinadora de la sede es su líder del Equipo de Gestión', () {
      final sede = MapeoCatalogo.sede({
        'id': 'sede-a',
        'nombre': 'Sede Beauchef',
        'region': 'Región Metropolitana',
        'modalidad': 'online',
        'institucion_anfitriona': 'Universidad de Chile',
        'activa': false,
        'usuarios_sedes': [
          {'es_lider_sede': false, 'perfiles': {'nombres': 'Daniela', 'apellidos': 'Valenzuela'}},
          {'es_lider_sede': true, 'perfiles': {'nombres': 'Camila', 'apellidos': 'Sepúlveda'}},
        ],
      });
      expect(sede.coordinadoraNombre, 'Camila Sepúlveda');
      expect(sede.modalidad, 'Online');
      expect(sede.estado, 'inactiva');
      expect(sede.universidad, 'Universidad de Chile');

      final sinLider = MapeoCatalogo.sede({'id': 's', 'nombre': 'Sede Nueva', 'modalidad': 'presencial'});
      expect(sinLider.coordinadoraNombre, isEmpty);
      expect(sinLider.modalidad, 'Presencial');
      expect(sinLider.estado, 'activa');
    });

    test('la instancia trae su sección, horario, día y total de sesiones', () {
      final c = MapeoCatalogo.instancia(filaInstancia);
      expect(c.codigo, 'PCB-2026-S2-SANJOAQUIN-B');
      expect(c.seccion, 2);
      expect(c.seccionLetra, 'B');
      expect(c.anio, 2026);
      expect(c.semestre, 2);
      expect(c.diaSemana, DateTime.saturday);
      expect(c.horaInicio, '10:00');
      expect(c.horaFin, '13:00');
      expect(c.totalSesiones, 18);
      expect(c.catalogoId, 'cat-pcb');
      expect(c.fechaTermino, DateTime(2026, 11, 28));
    });

    test('la sesión trae su tema, su estado y el motivo de la suspensión', () {
      final s = MapeoCatalogo.sesion({
        'id': 'clase-3',
        'instancia_curso_id': 'inst-1',
        'numero_sesion': 3,
        'fecha': '2026-09-19',
        'hora_inicio': '10:00:00',
        'hora_fin': '13:00:00',
        'estado': 'suspendida',
        'motivo_suspension': 'Fiestas Patrias',
        'es_especial': false,
        'planificacion_clases': {'tema_titulo': 'Ciclos'},
      });
      expect(s.suspendida, isTrue);
      expect(s.motivoSuspension, 'Fiestas Patrias');
      expect(s.tema, 'Ciclos');
      expect(s.horaInicio, '10:00');

      final sinPlan = MapeoCatalogo.sesion({
        'id': 'clase-19',
        'instancia_curso_id': 'inst-1',
        'numero_sesion': 19,
        'fecha': '2026-12-02',
        'estado': 'programada',
        'es_especial': true,
      });
      expect(sinPlan.tema, isEmpty);
      expect(sinPlan.esEspecial, isTrue);
    });
  });

  group('SupabaseCatalogoRepository', () {
    late List<http.Request> pedidos;

    SupabaseCatalogoRepository crear(http.Response Function(http.Request r) responder) {
      pedidos = [];
      final cliente = MockClient((r) async {
        pedidos.add(r);
        final resp = responder(r);
        return http.Response(resp.body, resp.statusCode, headers: resp.headers, request: r);
      });
      return SupabaseCatalogoRepository(SupabaseClient('http://localhost:54321', 'anon', httpClient: cliente));
    }

    http.Response error(int status, String code, String message) =>
        http.Response(jsonEncode({'code': code, 'message': message, 'details': null, 'hint': null}), status,
            headers: json);

    test('crea la sede con la modalidad de la base y avisa si el nombre ya existe', () async {
      var respuesta = http.Response(jsonEncode([{'id': 'sede-n'}]), 201, headers: json);
      final repo = crear((_) => respuesta);

      final ok = await repo.crearSede(
        const DatosSede(nombre: ' Sede Concepción ', institucion: 'UdeC', region: 'Biobío', modalidad: 'Online'),
      );
      expect(ok.ok, isTrue);
      expect(pedidos.single.method, 'POST');
      expect(pedidos.single.url.path, '/rest/v1/sedes');
      expect(jsonDecode(pedidos.single.body), containsPair('modalidad', 'online'));
      expect(jsonDecode(pedidos.single.body), containsPair('nombre', 'Sede Concepción'));

      respuesta = error(409, '23505', 'duplicate key value violates unique constraint "sedes_nombre_unico"');
      final repetida = await repo.crearSede(
        const DatosSede(nombre: 'Sede Concepción', institucion: 'UdeC', region: 'Biobío', modalidad: 'Presencial'),
      );
      expect(repetida.error, 'Ya existe una sede con ese nombre. Los nombres no distinguen tildes, mayúsculas ni signos.');
    });

    test('un curso con código repetido o sin permiso devuelve el mensaje para mostrar', () async {
      var respuesta = error(409, '23505', 'duplicate key');
      final repo = crear((_) => respuesta);

      final repetido = await repo.crearCurso(const DatosCurso(codigo: 'pcb', nombre: 'Otro'));
      expect(repetido.error, 'El código "PCB" ya está en uso.');
      expect(jsonDecode(pedidos.single.body), containsPair('codigo', 'PCB'));

      respuesta = error(403, '42501', 'new row violates row-level security policy for table "cursos"');
      final sinPermiso = await repo.crearCurso(const DatosCurso(codigo: 'WEB', nombre: 'Web'));
      expect(sinPermiso.error, 'No tienes permiso para hacer este cambio.');

      // La RLS de UPDATE no lanza error: devuelve 0 filas
      respuesta = http.Response('[]', 200, headers: json);
      final ninguna = await repo.actualizarCurso('cat-1', const DatosCurso(codigo: 'WEB', nombre: 'Web'));
      expect(ninguna.error, 'No tienes permiso para hacer este cambio.');
    });

    test('lee las instancias de una sede con el conteo de sesiones', () async {
      final repo = crear((_) => http.Response(jsonEncode([filaInstancia]), 200, headers: json));
      final lista = await repo.instancias(sedeId: 'sede-a');

      final q = pedidos.single.url.queryParameters;
      expect(pedidos.single.url.path, '/rest/v1/instancias_curso');
      expect(q['sede_id'], 'eq.sede-a');
      expect(q['select'], contains('clases(count)'));
      expect(lista.single.totalSesiones, 18);
    });

    test('programa la instancia con la RPC y distingue la duplicada', () async {
      var duplicada = true;
      final repo = crear((r) {
        if (r.url.path.endsWith('/rpc/crear_instancia_curso')) {
          return duplicada
              ? error(409, 'PT409', 'Ya existe una instancia de este curso en esta sede para el período 2026-2.')
              : http.Response(jsonEncode({'id': 'inst-1', 'total_sesiones': 18}), 200, headers: json);
        }
        return http.Response(jsonEncode(filaInstancia), 200, headers: json);
      });
      final solicitud = SolicitudInstancia(
        catalogoId: 'cat-pcb',
        sedeId: 'sede-a',
        inicio: DateTime(2026, 8, 1),
        termino: DateTime(2026, 11, 28),
        diaSemana: DateTime.saturday,
        horaInicio: '18:00',
        horaFin: '20:30',
      );

      final primera = await repo.crearInstancia(solicitud);
      expect(primera.duplicada, isTrue);
      expect(primera.error, contains('Ya existe una instancia'));
      final params = jsonDecode(pedidos.single.body) as Map<String, dynamic>;
      expect(params, containsPair('p_fecha_inicio', '2026-08-01'));
      expect(params, containsPair('p_fecha_termino', '2026-11-28'));
      expect(params, containsPair('p_dia_semana', 6));
      expect(params, containsPair('p_hora_fin', '20:30'));
      expect(params, containsPair('p_nueva_seccion', false));

      duplicada = false;
      final paralela = await repo.crearInstancia(solicitud, nuevaSeccion: true);
      expect(paralela.ok, isTrue);
      expect(paralela.valor!.codigo, 'PCB-2026-S2-SANJOAQUIN-B');
      expect(jsonDecode(pedidos[1].body), containsPair('p_nueva_seccion', true));
    });

    test('suspende, reanuda y agrega sesiones mostrando los mensajes de la base', () async {
      var respuesta = http.Response(jsonEncode([{'id': 'clase-3'}]), 200, headers: json);
      final repo = crear((_) => respuesta);

      expect((await repo.suspenderSesion('clase-3', ' Feriado ')).ok, isTrue);
      expect(pedidos.last.method, 'PATCH');
      expect(pedidos.last.url.queryParameters['id'], 'eq.clase-3');
      expect(jsonDecode(pedidos.last.body), {'estado': 'suspendida', 'motivo_suspension': 'Feriado'});

      expect((await repo.reanudarSesion('clase-3')).ok, isTrue);
      expect(jsonDecode(pedidos.last.body), {'estado': 'programada'});

      respuesta = error(400, '22023', 'No se puede suspender una clase que ya tiene asistencia registrada.');
      expect(
        (await repo.suspenderSesion('clase-1', 'Tarde')).error,
        'No se puede suspender una clase que ya tiene asistencia registrada.',
      );

      respuesta = http.Response(
        jsonEncode({
          'id': 'clase-19',
          'instancia_curso_id': 'inst-1',
          'numero_sesion': 19,
          'fecha': '2026-12-02',
          'hora_inicio': '15:00:00',
          'hora_fin': '18:00:00',
          'estado': 'programada',
          'es_especial': true,
        }),
        200,
        headers: json,
      );
      final especial = await repo.agregarSesionEspecial(
        instanciaId: 'inst-1',
        fecha: DateTime(2026, 12, 2),
        horaInicio: '15:00',
        horaFin: '18:00',
      );
      expect(especial.valor!.numeroSesion, 19);
      expect(pedidos.last.url.path, '/rest/v1/rpc/agregar_sesion_especial');
      expect(jsonDecode(pedidos.last.body), containsPair('p_fecha', '2026-12-02'));

      respuesta = error(403, '42501', 'Solo el Equipo de Gestión de la sede agrega sesiones.');
      final ajena = await repo.agregarSesionEspecial(
        instanciaId: 'inst-1',
        fecha: DateTime(2026, 12, 3),
        horaInicio: '15:00',
        horaFin: '18:00',
      );
      expect(ajena.error, 'Solo el Equipo de Gestión de la sede agrega sesiones.');

      respuesta = http.Response('boom', 500);
      expect((await repo.reanudarSesion('clase-3')).error, contains('Revisa tu conexión'));
    });

    test('lee los usos de sedes y cursos y elimina solo los que no se usan', () async {
      var respuesta = http.Response(
        jsonEncode([
          {
            'id': 'sede-a',
            'nombre': 'Sede Beauchef',
            'modalidad': 'presencial',
            'activa': true,
            'usuarios_sedes': [
              {'es_lider_sede': true, 'perfiles': {'nombres': 'Camila', 'apellidos': 'Sepúlveda'}},
              {'es_lider_sede': false, 'perfiles': {'nombres': 'Daniela', 'apellidos': 'Valenzuela'}},
            ],
            'instancias_curso': [
              {'count': 1},
            ],
            'correos_autorizados': [
              {'count': 3},
            ],
          },
          {
            'id': 'sede-b',
            'nombre': 'Sede Libre',
            'modalidad': 'presencial',
            'activa': true,
            'usuarios_sedes': [],
            'instancias_curso': [
              {'count': 0},
            ],
            'correos_autorizados': [
              {'count': 0},
            ],
          },
        ]),
        200,
        headers: json,
      );
      final repo = crear((_) => respuesta);

      final sedes = await repo.sedes();
      expect(sedes.first.usos, ['1 instancia de curso', '2 personas asignadas', '3 accesos pendientes']);
      expect(sedes.last.usos, isEmpty);
      expect(pedidos.last.url.queryParameters['correos_autorizados.usado_en'], 'is.null');

      respuesta = http.Response(
        jsonEncode([
          {
            'id': 'cat-1',
            'codigo': 'PCB',
            'nombre': 'Programación',
            'descripcion': null,
            'instancias_curso': [
              {'count': 2},
            ],
          },
        ]),
        200,
        headers: json,
      );
      expect((await repo.cursos()).single.usos, ['2 instancias de curso']);

      respuesta = http.Response(jsonEncode([{'id': 'sede-b'}]), 200, headers: json);
      expect((await repo.eliminarSede('sede-b')).ok, isTrue);
      expect(pedidos.last.method, 'DELETE');
      expect(pedidos.last.url.queryParameters['id'], 'eq.sede-b');

      respuesta = error(409, '23503', 'No se puede eliminar "PCB": tiene 2 instancias de curso.');
      expect((await repo.eliminarCurso('cat-1')).error, 'No se puede eliminar "PCB": tiene 2 instancias de curso.');

      respuesta = error(409, '23503', 'update or delete on table "sedes" violates foreign key constraint');
      expect((await repo.eliminarSede('sede-a')).error, 'No se puede eliminar: hay registros que lo usan.');

      respuesta = http.Response('[]', 200, headers: json);
      expect((await repo.eliminarCurso('cat-1')).error, 'No tienes permiso para hacer este cambio.');
    });

    test('lee las sesiones de la instancia ordenadas por fecha', () async {
      final repo = crear((_) => http.Response('[]', 200, headers: json));
      await repo.sesiones('inst-1');
      expect(pedidos.single.url.queryParameters['instancia_curso_id'], 'eq.inst-1');
      expect(pedidos.single.url.queryParameters['order'], 'fecha.asc.nullslast');
      await repo.sedes();
      await repo.cursos();
      expect(pedidos.map((p) => p.url.path), contains('/rest/v1/cursos'));
    });
  });
}
