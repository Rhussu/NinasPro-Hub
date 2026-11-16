import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'justificativos_repository.dart' show Resultado;

/// Rol del catálogo de tareas de las tutoras (US-43 escenario 1)
@immutable
class RolTarea {
  final String id;
  final String codigo;
  final String nombre;
  final String descripcion;
  final String colorHex;

  /// Debe quedar cubierto en cada clase
  final bool esRequerido;
  final bool activo;

  const RolTarea({
    required this.id,
    this.codigo = '',
    required this.nombre,
    this.descripcion = '',
    this.colorHex = '#8B3295',
    this.esRequerido = false,
    this.activo = true,
  });

  /// Color del rol a partir de [colorHex] ('#RRGGBB'); violeta de marca si no es válido
  Color get color {
    final valor = int.tryParse(colorHex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (valor ?? 0x8B3295));
  }

  RolTarea copyWith({String? nombre, String? descripcion, String? colorHex, bool? esRequerido, bool? activo}) =>
      RolTarea(
        id: id,
        codigo: codigo,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        colorHex: colorHex ?? this.colorHex,
        esRequerido: esRequerido ?? this.esRequerido,
        activo: activo ?? this.activo,
      );
}

/// Un rol asignado a una tutora en una clase, con su cumplimiento (US-44)
@immutable
class TareaClase {
  final String id;
  final String rolId;
  final bool completada;

  const TareaClase({required this.id, required this.rolId, this.completada = false});

  TareaClase copyWith({bool? completada}) =>
      TareaClase(id: id, rolId: rolId, completada: completada ?? this.completada);
}

/// Integrante del equipo del curso con sus roles en una clase (0, 1, 2 o más)
@immutable
class TutoraRolesClase {
  final String tutoraId;
  final String nombre;
  final bool esEquipoGestion;
  final List<TareaClase> tareas;

  const TutoraRolesClase({
    required this.tutoraId,
    required this.nombre,
    this.esEquipoGestion = false,
    this.tareas = const [],
  });

  Set<String> get rolIds => {for (final t in tareas) t.rolId};
}

/// Mis roles en una clase de mi curso
@immutable
class MiTareaCurso {
  final String claseId;
  final int numeroSesion;
  final TareaClase tarea;

  const MiTareaCurso({required this.claseId, required this.numeroSesion, required this.tarea});
}

/// Roles de las tutoras (US-43, US-44).
///
/// La Directiva administra el catálogo; Gestión de la sede asigna los roles de
/// cada clase y la tutora marca el cumplimiento de los suyos (Gestión también
/// puede marcar los de cualquiera). La base valida los permisos.
abstract class RolesRepository {
  /// Catálogo de roles; los inactivos solo si se piden (para administrarlos)
  Future<List<RolTarea>> roles({bool incluirInactivos = false});

  Future<Resultado<RolTarea>> crearRol(RolTarea rol);
  Future<Resultado<void>> actualizarRol(RolTarea rol);

  /// Elimina un rol que nunca se asignó; si ya tiene asignaciones, se desactiva en su lugar
  Future<Resultado<void>> eliminarRol(String id);

  /// Veces que se ha asignado un rol (para avisar antes de eliminarlo)
  Future<int> usosRol(String id);

  /// Equipo del curso de la clase con sus roles
  Future<List<TutoraRolesClase>> equipoClase(String claseId);

  /// Deja los roles de una tutora en una clase (la lista vacía la deja sin roles)
  Future<Resultado<void>> guardarRoles({
    required String claseId,
    required String tutoraId,
    required Set<String> rolIds,
  });

  Future<Resultado<void>> marcarCumplido(String tareaId, bool completada);

  /// Mis roles en cada clase de un curso
  Future<List<MiTareaCurso>> misRoles(String instanciaId);
}

class MapeoRoles {
  static RolTarea rol(Map<String, dynamic> f) => RolTarea(
    id: f['id'] as String,
    codigo: f['codigo'] as String? ?? '',
    nombre: f['nombre'] as String? ?? '',
    descripcion: f['descripcion'] as String? ?? '',
    colorHex: f['color_hex'] as String? ?? '#8B3295',
    esRequerido: f['es_requerido'] == true,
    activo: f['activo'] != false,
  );

  static Map<String, Object?> filaRol(RolTarea r) => {
    'nombre': r.nombre.trim(),
    'descripcion': r.descripcion.trim(),
    'color_hex': r.colorHex,
    'es_requerido': r.esRequerido,
    'activo': r.activo,
  };

  static TareaClase tarea(Map<String, dynamic> f) => TareaClase(
    id: (f['id'] ?? f['tarea_id']) as String,
    rolId: f['rol_id'] as String,
    completada: f['completada'] == true,
  );

