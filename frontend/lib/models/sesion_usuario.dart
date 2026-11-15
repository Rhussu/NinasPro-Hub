import 'package:flutter/foundation.dart';

/// Rol de la cuenta, tal como lo define el enum `rol_usuario` del esquema.
enum RolUsuario {
  directorio('directorio', 'Directiva', '🏛️'),
  equipoGestion('equipo_gestion', 'Gestión', '📋'),
  tutora('tutora', 'Tutora', '👩‍🏫'),
  alumna('alumna', 'Alumna', '👧'),
  comunicacion('comunicacion', 'Comunicación', '📣');

  final String valorDb;
  final String etiqueta;
  final String emoji;

  const RolUsuario(this.valorDb, this.etiqueta, this.emoji);

  static RolUsuario desdeDb(String valor) =>
      RolUsuario.values.firstWhere((r) => r.valorDb == valor, orElse: () => throw ArgumentError('Rol desconocido: $valor'));
}

/// Sede asignada a la cuenta (tabla `usuarios_sedes`).
@immutable
class SedeAsignada {
  final String id;
  final String nombre;
  final bool esLider;

  const SedeAsignada({required this.id, required this.nombre, this.esLider = false});
}

/// Usuaria autenticada con su perfil, rol y alcance territorial.
@immutable
class SesionUsuario {
  final String perfilId;
  final RolUsuario rol;
  final String nombres;
  final String apellidos;
  final String correo;
  final List<SedeAsignada> sedes;

  /// Ficha de alumna vinculada (solo rol alumna)
  final String? alumnaId;

  const SesionUsuario({
    required this.perfilId,
    required this.rol,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.sedes = const [],
    this.alumnaId,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  /// Sede principal (la primera asignada); null para la Directiva nacional
  SedeAsignada? get sedePrincipal => sedes.isEmpty ? null : sedes.first;

  /// La Directiva usa la consola de escritorio; el resto de los roles, la vista móvil
  bool get usaVistaEscritorio => rol == RolUsuario.directorio;
}
