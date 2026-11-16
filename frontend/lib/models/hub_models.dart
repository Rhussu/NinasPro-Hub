import 'package:flutter/foundation.dart';
import '../config/ninaspro_theme.dart';

/// Estado de la conexión con la nube (Supabase).
/// Con conexión, cada cambio se sube al instante; sin conexión, queda pendiente en el dispositivo.
enum EstadoSincronizacion {
  /// Hay conexión y todos los cambios ya están en la nube
  sincronizado,

  /// Volvió la conexión y se están subiendo los cambios pendientes
  sincronizando,

  /// Sin conexión: los cambios se guardan en el dispositivo hasta que vuelva internet
  sinConexion,
}

/// Estado de la conexión y de los cambios guardados solo en el dispositivo (nubecita del AppBar)
abstract class FuenteSincronizacion {
  /// Todo subido, subiendo pendientes o sin conexión
  ValueListenable<EstadoSincronizacion> get estadoSincronizacion;

  /// Cambios guardados solo en este dispositivo, que se subirán cuando vuelva la conexión
  ValueListenable<int> get cambiosPendientes;

  /// Motivo del último cambio guardado sin conexión que la nube rechazó al subirlo
  ValueListenable<String?> get ultimoRechazo;
}

/// Fuente sin cola sin conexión: siempre al día (roles que no pasan lista sin conexión)
class SinCambiosPendientes implements FuenteSincronizacion {
  const SinCambiosPendientes();

  static final _estado = ValueNotifier(EstadoSincronizacion.sincronizado);
  static final _pendientes = ValueNotifier(0);
  static final _rechazo = ValueNotifier<String?>(null);

  @override
  ValueListenable<EstadoSincronizacion> get estadoSincronizacion => _estado;

  @override
  ValueListenable<int> get cambiosPendientes => _pendientes;

  @override
  ValueListenable<String?> get ultimoRechazo => _rechazo;
}

/// Recurso educativo de aula con enlace HTTPS seguro (US-26)
@immutable
class RecursoEducativo {
  final String id;
  final String titulo;
  final String tipo; // 'slides' | 'codigo' | 'guia' | 'video'
  final String url;
  final bool esSeguraHttps;

  const RecursoEducativo({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.url,
    this.esSeguraHttps = true,
  });
}

/// Registro de asistencia de una tutora a una clase (US-33).
/// Solo usa Presente, Ausente o Pendiente: las tutoras no presentan justificativos.
@immutable
class RegistroAsistenciaTutora {
  final String sesionId;
  final String tutoraId;
  final String tutoraNombre;
  final bool esEquipoGestion;
  final EstadoAsistencia estado;

  /// Quién hizo la última edición y cuándo (US-33 escenario 3)
  final String? editadoPor;
  final DateTime? editadoEn;

  const RegistroAsistenciaTutora({
    required this.sesionId,
    required this.tutoraId,
    required this.tutoraNombre,
    required this.esEquipoGestion,
    required this.estado,
    this.editadoPor,
    this.editadoEn,
  });

  RegistroAsistenciaTutora copyWith({EstadoAsistencia? estado}) {
    return RegistroAsistenciaTutora(
      sesionId: sesionId,
      tutoraId: tutoraId,
      tutoraNombre: tutoraNombre,
      esEquipoGestion: esEquipoGestion,
      estado: estado ?? this.estado,
      editadoPor: editadoPor,
      editadoEn: editadoEn,
    );
  }
}

/// Sede territorial o modalidad de NiñasPro (US-01)
@immutable
class Sede {
  final String id;
  final String nombre;
  final String universidad;
  final String region;
  final String modalidad; // 'Presencial' | 'Online'
  final String coordinadoraNombre;
  final String estado; // 'activa' | 'inactiva'
  // Lo que impide eliminarla: '2 instancias de curso', '3 personas asignadas'… (US-01)
  final List<String> usos;

  const Sede({
    required this.id,
    required this.nombre,
    required this.universidad,
    required this.region,
    required this.modalidad,
    required this.coordinadoraNombre,
    this.estado = 'activa',
    this.usos = const [],
  });

  Sede copyWith({
    String? nombre,
    String? universidad,
    String? region,
    String? modalidad,
    String? coordinadoraNombre,
    String? estado,
  }) {
    return Sede(
      id: id,
      nombre: nombre ?? this.nombre,
      universidad: universidad ?? this.universidad,
      region: region ?? this.region,
      modalidad: modalidad ?? this.modalidad,
      coordinadoraNombre: coordinadoraNombre ?? this.coordinadoraNombre,
      estado: estado ?? this.estado,
      usos: usos,
    );
  }
}

/// Curso del catálogo general de NiñasPro, independiente de sede y período (US-01)
@immutable
class CursoCatalogo {
  final String id;
  final String codigo;
  final String nombre;
  final String descripcion;
  // Lo que impide eliminarlo: '2 instancias de curso' (US-01)
  final List<String> usos;

