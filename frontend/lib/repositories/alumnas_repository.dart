
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hub_models.dart';
import 'catalogo_repository.dart';

/// Estado del consentimiento de tratamiento de datos del apoderado (RB-1)
enum ConsentimientoDatos {
  pendiente,
  otorgado,
  noOtorgado;

  String get label => switch (this) {
    ConsentimientoDatos.pendiente => 'Pendiente',
    ConsentimientoDatos.otorgado => 'Otorgado',
    ConsentimientoDatos.noOtorgado => 'No otorgado',
  };

  String get valorDb => switch (this) {
    ConsentimientoDatos.pendiente => 'pendiente',
    ConsentimientoDatos.otorgado => 'otorgada',
    ConsentimientoDatos.noOtorgado => 'no_otorgada',
  };

  static ConsentimientoDatos desdeDb(String? valor) => switch (valor) {
    'otorgada' => ConsentimientoDatos.otorgado,
    'no_otorgada' || 'revocada' => ConsentimientoDatos.noOtorgado,
    _ => ConsentimientoDatos.pendiente,
  };
}

/// Una inscripción de la nómina: alumna + instancia de curso (US-07, US-09, US-11)
@immutable
class InscripcionNomina {
  final String inscripcionId;
  final String alumnaId;
  final String rut;
  final String nombres;
  final String apellidos;
  final String instanciaId;
  final String sedeId;
  final String sedeNombre;
  final String cursoCodigo;
  final String cursoNombre;
  final String periodo;
  final int seccion;
  final String estado; // 'preinscrita' | 'activa' | 'retirada' | 'egresada'
  final DateTime fechaInscripcion;
  final DateTime? fechaRetiro;
  final String? motivoRetiro;
  final ConsentimientoDatos consentimiento;
  final bool autorizaFotos;
  final int clasesComputables;
  final int clasesAsistidas;
  final int sesionesTranscurridas;

  /// Sigue sin consentimiento tras 2 sesiones desde su inscripción (US-11 escenario 3)
  final bool regularizacionUrgente;

  const InscripcionNomina({
    required this.inscripcionId,
    required this.alumnaId,
    required this.rut,
    required this.nombres,
    required this.apellidos,
    required this.instanciaId,
    required this.sedeId,
    required this.sedeNombre,
    required this.cursoCodigo,
    required this.cursoNombre,
    this.periodo = '',
    this.seccion = 1,
    required this.estado,
    required this.fechaInscripcion,
    this.fechaRetiro,
    this.motivoRetiro,
    this.consentimiento = ConsentimientoDatos.pendiente,
    this.autorizaFotos = false,
    this.clasesComputables = 0,
    this.clasesAsistidas = 0,
    this.sesionesTranscurridas = 0,
    this.regularizacionUrgente = false,
  });

  String get nombreCompleto => '$nombres $apellidos';

  /// 'PCB · 2026-2' o 'PCB · 2026-2 · Sección B'
  String get cursoEtiqueta => [
    cursoCodigo,
    if (periodo.isNotEmpty) periodo,
    if (seccion > 1) 'Sección ${String.fromCharCode(64 + seccion)}',
  ].join(' · ');

  /// Porcentaje sobre las clases realizadas; null si aún no hay clases realizadas
  double? get porcentajeAsistencia =>
      clasesComputables == 0 ? null : 100 * clasesAsistidas / clasesComputables;

  bool get vigente => estado == 'activa' || estado == 'preinscrita';
}

/// Apoderado/a de la alumna (solo lo ve la administración)
@immutable
class ApoderadoFicha {
  final String nombres;
  final String apellidos;
  final String? rut;
  final String telefono;
  final String correo;
  final String parentesco;

  const ApoderadoFicha({
    required this.nombres,
    required this.apellidos,
    this.rut,
    required this.telefono,
    required this.correo,
    this.parentesco = '',
  });

  String get nombreCompleto => '$nombres $apellidos';
}

/// Autorizaciones registradas del apoderado (US-10, US-12)
@immutable
class AutorizacionesFicha {
  final ConsentimientoDatos tratamientoDatos;
  final Map<CanalImagen, bool> canales;
  final Map<CanalImagen, RevocacionImagen> revocaciones;

