import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart' show Database;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/ninaspro_theme.dart';
import '../data/offline/base_local.dart';
import '../data/offline/cola_sincronizacion.dart';
import '../models/hub_models.dart';
import 'catalogo_repository.dart';

export '../data/offline/cola_sincronizacion.dart' show EstadoGuardado, ResultadoGuardado;

/// Pase de lista de una clase con la participación y el podio Kahoot (US-13, US-28, US-29)
@immutable
class ListaClase {
  final List<RegistroAsistencia> registros;
  final List<ParticipacionClase> participaciones;

  /// Podio Kahoot en orden, del 1° lugar en adelante (1 a 3 alumnas, según las presentes)
  final List<RegistroAsistencia> podio;

  /// Algún cambio de esta lista está guardado solo en el dispositivo
  final bool conPendientes;

  const ListaClase({
    this.registros = const [],
    this.participaciones = const [],
    this.podio = const [],
    this.conPendientes = false,
  });

  /// La clase ya tiene pase de lista (en la nube o pendiente de subir)
  bool get tienePaseLista => registros.any((r) => r.estado != EstadoAsistencia.pendiente);

  /// Ids de alumna del podio, del 1° lugar en adelante
  List<String> get podioAlumnas => [for (final r in podio) r.alumnaId];
}

/// Tipos de operación que pasan por la cola sin conexión
abstract final class OperacionesClase {
  static const asistencia = 'asistencia_alumnas';
  static const participacion = 'participacion_clase';
  static const podio = 'podio_kahoot';
  static const asistenciaTutores = 'asistencia_tutores';

  static String clave(String tipo, String claseId) => '$tipo:$claseId';
}

/// La clase en el aula: pase de lista de alumnas y tutoras, ejercicios,
/// participación y podio Kahoot (US-13..15, US-28, US-29, US-33, US-34).
///
/// Los guardados pasan por una cola en el dispositivo: sin conexión quedan
/// pendientes y se suben solos al volver internet, sin duplicar registros.
abstract class ClaseRepository implements FuenteSincronizacion {
  /// Cursos vigentes que opera la usuaria: los asignados a [tutoraId] o, sin
  /// ella, todos los de sus sedes (Gestión). La RLS acota a sus sedes.
  Future<List<Curso>> instancias({String? tutoraId});

  /// Sesiones del curso ordenadas por fecha
  Future<List<SesionClase>> sesiones(String instanciaId);

  /// Alumnas de la clase con su asistencia, participación y podio, incluidos
  /// los cambios que aún no se suben
  Future<ListaClase> lista(String claseId);

  /// Tutoras asignadas al curso con su asistencia a la clase (US-33)
  Future<List<RegistroAsistenciaTutora>> asistenciaTutoras(String claseId);

  /// Asistencia de [tutoraId] en cada clase del curso: id de clase → estado
  Future<Map<String, EstadoAsistencia>> miAsistencia({required String instanciaId, required String tutoraId});

  Future<ResultadoGuardado> guardarAsistencia(String claseId, List<RegistroAsistencia> registros);
  Future<ResultadoGuardado> guardarParticipacion(String claseId, List<ParticipacionClase> participaciones);

  /// Ids de inscripción del podio en orden (1° lugar primero). Lleva tantos
  /// lugares como presentes haya, hasta 3: con una sola alumna, queda primera.
  Future<ResultadoGuardado> guardarPodio(String claseId, List<String> inscripciones);

  Future<ResultadoGuardado> guardarAsistenciaTutoras(String claseId, List<RegistroAsistenciaTutora> registros);

  /// Sube los cambios guardados sin conexión (también al deslizar para recargar)
  Future<void> sincronizar();
}

/// Traducción entre las filas de Supabase, la cola y los modelos de la app
class MapeoClase {
  static EstadoAsistencia estado(Object? valor) => switch (valor) {
    'presente' => EstadoAsistencia.presente,
    'ausente' => EstadoAsistencia.ausente,
    'justificada' => EstadoAsistencia.justificada,
    _ => EstadoAsistencia.pendiente,
  };

  static String _nombre(Map<String, dynamic> f) => '${f['nombres'] ?? ''} ${f['apellidos'] ?? ''}'.trim();

