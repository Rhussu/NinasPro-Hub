import '../models/hub_models.dart';

/// Interfaz abstracta para la gestión y consulta de datos en NiñasPro Hub.
///
/// Durante la fase de mockup, se utiliza [MockHubRepository] con datos sintéticos coherentes en memoria.
/// Cuando se conecte a Supabase, la implementación [SupabaseHubRepository] implementará esta misma interfaz.
abstract class HubRepository {
  /// Obtiene el catálogo de sedes territoriales y su capacidad operativa (US-01)
  Future<List<Sede>> getSedes();

  /// Obtiene los cursos formativos, opcionalmente filtrados por sede
  Future<List<Curso>> getCursos({String? sedeId});

  /// Obtiene la nómina de alumnas, opcionalmente filtrada por curso o sede (US-07, US-09)
  Future<List<Alumna>> getAlumnas({String? cursoId, String? sedeId});

  /// Obtiene una alumna por su ID
  Future<Alumna?> getAlumnaById(String alumnaId);

  /// Registra el retiro formal de una alumna preservando su historial (US-09)
  Future<bool> registrarRetiroAlumna({
    required String alumnaId,
    required String motivo,
  });

  /// Obtiene las sesiones planificadas de un curso y sus recursos educativos vinculados (US-26)
  Future<List<SesionClase>> getSesiones({required String cursoId});

  /// Obtiene el pase de lista de asistencia para una sesión específica (US-13)
  Future<List<RegistroAsistencia>> getAsistenciaSesion({
    required String sesionId,
  });

  /// Guarda en lote la asistencia de la clase (US-13, US-15)
  Future<bool> guardarAsistencia({
    required String sesionId,
    required List<RegistroAsistencia> registros,
  });

  /// Obtiene los registros de participación y ejercicios de una sesión (US-28)
  Future<List<ParticipacionClase>> getParticipacionSesion({
    required String sesionId,
  });

  /// Guarda los ejercicios y participación activa de alumnas presentes (US-28)
  Future<bool> guardarParticipacion({
    required String sesionId,
    required List<ParticipacionClase> participaciones,
  });

  /// Registra el podio Kahoot de la clase (1°, 2° y 3° lugar) (US-29)
  Future<bool> guardarPodioKahoot({
    required String sesionId,
    required String primerLugarAlumnaId,
    required String segundoLugarAlumnaId,
    required String tercerLugarAlumnaId,
  });

  /// Obtiene la lista de alertas activas de deserción escolar (US-39, US-40)
  Future<List<AlertaDesercion>> getAlertasDesercion({String? sedeId});

  /// Registra el contacto preventivo con apoderada y actualiza estado de la alerta (US-40)
  Future<bool> contactarAlerta({
    required String alertaId,
    required String observacionesContacto,
  });

  /// Obtiene las solicitudes de justificativo de inasistencia (US-37)
  Future<List<Justificativo>> getJustificativos();

  /// Envía un justificativo de inasistencia especificando clase y fecha (US-35)
  Future<bool> enviarJustificativo({
    required String alumnaId,
    required String sesionId,
    required String motivoTipificado,
    required String detalle,
  });

  /// Resuelve (aprueba o rechaza) un justificativo por el Equipo de Gestión (US-37)
  Future<bool> resolverJustificativo({
    required String justificativoId,
    required bool aprobado,
    String? observaciones,
  });

  /// Obtiene la información agregada para el portal móvil de la alumna (US-25, US-26, US-29)
  Future<PortalAlumnaData> getPortalAlumnaData({required String alumnaId});

  /// Obtiene la nómina de tutoras voluntarias de la sede (US-33)
  Future<List<Tutora>> getTutoras();

  /// Actualiza la asistencia de una tutora en la clase actual (US-33)
  Future<bool> actualizarAsistenciaTutora({
    required String tutoraId,
    required bool presente,
  });

  /// Obtiene el catálogo de roles dinámicos de tutoras (US-43)
  Future<List<RolTutorConfig>> getRolesTutora();

  /// Crea un nuevo rol dinámico en el catálogo (US-43)
  Future<bool> crearRolTutora(RolTutorConfig rol);

  /// Actualiza un rol dinámico existente (US-43)
  Future<bool> actualizarRolTutora(RolTutorConfig rol);

  /// Obtiene las asignaciones semanales de roles de tutoras para una semana específica (US-43)
  Future<List<AsignacionSemanalTutora>> getAsignacionesSemanales({
    required int semanaNumero,
  });

  /// Asigna un rol específico a una tutora para una semana (US-43)
  Future<bool> asignarRolSemanal({
    required String tutoraId,
    required int semanaNumero,
    required String rolCodigo,
  });
}
