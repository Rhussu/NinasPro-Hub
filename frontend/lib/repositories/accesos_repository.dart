import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sesion_usuario.dart';

/// Estado de una autorización de correo.
enum EstadoAutorizacion {
  /// Vigente: el correo puede crear su cuenta
  pendiente,

  /// Ya se creó la cuenta con este correo
  usada,

  /// Venció sin usarse; hay que autorizarlo de nuevo
  vencida,
}

/// Correo habilitado para crear su cuenta (tabla `correos_autorizados`, US-04).
@immutable
class AutorizacionCorreo {
  final String id;
  final String correo;
  final RolUsuario rol;
  final String nombre;
  final String? sedeId;
  final String? sedeNombre;
  final bool esLiderSede;
  final DateTime expiraEn;
  final DateTime? usadoEn;

  const AutorizacionCorreo({
    required this.id,
    required this.correo,
    required this.rol,
    required this.nombre,
    this.sedeId,
    this.sedeNombre,
    this.esLiderSede = false,
    required this.expiraEn,
    this.usadoEn,
  });

  EstadoAutorizacion estado([DateTime? ahora]) {
    if (usadoEn != null) return EstadoAutorizacion.usada;
    return expiraEn.isAfter(ahora ?? DateTime.now()) ? EstadoAutorizacion.pendiente : EstadoAutorizacion.vencida;
  }

  factory AutorizacionCorreo.desdeFila(Map<String, dynamic> f) {
    final alumna = f['alumnas'] as Map<String, dynamic>?;
    final nombre = alumna != null
        ? '${alumna['nombres']} ${alumna['apellidos']}'
        : '${f['nombres'] ?? ''} ${f['apellidos'] ?? ''}';
    return AutorizacionCorreo(
      id: f['id'] as String,
      correo: f['correo'] as String,
      rol: RolUsuario.desdeDb(f['rol'] as String),
      nombre: nombre.trim(),
      sedeId: f['sede_id'] as String?,
      sedeNombre: (f['sedes'] as Map<String, dynamic>?)?['nombre'] as String?,
      esLiderSede: f['es_lider_sede'] == true,
      expiraEn: DateTime.parse(f['expira_en'] as String).toLocal(),
      usadoEn: f['usado_en'] == null ? null : DateTime.parse(f['usado_en'] as String).toLocal(),
    );
  }
}

/// Sede que se puede asignar al autorizar un correo.
@immutable
class SedeOpcion {
  final String id;
  final String nombre;

  const SedeOpcion({required this.id, required this.nombre});
}

/// Alumna inscrita que aún no tiene cuenta ni una autorización vigente.
@immutable
class AlumnaSinCuenta {
  final String id;
  final String rut;
  final String nombres;
  final String apellidos;
  final String? correo;
  final String sedeId;
  final String sedeNombre;

  const AlumnaSinCuenta({
    required this.id,
    required this.rut,
    required this.nombres,
    required this.apellidos,
    this.correo,
    required this.sedeId,
    required this.sedeNombre,
  });

  String get nombreCompleto => '$nombres $apellidos';
}

/// Datos para autorizar un correo. Las alumnas toman su nombre y RUT de su ficha.
@immutable
class SolicitudAutorizacion {
  final String correo;
  final RolUsuario rol;
  final String? sedeId;
  final String? alumnaId;
  final String? rut;
  final String? nombres;
  final String? apellidos;
  final bool esLiderSede;

  const SolicitudAutorizacion({
    required this.correo,
    required this.rol,
    this.sedeId,
    this.alumnaId,
    this.rut,
    this.nombres,
    this.apellidos,
    this.esLiderSede = false,
  });
}

/// Resultado de autorizar o revocar: [error] trae el mensaje listo para mostrar.
@immutable
class ResultadoAcceso {
  final AutorizacionCorreo? autorizacion;
  final String? error;

  const ResultadoAcceso.ok([this.autorizacion]) : error = null;
  const ResultadoAcceso.error(this.error) : autorizacion = null;

  bool get ok => error == null;
}