  /// Ruta del documento firmado en el bucket privado `autorizaciones`
  final String? documento;
  final DateTime? fechaFirma;
  final DateTime? actualizadoEn;
  final String? registradoPor;

  const AutorizacionesFicha({
    this.tratamientoDatos = ConsentimientoDatos.pendiente,
    this.canales = const {},
    this.revocaciones = const {},
    this.documento,
    this.fechaFirma,
    this.actualizadoEn,
    this.registradoPor,
  });

  /// Un canal sin respuesta explícita queda como no autorizado (RB-2)
  bool autorizado(CanalImagen canal) => canales[canal] ?? false;

  bool get registradas => actualizadoEn != null;

  /// Nombre del archivo sin la carpeta ni la marca de tiempo
  String? get nombreDocumento => documento?.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');
}

/// Ficha única de la alumna con todas sus inscripciones (US-09)
@immutable
class FichaAlumna {
  final String id;
  final String rut;
  final String nombres;
  final String apellidos;
  final DateTime? fechaNacimiento;
  final String? correo;
  final String? establecimiento;
  final String? cursoEscolar;
  final ApoderadoFicha? apoderado;
  final AutorizacionesFicha autorizaciones;
  final List<InscripcionNomina> inscripciones;

  const FichaAlumna({
    required this.id,
    required this.rut,
    required this.nombres,
    required this.apellidos,
    this.fechaNacimiento,
    this.correo,
    this.establecimiento,
    this.cursoEscolar,
    this.apoderado,
    this.autorizaciones = const AutorizacionesFicha(),
    this.inscripciones = const [],
  });

  String get nombreCompleto => '$nombres $apellidos';
}

/// Datos del formulario de inscripción individual (mismas columnas que la plantilla)
@immutable
class DatosAlumna {
  final String rut;
  final String nombres;
  final String apellidos;
  final DateTime fechaNacimiento;
  final String correo;
  final String establecimiento;
  final String cursoEscolar;
  final String rutApoderado;
  final String nombresApoderado;
  final String apellidosApoderado;
  final String telefonoApoderado;
  final String correoApoderado;
  final String parentesco;

  const DatosAlumna({
    required this.rut,
    required this.nombres,
    required this.apellidos,
    required this.fechaNacimiento,
    this.correo = '',
    this.establecimiento = '',
    this.cursoEscolar = '',
    this.rutApoderado = '',
    required this.nombresApoderado,
    required this.apellidosApoderado,
    required this.telefonoApoderado,
    required this.correoApoderado,
    this.parentesco = '',
  });

  /// Fila en el formato de la RPC importar_alumnas
  Map<String, Object?> get fila => {
    'fila': 1,
    'rut': rut.trim(),
    'nombres': nombres.trim(),
    'apellidos': apellidos.trim(),
    'fecha_nacimiento': MapeoCatalogo.fecha(fechaNacimiento),
    'correo': correo.trim(),
    'establecimiento': establecimiento.trim(),
    'curso_escolar': cursoEscolar.trim(),
    'rut_apoderado': rutApoderado.trim(),
    'nombres_apoderado': nombresApoderado.trim(),
    'apellidos_apoderado': apellidosApoderado.trim(),
    'telefono_apoderado': telefonoApoderado.trim(),
    'correo_apoderado': correoApoderado.trim(),
    'parentesco': parentesco.trim(),
  };
}

/// Documento firmado elegido en el dispositivo, aún sin subir
@immutable
class ArchivoAdjunto {
  final String nombre;
  final Uint8List bytes;

  const ArchivoAdjunto({required this.nombre, required this.bytes});

  /// Formatos y tamaño que admite el bucket de respaldos
  static const extensiones = ['pdf', 'png', 'jpg', 'jpeg'];
  static const tamanoMaximo = 5 * 1024 * 1024;

  String get extension => nombre.toLowerCase().split('.').last;

  String get tipo => switch (extension) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    _ => 'image/jpeg',
  };

  /// Mensaje si el archivo no se puede adjuntar
  String? get error {
    if (!extensiones.contains(extension)) return 'El respaldo debe ser PDF, PNG o JPG.';
    if (bytes.length > tamanoMaximo) return 'El respaldo pesa más de 5 MB.';
    return null;
  }
}

