import 'package:flutter/foundation.dart';
import '../models/hub_models.dart';

/// Interfaz abstracta para la gestión y consulta de datos en NiñasPro Hub.
///
/// Durante la fase de mockup, se utiliza [MockHubRepository] con datos sintéticos coherentes en memoria.
/// Cuando se conecte a Supabase, la implementación [SupabaseHubRepository] implementará esta misma interfaz.
abstract class HubRepository {
  /// Estado de la conexión con la nube: todo subido, subiendo pendientes o sin conexión
  ValueListenable<EstadoSincronizacion> get estadoSincronizacion;

  /// Cambios guardados solo en este dispositivo, que se subirán cuando vuelva la conexión
  ValueListenable<int> get cambiosPendientes;

  /// Descarga los datos actualizados de la nube (deslizar hacia abajo para recargar)
  Future<void> recargar();

  /// Obtiene el catálogo de sedes territoriales (US-01)
  Future<List<Sede>> getSedes();

  /// Crea una sede activa. Falla si ya existe una sede con el mismo nombre (US-01)
  Future<bool> crearSede({
    required String nombre,
    required String universidad,
    required String region,
    required String modalidad,
    required String coordinadoraNombre,
  });

  /// Actualiza una sede. Falla si el nuevo nombre ya lo usa otra sede (US-01)
  Future<bool> actualizarSede(Sede sede);

  /// Indicadores agregados por sede para el dashboard de la Directiva
  Future<List<ResumenSede>> getResumenSedes();

  /// Asistencia de cada sede en cada clase realizada, ordenada por fecha
  Future<List<SerieAsistencia>> getAsistenciaPorClase();

  /// Obtiene el catálogo general de cursos (US-01)
  Future<List<CursoCatalogo>> getCatalogoCursos();

  /// Agrega un curso al catálogo. Falla si el código se repite o el nombre está vacío (US-01)
  Future<bool> crearCursoCatalogo({
    required String codigo,
    required String nombre,
    String descripcion = '',
  });

  /// Actualiza un curso del catálogo con las mismas validaciones de la creación (US-01)
  Future<bool> actualizarCursoCatalogo(CursoCatalogo curso);

  /// Obtiene las instancias de curso (curso + sede + período), opcionalmente filtradas por sede
  Future<List<Curso>> getCursos({String? sedeId});

  /// true si ya existe una instancia del mismo curso, sede y período (US-02)
  Future<bool> existeInstancia({
    required String catalogoId,
    required String sedeId,
    required int anio,
    required int semestre,
  });

  /// Crea una instancia de curso y genera sus sesiones semanales 'programada' (US-02).
  /// Devuelve null si las fechas no son válidas (término anterior o igual al inicio).
  Future<Curso?> crearInstanciaCurso({
    required String catalogoId,
    required String sedeId,
    required DateTime inicio,
    required DateTime termino,
    required int diaSemana,
  });

  /// Obtiene la nómina de alumnas, opcionalmente filtrada por curso o sede (US-07, US-09)
  Future<List<Alumna>> getAlumnas({String? cursoId, String? sedeId});

  /// Obtiene una alumna por su ID
  Future<Alumna?> getAlumnaById(String alumnaId);

  /// Registra el retiro formal de una alumna preservando su historial (US-09)
  Future<bool> registrarRetiroAlumna({
    required String alumnaId,
    required String motivo,
    DateTime? fecha,
  });

  /// Inscribe una alumna en una instancia de curso. Si su RUT ya existe se reutiliza
  /// la misma ficha y se agrega la inscripción a su historial (US-09).
  /// Falla si el RUT no es válido o ya está inscrita en ese curso.
  Future<bool> inscribirAlumna({
    required String cursoId,
    required String nombre,
    required String rut,
    required String apoderadoNombre,
    required String apoderadoTelefono,
    required String apoderadoCorreo,
  });

  /// Procesa la planilla simulada de nómina de alumnas sin guardar nada (US-07, US-08).
  /// [columnasValidas] en false simula un archivo que no respeta la plantilla.
  Future<ResultadoImportacion> previsualizarImportacionAlumnas({
    required String cursoId,
    bool columnasValidas = true,
  });

  /// Inscribe las filas nuevas y existentes de la planilla como 'preinscrita' (US-07).
  /// Devuelve cuántas alumnas se inscribieron.
  Future<int> confirmarImportacionAlumnas({required String cursoId});

  /// Registra las autorizaciones del apoderado en la ficha de la alumna (US-10)
  Future<bool> actualizarAutorizaciones({
    required String alumnaId,
    required AutorizacionesAlumna autorizaciones,
  });

