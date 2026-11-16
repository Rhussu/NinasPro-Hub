import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hub_models.dart';
import '../utils/calendario.dart';

/// Datos editables de una sede (US-01). La coordinadora no se escribe aquí:
/// es la líder de sede del Equipo de Gestión (`usuarios_sedes.es_lider_sede`).
@immutable
class DatosSede {
  final String nombre;
  final String institucion;
  final String region;
  final String modalidad; // 'Presencial' | 'Online'
  final bool activa;

  const DatosSede({
    required this.nombre,
    required this.institucion,
    required this.region,
    required this.modalidad,
    this.activa = true,
  });
}

/// Datos de un curso del catálogo (US-01)
@immutable
class DatosCurso {
  final String codigo;
  final String nombre;
  final String descripcion;

  const DatosCurso({required this.codigo, required this.nombre, this.descripcion = ''});
}

/// Instancia a programar: curso del catálogo + sede + rango de fechas y horario (US-02)
@immutable
class SolicitudInstancia {
  final String catalogoId;
  final String sedeId;
  final DateTime inicio;
  final DateTime termino;
  final int diaSemana; // DateTime.monday..DateTime.sunday
  final String horaInicio; // 'HH:mm'
  final String horaFin;

  const SolicitudInstancia({
    required this.catalogoId,
    required this.sedeId,
    required this.inicio,
    required this.termino,
    required this.diaSemana,
    this.horaInicio = '10:00',
    this.horaFin = '13:00',
  });
}

/// Resultado de una escritura del catálogo. [error] trae el mensaje listo para
/// mostrar; [duplicada] indica que la instancia ya existe y se puede confirmar
/// como sección paralela.
@immutable
class ResultadoCatalogo<T> {
  final T? valor;
  final String? error;
  final bool duplicada;

  const ResultadoCatalogo.ok([this.valor]) : error = null, duplicada = false;
  const ResultadoCatalogo.error(this.error, {this.duplicada = false}) : valor = null;

  bool get ok => error == null;
}

/// Catálogo institucional y calendario de clases (US-01, US-02, US-03).
///
/// La base decide los privilegios: solo la Directiva escribe sedes, cursos e
/// instancias; Gestión suspende, reanuda y agrega sesiones en su sede.
abstract class CatalogoRepository {
  Future<List<Sede>> sedes();
  Future<ResultadoCatalogo<void>> crearSede(DatosSede datos);
  Future<ResultadoCatalogo<void>> actualizarSede(String id, DatosSede datos);

  /// Elimina una sede sin uso; si tiene instancias, personas o accesos pendientes la base lo impide
  Future<ResultadoCatalogo<void>> eliminarSede(String id);

  Future<List<CursoCatalogo>> cursos();
  Future<ResultadoCatalogo<void>> crearCurso(DatosCurso datos);
  Future<ResultadoCatalogo<void>> actualizarCurso(String id, DatosCurso datos);

  /// Elimina un curso del catálogo que aún no tiene instancias
  Future<ResultadoCatalogo<void>> eliminarCurso(String id);

  /// Instancias visibles para la usuaria (la RLS acota a sus sedes), de la más reciente a la más antigua
  Future<List<Curso>> instancias({String? sedeId});

  /// Programa la instancia y genera sus sesiones. Si ya existe una igual y no
  /// se pide [nuevaSeccion], responde con `duplicada` sin crear nada.
  Future<ResultadoCatalogo<Curso>> crearInstancia(SolicitudInstancia solicitud, {bool nuevaSeccion = false});

  /// Sesiones de la instancia ordenadas por fecha
  Future<List<SesionClase>> sesiones(String instanciaId);

  Future<ResultadoCatalogo<void>> suspenderSesion(String sesionId, String motivo);
  Future<ResultadoCatalogo<void>> reanudarSesion(String sesionId);
  Future<ResultadoCatalogo<SesionClase>> agregarSesionEspecial({
    required String instanciaId,
    required DateTime fecha,
    required String horaInicio,
    required String horaFin,
  });
}

const _mensajeErrorCatalogo = 'No pudimos guardar los cambios. Revisa tu conexión e inténtalo nuevamente.';
const _mensajeSinPermiso = 'No tienes permiso para hacer este cambio.';
const _sedeRepetida = 'Ya existe una sede con ese nombre. Los nombres no distinguen tildes, mayúsculas ni signos.';