  static DateTime? _fecha(Object? valor) => valor is String ? DateTime.parse(valor).toLocal() : null;

  /// Filas de `lista_asistencia_clase`
  static ListaClase lista(String claseId, List<Map<String, dynamic>> filas) {
    final registros = <RegistroAsistencia>[];
    final participaciones = <ParticipacionClase>[];
    final podio = <int, RegistroAsistencia>{};
    for (final f in filas) {
      final registro = RegistroAsistencia(
        id: f['inscripcion_id'] as String,
        sesionId: claseId,
        alumnaId: f['alumna_id'] as String,
        alumnaNombre: _nombre(f),
        alumnaRut: f['rut'] as String? ?? '',
        estado: estado(f['estado']),
        horaMarcado: _fecha(f['actualizado_en']),
        autorizaImagen: f['autoriza_imagen'] == true,
        editadoPor: f['registrado_por_nombre'] as String?,
        justificativo: EstadoJustificativo.desdeDb(f['justificativo_estado']),
        motivoJustificativo: MotivoJustificativo.desdeDb(f['justificativo_motivo']),
      );
      registros.add(registro);
      if (f['ejercicios'] != null) {
        participaciones.add(
          ParticipacionClase(
            id: registro.id,
            sesionId: claseId,
            alumnaId: registro.alumnaId,
            alumnaNombre: registro.alumnaNombre,
            ejerciciosResueltos: (f['ejercicios'] as num).toInt(),
            participacionActiva: f['participo_activa'] == true,
          ),
        );
      }
      final lugar = (f['podio_kahoot'] as num?)?.toInt();
      if (lugar != null) podio[lugar] = registro;
    }
    return ListaClase(registros: registros, participaciones: participaciones, podio: _podio(podio));
  }

  // Lugares ocupados en orden (1°, 2°, 3°); se corta en el primer lugar vacío
  static List<RegistroAsistencia> _podio(Map<int, RegistroAsistencia> lugares) {
    final podio = <RegistroAsistencia>[];
    for (var lugar = 1; lugar <= 3 && lugares[lugar] != null; lugar++) {
      podio.add(lugares[lugar]!);
    }
    return podio;
  }

  /// Datos de la operación del podio: los ids de inscripción en orden (los lugares sin alumna van nulos)
  static Map<String, dynamic> datosPodio(String claseId, List<String> inscripciones) => {
    'clase_id': claseId,
    'primero': inscripciones.isNotEmpty ? inscripciones[0] : null,
    'segundo': inscripciones.length > 1 ? inscripciones[1] : null,
    'tercero': inscripciones.length > 2 ? inscripciones[2] : null,
  };

  /// Filas de `lista_asistencia_tutores`
  static RegistroAsistenciaTutora tutora(String claseId, Map<String, dynamic> f) => RegistroAsistenciaTutora(
    sesionId: claseId,
    tutoraId: f['tutor_id'] as String,
    tutoraNombre: _nombre(f),
    esEquipoGestion: f['es_equipo_gestion'] == true,
    estado: estado(f['estado']),
    editadoPor: f['registrado_por_nombre'] as String?,
    editadoEn: _fecha(f['actualizado_en']),
  );

  // --- Datos de las operaciones de la cola ---

  static Map<String, dynamic> datosAsistencia(String claseId, List<RegistroAsistencia> registros) => {
    'clase_id': claseId,
    'registros': [
      for (final r in registros)
        if (r.estado != EstadoAsistencia.pendiente) {'inscripcion_id': r.id, 'estado': r.estado.name},
    ],
  };

  static Map<String, dynamic> datosParticipacion(String claseId, List<ParticipacionClase> participaciones) => {
    'clase_id': claseId,
    'registros': [
      for (final p in participaciones)
        {'inscripcion_id': p.id, 'ejercicios': p.ejerciciosResueltos, 'participo_activa': p.participacionActiva},
    ],
  };

  static Map<String, dynamic> datosTutoras(String claseId, List<RegistroAsistenciaTutora> registros) => {
    'clase_id': claseId,
    'registros': [
      for (final r in registros)
        if (r.estado != EstadoAsistencia.pendiente) {'tutor_id': r.tutoraId, 'estado': r.estado.name},
    ],
  };