  /// Revoca uno o más canales de imagen desde [fecha]. Las clases desde esa fecha
  /// dejan de considerar a la alumna apta para fotos (US-12)
  Future<bool> revocarAutorizacionImagen({
    required String alumnaId,
    required List<CanalImagen> canales,
    required DateTime fecha,
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

  /// Obtiene las alertas de deserción escolar, opcionalmente de una sede (US-39, US-40)
  Future<List<AlertaDesercion>> getAlertasDesercion({String? sedeId});

  /// Registra el contacto preventivo con apoderada y actualiza estado de la alerta (US-40)
  Future<bool> contactarAlerta({
    required String alertaId,
    required String observacionesContacto,
  });

  /// Obtiene las solicitudes de justificativo de inasistencia, opcionalmente de una sede (US-37)
  Future<List<Justificativo>> getJustificativos({String? sedeId});

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

  /// Registra manualmente un justificativo desde Gestión, quedando aprobado de inmediato (US-37)
  Future<bool> registrarJustificativoManual({
    required String alumnaId,
    required String sesionId,
    required String detalle,
  });

  /// Obtiene la información agregada para el portal móvil de la alumna (US-25, US-26, US-29)
  Future<PortalAlumnaData> getPortalAlumnaData({required String alumnaId});

  /// Obtiene la nómina de tutoras voluntarias, opcionalmente de una sede (US-32, US-33)
  Future<List<Tutora>> getTutoras({String? sedeId});

  /// Crea la ficha de una voluntaria activa. Falla si el RUT no es válido o ya existe (US-30)
  Future<bool> crearVoluntaria({
    required String nombre,
    required String rut,
    required String correo,
    required String institucion,
    required String sedeId,
    required bool esEquipoGestion,
  });

  /// Actualiza la ficha de una voluntaria (adhesión, salida, datos).
  /// Falla si la fecha de salida es anterior a la de ingreso (US-31, US-32)
  Future<bool> actualizarVoluntaria(Tutora voluntaria);

  /// Asigna una voluntaria a una instancia de curso.
  /// Falla si no tiene la declaración de adhesión firmada o está retirada (US-31)
  Future<bool> asignarVoluntariaACurso({
    required String tutoraId,
    required String cursoId,
  });

  /// Procesa la planilla simulada de voluntariado sin guardar nada (US-30)
  Future<ResultadoImportacion> previsualizarImportacionVoluntariado({
    bool columnasValidas = true,
  });

  /// Crea las fichas nuevas de la planilla en la sede indicada. Devuelve cuántas se crearon (US-30)
  Future<int> confirmarImportacionVoluntariado({required String sedeId});

  /// Actualiza la asistencia de una tutora en la clase actual (US-33)
  Future<bool> actualizarAsistenciaTutora({
    required String tutoraId,
    required bool presente,
  });

  /// Obtiene el pase de lista de tutoras de una clase (US-33)
  Future<List<RegistroAsistenciaTutora>> getAsistenciaTutoras({required String sesionId});

  /// Guarda el pase de lista de tutoras de una clase (US-33)
  Future<bool> guardarAsistenciaTutoras({
    required String sesionId,
    required List<RegistroAsistenciaTutora> registros,
  });

  /// Obtiene el catálogo de roles dinámicos de tutoras (US-43)
  Future<List<RolTutorConfig>> getRolesTutora();

  /// Crea un nuevo rol dinámico en el catálogo (US-43)
  Future<bool> crearRolTutora(RolTutorConfig rol);

  /// Actualiza un rol dinámico existente (US-43)
  Future<bool> actualizarRolTutora(RolTutorConfig rol);

  /// Elimina un rol del catálogo junto con sus asignaciones semanales (US-43)
  Future<bool> eliminarRolTutora(String codigo);

  /// Cuántas asignaciones semanales usan un rol (para advertir antes de eliminarlo)
  Future<int> contarAsignacionesRol(String codigo);

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

  /// Arma el reporte filtrado sin registrar la descarga (vista previa) (US-21, US-22)
  Future<ResultadoExportacion> previsualizarExportacion(FiltroExportacion filtro);

  /// Genera el reporte y registra la descarga en la auditoría (US-21, US-22)
  Future<ResultadoExportacion> exportarDatos(FiltroExportacion filtro);

  /// Consulta la bitácora de auditoría, del evento más reciente al más antiguo (US-24)
  Future<List<EventoAuditoria>> getEventosAuditoria({
    DateTime? desde,
    DateTime? hasta,
    String? usuaria,
    TipoAccionAuditoria? tipo,
    String? rutAlumna,
  });
}