  /// Filas de `roles_clase`
  static TutoraRolesClase equipo(Map<String, dynamic> f) => TutoraRolesClase(
    tutoraId: f['tutor_id'] as String,
    nombre: '${f['nombres'] ?? ''} ${f['apellidos'] ?? ''}'.trim(),
    esEquipoGestion: f['es_equipo_gestion'] == true,
    tareas: [for (final t in (f['tareas'] as List<dynamic>? ?? const [])) tarea(t as Map<String, dynamic>)],
  );

  /// Filas de `mis_roles_curso`
  static MiTareaCurso miTarea(Map<String, dynamic> f) => MiTareaCurso(
    claseId: f['clase_id'] as String,
    numeroSesion: (f['numero_sesion'] as num).toInt(),
    tarea: tarea(f),
  );
}

const _mensajeError = 'No pudimos guardar los roles. Inténtalo nuevamente.';

String mensajeRoles(PostgrestException e) => switch (e.code) {
  '23505' => 'Ya existe un rol con ese nombre.',
  '22023' || '42501' || 'P0001' => e.message,
  _ => _mensajeError,
};

class SupabaseRolesRepository implements RolesRepository {
  final SupabaseClient _client;

  SupabaseRolesRepository(this._client);

  @override
  Future<List<RolTarea>> roles({bool incluirInactivos = false}) async {
    var consulta = _client.from('rol_tarea_tutor').select();
    if (!incluirInactivos) consulta = consulta.eq('activo', true);
    final filas = await consulta.order('es_requerido', ascending: false).order('nombre');
    return [for (final f in filas) MapeoRoles.rol(f)];
  }

  @override
  Future<Resultado<RolTarea>> crearRol(RolTarea rol) async {
    try {
      final fila = await _client.from('rol_tarea_tutor').insert(MapeoRoles.filaRol(rol)).select().single();
      return Resultado.ok(MapeoRoles.rol(fila));
    } on PostgrestException catch (e) {
      return Resultado.error(mensajeRoles(e));
    }
  }

  @override
  Future<Resultado<void>> actualizarRol(RolTarea rol) async {
    try {
      await _client.from('rol_tarea_tutor').update(MapeoRoles.filaRol(rol)).eq('id', rol.id);
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      return Resultado.error(mensajeRoles(e));
    }
  }

  @override
  Future<Resultado<void>> eliminarRol(String id) async {
    try {
      await _client.from('rol_tarea_tutor').delete().eq('id', id);
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      // Con asignaciones (clave foránea) no se borra: se desactiva y queda en el historial
      if (e.code == '23503') {
        try {
          await _client.from('rol_tarea_tutor').update({'activo': false}).eq('id', id);
          return const Resultado.ok();
        } on PostgrestException catch (e2) {
          return Resultado.error(mensajeRoles(e2));
        }
      }
      return Resultado.error(mensajeRoles(e));
    }
  }

  @override
  Future<int> usosRol(String id) async {
    final respuesta = await _client.from('tareas_semanales_tutores').select('id').eq('rol_tarea_tutor_id', id).count();
    return respuesta.count;
  }

  @override
  Future<List<TutoraRolesClase>> equipoClase(String claseId) async {
    final filas = await _client.rpc('roles_clase', params: {'p_clase_id': claseId}) as List<dynamic>;
    return [for (final f in filas.cast<Map<String, dynamic>>()) MapeoRoles.equipo(f)];
  }

  @override
  Future<Resultado<void>> guardarRoles({
    required String claseId,
    required String tutoraId,
    required Set<String> rolIds,
  }) => _rpc('guardar_roles_tutora', {'p_clase_id': claseId, 'p_tutor_id': tutoraId, 'p_roles': rolIds.toList()});

  @override
  Future<Resultado<void>> marcarCumplido(String tareaId, bool completada) =>
      _rpc('marcar_rol_cumplido', {'p_tarea_id': tareaId, 'p_completada': completada});

  @override
  Future<List<MiTareaCurso>> misRoles(String instanciaId) async {
    final filas = await _client.rpc('mis_roles_curso', params: {'p_instancia_id': instanciaId}) as List<dynamic>;
    return [for (final f in filas.cast<Map<String, dynamic>>()) MapeoRoles.miTarea(f)];
  }

  Future<Resultado<void>> _rpc(String funcion, Map<String, Object?> params) async {
    try {
      await _client.rpc(funcion, params: params);
      return const Resultado.ok();
    } on PostgrestException catch (e) {
      return Resultado.error(mensajeRoles(e));
    }
  }
}
