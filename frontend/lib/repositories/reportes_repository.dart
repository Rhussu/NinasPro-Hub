import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hub_models.dart' show PuntoAsistencia, SerieAsistencia;
import '../utils/exportacion.dart';
import 'justificativos_repository.dart' show Resultado;

export '../models/hub_models.dart' show PuntoAsistencia, SerieAsistencia;
export '../utils/exportacion.dart' show FormatoExportacion;

/// Indicadores de una sede para el dashboard de la Directiva
@immutable
class ResumenSedeReporte {
  final String sedeId;
  final String nombre;
  final String? institucion;
  final bool activa;
  final int cursos;
  final int alumnasActivas;

  /// Presentes sobre los registros de las clases realizadas; null sin clases
  final double? asistenciaPromedio;
  final int voluntariasActivas;

  const ResumenSedeReporte({
    required this.sedeId,
    required this.nombre,
    this.institucion,
    this.activa = true,
    required this.cursos,
    required this.alumnasActivas,
    this.asistenciaPromedio,
    required this.voluntariasActivas,
  });
}

/// Reporte que se puede exportar (US-21)
enum TipoReporte {
  asistencia('Asistencia'),
  nomina('Nómina de alumnas'),
  participacion('Participación y ejercicios');

  final String etiqueta;

  const TipoReporte(this.etiqueta);
}

/// Filtros del formulario de exportación (US-21, US-22)
@immutable
class FiltroReporte {
  final TipoReporte tipo;
  final String? sedeId;

  /// Instancia de curso (curso + sede + período)
  final String? instanciaId;
  final DateTime? desde;
  final DateTime? hasta;

  /// Nombres y RUT reemplazados por ALUMNA-001, ALUMNA-002… (US-22)
  final bool disociado;

  const FiltroReporte({
    required this.tipo,
    this.sedeId,
    this.instanciaId,
    this.desde,
    this.hasta,
    this.disociado = false,
  });

  /// asistencia_2026-11-16 o asistencia_disociado_2026-11-16
  String nombreArchivo(DateTime hoy) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final fecha = '${hoy.year}-${dos(hoy.month)}-${dos(hoy.day)}';
    return [tipo.name, if (disociado) 'disociado', fecha].join('_');
  }
}

/// Filas de un reporte; [total] cuenta todas aunque la vista previa traiga menos
@immutable
class Reporte {
  final List<String> encabezados;
  final List<List<String>> filas;
  final int total;

  const Reporte({required this.encabezados, required this.filas, required this.total});
}

/// Tipo de evento de la bitácora (US-23, US-24)
enum TipoEventoAuditoria {
  modificacion('modificacion', 'Modificación'),
  exportacion('exportacion', 'Exportación'),
  accesoDenegado('acceso_denegado', 'Acceso denegado'),
  seguridad('seguridad', 'Seguridad');

  final String valorDb;
  final String etiqueta;

  const TipoEventoAuditoria(this.valorDb, this.etiqueta);

  static TipoEventoAuditoria desdeDb(Object? valor) =>
      values.firstWhere((t) => t.valorDb == valor, orElse: () => TipoEventoAuditoria.modificacion);
}

/// Evento inmutable de la bitácora: cambio de datos, descarga o evento de seguridad
@immutable
class EventoAuditoria {
  final String id;
  final DateTime fecha;
  final TipoEventoAuditoria tipo;
  final String usuariaNombre;
  final String? usuariaCorreo;
  final String? sedeNombre;
  final String descripcion;
  final String? alumnaRut;
  final String? alumnaNombre;

  /// Valores anterior y nuevo, filtros de la descarga o parámetros del intento
  final Map<String, dynamic> detalle;

  const EventoAuditoria({
    required this.id,
    required this.fecha,
    required this.tipo,
    required this.usuariaNombre,
    this.usuariaCorreo,
    this.sedeNombre,
    required this.descripcion,
    this.alumnaRut,
    this.alumnaNombre,
    this.detalle = const {},
  });
}

/// Dashboard, exportación y auditoría de la Directiva y de Gestión de la sede
/// (US-21..US-24). La base decide el alcance: Gestión solo ve y exporta su
/// sede, y cada descarga queda registrada en la misma llamada que la arma.
abstract class ReportesRepository {
  /// Indicadores por sede
  Future<List<ResumenSedeReporte>> resumenSedes();

  /// Asistencia de cada sede en cada clase realizada, ordenada por fecha
  Future<List<SerieAsistencia>> asistenciaPorClase();

  /// Las primeras filas y el total, sin registrar la descarga
  Future<Resultado<Reporte>> vistaPrevia(FiltroReporte filtro);

  /// Todas las filas; la descarga queda en la auditoría (US-22 E2)
  Future<Resultado<Reporte>> exportar(FiltroReporte filtro, FormatoExportacion formato);

  /// Bitácora filtrada, del evento más reciente al más antiguo (US-24)
  Future<List<EventoAuditoria>> auditoria({
    DateTime? desde,
    DateTime? hasta,
    String? usuaria,
    TipoEventoAuditoria? tipo,
    String? rutAlumna,
  });
}

/// Traducción entre las respuestas de Supabase y los modelos de la app
class MapeoReportes {
  static String? fecha(DateTime? f) {
    if (f == null) return null;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${f.year}-${dos(f.month)}-${dos(f.day)}';
  }

