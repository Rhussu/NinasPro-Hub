import '../models/hub_models.dart';

/// Interfaz abstracta para la gestión y consulta de datos en NiñasPro Hub.
///
/// Durante la fase de mockup, se utiliza [MockHubRepository] con datos sintéticos en memoria.
/// Cuando se apruebe la versión oficial, se conectará [SupabaseHubRepository] implementando
/// esta misma interfaz sin necesidad de alterar los componentes de la interfaz de usuario.
abstract class HubRepository {
  /// Obtiene el catálogo de sedes maestras
  Future<List<Sede>> getSedes();

  /// Obtiene los cursos formativos, opcionalmente filtrados por sede
  Future<List<Curso>> getCursos({String? sedeId});

  /// Obtiene la nómina de alumnas, opcionalmente filtrada por curso o sede
  Future<List<Alumna>> getAlumnas({String? cursoId, String? sedeId});

  /// Obtiene una alumna por su ID
  Future<Alumna?> getAlumnaById(String alumnaId);

  /// Registra el retiro formal de una alumna preservando su historial (US-09)
  Future<bool> registrarRetiroAlumna({required String alumnaId, required String motivo});

  /// Obtiene las sesiones planificadas de un curso
  Future<List<SesionClase>> getSesiones({required String cursoId});

  /// Obtiene el pase de lista de asistencia para una sesión específica (US-13)
  Future<List<RegistroAsistencia>> getAsistenciaSesion({required String sesionId});

  /// Guarda en lote la asistencia de la clase (US-13, US-15)
  Future<bool> guardarAsistencia({
    required String sesionId,
    required List<RegistroAsistencia> registros,
  });

  /// Obtiene los registros de participación y ejercicios de una sesión (US-28)
  Future<List<ParticipacionClase>> getParticipacionSesion({required String sesionId});

  /// Guarda los ejercicios y participación activa (US-28)
  Future<bool> guardarParticipacion({
    required String sesionId,
    required List<ParticipacionClase> participaciones,
  });

  /// Obtiene la lista de alertas activas de deserción escolar (US-39, US-40)
  Future<List<AlertaDesercion>> getAlertasDesercion({String? sedeId});

  /// Registra el contacto de acompañamiento con el apoderado y resuelve la alerta (US-40)
  Future<bool> atenderAlertaDesercion({
    required String alertaId,
    required String observacion,
  });

  /// Obtiene los justificativos de inasistencia presentados (US-37)
  Future<List<Justificativo>> getJustificativos({String? sedeId});

  /// Resuelve (aprueba o rechaza) un justificativo presentado (US-37)
  Future<bool> resolverJustificativo({
    required String justificativoId,
    required String nuevoEstado,
    String? respuestaGestion,
  });

  /// Obtiene los datos consolidados para el portal de la estudiante (US-25)
  Future<PortalAlumnaData> getPortalAlumnaData({required String alumnaId});

  /// Envía un nuevo justificativo de inasistencia desde el portal de la alumna (US-35)
  Future<bool> enviarJustificativo({
    required String alumnaId,
    required String sesionId,
    required String motivoTipificado,
    required String detalle,
  });

  /// Obtiene el listado de voluntarias / tutoras de la red (US-30, US-32)
  Future<List<Tutora>> getTutoras({String? sedeId});

  /// Registra el pase de asistencia docente para una sesión (US-33)
  Future<bool> actualizarAsistenciaTutora({
    required String tutoraId,
    required bool presente,
  });
}
