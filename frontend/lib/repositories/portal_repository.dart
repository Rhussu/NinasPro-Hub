import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/ninaspro_theme.dart' show EstadoAsistencia;
import '../models/hub_models.dart' show Curso, RecursoEducativo, SesionClase;
import 'clase_repository.dart' show MapeoClase;

export '../config/ninaspro_theme.dart' show EstadoAsistencia;
export '../models/hub_models.dart' show Curso, RecursoEducativo, SesionClase;

/// Asistencia de la alumna frente a la meta para certificar (US-25)
@immutable
class AsistenciaPortal {
  final int realizadas;
  final int presentes;
  final int justificadas;

  /// Justificadas que se cuentan como presentes gracias a los ejercicios (hasta 2)
  final int recuperadas;

  /// Presentes + recuperadas
  final int asistidas;

  /// null mientras no haya clases realizadas
  final double? porcentaje;

  /// Meta para certificar: el mínimo del curso, o 70 % con un justificativo aceptado
  final int umbral;
  final bool umbralReducido;
  final int justificativosAceptados;

  /// Clases del curso sin contar las suspendidas, y las que aún quedan
  final int totalClases;
  final int restantes;

  /// Clases que le faltan asistir para llegar a la meta (US-25 E2)
  final int clasesNecesarias;

  const AsistenciaPortal({
    required this.realizadas,
    required this.presentes,
    this.justificadas = 0,
    this.recuperadas = 0,
    required this.asistidas,
    this.porcentaje,
    required this.umbral,
    this.umbralReducido = false,
    this.justificativosAceptados = 0,
    required this.totalClases,
    required this.restantes,
    this.clasesNecesarias = 0,
  });

  /// Sin clases realizadas todavía no hay nada que cumplir
  bool get cumpleMeta => porcentaje == null || porcentaje! >= umbral;
}

/// Portal de la alumna autenticada: su curso, cronograma con asistencia y
/// recursos, ejercicios y podios (US-25, US-26, US-29)
@immutable
class PortalAlumna {
  final String alumnaId;
  final String nombres;
  final String apellidos;
  final String rut;
  final String apoderadoNombre;
  final String apoderadoTelefono;

  /// Estado de su inscripción ('activa', 'retirada'…); null si no tiene curso
  final String? inscripcionEstado;

  /// Curso con sus enlaces de Classroom y Juez Virtual; null si no tiene
  final Curso? curso;

  /// Sesiones del curso con su tema publicado y recursos
  final List<SesionClase> sesiones;

  /// Asistencia de la alumna en cada sesión registrada (id de la sesión → estado)
  final Map<String, EstadoAsistencia> asistencias;
  final AsistenciaPortal asistencia;

  final int ejercicios;

  /// Clases recuperables ganadas con ejercicios: 25 = 1, 50 = 2
  final int hitosEjercicios;
  final int podiosPrimero;
  final int podiosSegundo;
  final int podiosTercero;

  /// Fecha de hoy en Chile, según la base
  final DateTime hoy;

