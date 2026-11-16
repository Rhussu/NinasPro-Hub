import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../../models/hub_models.dart';

/// Escritura guardada en el dispositivo hasta que la nube la confirme (US-14, US-34).
///
/// [clave] identifica qué se guarda (ej. `asistencia_alumnas:<clase>`): un
/// guardado nuevo de la misma lista reemplaza al pendiente anterior, así que al
/// reconectar solo se sube la última versión.
@immutable
class OperacionPendiente {
  final String clave;
  final String tipo;
  final Map<String, dynamic> datos;

  /// Momento del guardado en el dispositivo, en UTC. La base lo usa para que
  /// una lista que llega tarde no pise una corrección posterior.
  final DateTime guardadoEn;

  /// Cuenta que hizo el cambio: solo se sube con su propia sesión
  final String perfilId;

  /// Orden de subida: la asistencia antes que la participación y el podio
  final int prioridad;

  const OperacionPendiente({
    required this.clave,
    required this.tipo,
    required this.datos,
    required this.guardadoEn,
    required this.perfilId,
    this.prioridad = 0,
  });

  Map<String, Object?> toJson() => {
    'clave': clave,
    'tipo': tipo,
    'datos': datos,
    'guardado_en': guardadoEn.toUtc().toIso8601String(),
    'perfil_id': perfilId,
    'prioridad': prioridad,
  };

  factory OperacionPendiente.fromJson(Map<String, Object?> j) => OperacionPendiente(
    clave: j['clave'] as String,
    tipo: j['tipo'] as String,
    datos: Map<String, dynamic>.from(j['datos'] as Map),
    guardadoEn: DateTime.parse(j['guardado_en'] as String),
    perfilId: j['perfil_id'] as String,
    prioridad: (j['prioridad'] as num?)?.toInt() ?? 0,
  );
}

/// La nube respondió y no aceptó el cambio (permisos o reglas): no se reintenta
class RechazoServidorException implements Exception {
  final String mensaje;

  const RechazoServidorException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Qué pasó con un guardado de la clase
enum EstadoGuardado {
  /// Quedó en la nube
  guardado,

  /// Sin conexión: quedó en el dispositivo y se subirá solo al volver internet
  pendiente,

  /// La nube no lo aceptó (ver [ResultadoGuardado.mensaje])
  rechazado,
}

@immutable
class ResultadoGuardado {
  final EstadoGuardado estado;

  /// Motivo del rechazo, o un aviso de la nube al guardar (ej. justificadas que se mantuvieron)
  final String? mensaje;

  const ResultadoGuardado(this.estado, [this.mensaje]);

  bool get guardado => estado == EstadoGuardado.guardado;
  bool get pendiente => estado == EstadoGuardado.pendiente;
  bool get rechazado => estado == EstadoGuardado.rechazado;
}

/// Sube una operación a la nube. Devuelve un aviso opcional para mostrar.
/// Lanza [RechazoServidorException] si la nube la rechaza; cualquier otro
/// error se trata como falta de conexión y la operación se reintenta.
typedef EnviarOperacion = Future<String?> Function(OperacionPendiente operacion);

/// Cola de cambios de la clase que sobrevive a cortes de conexión y recargas
/// de la página (IndexedDB en el navegador, vía sembast).
///
/// Cada guardado se escribe primero en el dispositivo y luego se intenta
/// subir. Si no hay conexión queda pendiente y se reintenta al volver la red
/// (o cada [intervaloReintento]). La base hace idempotentes las RPC, así que
/// reenviar una lista ya subida no duplica registros.
class ColaSincronizacion implements FuenteSincronizacion {
  final Future<Database> _base;
  final EnviarOperacion _enviar;
  final String? Function() _perfilActual;
  final Duration intervaloReintento;
  final Duration tiempoMaximoEnvio;

  final _store = stringMapStoreFactory.store('cola_sincronizacion');
  final _estado = ValueNotifier(EstadoSincronizacion.sincronizado);
  final _pendientes = ValueNotifier(0);
  final _ultimoRechazo = ValueNotifier<String?>(null);
  StreamSubscription<bool>? _suscripcionConexion;
  Timer? _reintento;
  Future<void>? _enCurso;
  bool _otraVuelta = false;
  bool _cerrada = false;

  /// Rechazos y avisos de las operaciones que alguien espera con [guardar]
  final _esperando = <String>{};
  final _rechazos = <String, String>{};
  final _avisos = <String, String>{};

  ColaSincronizacion({
    required Future<Database> base,
    required EnviarOperacion enviar,
    required String? Function() perfilActual,
    Stream<bool>? conexion,
    this.intervaloReintento = const Duration(seconds: 30),
    this.tiempoMaximoEnvio = const Duration(seconds: 10),
  }) : _base = base,
       _enviar = enviar,
       _perfilActual = perfilActual {
    _suscripcionConexion = conexion?.listen((conectado) {
      if (conectado) {
        sincronizar();
      } else {
        _estado.value = EstadoSincronizacion.sinConexion;
      }
    });
  }

  @override
  ValueListenable<EstadoSincronizacion> get estadoSincronizacion => _estado;

  @override
  ValueListenable<int> get cambiosPendientes => _pendientes;