/// Resultado de una operación: [valor] si salió bien o [error] listo para mostrar
@immutable
class ResultadoAlumnas<T> {
  final T? valor;
  final String? error;

  const ResultadoAlumnas.ok([this.valor]) : error = null;
  const ResultadoAlumnas.error(this.error) : valor = null;

  bool get ok => error == null;
}

/// Nómina, fichas, cargas masivas y autorizaciones de las alumnas (US-07..US-12).
///
/// La base decide los privilegios: la Directiva opera en todas las sedes y el
/// Equipo de Gestión solo en las suyas.
abstract class AlumnasRepository {
  /// Una fila por inscripción, de las sedes que ve la usuaria
  Future<List<InscripcionNomina>> nomina({String? sedeId});

  /// Instancias de curso donde se puede inscribir
  Future<List<Curso>> instancias();

  Future<FichaAlumna?> ficha(String alumnaId);

  /// Clasifica cada fila (nueva, existente o inválida con su motivo) sin guardar nada
  Future<ResultadoAlumnas<ResultadoImportacion>> previsualizarImportacion({
    required String instanciaId,
    required String nombreArchivo,
    required List<Map<String, Object?>> filas,
  });

  /// Inscribe todas las filas válidas en una transacción y devuelve el resultado final
  Future<ResultadoAlumnas<({int inscritas, ResultadoImportacion detalle})>> confirmarImportacion({
    required String instanciaId,
    required String nombreArchivo,
    required List<Map<String, Object?>> filas,
  });

  /// Inscripción individual: si el RUT ya tiene ficha se reutiliza (US-09)
  Future<ResultadoAlumnas<void>> inscribir({required String instanciaId, required DatosAlumna datos});

  Future<ResultadoAlumnas<void>> registrarAutorizaciones({
    required String alumnaId,
    required ConsentimientoDatos tratamientoDatos,
    required Map<CanalImagen, bool> canales,
    ArchivoAdjunto? respaldo,
    DateTime? fechaFirma,
  });

  Future<ResultadoAlumnas<void>> revocarImagen({
    required String alumnaId,
    required List<CanalImagen> canales,
    required DateTime fecha,
    required String motivo,
  });

  Future<ResultadoAlumnas<void>> retirar({
    required String inscripcionId,
    required DateTime fecha,
    required String motivo,
  });

  /// URL firmada de corta duración para ver el respaldo
  Future<ResultadoAlumnas<String>> urlRespaldo(String documento);
}

/// Traducción de filas de Supabase a los modelos de la app
class MapeoAlumnas {
  static const canalesDb = {
    CanalImagen.redesSociales: 'redes_sociales',
    CanalImagen.memoriaAnual: 'memoria_anual',
    CanalImagen.prensa: 'prensa',
    CanalImagen.webInstitucional: 'sitio_web',
    CanalImagen.patrocinadores: 'reporte_patrocinantes',
  };

  static CanalImagen? canal(String? valor) =>
      canalesDb.entries.where((e) => e.value == valor).map((e) => e.key).firstOrNull;