  const PortalAlumna({
    required this.alumnaId,
    required this.nombres,
    required this.apellidos,
    required this.rut,
    this.apoderadoNombre = '',
    this.apoderadoTelefono = '',
    this.inscripcionEstado,
    this.curso,
    this.sesiones = const [],
    this.asistencias = const {},
    required this.asistencia,
    this.ejercicios = 0,
    this.hitosEjercicios = 0,
    this.podiosPrimero = 0,
    this.podiosSegundo = 0,
    this.podiosTercero = 0,
    required this.hoy,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  /// La clase de hoy, si no está suspendida
  SesionClase? get sesionHoy => sesiones.where((s) => !s.suspendida && _mismoDia(s.fecha, hoy)).firstOrNull;

  /// Estado que se muestra en el cronograma: la asistencia registrada, ausente
  /// en una clase realizada sin registro, o pendiente si aún no ocurre
  EstadoAsistencia estadoDe(SesionClase sesion) =>
      asistencias[sesion.id] ?? (sesion.estado == 'realizada' ? EstadoAsistencia.ausente : EstadoAsistencia.pendiente);
}

bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// El portal no se puede mostrar: otra alumna, o la cuenta no es de alumna
class PortalDenegado implements Exception {
  final String mensaje;

  const PortalDenegado(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Portal de la alumna autenticada (US-25..US-27). La base arma todo: con el
/// id de otra alumna responde 403 y registra el intento.
abstract class PortalRepository {
  /// Lanza [PortalDenegado] si la cuenta no puede ver el portal
  Future<PortalAlumna> portal();
}

class MapeoPortal {
  static int _n(Object? v) => (v as num?)?.toInt() ?? 0;

  static PortalAlumna portal(Map<String, dynamic> r) {
    if (r['code'] != null) throw PortalDenegado(r['message'] as String? ?? 'No puedes ver este portal.');

    final alumna = r['alumna'] as Map<String, dynamic>;
    final apoderado = (r['apoderado'] as Map<String, dynamic>?) ?? const {};
    final inscripcion = r['inscripcion'] as Map<String, dynamic>?;
    final c = r['curso'] as Map<String, dynamic>?;
    final a = (r['asistencia'] as Map<String, dynamic>?) ?? const {};
    final ejercicios = (r['ejercicios'] as Map<String, dynamic>?) ?? const {};
    final podios = (r['podios'] as Map<String, dynamic>?) ?? const {};

    final curso = c == null
        ? null
        : Curso(
            id: c['instancia_id'] as String,
            codigo: c['codigo'] as String? ?? '',
            nombre: c['nombre'] as String? ?? '',
            sedeId: '',
            sedeNombre: c['sede_nombre'] as String? ?? '',
            anio: int.tryParse('${c['periodo'] ?? ''}'.split('-').first) ?? 0,
            semestre: int.tryParse('${c['periodo'] ?? ''}'.split('-').last) ?? 0,
            totalSesiones: _n(a['total_clases']),
            classroomUrl: c['classroom_url'] as String?,
            juezVirtualUrl: c['juez_virtual_url'] as String?,
            seccion: _n(c['seccion']) == 0 ? 1 : _n(c['seccion']),
          );

    final sesiones = <SesionClase>[];
    final asistencias = <String, EstadoAsistencia>{};
    for (final s in (r['sesiones'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>()) {
      final id = s['id'] as String;
      sesiones.add(
        SesionClase(
          id: id,
          cursoId: curso?.id ?? '',
          numeroSesion: _n(s['numero_sesion']),
          fecha: DateTime.parse(s['fecha'] as String),
          tema: s['tema'] as String? ?? 'Tema por publicar',
          estado: s['estado'] as String? ?? 'programada',
          motivoSuspension: s['motivo_suspension'] as String?,
          esEspecial: s['es_especial'] == true,
          horaInicio: s['hora_inicio'] as String?,
          horaFin: s['hora_fin'] as String?,
          recursos: [
            for (final rec in (s['recursos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
              RecursoEducativo(
                id: rec['id'] as String,
                titulo: rec['titulo'] as String? ?? '',
                tipo: rec['tipo'] as String? ?? '',
                url: rec['url'] as String? ?? '',
                esSeguraHttps: '${rec['url']}'.startsWith('https://'),
              ),
          ],
        ),
      );
      if (s['asistencia'] != null) asistencias[id] = MapeoClase.estado(s['asistencia']);
    }

    return PortalAlumna(
      alumnaId: alumna['id'] as String,
      nombres: alumna['nombres'] as String? ?? '',
      apellidos: alumna['apellidos'] as String? ?? '',
      rut: alumna['rut'] as String? ?? '',
      apoderadoNombre: apoderado['nombre'] as String? ?? '',
      apoderadoTelefono: apoderado['telefono'] as String? ?? '',
      inscripcionEstado: inscripcion?['estado'] as String?,
      curso: curso,
      sesiones: sesiones,
      asistencias: asistencias,
      asistencia: AsistenciaPortal(
        realizadas: _n(a['realizadas']),
        presentes: _n(a['presentes']),
        justificadas: _n(a['justificadas']),
        recuperadas: _n(a['recuperadas']),
        asistidas: _n(a['asistidas']),
        porcentaje: (a['porcentaje'] as num?)?.toDouble(),
        umbral: a['umbral'] == null ? 80 : _n(a['umbral']),
        umbralReducido: a['umbral_reducido'] == true,
        justificativosAceptados: _n(a['justificativos_aceptados']),
        totalClases: _n(a['total_clases']),
        restantes: _n(a['restantes']),
        clasesNecesarias: _n(a['clases_necesarias']),
      ),
      ejercicios: _n(ejercicios['total']),
      hitosEjercicios: _n(ejercicios['hitos']),
      podiosPrimero: _n(podios['primero']),
      podiosSegundo: _n(podios['segundo']),
      podiosTercero: _n(podios['tercero']),
      hoy: r['hoy'] is String ? DateTime.parse(r['hoy'] as String) : DateTime.now(),
    );
  }
}

class SupabasePortalRepository implements PortalRepository {
  final SupabaseClient _client;

  SupabasePortalRepository(this._client);

  @override
  Future<PortalAlumna> portal() async {
    final respuesta = await _client.rpc('portal_alumna');
    return MapeoPortal.portal(respuesta as Map<String, dynamic>);
  }
}
