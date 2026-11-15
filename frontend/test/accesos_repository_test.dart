import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/models/sesion_usuario.dart';
import 'package:ninas_pro_hub/repositories/accesos_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const json = {'content-type': 'application/json'};

  final filaTutora = {
    'id': 'aut-1',
    'correo': 'nueva@ninaspro.cl',
    'rol': 'equipo_gestion',
    'sede_id': 'sede-a',
    'es_lider_sede': true,
    'nombres': 'Paula',
    'apellidos': 'Líder',
    'expira_en': '2026-12-15T12:00:00+00:00',
    'usado_en': null,
    'sedes': {'nombre': 'Sede Beauchef'},
    'alumnas': null,
  };
  final filaAlumna = {
    'id': 'aut-2',
    'correo': 'florencia@correo.cl',
    'rol': 'alumna',
    'sede_id': 'sede-a',
    'es_lider_sede': false,
    'nombres': null,
    'apellidos': null,
    'expira_en': '2026-01-01T00:00:00+00:00',
    'usado_en': '2026-01-01T00:00:00+00:00',
    'sedes': {'nombre': 'Sede Beauchef'},
    'alumnas': {'nombres': 'Florencia', 'apellidos': 'Muñoz Tapia'},
  };

  late List<http.Request> pedidos;

  SupabaseAccesosRepository crear(http.Response Function(http.Request r) responder) {
    pedidos = [];
    final cliente = MockClient((r) async {
      pedidos.add(r);
      final resp = responder(r);
      return http.Response(resp.body, resp.statusCode, headers: resp.headers, request: r);
    });
    return SupabaseAccesosRepository(SupabaseClient('http://localhost:54321', 'anon', httpClient: cliente));
  }

  test('lee las autorizaciones con el nombre de la sede y de la alumna', () async {
    final repo = crear((_) => http.Response(jsonEncode([filaTutora, filaAlumna]), 200, headers: json));
    final lista = await repo.autorizaciones();

    expect(pedidos.single.url.path, '/rest/v1/correos_autorizados');
    expect(pedidos.single.url.queryParameters['order'], startsWith('created_at.desc'));

    final lider = lista.first;
    expect(lider.rol, RolUsuario.equipoGestion);
    expect(lider.esLiderSede, isTrue);
    expect(lider.nombre, 'Paula Líder');
    expect(lider.sedeNombre, 'Sede Beauchef');
    expect(lider.estado(DateTime(2026, 11, 15)), EstadoAutorizacion.pendiente);
    expect(lider.estado(DateTime(2027, 1, 1)), EstadoAutorizacion.vencida);

    final alumna = lista.last;
    expect(alumna.nombre, 'Florencia Muñoz Tapia');
    expect(alumna.estado(), EstadoAutorizacion.usada);
  });

  test('lee las sedes y las alumnas sin cuenta ordenadas por nombre', () async {
    final repo = crear((r) => r.url.path.endsWith('/sedes')
        ? http.Response(jsonEncode([{'id': 'sede-a', 'nombre': 'Sede Beauchef'}]), 200, headers: json)
        : http.Response(
            jsonEncode([
              {'id': 'a2', 'rut': '2-7', 'nombres': 'Sofía', 'apellidos': 'Araya', 'correo': null, 'sede_id': 'sede-a', 'sede_nombre': 'Sede Beauchef'},
              {'id': 'a1', 'rut': '1-9', 'nombres': 'Amanda', 'apellidos': 'Contreras', 'correo': 'amanda@correo.cl', 'sede_id': 'sede-a', 'sede_nombre': 'Sede Beauchef'},
            ]),
            200,
            headers: json,
          ));

    final sedes = await repo.sedes();
    expect(sedes.single.nombre, 'Sede Beauchef');

    final alumnas = await repo.alumnasSinCuenta();
    expect(pedidos.last.url.path, '/rest/v1/rpc/alumnas_para_autorizar');
    expect(alumnas.map((a) => a.nombreCompleto), ['Amanda Contreras', 'Sofía Araya']);
    expect(alumnas.first.correo, 'amanda@correo.cl');
  });

  test('autorizar llama a la RPC con todos los datos y relee la fila completa', () async {
    final repo = crear((r) => r.url.path.endsWith('/rpc/autorizar_correo')
        ? http.Response(jsonEncode({...filaTutora, 'sedes': null}), 200, headers: json)
        : http.Response(jsonEncode(filaTutora), 200, headers: json));

    final r = await repo.autorizar(const SolicitudAutorizacion(
      correo: 'nueva@ninaspro.cl',
      rol: RolUsuario.equipoGestion,
      sedeId: 'sede-a',
      rut: '12.345.678-5',
      nombres: 'Paula',
      apellidos: 'Líder',
      esLiderSede: true,
    ));

    expect(r.ok, isTrue);
    expect(r.autorizacion?.sedeNombre, 'Sede Beauchef');
    final cuerpo = jsonDecode(pedidos.first.body) as Map<String, dynamic>;
    expect(cuerpo, containsPair('p_rol', 'equipo_gestion'));
    expect(cuerpo, containsPair('p_es_lider_sede', true));
    expect(cuerpo, containsPair('p_rut', '12.345.678-5'));
    expect(pedidos.last.url.queryParameters['id'], 'eq.aut-1');
  });

  test('el 403 y las validaciones de la base llegan como mensaje; otros errores, como uno genérico', () async {
    var respuesta = http.Response(
      jsonEncode({'code': '42501', 'message': 'No tienes permiso para autorizar este acceso. El intento quedó registrado.'}),
      403,
      headers: json,
    );
    final repo = crear((_) => respuesta);
    const solicitud = SolicitudAutorizacion(correo: 'x@ninaspro.cl', rol: RolUsuario.tutora, sedeId: 'sede-a');

    expect((await repo.autorizar(solicitud)).error, contains('No tienes permiso'));

    respuesta = http.Response(
      jsonEncode({'code': 'P0001', 'message': 'El correo x@ninaspro.cl ya tiene una autorización pendiente.'}),
      400,
      headers: json,
    );
    expect((await repo.autorizar(solicitud)).error, contains('ya tiene una autorización pendiente'));

    respuesta = http.Response(jsonEncode({'code': '23505', 'message': 'duplicate key value'}), 409, headers: json);
    expect((await repo.autorizar(solicitud)).error, contains('No pudimos completar la operación'));
  });

  test('revocar avisa si la autorización ya no se puede borrar', () async {
    var filas = <Map<String, dynamic>>[{'id': 'aut-1'}];
    final repo = crear((_) => http.Response(jsonEncode(filas), 200, headers: json));

    expect((await repo.revocar('aut-1')).ok, isTrue);
    expect(pedidos.single.method, 'DELETE');
    expect(pedidos.single.url.queryParameters['id'], 'eq.aut-1');

    filas = [];
    final r = await repo.revocar('aut-1');
    expect(r.ok, isFalse);
    expect(r.error, contains('ya se creó o no tienes permiso'));
  });
}