  static DateTime? _fecha(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
  static DateTime? _dia(Object? v) {
    final f = v == null ? null : DateTime.parse(v as String);
    return f == null ? null : DateTime(f.year, f.month, f.day);
  }

  static InscripcionNomina inscripcion(Map<String, dynamic> f) => InscripcionNomina(
    inscripcionId: f['inscripcion_id'] as String,
    alumnaId: f['alumna_id'] as String,
    rut: f['rut'] as String,
    nombres: f['nombres'] as String,
    apellidos: f['apellidos'] as String,
    instanciaId: f['instancia_curso_id'] as String,
    sedeId: f['sede_id'] as String,
    sedeNombre: f['sede_nombre'] as String,
    cursoCodigo: f['curso_codigo'] as String,
    cursoNombre: f['curso_nombre'] as String,
    periodo: f['periodo_academico'] as String? ?? '',
    seccion: (f['seccion'] as num?)?.toInt() ?? 1,
    estado: f['estado'] as String,
    fechaInscripcion: _dia(f['fecha_inscripcion'])!,
    fechaRetiro: _dia(f['fecha_retiro']),
    motivoRetiro: f['motivo_retiro'] as String?,
    consentimiento: ConsentimientoDatos.desdeDb(f['tratamiento_datos'] as String?),
    autorizaFotos: f['autoriza_fotos'] == true,
    clasesComputables: (f['clases_computables'] as num?)?.toInt() ?? 0,
    clasesAsistidas: (f['clases_asistidas'] as num?)?.toInt() ?? 0,
    sesionesTranscurridas: (f['sesiones_transcurridas'] as num?)?.toInt() ?? 0,
    regularizacionUrgente: f['regularizacion_urgente'] == true,
  );

  /// PostgREST entrega las relaciones 1 a 1 como objeto (o lista en versiones antiguas)
  static Map<String, dynamic>? _uno(Object? v) =>
      v is Map<String, dynamic> ? v : (v is List && v.isNotEmpty ? v.first as Map<String, dynamic> : null);

  static AutorizacionesFicha autorizaciones(Map<String, dynamic>? f) {
    if (f == null) return const AutorizacionesFicha();
    final canales = <CanalImagen, bool>{};
    final revocaciones = <CanalImagen, RevocacionImagen>{};
    for (final c in (f['autorizaciones_imagen_canales'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>()) {
      final canal = MapeoAlumnas.canal(c['canal'] as String?);
      if (canal == null) continue;
      canales[canal] = c['autorizado'] == true;
      final fecha = _dia(c['fecha_revocacion']);
      if (fecha != null) revocaciones[canal] = RevocacionImagen(fecha: fecha, motivo: c['motivo_revocacion'] as String? ?? '');
    }
    final perfil = _uno(f['perfiles']);
    return AutorizacionesFicha(
      tratamientoDatos: ConsentimientoDatos.desdeDb(f['autoriza_tratamiento_datos'] as String?),
      canales: canales,
      revocaciones: revocaciones,
      documento: f['documento_respaldo_url'] as String?,
      fechaFirma: _dia(f['fecha_firma']),
      actualizadoEn: _fecha(f['updated_at']),
      registradoPor: perfil == null ? null : '${perfil['nombres']} ${perfil['apellidos']}'.trim(),
    );
  }

  static FichaAlumna ficha(Map<String, dynamic> f, List<InscripcionNomina> inscripciones) {
    final apoderado = _uno(f['apoderados']);
    return FichaAlumna(
      id: f['id'] as String,
      rut: f['rut'] as String,
      nombres: f['nombres'] as String,
      apellidos: f['apellidos'] as String,
      fechaNacimiento: _dia(f['fecha_nacimiento']),
      correo: f['correo'] as String?,
      establecimiento: f['establecimiento_educacional'] as String?,
      cursoEscolar: f['curso_escolar'] as String?,
      apoderado: apoderado == null
          ? null
          : ApoderadoFicha(
              nombres: apoderado['nombres'] as String,
              apellidos: apoderado['apellidos'] as String,
              rut: apoderado['rut'] as String?,
              telefono: apoderado['telefono'] as String,
              correo: apoderado['correo'] as String,
              parentesco: apoderado['parentesco'] as String? ?? '',
            ),
      autorizaciones: autorizaciones(_uno(f['autorizaciones_apoderado'])),
      inscripciones: inscripciones,
    );
  }

  static ResultadoImportacion importacion(String nombreArchivo, Map<String, dynamic> r) => ResultadoImportacion(
    nombreArchivo: nombreArchivo,
    filas: [
      for (final f in (r['filas'] as List<dynamic>).cast<Map<String, dynamic>>())
        FilaImportacion(
          numeroFila: (f['fila'] as num).toInt(),
          nombre: f['nombre'] as String? ?? '',
          rut: f['rut'] as String? ?? '',
          detalle: f['apoderado'] as String? ?? '',
          estado: switch (f['estado']) {
            'nueva' => EstadoFilaImportacion.nueva,
            'existente' => EstadoFilaImportacion.existente,
            _ => EstadoFilaImportacion.invalida,
          },
          motivo: f['motivo'] as String?,
        ),
    ],
  );

  /// 'Autorización Firmada (1).PDF' -> 'autorizacion_firmada_1_.pdf'
  static String nombreSeguro(String nombre) {
    const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
    final limpio = nombre.toLowerCase().split('').map((c) => tildes[c] ?? c).join();
    return limpio.replaceAll(RegExp(r'[^a-z0-9.]+'), '_');
  }
}

class SupabaseAlumnasRepository implements AlumnasRepository {
  final SupabaseClient _client;
  final CatalogoRepository _catalogo;

  /// Reloj inyectable para nombrar los respaldos en las pruebas
  final DateTime Function() _ahora;

  SupabaseAlumnasRepository(this._client, {DateTime Function()? ahora})
    : _catalogo = SupabaseCatalogoRepository(_client),
      _ahora = ahora ?? DateTime.now;

  static const _bucket = 'autorizaciones';
  static const _columnasFicha =
      'id, rut, nombres, apellidos, fecha_nacimiento, correo, establecimiento_educacional, curso_escolar, '
      'apoderados!alumnas_apoderado_id_fkey(rut, nombres, apellidos, telefono, correo, parentesco), '
      'autorizaciones_apoderado(autoriza_tratamiento_datos, documento_respaldo_url, fecha_firma, updated_at, '
      'perfiles(nombres, apellidos), autorizaciones_imagen_canales(canal, autorizado, fecha_revocacion, motivo_revocacion))';

  @override
  Future<List<InscripcionNomina>> nomina({String? sedeId}) async {
    var consulta = _client.from('nomina_alumnas').select();
    if (sedeId != null) consulta = consulta.eq('sede_id', sedeId);
    final filas = await consulta.order('apellidos').order('nombres').order('fecha_inicio', ascending: false);
    return [for (final f in filas) MapeoAlumnas.inscripcion(f)];
  }

  @override
  Future<List<Curso>> instancias() => _catalogo.instancias();

  @override
  Future<FichaAlumna?> ficha(String alumnaId) async {
    final fila = await _client.from('alumnas').select(_columnasFicha).eq('id', alumnaId).maybeSingle();
    if (fila == null) return null;
    final inscripciones = await _client
        .from('nomina_alumnas')
        .select()
        .eq('alumna_id', alumnaId)
        .order('fecha_inicio', ascending: false);
    return MapeoAlumnas.ficha(fila, [for (final f in inscripciones) MapeoAlumnas.inscripcion(f)]);
  }

  Future<Map<String, dynamic>> _importar(String instanciaId, List<Map<String, Object?>> filas, bool soloValidar) async =>
      await _client.rpc(
            'importar_alumnas',
            params: {'p_instancia_id': instanciaId, 'p_filas': filas, 'p_solo_validar': soloValidar},
          )
          as Map<String, dynamic>;

  @override
  Future<ResultadoAlumnas<ResultadoImportacion>> previsualizarImportacion({
    required String instanciaId,
    required String nombreArchivo,
    required List<Map<String, Object?>> filas,
  }) async {
    try {
      final r = await _importar(instanciaId, filas, true);
      return ResultadoAlumnas.ok(MapeoAlumnas.importacion(nombreArchivo, r));
    } on PostgrestException catch (e) {
      return ResultadoAlumnas.error(_mensaje(e));
    }
  }

  @override
  Future<ResultadoAlumnas<({int inscritas, ResultadoImportacion detalle})>> confirmarImportacion({
    required String instanciaId,
    required String nombreArchivo,
    required List<Map<String, Object?>> filas,
  }) async {
    try {
      final r = await _importar(instanciaId, filas, false);
      return ResultadoAlumnas.ok((
        inscritas: (r['inscritas'] as num).toInt(),
        detalle: MapeoAlumnas.importacion(nombreArchivo, r),
      ));
    } on PostgrestException catch (e) {
      return ResultadoAlumnas.error(_mensaje(e));
    }
  }

  @override
  Future<ResultadoAlumnas<void>> inscribir({required String instanciaId, required DatosAlumna datos}) async {
    try {
      final r = MapeoAlumnas.importacion('', await _importar(instanciaId, [datos.fila], false));
      final fila = r.filas.first;
      return fila.estado == EstadoFilaImportacion.invalida
          ? ResultadoAlumnas.error(fila.motivo)
          : const ResultadoAlumnas.ok();
    } on PostgrestException catch (e) {
      return ResultadoAlumnas.error(_mensaje(e));
    }
  }

  @override
  Future<ResultadoAlumnas<void>> registrarAutorizaciones({
    required String alumnaId,
    required ConsentimientoDatos tratamientoDatos,
    required Map<CanalImagen, bool> canales,
    ArchivoAdjunto? respaldo,
    DateTime? fechaFirma,
  }) async {
    final errorArchivo = respaldo?.error;
    if (errorArchivo != null) return ResultadoAlumnas.error(errorArchivo);
    String? ruta;
    try {
      if (respaldo != null) {
        ruta = '$alumnaId/${_ahora().millisecondsSinceEpoch}_${MapeoAlumnas.nombreSeguro(respaldo.nombre)}';
        await _client.storage
            .from(_bucket)
            .uploadBinary(ruta, respaldo.bytes, fileOptions: FileOptions(contentType: respaldo.tipo));
      }
      await _client.rpc(
        'registrar_autorizaciones',
        params: {
          'p_alumna_id': alumnaId,
          'p_tratamiento_datos': tratamientoDatos.valorDb,
          'p_canales': {for (final c in CanalImagen.values) MapeoAlumnas.canalesDb[c]!: canales[c] ?? false},
          'p_documento': ruta,
          'p_fecha_firma': fechaFirma == null ? null : MapeoCatalogo.fecha(fechaFirma),
        },
      );
      return const ResultadoAlumnas.ok();
    } on StorageException catch (e) {
      return ResultadoAlumnas.error(
        e.statusCode == '403' ? 'No tienes permiso para adjuntar respaldos de esta alumna.' : 'No pudimos subir el respaldo. Inténtalo nuevamente.',
      );
    } on PostgrestException catch (e) {
      // El registro no se guardó: el archivo subido queda huérfano y se borra
      if (ruta != null) await _client.storage.from(_bucket).remove([ruta]).catchError((_) => <FileObject>[]);
      return ResultadoAlumnas.error(_mensaje(e));
    }
  }

  @override
  Future<ResultadoAlumnas<void>> revocarImagen({
    required String alumnaId,
    required List<CanalImagen> canales,
    required DateTime fecha,
    required String motivo,
  }) => _rpc('revocar_autorizacion_imagen', {
    'p_alumna_id': alumnaId,
    'p_canales': [for (final c in canales) MapeoAlumnas.canalesDb[c]],
    'p_fecha': MapeoCatalogo.fecha(fecha),
    'p_motivo': motivo.trim(),
  });

  @override
  Future<ResultadoAlumnas<void>> retirar({
    required String inscripcionId,
    required DateTime fecha,
    required String motivo,
  }) => _rpc('retirar_inscripcion', {
    'p_inscripcion_id': inscripcionId,
    'p_fecha': MapeoCatalogo.fecha(fecha),
    'p_motivo': motivo.trim(),
  });

  @override
  Future<ResultadoAlumnas<String>> urlRespaldo(String documento) async {
    try {
      return ResultadoAlumnas.ok(await _client.storage.from(_bucket).createSignedUrl(documento, 60));
    } on StorageException {
      return const ResultadoAlumnas.error('No pudimos abrir el respaldo.');
    }
  }

  Future<ResultadoAlumnas<void>> _rpc(String funcion, Map<String, Object?> params) async {
    try {
      await _client.rpc(funcion, params: params);
      return const ResultadoAlumnas.ok();
    } on PostgrestException catch (e) {
      return ResultadoAlumnas.error(_mensaje(e));
    }
  }

  /// Los mensajes de las RPC y triggers ya vienen en español
  static String _mensaje(PostgrestException e) => switch (e.code) {
    '22023' || 'P0001' => e.message,
    '42501' =>
      e.message.startsWith('new row') || e.message.startsWith('permission denied')
          ? 'No tienes permiso para hacer este cambio.'
          : e.message,
    '23514' => 'Revisa los datos: hay campos vacíos o con un formato no válido.',
    _ => 'No pudimos guardar los cambios. Revisa tu conexión e inténtalo nuevamente.',
  };
}
