import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/ninaspro_theme.dart';
import '../models/hub_models.dart';
import 'clase_repository.dart' show MapeoClase;

export '../models/hub_models.dart' show EstadoJustificativo, MotivoJustificativo;

/// Resultado de una operación: el valor, o el mensaje para mostrar si falló
@immutable
class Resultado<T> {
  final T? valor;
  final String? error;

  const Resultado.ok([this.valor]) : error = null;
  const Resultado.error(this.error) : valor = null;

  bool get ok => error == null;
}

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

/// 25/04/2026
String fechaCorta(DateTime f) => '${_dosDigitos(f.day)}/${_dosDigitos(f.month)}/${f.year}';

/// Justificativo con la alumna y la clase, para la bandeja de Gestión y el portal de la alumna
@immutable
class JustificativoDetalle {
  final String id;
  final String claseId;
  final String inscripcionId;
  final String alumnaId;
  final String alumnaNombre;
  final String alumnaRut;
  final int numeroSesion;
  final DateTime claseFecha;
  final String? claseTema;
  final String cursoNombre;
  final String sedeNombre;
  final MotivoJustificativo motivo;
  final String? explicacion;

  final EstadoJustificativo estado;
  final String? observacion;
  final String? resueltoPor;
  final DateTime? fechaResolucion;

  /// Lo envió la alumna desde su portal (si no, lo registró Gestión)
  final bool enviadoPorAlumna;
  final DateTime creadoEn;

  const JustificativoDetalle({
    required this.id,
    required this.claseId,
    required this.inscripcionId,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.alumnaRut,
    required this.numeroSesion,
    required this.claseFecha,
    this.claseTema,
    required this.cursoNombre,
    required this.sedeNombre,
    required this.motivo,
    this.explicacion,
    required this.estado,
    this.observacion,
    this.resueltoPor,
    this.fechaResolucion,
    required this.enviadoPorAlumna,
    required this.creadoEn,
  });

  /// Clase #4 · 25/04/2026
  String get claseEtiqueta => 'Clase #$numeroSesion · ${fechaCorta(claseFecha)}';
}

/// Clase que la alumna puede elegir al justificar (US-35 escenario 1)
@immutable
class ClaseJustificable {
  final String claseId;
  final String inscripcionId;
  final int numeroSesion;
  final DateTime fecha;
  final String? tema;
  final String cursoNombre;
  final EstadoAsistencia asistencia;

  /// Justificativo pendiente o aprobado que ya tiene esta clase
  final EstadoJustificativo? justificativo;

  const ClaseJustificable({
    required this.claseId,
    required this.inscripcionId,
    required this.numeroSesion,
    required this.fecha,
    this.tema,
    required this.cursoNombre,
    required this.asistencia,
    this.justificativo,
  });

  /// Sin otro justificativo vigente ni la inasistencia ya justificada (US-35 escenario 4)
  bool get disponible => justificativo == null && asistencia != EstadoAsistencia.justificada;

  /// Clase #4 · 25/04/2026 · Tema
  String get etiqueta {
    final base = 'Clase #$numeroSesion · ${fechaCorta(fecha)}';
    return tema == null ? base : '$base · $tema';
  }
}

/// Justificativos de inasistencia (US-16, US-17, US-35..US-38).
///
/// La alumna envía los suyos y quedan pendientes; el Equipo de Gestión de la
/// sede los aprueba o rechaza, o registra ya aprobado el aviso de la apoderada.
/// La base decide los permisos: las tutoras no resuelven ni leen el detalle.
abstract class JustificativosRepository {
  /// Los que la usuaria puede ver: los suyos (alumna) o los de sus sedes (Gestión)
  Future<List<JustificativoDetalle>> justificativos();

  /// Clases que la alumna autenticada puede justificar
  Future<List<ClaseJustificable>> clasesParaJustificar();

  /// La alumna envía su justificativo con su explicación: queda pendiente para Gestión (US-35)
  Future<Resultado<void>> enviar({
    required ClaseJustificable clase,
    required MotivoJustificativo motivo,
    required String explicacion,
  });

  /// Gestión registra el aviso de la apoderada: queda aprobado (US-16)
  Future<Resultado<void>> registrar({
    required String claseId,
    required String inscripcionId,
    required MotivoJustificativo motivo,
    required String explicacion,
  });

  /// Gestión aprueba o rechaza un pendiente; el rechazo lleva observación (US-37)
  Future<Resultado<void>> resolver(String id, {required bool aprobar, String? observacion});

  /// Gestión elimina un justificativo vinculado por error (US-16 escenario 3)
  Future<Resultado<void>> eliminar(String id);
}