  static List<Map<String, dynamic>> _registros(Map<String, dynamic> datos) => [
    for (final r in datos['registros'] as List) Map<String, dynamic>.from(r as Map),
  ];

  /// Aplica sobre la lista de la nube los cambios que siguen en el dispositivo
  static ListaClase conPendientes(
    ListaClase lista, {
    OperacionPendiente? asistencia,
    OperacionPendiente? participacion,
    OperacionPendiente? podio,
  }) {
    if (asistencia == null && participacion == null && podio == null) return lista;

    var registros = lista.registros;
    if (asistencia != null) {
      final estados = {for (final r in _registros(asistencia.datos)) r['inscripcion_id']: estado(r['estado'])};
      registros = [for (final r in registros) estados.containsKey(r.id) ? r.copyWith(estado: estados[r.id]) : r];
    }

    var participaciones = lista.participaciones;
    if (participacion != null) {
      final porId = {for (final p in participaciones) p.id: p};
      for (final f in _registros(participacion.datos)) {
        final r = registros.where((r) => r.id == f['inscripcion_id']).firstOrNull;
        if (r == null) continue;
        porId[r.id] = ParticipacionClase(
          id: r.id,
          sesionId: r.sesionId,
          alumnaId: r.alumnaId,
          alumnaNombre: r.alumnaNombre,
          ejerciciosResueltos: (f['ejercicios'] as num).toInt(),
          participacionActiva: f['participo_activa'] == true,
        );
      }
      participaciones = porId.values.toList();
    }

    var podioLista = lista.podio;
    if (podio != null) {
      RegistroAsistencia? de(String clave) => registros.where((r) => r.id == podio.datos[clave]).firstOrNull;
      final lugares = {1: de('primero'), 2: de('segundo'), 3: de('tercero')};
      podioLista = _podio({
        for (final e in lugares.entries)
          if (e.value != null) e.key: e.value!,
      });
    }

    return ListaClase(registros: registros, participaciones: participaciones, podio: podioLista, conPendientes: true);
  }

  static List<RegistroAsistenciaTutora> tutorasConPendientes(
    List<RegistroAsistenciaTutora> registros,
    OperacionPendiente? pendiente,
  ) {
    if (pendiente == null) return registros;
    final estados = {for (final r in _registros(pendiente.datos)) r['tutor_id']: estado(r['estado'])};
    return [for (final r in registros) estados.containsKey(r.tutoraId) ? r.copyWith(estado: estados[r.tutoraId]) : r];
  }

  // --- Respuestas de las RPC ---

  static int _n(Map<String, dynamic> r, String clave) => (r[clave] as num?)?.toInt() ?? 0;

  static String? _unir(List<String?> partes) {
    final avisos = partes.whereType<String>().toList();
    return avisos.isEmpty ? null : avisos.join(' ');
  }

  static String? avisoAsistencia(Map<String, dynamic> r) {
    final justificadas = _n(r, 'justificadas_conservadas');
    final posteriores = _n(r, 'conservados_por_edicion_posterior');
    final omitidas = _n(r, 'omitidas');
    return _unir([
      if (justificadas > 0)
        justificadas == 1
            ? '1 inasistencia justificada se mantiene: la gestiona el Equipo de Gestión.'
            : '$justificadas inasistencias justificadas se mantienen: las gestiona el Equipo de Gestión.',
      if (posteriores > 0)
        posteriores == 1
            ? '1 registro ya tenía una corrección más reciente y se conservó.'
            : '$posteriores registros ya tenían una corrección más reciente y se conservaron.',
      if (omitidas > 0)
        omitidas == 1
            ? '1 alumna ya no tiene la matrícula activa y no se registró.'
            : '$omitidas alumnas ya no tienen la matrícula activa y no se registraron.',
    ]);
  }

  static String? avisoParticipacion(Map<String, dynamic> r) {
    final omitidas = _n(r, 'omitidas');
    if (omitidas == 0) return null;
    return omitidas == 1
        ? '1 alumna ya no figura presente y no se guardaron sus ejercicios.'
        : '$omitidas alumnas ya no figuran presentes y no se guardaron sus ejercicios.';
  }
}

const _mensajeSinPermiso = 'No tienes permiso para registrar esta clase.';
const _mensajeError = 'No pudimos guardar los cambios. Inténtalo nuevamente.';