  const CursoCatalogo({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion = '',
    this.usos = const [],
  });

  CursoCatalogo copyWith({String? codigo, String? nombre, String? descripcion}) {
    return CursoCatalogo(
      id: id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      usos: usos,
    );
  }
}

/// Instancia de un curso del catálogo dictada en una sede y período (US-01, US-02)
@immutable
class Curso {
  final String id;
  final String codigo;
  final String nombre;
  final String sedeId;
  final String sedeNombre;
  final int anio;
  final int semestre;
  final int totalSesiones;
  // Enlaces únicos para todo el curso (US-26)
  final String? classroomUrl;
  final String? juezVirtualUrl;
  // Origen en el catálogo y calendario de la instancia (US-02)
  final String? catalogoId;
  final DateTime? fechaInicio;
  final DateTime? fechaTermino;
  final int diaSemana; // DateTime.monday..DateTime.sunday
  // Sección paralela del mismo curso, sede y período: 1 = A, 2 = B… (US-02)
  final int seccion;
  final String? horaInicio; // 'HH:mm'
  final String? horaFin;

  const Curso({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.anio,
    required this.semestre,
    required this.totalSesiones,
    this.classroomUrl,
    this.juezVirtualUrl,
    this.catalogoId,
    this.fechaInicio,
    this.fechaTermino,
    this.diaSemana = DateTime.saturday,
    this.seccion = 1,
    this.horaInicio,
    this.horaFin,
  });

  /// 'A', 'B', … según la sección
  String get seccionLetra => String.fromCharCode(64 + seccion);

  Curso copyWith({String? sedeNombre, String? nombre}) {
    return Curso(
      id: id,
      codigo: codigo,
      nombre: nombre ?? this.nombre,
      sedeId: sedeId,
      sedeNombre: sedeNombre ?? this.sedeNombre,
      anio: anio,
      semestre: semestre,
      totalSesiones: totalSesiones,
      classroomUrl: classroomUrl,
      juezVirtualUrl: juezVirtualUrl,
      catalogoId: catalogoId,
      fechaInicio: fechaInicio,
      fechaTermino: fechaTermino,
      diaSemana: diaSemana,
      seccion: seccion,
      horaInicio: horaInicio,
      horaFin: horaFin,
    );
  }
}

/// Canales de difusión de imagen que el apoderado autoriza por separado (US-10)
enum CanalImagen {
  redesSociales,
  memoriaAnual,
  prensa,
  webInstitucional,
  patrocinadores;

  String get label => switch (this) {
        CanalImagen.redesSociales => 'Redes sociales',
        CanalImagen.memoriaAnual => 'Memoria anual',
        CanalImagen.prensa => 'Prensa',
        CanalImagen.webInstitucional => 'Web institucional',
        CanalImagen.patrocinadores => 'Patrocinadores',
      };
}

/// Estado de la autorización de un canal de imagen (US-10, US-12)
enum EstadoAutorizacion {
  otorgada,
  noAutorizada,
  revocada;

  String get label => switch (this) {
        EstadoAutorizacion.otorgada => 'Autorizada',
        EstadoAutorizacion.noAutorizada => 'No autorizada',
        EstadoAutorizacion.revocada => 'Revocada',
      };
}

/// Revocación formal de un canal de imagen solicitada por el apoderado (US-12)
@immutable
class RevocacionImagen {
  final DateTime fecha;
  final String motivo;

  const RevocacionImagen({required this.fecha, required this.motivo});
}

/// Sesión de clase de un curso (sábado de clases) (US-13, US-26)
@immutable
class SesionClase {
  final String id;
  final String cursoId;
  final int numeroSesion;
  final DateTime fecha;
  final String tema;
  final String estado; // 'programada' | 'realizada' | 'suspendida'
  final List<RecursoEducativo> recursos;
  // Calendario de la sede (US-03)
  final String? motivoSuspension;
  final bool esEspecial;
  final String? horaInicio; // 'HH:mm'
  final String? horaFin;

  const SesionClase({
    required this.id,
    required this.cursoId,
    required this.numeroSesion,
    required this.fecha,
    required this.tema,
    required this.estado,
    this.recursos = const [],
    this.motivoSuspension,
    this.esEspecial = false,
    this.horaInicio,
    this.horaFin,
  });

  bool get suspendida => estado == 'suspendida';

  SesionClase copyWith({
    String? id,
    String? cursoId,
    int? numeroSesion,
    DateTime? fecha,
    String? tema,
    String? estado,
    List<RecursoEducativo>? recursos,
  }) {
    return SesionClase(
      id: id ?? this.id,
      cursoId: cursoId ?? this.cursoId,
      numeroSesion: numeroSesion ?? this.numeroSesion,
      fecha: fecha ?? this.fecha,
      tema: tema ?? this.tema,
      estado: estado ?? this.estado,
      recursos: recursos ?? this.recursos,
      motivoSuspension: motivoSuspension,
      esEspecial: esEspecial,
      horaInicio: horaInicio,
      horaFin: horaFin,
    );
  }
}