/// Traducción entre las filas de Supabase y los modelos de la app
class MapeoJustificativos {
  static DateTime _fecha(Object? v) => DateTime.parse(v as String);
  static DateTime? _fechaHora(Object? v) => v is String ? DateTime.parse(v).toLocal() : null;

  /// Filas de la vista `justificativos_detalle`
  static JustificativoDetalle detalle(Map<String, dynamic> f) => JustificativoDetalle(
    id: f['id'] as String,
    claseId: f['clase_id'] as String,
    inscripcionId: f['inscripcion_id'] as String,
    alumnaId: f['alumna_id'] as String,
    alumnaNombre: '${f['alumna_nombres'] ?? ''} ${f['alumna_apellidos'] ?? ''}'.trim(),
    alumnaRut: f['alumna_rut'] as String? ?? '',
    numeroSesion: (f['numero_sesion'] as num).toInt(),
    claseFecha: _fecha(f['clase_fecha']),
    claseTema: f['clase_tema'] as String?,
    cursoNombre: f['curso_nombre'] as String? ?? '',
    sedeNombre: f['sede_nombre'] as String? ?? '',
    motivo: MotivoJustificativo.desdeDb(f['motivo']) ?? MotivoJustificativo.otro,
    explicacion: f['explicacion'] as String?,
    estado: EstadoJustificativo.desdeDb(f['estado']) ?? EstadoJustificativo.pendiente,
    observacion: f['observacion_resolucion'] as String?,
    resueltoPor: f['resuelto_por_nombre'] as String?,
    fechaResolucion: _fechaHora(f['fecha_resolucion']),
    enviadoPorAlumna: f['enviado_por_alumna'] == true,
    creadoEn: _fechaHora(f['created_at']) ?? DateTime.now(),
  );

  /// Filas de `clases_para_justificar`
  static ClaseJustificable clase(Map<String, dynamic> f) => ClaseJustificable(
    claseId: f['clase_id'] as String,
    inscripcionId: f['inscripcion_id'] as String,
    numeroSesion: (f['numero_sesion'] as num).toInt(),
    fecha: _fecha(f['fecha']),
    tema: f['tema'] as String?,
    cursoNombre: f['curso_nombre'] as String? ?? '',
    asistencia: MapeoClase.estado(f['asistencia']),
    justificativo: EstadoJustificativo.desdeDb(f['justificativo_estado']),
  );
}

const _mensajeError = 'No pudimos guardar el justificativo. Inténtalo nuevamente.';

class SupabaseJustificativosRepository implements JustificativosRepository {
  final SupabaseClient _client;

  SupabaseJustificativosRepository(this._client);

  @override
  Future<List<JustificativoDetalle>> justificativos() async {
    final filas = await _client.from('justificativos_detalle').select().order('created_at', ascending: false);
    return [for (final f in filas) MapeoJustificativos.detalle(f)];
  }

  @override
  Future<List<ClaseJustificable>> clasesParaJustificar() async {
    final filas = await _client.rpc('clases_para_justificar') as List<dynamic>;
    return [for (final f in filas.cast<Map<String, dynamic>>()) MapeoJustificativos.clase(f)];
  }

  @override
  Future<Resultado<void>> enviar({
    required ClaseJustificable clase,
    required MotivoJustificativo motivo,
    required String explicacion,
  }) => _rpc('enviar_justificativo', {
    'p_clase_id': clase.claseId,
    'p_motivo': motivo.name,
    'p_explicacion': explicacion.trim(),
  });

  @override
  Future<Resultado<void>> registrar({
    required String claseId,
    required String inscripcionId,
    required MotivoJustificativo motivo,
    required String explicacion,
  }) => _rpc('registrar_justificativo', {
    'p_clase_id': claseId,
    'p_inscripcion_id': inscripcionId,
    'p_motivo': motivo.name,
    'p_explicacion': explicacion.trim(),
  });

  @override
  Future<Resultado<void>> resolver(String id, {required bool aprobar, String? observacion}) =>
      _rpc('resolver_justificativo', {'p_id': id, 'p_aprobar': aprobar, 'p_observacion': observacion?.trim()});

  @override
  Future<Resultado<void>> eliminar(String id) => _rpc('eliminar_justificativo', {'p_id': id});

  Future<Resultado<void>> _rpc(String funcion, Map<String, Object?> params) async {
    try {
      await _client.rpc(funcion, params: params);
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      return Resultado.error(_mensaje(e));
    }
  }

  static String _mensaje(PostgrestException e) => switch (e.code) {
    '22023' || '23505' || '42501' || 'P0001' => e.message,
    _ => _mensajeError,
  };
}