class SupabaseClaseRepository implements ClaseRepository {
  final SupabaseClient _client;
  final String? Function() _perfilActual;
  late final ColaSincronizacion cola;

  /// [perfilActual]: cuenta que guarda (por defecto, la de la sesión de Supabase)
  SupabaseClaseRepository(
    this._client, {
    required Future<Database> base,
    Stream<bool>? conexion,
    String? Function()? perfilActual,
  }) : _perfilActual = perfilActual ?? (() => _client.auth.currentUser?.id) {
    cola = ColaSincronizacion(base: base, enviar: _enviar, perfilActual: _perfilActual, conexion: conexion);
  }

  /// En el navegador: cola en IndexedDB y aviso de conexión de connectivity_plus
  factory SupabaseClaseRepository.enNavegador(SupabaseClient client) {
    final conectividad = Connectivity();
    final conexion = conectividad.onConnectivityChanged.map((r) => !r.contains(ConnectivityResult.none));
    return SupabaseClaseRepository(client, base: abrirBaseLocal('ninaspro_hub'), conexion: conexion);
  }

  @override
  ValueListenable<EstadoSincronizacion> get estadoSincronizacion => cola.estadoSincronizacion;

  @override
  ValueListenable<int> get cambiosPendientes => cola.cambiosPendientes;

  @override
  ValueListenable<String?> get ultimoRechazo => cola.ultimoRechazo;

  @override
  Future<void> sincronizar() => cola.sincronizar();

  @override
  Future<List<Curso>> instancias({String? tutoraId}) async {
    // Vigentes: terminan a lo más hace un mes
    final desde = MapeoCatalogo.fecha(DateTime.now().subtract(const Duration(days: 30)));
    var consulta = _client
        .from('instancias_curso')
        .select(
          tutoraId == null
              ? MapeoCatalogo.columnasInstancia
              : '${MapeoCatalogo.columnasInstancia}, tutores_instancia!inner(tutor_id)',
        )
        .eq('activo', true)
        .gte('fecha_termino', desde);
    if (tutoraId != null) consulta = consulta.eq('tutores_instancia.tutor_id', tutoraId);
    final filas = await consulta.order('fecha_inicio', ascending: false).order('seccion', ascending: true);
    // Aprovecha que hay conexión para subir lo pendiente de una sesión anterior
    unawaited(cola.sincronizar());
    return [for (final f in filas) MapeoCatalogo.instancia(f)];
  }

  @override
  Future<List<SesionClase>> sesiones(String instanciaId) async {
    final filas = await _client
        .from('clases')
        .select(MapeoCatalogo.columnasSesion)
        .eq('instancia_curso_id', instanciaId)
        .order('fecha', ascending: true);
    return [for (final f in filas) MapeoCatalogo.sesion(f)];
  }

  @override
  Future<ListaClase> lista(String claseId) async {
    final filas = await _client.rpc('lista_asistencia_clase', params: {'p_clase_id': claseId}) as List<dynamic>;
    return MapeoClase.conPendientes(
      MapeoClase.lista(claseId, filas.cast<Map<String, dynamic>>()),
      asistencia: await cola.pendiente(OperacionesClase.clave(OperacionesClase.asistencia, claseId)),
      participacion: await cola.pendiente(OperacionesClase.clave(OperacionesClase.participacion, claseId)),
      podio: await cola.pendiente(OperacionesClase.clave(OperacionesClase.podio, claseId)),
    );
  }

  @override
  Future<List<RegistroAsistenciaTutora>> asistenciaTutoras(String claseId) async {
    final filas = await _client.rpc('lista_asistencia_tutores', params: {'p_clase_id': claseId}) as List<dynamic>;
    return MapeoClase.tutorasConPendientes([
      for (final f in filas.cast<Map<String, dynamic>>()) MapeoClase.tutora(claseId, f),
    ], await cola.pendiente(OperacionesClase.clave(OperacionesClase.asistenciaTutores, claseId)));
  }

