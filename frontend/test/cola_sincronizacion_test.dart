import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/data/offline/cola_sincronizacion.dart';
import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:sembast/sembast_memory.dart';

var _base = 0;

void main() {
  late StreamController<bool> conexion;
  late List<OperacionPendiente> recibidas;
  late bool conectado;
  late String? rechazo;
  late String perfil;
  late ColaSincronizacion cola;

  OperacionPendiente op(String clave, {int prioridad = 0, Map<String, dynamic>? datos, DateTime? en, String? de}) =>
      OperacionPendiente(
        clave: clave,
        tipo: 'asistencia_alumnas',
        datos: datos ?? {'clase_id': clave},
        guardadoEn: en ?? DateTime.now().toUtc(),
        perfilId: de ?? perfil,
        prioridad: prioridad,
      );

  setUp(() {
    conexion = StreamController<bool>();
    recibidas = [];
    conectado = true;
    rechazo = null;
    perfil = 'perfil-daniela';
    cola = ColaSincronizacion(
      base: databaseFactoryMemory.openDatabase('cola_test_${_base++}'),
      enviar: (o) async {
        if (!conectado) throw Exception('Sin conexión');
        if (rechazo != null) throw RechazoServidorException(rechazo!);
        recibidas.add(o);
        return o.datos['aviso'] as String?;
      },
      perfilActual: () => perfil,
      conexion: conexion.stream,
      intervaloReintento: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    await cola.cerrar();
    await conexion.close();
  });

  test('con conexión el guardado sube al instante y devuelve el aviso de la nube', () async {
    final r = await cola.guardar(op('a', datos: {'aviso': '1 justificada se mantiene.'}));

    expect(r.guardado, isTrue);
    expect(r.mensaje, '1 justificada se mantiene.');
    expect(recibidas, hasLength(1));
    expect(cola.cambiosPendientes.value, 0);
    expect(cola.estadoSincronizacion.value, EstadoSincronizacion.sincronizado);
  });

  test('sin conexión queda pendiente y se sube sola al volver la red, sin duplicar (US-14)', () async {
    conectado = false;
    final r = await cola.guardar(op('a'));

    expect(r.pendiente, isTrue);
    expect(cola.cambiosPendientes.value, 1);
    expect(cola.estadoSincronizacion.value, EstadoSincronizacion.sinConexion);
    expect(await cola.pendiente('a'), isNotNull);

    conectado = true;
    conexion.add(true);
    await Future<void>.delayed(Duration.zero);
    await cola.sincronizar();

    expect(recibidas, hasLength(1));
    expect(cola.cambiosPendientes.value, 0);
    expect(cola.estadoSincronizacion.value, EstadoSincronizacion.sincronizado);
    expect(await cola.pendiente('a'), isNull);

    // Otra vuelta no reenvía nada
    await cola.sincronizar();
    expect(recibidas, hasLength(1));
  });

  test('un guardado nuevo de la misma lista reemplaza al pendiente: se sube solo la última versión', () async {
    conectado = false;
    await cola.guardar(op('a', datos: {'version': 1}));
    await cola.guardar(op('a', datos: {'version': 2}));
    expect(cola.cambiosPendientes.value, 1);

    conectado = true;
    await cola.sincronizar();
    expect(recibidas.map((o) => o.datos['version']), [2]);
  });

  test('sube primero la asistencia y después la participación y el podio', () async {
    conectado = false;
    final ahora = DateTime.now().toUtc();
    await cola.guardar(op('podio', prioridad: 2, en: ahora));
    await cola.guardar(op('participacion', prioridad: 1, en: ahora.add(const Duration(seconds: 1))));
    await cola.guardar(op('asistencia', en: ahora.add(const Duration(seconds: 2))));

    conectado = true;
    await cola.sincronizar();
    expect(recibidas.map((o) => o.clave), ['asistencia', 'participacion', 'podio']);
  });

  test('si la nube rechaza el guardado se informa y no se reintenta', () async {
    rechazo = 'La clase está suspendida.';
    final r = await cola.guardar(op('a'));

    expect(r.rechazado, isTrue);
    expect(r.mensaje, 'La clase está suspendida.');
    expect(cola.cambiosPendientes.value, 0);
    expect(cola.ultimoRechazo.value, isNull, reason: 'quien guardó ya lo ve en su pantalla');
  });

  test('un pendiente que la nube rechaza al reconectar se avisa en la nubecita', () async {
    conectado = false;
    await cola.guardar(op('a'));

    conectado = true;
    rechazo = 'La clase ya está cerrada para edición.';
    await cola.sincronizar();

    expect(cola.ultimoRechazo.value, 'La clase ya está cerrada para edición.');
    expect(cola.cambiosPendientes.value, 0);
  });

  test('los pendientes de otra cuenta del mismo dispositivo no se suben con la sesión actual', () async {
    conectado = false;
    await cola.guardar(op('a'));
    perfil = 'perfil-camila';
    conectado = true;
    await cola.sincronizar();

    expect(recibidas, isEmpty);
    expect(cola.cambiosPendientes.value, 0);

    perfil = 'perfil-daniela';
    await cola.sincronizar();
    expect(recibidas.single.perfilId, 'perfil-daniela');
  });

  test('sin conexión reintenta solo cada cierto tiempo', () async {
    conectado = false;
    await cola.guardar(op('a'));
    conectado = true;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(recibidas, hasLength(1));
    expect(cola.estadoSincronizacion.value, EstadoSincronizacion.sincronizado);
  });

  test('al perder la red el estado pasa a sin conexión', () async {
    conexion.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(cola.estadoSincronizacion.value, EstadoSincronizacion.sinConexion);
  });

  test('la operación se guarda y se lee igual desde el dispositivo', () {
    final original = op(
      'asistencia_alumnas:clase-1',
      prioridad: 1,
      datos: {
        'registros': [
          {'inscripcion_id': 'i1', 'estado': 'presente'},
        ],
      },
    );
    final copia = OperacionPendiente.fromJson(original.toJson());

    expect(copia.clave, original.clave);
    expect(copia.prioridad, 1);
    expect(copia.guardadoEn, original.guardadoEn);
    expect(copia.datos['registros'], original.datos['registros']);
  });
}