  static ResumenSedeReporte resumen(Map<String, dynamic> f) => ResumenSedeReporte(
    sedeId: f['sede_id'] as String,
    nombre: f['nombre'] as String? ?? '',
    institucion: f['institucion'] as String?,
    activa: f['activa'] != false,
    cursos: (f['cursos'] as num?)?.toInt() ?? 0,
    alumnasActivas: (f['alumnas_activas'] as num?)?.toInt() ?? 0,
    asistenciaPromedio: (f['asistencia_promedio'] as num?)?.toDouble(),
    voluntariasActivas: (f['voluntarias_activas'] as num?)?.toInt() ?? 0,
  );

  /// Filas de asistencia_por_clase agrupadas en una serie por sede
  static List<SerieAsistencia> series(List<Map<String, dynamic>> filas) {
    final porSede = <String, (String, List<PuntoAsistencia>)>{};
    for (final f in filas) {
      final id = f['sede_id'] as String;
      final serie = porSede.putIfAbsent(id, () => (f['sede_nombre'] as String? ?? '', []));
      serie.$2.add(
        PuntoAsistencia(
          fecha: DateTime.parse(f['fecha'] as String),
          presentes: (f['presentes'] as num).toInt(),
          total: (f['total'] as num).toInt(),
        ),
      );
    }
    return [
      for (final e in porSede.entries) SerieAsistencia(sedeId: e.key, sedeNombre: e.value.$1, puntos: e.value.$2),
    ];
  }

  /// Respuesta de exportar_reporte; un {code, message} es un rechazo
  static Resultado<Reporte> reporte(Object? respuesta) {
    final r = respuesta as Map<String, dynamic>;
    if (r['code'] != null) return Resultado.error(r['message'] as String? ?? 'No tienes permiso para exportar.');
    return Resultado.ok(
      Reporte(
        encabezados: [for (final e in r['encabezados'] as List<dynamic>) '$e'],
        filas: [
          for (final fila in r['filas'] as List<dynamic>)
            [for (final c in fila as List<dynamic>) c == null ? '' : '$c'],
        ],
        total: (r['total'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  static EventoAuditoria evento(Map<String, dynamic> f) => EventoAuditoria(
    id: f['id'] as String,
    fecha: DateTime.parse(f['fecha_hora'] as String).toLocal(),
    tipo: TipoEventoAuditoria.desdeDb(f['tipo']),
    usuariaNombre: f['usuaria_nombre'] as String? ?? 'Sistema',
    usuariaCorreo: f['usuaria_correo'] as String?,
    sedeNombre: f['sede_nombre'] as String?,
    descripcion: f['descripcion'] as String? ?? '',
    alumnaRut: f['alumna_rut'] as String?,
    alumnaNombre: f['alumna_nombre'] as String?,
    detalle: (f['detalle'] as Map<String, dynamic>?) ?? const {},
  );
}

const _mensajeError = 'No pudimos armar el reporte. Inténtalo nuevamente.';

class SupabaseReportesRepository implements ReportesRepository {
  final SupabaseClient _client;

  SupabaseReportesRepository(this._client);

  @override
  Future<List<ResumenSedeReporte>> resumenSedes() async {
    final filas = await _client.rpc('resumen_sedes') as List<dynamic>;
    return [for (final f in filas.cast<Map<String, dynamic>>()) MapeoReportes.resumen(f)];
  }

  @override
  Future<List<SerieAsistencia>> asistenciaPorClase() async {
    final filas = await _client.rpc('asistencia_por_clase') as List<dynamic>;
    return MapeoReportes.series(filas.cast<Map<String, dynamic>>());
  }

  @override
  Future<Resultado<Reporte>> vistaPrevia(FiltroReporte filtro) => _reporte(filtro, null);

  @override
  Future<Resultado<Reporte>> exportar(FiltroReporte filtro, FormatoExportacion formato) => _reporte(filtro, formato);

  Future<Resultado<Reporte>> _reporte(FiltroReporte filtro, FormatoExportacion? formato) async {
    try {
      final respuesta = await _client.rpc(
        'exportar_reporte',
        params: {
          'p_tipo': filtro.tipo.name,
          'p_sede_id': filtro.sedeId,
          'p_instancia_id': filtro.instanciaId,
          'p_desde': MapeoReportes.fecha(filtro.desde),
          'p_hasta': MapeoReportes.fecha(filtro.hasta),
          'p_disociado': filtro.disociado,
          'p_formato': (formato ?? FormatoExportacion.csv).extension.toUpperCase(),
          'p_vista_previa': formato == null,
        },
      );
      return MapeoReportes.reporte(respuesta);
    } on PostgrestException catch (e) {
      return Resultado.error(switch (e.code) {
        '22023' || '42501' || 'P0001' => e.message,
        _ => _mensajeError,
      });
    }
  }

  @override
  Future<List<EventoAuditoria>> auditoria({
    DateTime? desde,
    DateTime? hasta,
    String? usuaria,
    TipoEventoAuditoria? tipo,
    String? rutAlumna,
  }) async {
    final filas =
        await _client.rpc(
              'consultar_auditoria',
              params: {
                'p_desde': MapeoReportes.fecha(desde),
                'p_hasta': MapeoReportes.fecha(hasta),
                'p_usuaria': usuaria?.trim().isEmpty ?? true ? null : usuaria!.trim(),
                'p_tipo': tipo?.valorDb,
                'p_rut': rutAlumna?.trim().isEmpty ?? true ? null : rutAlumna!.trim(),
              },
            )
            as List<dynamic>;
    return [for (final f in filas.cast<Map<String, dynamic>>()) MapeoReportes.evento(f)];
  }
}
