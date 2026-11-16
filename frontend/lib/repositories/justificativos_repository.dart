import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/ninaspro_theme.dart';
import '../models/hub_models.dart';
import 'alumnas_repository.dart' show ArchivoAdjunto, MapeoAlumnas;
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

  /// Ruta del respaldo en el bucket privado (se abre con una URL firmada)
  final String? respaldo;
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
    this.respaldo,
    required this.estado,
    this.observacion,
    this.resueltoPor,
    this.fechaResolucion,
    required this.enviadoPorAlumna,
    required this.creadoEn,
  });

  /// Clase #4 · 25/04/2026
  String get claseEtiqueta => 'Clase #$numeroSesion · ${fechaCorta(claseFecha)}';

  /// Nombre del archivo de respaldo, sin la carpeta ni la marca de tiempo
  String? get nombreRespaldo {
    final r = respaldo;
    if (r == null) return null;
    final archivo = r.split('/').last;
    return archivo.replaceFirst(RegExp(r'^\d+_'), '');
  }
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

  /// La alumna envía su justificativo: queda pendiente para Gestión (US-35, US-36)
  Future<Resultado<void>> enviar({
    required ClaseJustificable clase,
    required MotivoJustificativo motivo,
    required String explicacion,
    ArchivoAdjunto? respaldo,
  });

  /// Gestión registra el aviso de la apoderada: queda aprobado (US-16)
  Future<Resultado<void>> registrar({
    required String claseId,
    required String inscripcionId,
    required MotivoJustificativo motivo,
    required String explicacion,
    ArchivoAdjunto? respaldo,
  });

  /// Gestión aprueba o rechaza un pendiente; el rechazo lleva observación (US-37)
  Future<Resultado<void>> resolver(String id, {required bool aprobar, String? observacion});

  /// Gestión elimina un justificativo vinculado por error (US-16 escenario 3)
  Future<Resultado<void>> eliminar(String id);

  /// URL firmada de corta duración para ver el respaldo (US-17 escenario 1)
  Future<Resultado<String>> urlRespaldo(String ruta);
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
    respaldo: f['archivo_adjunto_url'] as String?,
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

  /// Ruta del respaldo: carpeta de la inscripción y la clase (la exigen las políticas del bucket)
  static String rutaRespaldo(String inscripcionId, String claseId, ArchivoAdjunto archivo, DateTime ahora) =>
      '$inscripcionId/$claseId/${ahora.millisecondsSinceEpoch}_${MapeoAlumnas.nombreSeguro(archivo.nombre)}';
}

const _mensajeError = 'No pudimos guardar el justificativo. Inténtalo nuevamente.';

class SupabaseJustificativosRepository implements JustificativosRepository {
  static const _bucket = 'justificativos';

  final SupabaseClient _client;

  /// Reloj inyectable para nombrar los respaldos en las pruebas
  final DateTime Function() _ahora;

  SupabaseJustificativosRepository(this._client, {DateTime Function()? ahora}) : _ahora = ahora ?? DateTime.now;

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
    ArchivoAdjunto? respaldo,
  }) => _conRespaldo(
    inscripcionId: clase.inscripcionId,
    claseId: clase.claseId,
    respaldo: respaldo,
    guardar: (ruta) => _client.rpc(
      'enviar_justificativo',
      params: {
        'p_clase_id': clase.claseId,
        'p_motivo': motivo.name,
        'p_explicacion': explicacion.trim(),
        'p_archivo': ruta,
      },
    ),
  );

  @override
  Future<Resultado<void>> registrar({
    required String claseId,
    required String inscripcionId,
    required MotivoJustificativo motivo,
    required String explicacion,
    ArchivoAdjunto? respaldo,
  }) => _conRespaldo(
    inscripcionId: inscripcionId,
    claseId: claseId,
    respaldo: respaldo,
    guardar: (ruta) => _client.rpc(
      'registrar_justificativo',
      params: {
        'p_clase_id': claseId,
        'p_inscripcion_id': inscripcionId,
        'p_motivo': motivo.name,
        'p_explicacion': explicacion.trim(),
        'p_archivo': ruta,
      },
    ),
  );

  // Sube el respaldo (si hay) y guarda; si la base lo rechaza, borra el archivo huérfano
  Future<Resultado<void>> _conRespaldo({
    required String inscripcionId,
    required String claseId,
    required ArchivoAdjunto? respaldo,
    required Future<dynamic> Function(String? ruta) guardar,
  }) async {
    final errorArchivo = respaldo?.error;
    if (errorArchivo != null) return Resultado.error(errorArchivo);
    String? ruta;
    try {
      if (respaldo != null) {
        ruta = MapeoJustificativos.rutaRespaldo(inscripcionId, claseId, respaldo, _ahora());
        await _client.storage
            .from(_bucket)
            .uploadBinary(ruta, respaldo.bytes, fileOptions: FileOptions(contentType: respaldo.tipo));
      }
      await guardar(ruta);
      return const Resultado.ok();
    } on StorageException catch (e) {
      return Resultado.error(
        e.statusCode == '403'
            ? 'No tienes permiso para adjuntar respaldos de esta alumna.'
            : 'No pudimos subir el respaldo. Inténtalo nuevamente.',
      );
    } on PostgrestException catch (e) {
      if (ruta != null) await _client.storage.from(_bucket).remove([ruta]).catchError((_) => <FileObject>[]);
      return Resultado.error(_mensaje(e));
    }
  }

  @override
  Future<Resultado<void>> resolver(String id, {required bool aprobar, String? observacion}) async {
    try {
      await _client.rpc(
        'resolver_justificativo',
        params: {'p_id': id, 'p_aprobar': aprobar, 'p_observacion': observacion?.trim()},
      );
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      return Resultado.error(_mensaje(e));
    }
  }

  @override
  Future<Resultado<void>> eliminar(String id) async {
    try {
      final ruta = await _client.rpc('eliminar_justificativo', params: {'p_id': id}) as String?;
      // El justificativo ya no existe: si el respaldo no se borra, queda inaccesible para la app
      if (ruta != null) await _client.storage.from(_bucket).remove([ruta]).catchError((_) => <FileObject>[]);
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      return Resultado.error(_mensaje(e));
    }
  }

  @override
  Future<Resultado<String>> urlRespaldo(String ruta) async {
    try {
      return Resultado.ok(await _client.storage.from(_bucket).createSignedUrl(ruta, 60));
    } on StorageException {
      return const Resultado.error('No pudimos abrir el respaldo.');
    }
  }

  static String _mensaje(PostgrestException e) => switch (e.code) {
    '22023' || '23505' || '42501' || 'P0001' => e.message,
    _ => _mensajeError,
  };
}