/// Código visible de una instancia: PCB-2026-S2-BEAUCHEF (y -B, -C… en secciones paralelas)
String codigoInstancia({
  required String codigoCurso,
  required String sedeNombre,
  required int anio,
  required int semestre,
  int seccion = 1,
}) {
  const acentos = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N'};
  final sufijo = sedeNombre
      .replaceFirst(RegExp(r'^Sede\s+', caseSensitive: false), '')
      .toUpperCase()
      .split('')
      .map((c) => acentos[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final base = '$codigoCurso-$anio-S$semestre-$sufijo';
  return seccion > 1 ? '$base-${String.fromCharCode(64 + seccion)}' : base;
}

/// Traducción de filas de Supabase a los modelos de la app
class MapeoCatalogo {
  /// Columnas que necesita [instancia] (curso, sede y total de sesiones embebidos)
  static const columnasInstancia =
      'id, curso_id, sede_id, periodo_academico, seccion, fecha_inicio, fecha_termino, dia_semana, hora_inicio, hora_fin, '
      'classroom_url, juez_virtual_url, cursos(codigo, nombre), sedes(nombre), clases(count)';

  /// Columnas que necesita [sesion] (con el tema de la planificación)
  static const columnasSesion =
      'id, instancia_curso_id, numero_sesion, fecha, hora_inicio, hora_fin, estado, motivo_suspension, es_especial, '
      'planificacion_clases(tema_titulo)';

  static const _dias = {
    'Lunes': DateTime.monday,
    'Martes': DateTime.tuesday,
    'Miércoles': DateTime.wednesday,
    'Jueves': DateTime.thursday,
    'Viernes': DateTime.friday,
    'Sábado': DateTime.saturday,
    'Domingo': DateTime.sunday,
  };

  static Sede sede(Map<String, dynamic> f) {
    final asignaciones = (f['usuarios_sedes'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final lider =
        asignaciones.where((a) => a['es_lider_sede'] == true).map((a) => a['perfiles']).firstOrNull
            as Map<String, dynamic>?;
    return Sede(
      id: f['id'] as String,
      nombre: f['nombre'] as String,
      universidad: f['institucion_anfitriona'] as String? ?? '',
      region: f['region'] as String? ?? '',
      modalidad: f['modalidad'] == 'online' ? 'Online' : 'Presencial',
      coordinadoraNombre: lider == null ? '' : '${lider['nombres']} ${lider['apellidos']}'.trim(),
      estado: f['activa'] == false ? 'inactiva' : 'activa',
      usos: [
        ?_uso(_conteo(f['instancias_curso']), 'instancia de curso', 'instancias de curso'),
        ?_uso(asignaciones.length, 'persona asignada', 'personas asignadas'),
        ?_uso(_conteo(f['correos_autorizados']), 'acceso pendiente', 'accesos pendientes'),
      ],
    );
  }

  /// `[{count: 3}]` de un conteo embebido de PostgREST
  static int _conteo(Object? valor) =>
      valor is List && valor.isNotEmpty ? ((valor.first as Map)['count'] as num).toInt() : 0;

  static String? _uso(int cantidad, String singular, String plural) =>
      cantidad == 0 ? null : '$cantidad ${cantidad == 1 ? singular : plural}';

  static Map<String, dynamic> filaSede(DatosSede d) => {
    'nombre': d.nombre.trim(),
    'institucion_anfitriona': d.institucion.trim(),
    'region': d.region.trim(),
    'modalidad': d.modalidad == 'Online' ? 'online' : 'presencial',
    'activa': d.activa,
  };

  static CursoCatalogo curso(Map<String, dynamic> f) => CursoCatalogo(
    id: f['id'] as String,
    codigo: f['codigo'] as String,
    nombre: f['nombre'] as String,
    descripcion: f['descripcion'] as String? ?? '',
    usos: [?_uso(_conteo(f['instancias_curso']), 'instancia de curso', 'instancias de curso')],
  );

  static Map<String, dynamic> filaCurso(DatosCurso d) => {
    'codigo': d.codigo.trim().toUpperCase(),
    'nombre': d.nombre.trim(),
    'descripcion': d.descripcion.trim(),
  };

  static Curso instancia(Map<String, dynamic> f) {
    final curso = f['cursos'] as Map<String, dynamic>? ?? const {};
    final sedeNombre = (f['sedes'] as Map<String, dynamic>?)?['nombre'] as String? ?? '';
    final inicio = DateTime.parse(f['fecha_inicio'] as String);
    final periodo = partesPeriodo(f['periodo_academico'] as String, inicio);
    final seccion = (f['seccion'] as num?)?.toInt() ?? 1;
    final conteo = f['clases'];
    final total = conteo is List && conteo.isNotEmpty ? (conteo.first['count'] as num).toInt() : 0;
    return Curso(
      id: f['id'] as String,
      codigo: codigoInstancia(
        codigoCurso: curso['codigo'] as String? ?? '',
        sedeNombre: sedeNombre,
        anio: periodo.anio,
        semestre: periodo.semestre,
        seccion: seccion,
      ),
      nombre: curso['nombre'] as String? ?? '',
      sedeId: f['sede_id'] as String,
      sedeNombre: sedeNombre,
      anio: periodo.anio,
      semestre: periodo.semestre,
      totalSesiones: total,
      classroomUrl: f['classroom_url'] as String?,
      juezVirtualUrl: f['juez_virtual_url'] as String?,
      catalogoId: f['curso_id'] as String?,
      fechaInicio: inicio,
      fechaTermino: DateTime.parse(f['fecha_termino'] as String),
      diaSemana: _dias[f['dia_semana']] ?? DateTime.saturday,
      seccion: seccion,
      horaInicio: horaCorta(f['hora_inicio'] as String?),
      horaFin: horaCorta(f['hora_fin'] as String?),
    );
  }

  static SesionClase sesion(Map<String, dynamic> f) {
    // planificacion_clases es 1 a 1 con la clase: PostgREST la entrega como objeto
    final plan = f['planificacion_clases'];
    final tema = plan is Map
        ? plan['tema_titulo'] as String?
        : (plan is List && plan.isNotEmpty ? plan.first['tema_titulo'] as String? : null);
    return SesionClase(
      id: f['id'] as String,
      cursoId: f['instancia_curso_id'] as String,
      numeroSesion: (f['numero_sesion'] as num).toInt(),
      fecha: DateTime.parse(f['fecha'] as String),
      tema: tema ?? '',
      estado: f['estado'] as String,
      motivoSuspension: f['motivo_suspension'] as String?,
      esEspecial: f['es_especial'] == true,
      horaInicio: horaCorta(f['hora_inicio'] as String?),
      horaFin: horaCorta(f['hora_fin'] as String?),
    );
  }

  static String fecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class SupabaseCatalogoRepository implements CatalogoRepository {
  final SupabaseClient _client;

  SupabaseCatalogoRepository(this._client);

  static const _columnasSede =
      'id, nombre, region, modalidad, institucion_anfitriona, activa, usuarios_sedes(es_lider_sede, perfiles(nombres, apellidos)), '
      'instancias_curso(count), correos_autorizados(count)';
  static const _columnasInstancia = MapeoCatalogo.columnasInstancia;
  static const _columnasSesion = MapeoCatalogo.columnasSesion;

  @override
  Future<List<Sede>> sedes() async {
    // Solo los accesos pendientes impiden eliminar la sede (los usados ya tienen su persona asignada)
    final filas = await _client
        .from('sedes')
        .select(_columnasSede)
        .isFilter('correos_autorizados.usado_en', null)
        .order('nombre', ascending: true);
    return [for (final f in filas) MapeoCatalogo.sede(f)];
  }

  @override
  Future<ResultadoCatalogo<void>> crearSede(DatosSede datos) => _escribir(
    () => _client.from('sedes').insert(MapeoCatalogo.filaSede(datos)).select('id'),
    duplicado: _sedeRepetida,
  );

  @override
  Future<ResultadoCatalogo<void>> actualizarSede(String id, DatosSede datos) => _escribir(
    () => _client.from('sedes').update(MapeoCatalogo.filaSede(datos)).eq('id', id).select('id'),
    duplicado: _sedeRepetida,
  );

  @override
  Future<ResultadoCatalogo<void>> eliminarSede(String id) =>
      _escribir(() => _client.from('sedes').delete().eq('id', id).select('id'));

  @override
  Future<List<CursoCatalogo>> cursos() async {
    final filas = await _client
        .from('cursos')
        .select('id, codigo, nombre, descripcion, instancias_curso(count)')
        .order('codigo', ascending: true);
    return [for (final f in filas) MapeoCatalogo.curso(f)];
  }

  @override
  Future<ResultadoCatalogo<void>> crearCurso(DatosCurso datos) => _escribir(
    () => _client.from('cursos').insert(MapeoCatalogo.filaCurso(datos)).select('id'),
    duplicado: 'El código "${datos.codigo.trim().toUpperCase()}" ya está en uso.',
  );

  @override
  Future<ResultadoCatalogo<void>> actualizarCurso(String id, DatosCurso datos) => _escribir(
    () => _client.from('cursos').update(MapeoCatalogo.filaCurso(datos)).eq('id', id).select('id'),
    duplicado: 'El código "${datos.codigo.trim().toUpperCase()}" ya está en uso.',
  );

  @override
  Future<ResultadoCatalogo<void>> eliminarCurso(String id) =>
      _escribir(() => _client.from('cursos').delete().eq('id', id).select('id'));

  @override
  Future<List<Curso>> instancias({String? sedeId}) async {
    var consulta = _client.from('instancias_curso').select(_columnasInstancia);
    if (sedeId != null) consulta = consulta.eq('sede_id', sedeId);
    final filas = await consulta.order('fecha_inicio', ascending: false).order('seccion', ascending: true);
    return [for (final f in filas) MapeoCatalogo.instancia(f)];
  }

  @override
  Future<ResultadoCatalogo<Curso>> crearInstancia(SolicitudInstancia s, {bool nuevaSeccion = false}) async {
    try {
      final fila =
          await _client.rpc(
                'crear_instancia_curso',
                params: {
                  'p_curso_id': s.catalogoId,
                  'p_sede_id': s.sedeId,
                  'p_fecha_inicio': MapeoCatalogo.fecha(s.inicio),
                  'p_fecha_termino': MapeoCatalogo.fecha(s.termino),
                  'p_dia_semana': s.diaSemana,
                  'p_hora_inicio': s.horaInicio,
                  'p_hora_fin': s.horaFin,
                  'p_nueva_seccion': nuevaSeccion,
                },
              )
              as Map<String, dynamic>;
      final completa = await _client
          .from('instancias_curso')
          .select(_columnasInstancia)
          .eq('id', fila['id'] as String)
          .single();
      return ResultadoCatalogo.ok(MapeoCatalogo.instancia(completa));
    } on PostgrestException catch (e) {
      if (e.code == 'PT409') return ResultadoCatalogo.error(e.message, duplicada: true);
      return ResultadoCatalogo.error(_mensaje(e));
    }
  }

  @override
  Future<List<SesionClase>> sesiones(String instanciaId) async {
    final filas = await _client
        .from('clases')
        .select(_columnasSesion)
        .eq('instancia_curso_id', instanciaId)
        .order('fecha', ascending: true);
    return [for (final f in filas) MapeoCatalogo.sesion(f)];
  }

  @override
  Future<ResultadoCatalogo<void>> suspenderSesion(String sesionId, String motivo) => _escribir(
    () => _client
        .from('clases')
        .update({'estado': 'suspendida', 'motivo_suspension': motivo.trim()})
        .eq('id', sesionId)
        .select('id'),
  );

  @override
  Future<ResultadoCatalogo<void>> reanudarSesion(String sesionId) =>
      _escribir(() => _client.from('clases').update({'estado': 'programada'}).eq('id', sesionId).select('id'));

  @override
  Future<ResultadoCatalogo<SesionClase>> agregarSesionEspecial({
    required String instanciaId,
    required DateTime fecha,
    required String horaInicio,
    required String horaFin,
  }) async {
    try {
      final fila =
          await _client.rpc(
                'agregar_sesion_especial',
                params: {
                  'p_instancia_id': instanciaId,
                  'p_fecha': MapeoCatalogo.fecha(fecha),
                  'p_hora_inicio': horaInicio,
                  'p_hora_fin': horaFin,
                },
              )
              as Map<String, dynamic>;
      return ResultadoCatalogo.ok(MapeoCatalogo.sesion(fila));
    } on PostgrestException catch (e) {
      return ResultadoCatalogo.error(_mensaje(e));
    }
  }

  /// Ejecuta una escritura que devuelve las filas afectadas; 0 filas significa que la RLS no la permitió
  Future<ResultadoCatalogo<void>> _escribir(
    Future<List<Map<String, dynamic>>> Function() operacion, {
    String? duplicado,
  }) async {
    try {
      final filas = await operacion();
      return filas.isEmpty ? const ResultadoCatalogo.error(_mensajeSinPermiso) : const ResultadoCatalogo.ok();
    } on PostgrestException catch (e) {
      if (e.code == '23505' && duplicado != null) return ResultadoCatalogo.error(duplicado);
      return ResultadoCatalogo.error(_mensaje(e));
    }
  }

  /// Los mensajes de las RPC y triggers ya vienen en español
  static String _mensaje(PostgrestException e) => switch (e.code) {
    '22023' || 'P0001' => e.message,
    '42501' =>
      e.message.startsWith('new row') || e.message.startsWith('permission denied') ? _mensajeSinPermiso : e.message,
    '23514' => 'Revisa los datos: hay campos vacíos o con un formato no válido.',
    // El trigger de eliminación explica qué está usando la sede o el curso
    '23503' => e.message.startsWith('No se puede') ? e.message : 'No se puede eliminar: hay registros que lo usan.',
    _ => _mensajeErrorCatalogo,
  };
}