/// Estado de un justificativo de inasistencia (US-35, US-37, US-38)
enum EstadoJustificativo {
  pendiente,
  aceptado,
  rechazado;

  String get label => switch (this) {
    EstadoJustificativo.pendiente => 'Pendiente',
    EstadoJustificativo.aceptado => 'Aprobado',
    EstadoJustificativo.rechazado => 'Rechazado',
  };

  static EstadoJustificativo? desdeDb(Object? valor) => EstadoJustificativo.values.where((e) => e.name == valor).firstOrNull;
}

/// Motivo tipificado del justificativo: sin diagnósticos (RB-8, US-35 escenario 2)
enum MotivoJustificativo {
  salud,
  escolar,
  familiar,
  transporte,
  otro;

  String get label => switch (this) {
    MotivoJustificativo.salud => 'Salud',
    MotivoJustificativo.escolar => 'Académico / Pruebas',
    MotivoJustificativo.familiar => 'Familiar / Personal',
    MotivoJustificativo.transporte => 'Transporte / Clima',
    MotivoJustificativo.otro => 'Otro',
  };

  static MotivoJustificativo? desdeDb(Object? valor) => MotivoJustificativo.values.where((e) => e.name == valor).firstOrNull;
}

/// Registro de asistencia de una alumna en una sesión (US-13).
/// Con Supabase, [id] es la inscripción de la alumna en el curso: la clave con
/// que se guardan su asistencia, su participación y su lugar en el podio.
@immutable
class RegistroAsistencia {
  final String id;
  final String sesionId;
  final String alumnaId;
  final String alumnaNombre;
  final String alumnaRut;
  final EstadoAsistencia estado;
  final DateTime? horaMarcado;
  final bool autorizaImagen;

  /// Quién hizo la última edición del registro (US-15)
  final String? editadoPor;

  /// Justificativo de la alumna en esta clase: estado y motivo general, sin el detalle (US-38)
  final EstadoJustificativo? justificativo;
  final MotivoJustificativo? motivoJustificativo;

  const RegistroAsistencia({
    required this.id,
    required this.sesionId,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.alumnaRut,
    required this.estado,
    this.horaMarcado,
    required this.autorizaImagen,
    this.editadoPor,
    this.justificativo,
    this.motivoJustificativo,
  });

  /// Con un justificativo aprobado entra al pase de lista como justificada (US-16 escenario 2)
  bool get justificadaPorAdelantado => justificativo == EstadoJustificativo.aceptado;

  RegistroAsistencia copyWith({
    String? id,
    String? sesionId,
    String? alumnaId,
    String? alumnaNombre,
    String? alumnaRut,
    EstadoAsistencia? estado,
    DateTime? horaMarcado,
    bool? autorizaImagen,
  }) {
    return RegistroAsistencia(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      alumnaRut: alumnaRut ?? this.alumnaRut,
      estado: estado ?? this.estado,
      horaMarcado: horaMarcado ?? this.horaMarcado,
      autorizaImagen: autorizaImagen ?? this.autorizaImagen,
      editadoPor: editadoPor,
      justificativo: justificativo,
      motivoJustificativo: motivoJustificativo,
    );
  }
}

/// Participación de clase y ejercicios resueltos en aula (US-28).
/// Con Supabase, [id] es la inscripción de la alumna (igual que en [RegistroAsistencia]).
@immutable
class ParticipacionClase {
  final String id;
  final String sesionId;
  final String alumnaId;
  final String alumnaNombre;
  final int ejerciciosResueltos;
  final bool participacionActiva;

  const ParticipacionClase({
    required this.id,
    required this.sesionId,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.ejerciciosResueltos,
    required this.participacionActiva,
  });

  ParticipacionClase copyWith({
    String? id,
    String? sesionId,
    String? alumnaId,
    String? alumnaNombre,
    int? ejerciciosResueltos,
    bool? participacionActiva,
  }) {
    return ParticipacionClase(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      ejerciciosResueltos: ejerciciosResueltos ?? this.ejerciciosResueltos,
      participacionActiva: participacionActiva ?? this.participacionActiva,
    );
  }
}

/// Asistencia de una sede en un día de clases
@immutable
class PuntoAsistencia {
  final DateTime fecha;
  final int presentes;
  final int total;

  const PuntoAsistencia({required this.fecha, required this.presentes, required this.total});

  double get porcentaje => total == 0 ? 0 : presentes * 100 / total;
}

/// Evolución de la asistencia de una sede, clase a clase (dashboard de la Directiva)
@immutable
class SerieAsistencia {
  final String sedeId;
  final String sedeNombre;
  final List<PuntoAsistencia> puntos;

  const SerieAsistencia({required this.sedeId, required this.sedeNombre, required this.puntos});
}