  @override
  ValueListenable<String?> get ultimoRechazo => _ultimoRechazo;

  String _id(OperacionPendiente op) => '${op.perfilId}|${op.clave}';

  /// Guarda la operación en el dispositivo e intenta subirla de inmediato
  Future<ResultadoGuardado> guardar(OperacionPendiente operacion) async {
    final db = await _base;
    final id = _id(operacion);
    await _store.record(id).put(db, operacion.toJson());
    await _contarPendientes();
    _esperando.add(id);
    try {
      await sincronizar();
    } finally {
      _esperando.remove(id);
    }

    final rechazo = _rechazos.remove(id);
    if (rechazo != null) return ResultadoGuardado(EstadoGuardado.rechazado, rechazo);
    final aviso = _avisos.remove(id);
    final sigue = await _store.record(id).get(db);
    if (sigue != null && sigue['guardado_en'] == operacion.toJson()['guardado_en']) {
      return const ResultadoGuardado(EstadoGuardado.pendiente);
    }
    return ResultadoGuardado(EstadoGuardado.guardado, aviso);
  }

  /// Operación de la usuaria actual que aún no se sube, si la hay
  Future<OperacionPendiente?> pendiente(String clave) async {
    final perfil = _perfilActual();
    if (perfil == null) return null;
    final fila = await _store.record('$perfil|$clave').get(await _base);
    return fila == null ? null : OperacionPendiente.fromJson(fila);
  }

  /// Sube los pendientes de la usuaria actual. Si ya hay una subida en curso,
  /// la espera y repite la vuelta para incluir lo que llegó mientras tanto.
  Future<void> sincronizar() {
    final enCurso = _enCurso;
    if (enCurso != null) {
      _otraVuelta = true;
      return enCurso;
    }
    final vuelta = _vueltas().whenComplete(() => _enCurso = null);
    _enCurso = vuelta;
    return vuelta;
  }

  Future<void> _vueltas() async {
    do {
      _otraVuelta = false;
      await _subirPendientes();
    } while (_otraVuelta && !_cerrada && _estado.value != EstadoSincronizacion.sinConexion);
  }

  Future<List<OperacionPendiente>> _deLaUsuaria(Database db) async {
    final perfil = _perfilActual();
    if (perfil == null) return const [];
    final filas = await _store.find(db, finder: Finder(filter: Filter.equals('perfil_id', perfil)));
    final ops = [for (final f in filas) OperacionPendiente.fromJson(f.value)];
    ops.sort((a, b) {
      final p = a.prioridad.compareTo(b.prioridad);
      return p != 0 ? p : a.guardadoEn.compareTo(b.guardadoEn);
    });
    return ops;
  }

  Future<void> _subirPendientes() async {
    final db = await _base;
    final ops = await _deLaUsuaria(db);
    if (ops.isEmpty) {
      await _contarPendientes();
      if (_estado.value == EstadoSincronizacion.sincronizando) _estado.value = EstadoSincronizacion.sincronizado;
      return;
    }

    _estado.value = EstadoSincronizacion.sincronizando;
    for (final op in ops) {
      if (_cerrada) return;
      final id = _id(op);
      try {
        final aviso = await _enviar(op).timeout(tiempoMaximoEnvio);
        if (aviso != null && _esperando.contains(id)) _avisos[id] = aviso;
        await _quitarSiNoCambio(db, op);
      } on RechazoServidorException catch (e) {
        // Quien guardó lo ve en su pantalla; si se subió más tarde, lo avisa la nubecita
        if (_esperando.contains(id)) {
          _rechazos[id] = e.mensaje;
        } else {
          _ultimoRechazo.value = e.mensaje;
        }
        await _quitarSiNoCambio(db, op);
      } catch (_) {
        // Sin conexión (o la sesión expiró): queda pendiente y se reintenta
        await _contarPendientes();
        _estado.value = EstadoSincronizacion.sinConexion;
        _programarReintento();
        return;
      }
      await _contarPendientes();
    }
    _reintento?.cancel();
    _estado.value = EstadoSincronizacion.sincronizado;
  }

  /// Borra la operación subida, salvo que mientras tanto se haya guardado una versión más nueva
  Future<void> _quitarSiNoCambio(Database db, OperacionPendiente op) async {
    final guardadoEn = op.toJson()['guardado_en'];
    await db.transaction((txn) async {
      final registro = _store.record(_id(op));
      final actual = await registro.get(txn);
      if (actual != null && actual['guardado_en'] == guardadoEn) await registro.delete(txn);
    });
  }

  Future<void> _contarPendientes() async {
    final perfil = _perfilActual();
    _pendientes.value = perfil == null
        ? 0
        : await _store.count(await _base, filter: Filter.equals('perfil_id', perfil));
  }

  void _programarReintento() {
    _reintento?.cancel();
    if (_cerrada) return;
    _reintento = Timer(intervaloReintento, sincronizar);
  }

  /// Deja de escuchar la red y los reintentos (los pendientes siguen guardados)
  Future<void> cerrar() async {
    _cerrada = true;
    _reintento?.cancel();
    await _suscripcionConexion?.cancel();
  }
}