/// Correos autorizados para crear cuenta (vista "Accesos", US-04).
///
/// La base decide los privilegios: la Directiva autoriza cualquier rol y la
/// Gestión solo alumnas de su sede; un intento sin permiso responde 403 y queda
/// en la auditoría de seguridad.
abstract class AccesosRepository {
  /// Autorizaciones visibles para la usuaria, de la más reciente a la más antigua
  Future<List<AutorizacionCorreo>> autorizaciones();

  Future<List<SedeOpcion>> sedes();

  Future<List<AlumnaSinCuenta>> alumnasSinCuenta();

  Future<ResultadoAcceso> autorizar(SolicitudAutorizacion solicitud);

  /// Revoca una autorización que aún no se usa
  Future<ResultadoAcceso> revocar(String id);
}

const _mensajeErrorAccesos = 'No pudimos completar la operación. Revisa tu conexión e inténtalo nuevamente.';

class SupabaseAccesosRepository implements AccesosRepository {
  final SupabaseClient _client;

  SupabaseAccesosRepository(this._client);

  static const _columnas =
      'id, correo, rol, sede_id, es_lider_sede, nombres, apellidos, expira_en, usado_en, sedes(nombre), alumnas(nombres, apellidos)';

  @override
  Future<List<AutorizacionCorreo>> autorizaciones() async {
    final filas = await _client.from('correos_autorizados').select(_columnas).order('created_at', ascending: false);
    return [for (final f in filas) AutorizacionCorreo.desdeFila(f)];
  }

  @override
  Future<List<SedeOpcion>> sedes() async {
    final filas = await _client.from('sedes').select('id, nombre').order('nombre');
    return [for (final f in filas) SedeOpcion(id: f['id'] as String, nombre: f['nombre'] as String)];
  }

  @override
  Future<List<AlumnaSinCuenta>> alumnasSinCuenta() async {
    final filas = await _client.rpc('alumnas_para_autorizar') as List<dynamic>;
    final alumnas = [
      for (final f in filas.cast<Map<String, dynamic>>())
        AlumnaSinCuenta(
          id: f['id'] as String,
          rut: f['rut'] as String,
          nombres: f['nombres'] as String,
          apellidos: f['apellidos'] as String,
          correo: f['correo'] as String?,
          sedeId: f['sede_id'] as String,
          sedeNombre: f['sede_nombre'] as String,
        ),
    ];
    return alumnas..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
  }

  @override
  Future<ResultadoAcceso> autorizar(SolicitudAutorizacion s) async {
    try {
      final fila = await _client.rpc('autorizar_correo', params: {
        'p_correo': s.correo,
        'p_rol': s.rol.valorDb,
        'p_sede_id': s.sedeId,
        'p_alumna_id': s.alumnaId,
        'p_rut': s.rut,
        'p_nombres': s.nombres,
        'p_apellidos': s.apellidos,
        'p_es_lider_sede': s.esLiderSede,
      }) as Map<String, dynamic>;
      // La fila de la RPC no trae los nombres de la sede ni de la alumna: se vuelve a leer
      final completa = await _client.from('correos_autorizados').select(_columnas).eq('id', fila['id'] as String).single();
      return ResultadoAcceso.ok(AutorizacionCorreo.desdeFila(completa));
    } on PostgrestException catch (e) {
      // Los mensajes de autorizar_correo ya vienen en español (validaciones y 403)
      return ResultadoAcceso.error(e.code == 'P0001' || e.code == '42501' ? e.message : _mensajeErrorAccesos);
    }
  }

  @override
  Future<ResultadoAcceso> revocar(String id) async {
    try {
      final borradas = await _client.from('correos_autorizados').delete().eq('id', id).select('id');
      if (borradas.isEmpty) {
        return const ResultadoAcceso.error('No se pudo revocar: la cuenta ya se creó o no tienes permiso.');
      }
      return const ResultadoAcceso.ok();
    } on PostgrestException {
      return const ResultadoAcceso.error(_mensajeErrorAccesos);
    }
  }
}
