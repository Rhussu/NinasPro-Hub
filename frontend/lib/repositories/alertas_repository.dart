import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'justificativos_repository.dart' show Resultado, fechaCorta;

/// Alerta de deserción con la alumna, su curso y el contacto de la apoderada (US-39, US-40)
@immutable
class AlertaDesercionDetalle {
  final String id;
  final String inscripcionId;
  final String alumnaId;
  final String alumnaNombre;
  final String alumnaRut;
  final String cursoCodigo;
  final String cursoNombre;
  final String sedeId;
  final String sedeNombre;

  /// Última clase de la racha
  final int numeroSesion;
  final DateTime claseFecha;
  final int inasistenciasConsecutivas;

  final bool atendida;
  final DateTime? fechaContacto;
  final String? observacion;
  final String? atendidaPor;

  final String? apoderadoNombre;
  final String? apoderadoTelefono;
  final String? apoderadoCorreo;
  final String? apoderadoParentesco;
  final DateTime creadaEn;

  const AlertaDesercionDetalle({
    required this.id,
    required this.inscripcionId,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.alumnaRut,
    required this.cursoCodigo,
    required this.cursoNombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.numeroSesion,
    required this.claseFecha,
    required this.inasistenciasConsecutivas,
    this.atendida = false,
    this.fechaContacto,
    this.observacion,
    this.atendidaPor,
    this.apoderadoNombre,
    this.apoderadoTelefono,
    this.apoderadoCorreo,
    this.apoderadoParentesco,
    required this.creadaEn,
  });

  /// Clase #7 · 14/11/2026
  String get ultimaClase => 'Clase #$numeroSesion · ${fechaCorta(claseFecha)}';
}

/// Alertas de deserción de la sede y registro del contacto preventivo (US-39, US-40).
///
/// Las crea la base al guardar la asistencia (3 faltas seguidas sin
/// justificar). Las ve y atiende el Equipo de Gestión de la sede (y la
/// Directiva); las tutoras y las alumnas no las ven.
abstract class AlertasRepository {
  /// Sin atender primero, de la más reciente a la más antigua
  Future<List<AlertaDesercionDetalle>> alertas();

  /// Gestión registra lo que conversó con la apoderada: la alerta queda atendida
  Future<Resultado<void>> registrarContacto(String id, String observacion);
}

class MapeoAlertas {
  static DateTime? _fecha(Object? v) => v is String ? DateTime.parse(v) : null;

  /// Filas de la vista `alertas_detalle`
  static AlertaDesercionDetalle alerta(Map<String, dynamic> f) => AlertaDesercionDetalle(
    id: f['id'] as String,
    inscripcionId: f['inscripcion_id'] as String,
    alumnaId: f['alumna_id'] as String,
    alumnaNombre: '${f['alumna_nombres'] ?? ''} ${f['alumna_apellidos'] ?? ''}'.trim(),
    alumnaRut: f['alumna_rut'] as String? ?? '',
    cursoCodigo: f['curso_codigo'] as String? ?? '',
    cursoNombre: f['curso_nombre'] as String? ?? '',
    sedeId: f['sede_id'] as String,
    sedeNombre: f['sede_nombre'] as String? ?? '',
    numeroSesion: (f['numero_sesion'] as num).toInt(),
    claseFecha: DateTime.parse(f['clase_fecha'] as String),
    inasistenciasConsecutivas: (f['inasistencias_consecutivas'] as num).toInt(),
    atendida: f['atendida'] == true,
    fechaContacto: _fecha(f['fecha_contacto']),
    observacion: f['observacion_gestion'] as String?,
    atendidaPor: f['atendida_por_nombre'] as String?,
    apoderadoNombre: f['apoderado_nombre'] as String?,
    apoderadoTelefono: f['apoderado_telefono'] as String?,
    apoderadoCorreo: f['apoderado_correo'] as String?,
    apoderadoParentesco: f['apoderado_parentesco'] as String?,
    creadaEn: DateTime.parse(f['created_at'] as String).toLocal(),
  );
}

class SupabaseAlertasRepository implements AlertasRepository {
  final SupabaseClient _client;

  SupabaseAlertasRepository(this._client);

  @override
  Future<List<AlertaDesercionDetalle>> alertas() async {
    final filas = await _client
        .from('alertas_detalle')
        .select()
        .order('atendida')
        .order('created_at', ascending: false);
    return [for (final f in filas) MapeoAlertas.alerta(f)];
  }

  @override
  Future<Resultado<void>> registrarContacto(String id, String observacion) async {
    try {
      await _client.rpc('registrar_contacto_alerta', params: {'p_id': id, 'p_observacion': observacion.trim()});
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      return Resultado.error(switch (e.code) {
        '22023' || '42501' || 'P0001' => e.message,
        _ => 'No pudimos registrar el contacto. Inténtalo nuevamente.',
      });
    }
  }
}