  @override
  Future<Map<String, EstadoAsistencia>> miAsistencia({required String instanciaId, required String tutoraId}) async {
    final filas = await _client
        .from('asistencia_tutores')
        .select('clase_id, estado, clases!inner(instancia_curso_id)')
        .eq('tutor_id', tutoraId)
        .eq('clases.instancia_curso_id', instanciaId);
    return {for (final f in filas) f['clase_id'] as String: MapeoClase.estado(f['estado'])};
  }

  Future<ResultadoGuardado> _guardar(String tipo, String claseId, Map<String, dynamic> datos, {int prioridad = 0}) {
    final perfil = _perfilActual();
    if (perfil == null) {
      return Future.value(const ResultadoGuardado(EstadoGuardado.rechazado, 'Tu sesión terminó. Vuelve a ingresar.'));
    }
    return cola.guardar(
      OperacionPendiente(
        clave: OperacionesClase.clave(tipo, claseId),
        tipo: tipo,
        datos: datos,
        guardadoEn: DateTime.now().toUtc(),
        perfilId: perfil,
        prioridad: prioridad,
      ),
    );
  }

  @override
  Future<ResultadoGuardado> guardarAsistencia(String claseId, List<RegistroAsistencia> registros) =>
      _guardar(OperacionesClase.asistencia, claseId, MapeoClase.datosAsistencia(claseId, registros));

  @override
  Future<ResultadoGuardado> guardarParticipacion(String claseId, List<ParticipacionClase> participaciones) => _guardar(
    OperacionesClase.participacion,
    claseId,
    MapeoClase.datosParticipacion(claseId, participaciones),
    prioridad: 1,
  );

  @override
  Future<ResultadoGuardado> guardarPodio(String claseId, List<String> inscripciones) =>
      _guardar(OperacionesClase.podio, claseId, MapeoClase.datosPodio(claseId, inscripciones), prioridad: 2);

  @override
  Future<ResultadoGuardado> guardarAsistenciaTutoras(String claseId, List<RegistroAsistenciaTutora> registros) =>
      _guardar(OperacionesClase.asistenciaTutores, claseId, MapeoClase.datosTutoras(claseId, registros));

  /// Sube una operación de la cola con su RPC
  Future<String?> _enviar(OperacionPendiente op) async {
    final d = op.datos;
    final guardadoEn = op.guardadoEn.toUtc().toIso8601String();
    try {
      switch (op.tipo) {
        case OperacionesClase.asistencia:
          final r = await _client.rpc(
            'guardar_asistencia_clase',
            params: {'p_clase_id': d['clase_id'], 'p_registros': d['registros'], 'p_guardado_en': guardadoEn},
          );
          return MapeoClase.avisoAsistencia(Map<String, dynamic>.from(r as Map));
        case OperacionesClase.participacion:
          final r = await _client.rpc(
            'guardar_participacion_clase',
            params: {'p_clase_id': d['clase_id'], 'p_registros': d['registros']},
          );
          return MapeoClase.avisoParticipacion(Map<String, dynamic>.from(r as Map));
        case OperacionesClase.podio:
          await _client.rpc(
            'guardar_podio_kahoot',
            params: {
              'p_clase_id': d['clase_id'],
              'p_primero': d['primero'],
              'p_segundo': d['segundo'],
              'p_tercero': d['tercero'],
            },
          );
          return null;
        case OperacionesClase.asistenciaTutores:
          final r = await _client.rpc(
            'guardar_asistencia_tutores',
            params: {'p_clase_id': d['clase_id'], 'p_registros': d['registros'], 'p_guardado_en': guardadoEn},
          );
          final posteriores = (Map<String, dynamic>.from(r as Map)['conservados_por_edicion_posterior'] as num?) ?? 0;
          return posteriores > 0 ? 'Se conservaron las correcciones más recientes de $posteriores tutoras.' : null;
        default:
          throw RechazoServidorException('Operación desconocida: ${op.tipo}');
      }
    } on PostgrestException catch (e) {
      // Sesión vencida: se reintenta cuando el cliente renueve el token
      if (e.code == 'PGRST301' || e.code == 'PGRST303') rethrow;
      throw RechazoServidorException(_mensaje(e));
    }
  }

  static String _mensaje(PostgrestException e) => switch (e.code) {
    '22023' || 'P0001' => e.message,
    '42501' => e.message.startsWith('permission denied') ? _mensajeSinPermiso : e.message,
    _ => _mensajeError,
  };
}
