import 'package:ninas_pro_hub/repositories/justificativos_repository.dart' show Resultado;
import 'package:ninas_pro_hub/repositories/roles_repository.dart';

/// Catálogo de ejemplo: los roles del seed (los cuatro primeros, obligatorios)
const rolesDemo = [
  RolTarea(
    id: 'rol-recepcion',
    codigo: 'recepcion_alumnas',
    nombre: 'Recepción de Alumnas',
    colorHex: '#FF78CF',
    esRequerido: true,
  ),
  RolTarea(
    id: 'rol-presentar',
    codigo: 'presentar_clase',
    nombre: 'Presentar la Clase',
    descripcion: 'Expone los contenidos del día',
    colorHex: '#8B3295',
    esRequerido: true,
  ),
  RolTarea(
    id: 'rol-foto',
    codigo: 'foto_asistencia',
    nombre: 'Foto y Asistencia',
    colorHex: '#1D5CA5',
    esRequerido: true,
  ),
  RolTarea(id: 'rol-kahoot', codigo: 'preparar_kahoot', nombre: 'Preparar el Kahoot', colorHex: '#E28F12'),
  RolTarea(id: 'rol-antiguo', codigo: 'tutora_lider', nombre: 'Tutora líder', activo: false),
];

/// [RolesRepository] en memoria con las reglas de la migración 19: Gestión
/// asigna varios roles por tutora y clase, la tutora marca los suyos y Gestión
/// los de cualquiera; un rol con asignaciones se desactiva en vez de borrarse.
class FakeRolesRepository implements RolesRepository {
  /// Cuenta que usa la app
  String perfilId;

  /// Cuentas del Equipo de Gestión de la sede
  final Set<String> gestion;

  final List<RolTarea> catalogo;

  /// Equipo del curso: id de la tutora -> (nombre, es de Gestión)
  final Map<String, (String, bool)> equipo;

  /// Roles por clase y tutora
  final Map<String, Map<String, List<TareaClase>>> tareas = {};

  /// Número de sesión de cada clase (para misRoles)
  final Map<String, int> sesiones;

  /// Si no es null, la base rechaza las escrituras con este mensaje
  String? rechazo;

  var _secuencia = 0;

  FakeRolesRepository({
    this.perfilId = 'perfil-daniela',
    this.gestion = const {'perfil-camila'},
    List<RolTarea>? catalogo,
    Map<String, (String, bool)>? equipo,
    Map<String, int>? sesiones,
  }) : catalogo = catalogo ?? List.of(rolesDemo),
       equipo =
           equipo ??
           const {
             'perfil-camila': ('Camila Sepúlveda Rivas', true),
             'perfil-daniela': ('Daniela Valenzuela Castro', false),
             'perfil-javiera': ('Javiera Muñoz Pizarro', false),
           },
       sesiones = sesiones ?? {for (var n = 1; n <= 10; n++) 'clase-$n': n};

  /// Asigna roles directamente (datos de partida de una prueba)
  void asignar(String claseId, String tutoraId, List<String> rolIds, {Set<String> cumplidos = const {}}) {
    (tareas[claseId] ??= {})[tutoraId] = [
      for (final r in rolIds) TareaClase(id: 'tarea-${++_secuencia}', rolId: r, completada: cumplidos.contains(r)),
    ];
  }

  List<TareaClase> rolesDe(String claseId, String tutoraId) => tareas[claseId]?[tutoraId] ?? const [];

  @override
  Future<List<RolTarea>> roles({bool incluirInactivos = false}) async =>
      catalogo.where((r) => incluirInactivos || r.activo).toList();

  @override
  Future<Resultado<RolTarea>> crearRol(RolTarea rol) async {
    if (rechazo != null) return Resultado.error(rechazo);
    if (catalogo.any((r) => r.nombre.toLowerCase() == rol.nombre.toLowerCase())) {
      return const Resultado.error('Ya existe un rol con ese nombre.');
    }
    final nuevo = RolTarea(
      id: 'rol-${++_secuencia}',
      codigo: 'rol_$_secuencia',
      nombre: rol.nombre,
      descripcion: rol.descripcion,
      colorHex: rol.colorHex,
      esRequerido: rol.esRequerido,
    );
    catalogo.add(nuevo);
    return Resultado.ok(nuevo);
  }

  @override
  Future<Resultado<void>> actualizarRol(RolTarea rol) async {
    if (rechazo != null) return Resultado.error(rechazo);
    final i = catalogo.indexWhere((r) => r.id == rol.id);
    catalogo[i] = rol;
    return const Resultado.ok();
  }

  @override
  Future<int> usosRol(String id) async =>
      tareas.values.expand((m) => m.values).expand((l) => l).where((t) => t.rolId == id).length;

  @override
  Future<Resultado<void>> eliminarRol(String id) async {
    if (rechazo != null) return Resultado.error(rechazo);
    if (await usosRol(id) > 0) {
      final i = catalogo.indexWhere((r) => r.id == id);
      catalogo[i] = catalogo[i].copyWith(activo: false);
    } else {
      catalogo.removeWhere((r) => r.id == id);
    }
    return const Resultado.ok();
  }

  @override
  Future<List<TutoraRolesClase>> equipoClase(String claseId) async => [
    for (final e in equipo.entries)
      TutoraRolesClase(
        tutoraId: e.key,
        nombre: e.value.$1,
        esEquipoGestion: e.value.$2,
        tareas: rolesDe(claseId, e.key),
      ),
  ];

  @override
  Future<Resultado<void>> guardarRoles({
    required String claseId,
    required String tutoraId,
    required Set<String> rolIds,
  }) async {
    if (rechazo != null) return Resultado.error(rechazo);
    if (!gestion.contains(perfilId)) {
      return const Resultado.error('Solo el Equipo de Gestión de la sede asigna los roles de la clase.');
    }
    final actuales = {for (final t in rolesDe(claseId, tutoraId)) t.rolId: t};
    (tareas[claseId] ??= {})[tutoraId] = [
      for (final r in rolIds) actuales[r] ?? TareaClase(id: 'tarea-${++_secuencia}', rolId: r),
    ];
    return const Resultado.ok();
  }

  @override
  Future<Resultado<void>> marcarCumplido(String tareaId, bool completada) async {
    if (rechazo != null) return Resultado.error(rechazo);
    for (final porTutora in tareas.values) {
      for (final e in porTutora.entries) {
        final i = e.value.indexWhere((t) => t.id == tareaId);
        if (i < 0) continue;
        if (e.key != perfilId && !gestion.contains(perfilId)) {
          return const Resultado.error('Solo la tutora o el Equipo de Gestión de la sede marcan este rol.');
        }
        e.value[i] = e.value[i].copyWith(completada: completada);
        return const Resultado.ok();
      }
    }
    return const Resultado.error('El rol ya no está asignado.');
  }

  @override
  Future<List<MiTareaCurso>> misRoles(String instanciaId) async => [
    for (final c in tareas.entries)
      for (final t in c.value[perfilId] ?? const <TareaClase>[])
        MiTareaCurso(claseId: c.key, numeroSesion: sesiones[c.key] ?? 0, tarea: t),
  ];
}
