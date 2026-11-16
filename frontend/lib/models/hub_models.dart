import 'dart:ui' show Color;

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

/// Registro del podio de Kahoot de una sesión (US-29)
@immutable
class PodioKahootSesion {
  final String primerLugarAlumnaId;
  final String primerLugarNombre;
  final String segundoLugarAlumnaId;
  final String segundoLugarNombre;
  final String tercerLugarAlumnaId;
  final String tercerLugarNombre;

  const PodioKahootSesion({
    required this.primerLugarAlumnaId,
    required this.primerLugarNombre,
    required this.segundoLugarAlumnaId,
    required this.segundoLugarNombre,
    required this.tercerLugarAlumnaId,
    required this.tercerLugarNombre,
  });
}

/// Configuración de rol dinámico de tutoras de aula (US-43)
@immutable
class RolTutorConfig {
  final String codigo;
  final String nombre;
  final String descripcion;
  final String colorHex;
  final bool esRequerido;

  const RolTutorConfig({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.colorHex,
    this.esRequerido = false,
  });

  /// Color del rol a partir de [colorHex] ('#RRGGBB'); violeta de marca si no es válido.
  Color get color {
    final valor = int.tryParse(colorHex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (valor ?? 0x8B3295));
  }
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

/// Asignación semanal de rol a una tutora (US-43)
@immutable
class AsignacionSemanalTutora {
  final String tutoraId;
  final String tutoraNombre;
  final int semanaNumero;
  final String rolCodigo;

  const AsignacionSemanalTutora({
    required this.tutoraId,
    required this.tutoraNombre,
    required this.semanaNumero,
    required this.rolCodigo,
  });
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

/// Autorizaciones del apoderado registradas en la ficha de la alumna (US-10, US-12)
@immutable
class AutorizacionesAlumna {
  final bool tratamientoDatos;
  final Map<CanalImagen, EstadoAutorizacion> canales;
  final Map<CanalImagen, RevocacionImagen> revocaciones;
  // Mockup: nombre del documento firmado (la subida es simulada)
  final String? respaldoNombre;
  final DateTime? fechaRegistro;

  const AutorizacionesAlumna({
    this.tratamientoDatos = false,
    this.canales = const {},
    this.revocaciones = const {},
    this.respaldoNombre,
    this.fechaRegistro,
  });

  /// Un canal sin respuesta explícita queda como no autorizado (RB-2)
  EstadoAutorizacion estado(CanalImagen canal) =>
      canales[canal] ?? EstadoAutorizacion.noAutorizada;

  /// Apta para fotos si hay tratamiento de datos y al menos un canal autorizado
  bool get permiteFotos =>
      tratamientoDatos && CanalImagen.values.any((c) => estado(c) == EstadoAutorizacion.otorgada);
}

/// Alumna participante en NiñasPro Hub (US-07, US-09, US-25)
@immutable
class Alumna {
  final String id;
  final String nombre;
  final String rut;
  final String cursoId;
  final String cursoNombre;
  final String sedeId;
  final String sedeNombre;
  final double porcentajeAsistencia;
  final int asistenciasCount;
  final bool autorizaFoto;
  final String apoderadoNombre;
  final String apoderadoTelefono;
  final String apoderadoCorreo;
  final String estado; // 'preinscrita' | 'activa' | 'retirada' | 'egresada'
  final String? motivoRetiro;
  final DateTime? fechaRetiro;
  final AutorizacionesAlumna autorizaciones;

  /// Inscripciones anteriores de la misma ficha (ej. 'PCB · Sede San Joaquín · 2026') (US-09)
  final List<String> historialInscripciones;

  const Alumna({
    required this.id,
    required this.nombre,
    required this.rut,
    required this.cursoId,
    required this.cursoNombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.porcentajeAsistencia,
    required this.asistenciasCount,
    required this.autorizaFoto,
    required this.apoderadoNombre,
    required this.apoderadoTelefono,
    this.apoderadoCorreo = '',
    this.estado = 'activa',
    this.motivoRetiro,
    this.fechaRetiro,
    this.autorizaciones = const AutorizacionesAlumna(),
    this.historialInscripciones = const [],
  });

  Alumna copyWith({
    String? id,
    String? nombre,
    String? rut,
    String? cursoId,
    String? cursoNombre,
    String? sedeId,
    String? sedeNombre,
    double? porcentajeAsistencia,
    int? asistenciasCount,
    bool? autorizaFoto,
    String? apoderadoNombre,
    String? apoderadoTelefono,
    String? apoderadoCorreo,
    String? estado,
    String? motivoRetiro,
    DateTime? fechaRetiro,
    AutorizacionesAlumna? autorizaciones,
    List<String>? historialInscripciones,
  }) {
    return Alumna(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      rut: rut ?? this.rut,
      cursoId: cursoId ?? this.cursoId,
      cursoNombre: cursoNombre ?? this.cursoNombre,
      sedeId: sedeId ?? this.sedeId,
      sedeNombre: sedeNombre ?? this.sedeNombre,
      porcentajeAsistencia: porcentajeAsistencia ?? this.porcentajeAsistencia,
      asistenciasCount: asistenciasCount ?? this.asistenciasCount,
      autorizaFoto: autorizaFoto ?? this.autorizaFoto,
      apoderadoNombre: apoderadoNombre ?? this.apoderadoNombre,
      apoderadoTelefono: apoderadoTelefono ?? this.apoderadoTelefono,
      apoderadoCorreo: apoderadoCorreo ?? this.apoderadoCorreo,
      estado: estado ?? this.estado,
      motivoRetiro: motivoRetiro ?? this.motivoRetiro,
      fechaRetiro: fechaRetiro ?? this.fechaRetiro,
      autorizaciones: autorizaciones ?? this.autorizaciones,
      historialInscripciones: historialInscripciones ?? this.historialInscripciones,
    );
  }
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
  final PodioKahootSesion? podioKahoot;
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
    this.podioKahoot,
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
    PodioKahootSesion? podioKahoot,
  }) {
    return SesionClase(
      id: id ?? this.id,
      cursoId: cursoId ?? this.cursoId,
      numeroSesion: numeroSesion ?? this.numeroSesion,
      fecha: fecha ?? this.fecha,
      tema: tema ?? this.tema,
      estado: estado ?? this.estado,
      recursos: recursos ?? this.recursos,
      podioKahoot: podioKahoot ?? this.podioKahoot,
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

/// Alerta confidencial de riesgo de deserción escolar (US-39, US-40)
@immutable
class AlertaDesercion {
  final String id;
  final String alumnaId;
  final String alumnaNombre;
  final String sedeNombre;
  final int inasistenciasConsecutivas;
  final String apoderadoContacto;
  final String estado; // 'activa' | 'contactada'
  final String? observacionesContacto;

  const AlertaDesercion({
    required this.id,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.sedeNombre,
    required this.inasistenciasConsecutivas,
    required this.apoderadoContacto,
    required this.estado,
    this.observacionesContacto,
  });

  AlertaDesercion copyWith({
    String? id,
    String? alumnaId,
    String? alumnaNombre,
    String? sedeNombre,
    int? inasistenciasConsecutivas,
    String? apoderadoContacto,
    String? estado,
    String? observacionesContacto,
  }) {
    return AlertaDesercion(
      id: id ?? this.id,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      sedeNombre: sedeNombre ?? this.sedeNombre,
      inasistenciasConsecutivas: inasistenciasConsecutivas ?? this.inasistenciasConsecutivas,
      apoderadoContacto: apoderadoContacto ?? this.apoderadoContacto,
      estado: estado ?? this.estado,
      observacionesContacto: observacionesContacto ?? this.observacionesContacto,
    );
  }
}

/// Solicitud de justificativo de inasistencia (US-35, US-37)
@immutable
class Justificativo {
  final String id;
  final String alumnaId;
  final String alumnaNombre;
  final String sesionId;
  final DateTime sesionFecha;
  final String motivoTipificado;
  final String detalle;
  final String estado; // 'pendiente' | 'aprobado' | 'rechazado'
  final String? observacionesResolucion;

  const Justificativo({
    required this.id,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.sesionId,
    required this.sesionFecha,
    required this.motivoTipificado,
    required this.detalle,
    required this.estado,
    this.observacionesResolucion,
  });

  Justificativo copyWith({
    String? id,
    String? alumnaId,
    String? alumnaNombre,
    String? sesionId,
    DateTime? sesionFecha,
    String? motivoTipificado,
    String? detalle,
    String? estado,
    String? observacionesResolucion,
  }) {
    return Justificativo(
      id: id ?? this.id,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      sesionId: sesionId ?? this.sesionId,
      sesionFecha: sesionFecha ?? this.sesionFecha,
      motivoTipificado: motivoTipificado ?? this.motivoTipificado,
      detalle: detalle ?? this.detalle,
      estado: estado ?? this.estado,
      observacionesResolucion: observacionesResolucion ?? this.observacionesResolucion,
    );
  }
}

/// Tutora voluntaria del equipo pedagógico y su ficha de voluntariado (US-30, US-31, US-32, US-33, US-43)
@immutable
class Tutora {
  final String id;
  final String nombre;
  final String rol;
  final String sedeId;
  final String sedeNombre;
  final bool adhesionFirmada;
  final bool presenteClaseActual;
  final bool esEquipoGestion;
  final String rut;
  final String correo;
  final String institucion;
  final DateTime? fechaIngreso;
  final DateTime? fechaSalida;
  final String estado; // 'activa' | 'retirada'
  final DateTime? fechaFirmaAdhesion;

  /// Cursos (instancias) en que ha participado, del más antiguo al más reciente
  final List<String> cursoIds;

  const Tutora({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.sedeId,
    required this.sedeNombre,
    required this.adhesionFirmada,
    required this.presenteClaseActual,
    this.esEquipoGestion = false,
    this.rut = '',
    this.correo = '',
    this.institucion = '',
    this.fechaIngreso,
    this.fechaSalida,
    this.estado = 'activa',
    this.fechaFirmaAdhesion,
    this.cursoIds = const [],
  });

  /// Rol institucional para filtros del directorio de voluntariado (US-32)
  String get rolVoluntariado => esEquipoGestion ? 'Equipo de Gestión' : 'Tutora';

  Tutora copyWith({
    String? id,
    String? nombre,
    String? rol,
    String? sedeId,
    String? sedeNombre,
    bool? adhesionFirmada,
    bool? presenteClaseActual,
    bool? esEquipoGestion,
    String? rut,
    String? correo,
    String? institucion,
    DateTime? fechaIngreso,
    DateTime? fechaSalida,
    String? estado,
    DateTime? fechaFirmaAdhesion,
    List<String>? cursoIds,
  }) {
    return Tutora(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      sedeId: sedeId ?? this.sedeId,
      sedeNombre: sedeNombre ?? this.sedeNombre,
      adhesionFirmada: adhesionFirmada ?? this.adhesionFirmada,
      presenteClaseActual: presenteClaseActual ?? this.presenteClaseActual,
      esEquipoGestion: esEquipoGestion ?? this.esEquipoGestion,
      rut: rut ?? this.rut,
      correo: correo ?? this.correo,
      institucion: institucion ?? this.institucion,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      fechaSalida: fechaSalida ?? this.fechaSalida,
      estado: estado ?? this.estado,
      fechaFirmaAdhesion: fechaFirmaAdhesion ?? this.fechaFirmaAdhesion,
      cursoIds: cursoIds ?? this.cursoIds,
    );
  }
}

/// Clasificación de una fila en la previsualización de una carga masiva (US-07, US-08, US-30)
enum EstadoFilaImportacion {
  nueva,
  existente,
  invalida;

  String get label => switch (this) {
        EstadoFilaImportacion.nueva => 'Nueva',
        EstadoFilaImportacion.existente => 'Ya existe',
        EstadoFilaImportacion.invalida => 'Inválida',
      };
}

/// Fila de una planilla de carga masiva (alumnas o voluntariado)
@immutable
class FilaImportacion {
  final int numeroFila;
  final String nombre;
  final String rut;
  final String detalle; // apoderado o institución, según la planilla
  final EstadoFilaImportacion estado;
  final String? motivo;

  const FilaImportacion({
    required this.numeroFila,
    required this.nombre,
    required this.rut,
    required this.detalle,
    required this.estado,
    this.motivo,
  });
}

/// Resultado de procesar una planilla simulada antes de confirmar la carga (US-07, US-08, US-30)
@immutable
class ResultadoImportacion {
  final String nombreArchivo;
  final List<FilaImportacion> filas;

  /// Si no es null, la planilla no respeta la plantilla y se rechaza completa (US-08)
  final String? errorColumnas;

  const ResultadoImportacion({
    required this.nombreArchivo,
    this.filas = const [],
    this.errorColumnas,
  });

  int contar(EstadoFilaImportacion estado) => filas.where((f) => f.estado == estado).length;
}

/// Tipo de acción registrada en la bitácora de auditoría (US-23, US-24)
enum TipoAccionAuditoria {
  consulta,
  modificacion,
  exportacion,
  acceso;

  String get label => switch (this) {
        TipoAccionAuditoria.consulta => 'Consulta',
        TipoAccionAuditoria.modificacion => 'Modificación',
        TipoAccionAuditoria.exportacion => 'Exportación',
        TipoAccionAuditoria.acceso => 'Inicio de sesión',
      };
}

/// Evento inmutable de la bitácora de auditoría (US-22, US-24)
@immutable
class EventoAuditoria {
  final String id;
  final DateTime fecha;
  final String usuariaNombre;
  final String usuariaCorreo;
  final String sedeNombre;
  final TipoAccionAuditoria tipo;
  final String descripcion;
  final String? alumnaRut;

  const EventoAuditoria({
    required this.id,
    required this.fecha,
    required this.usuariaNombre,
    required this.usuariaCorreo,
    required this.sedeNombre,
    required this.tipo,
    required this.descripcion,
    this.alumnaRut,
  });
}

/// Indicadores agregados de una sede para el dashboard de la Directiva
@immutable
class ResumenSede {
  final Sede sede;
  final int cursos;
  final int alumnasActivas;
  final double asistenciaPromedio;
  final int voluntariasActivas;

  const ResumenSede({
    required this.sede,
    required this.cursos,
    required this.alumnasActivas,
    required this.asistenciaPromedio,
    required this.voluntariasActivas,
  });
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

/// Reporte que se puede exportar (US-21)
enum TipoExportacion {
  asistencia,
  nomina,
  participacion;

  String get label => switch (this) {
        TipoExportacion.asistencia => 'Asistencia',
        TipoExportacion.nomina => 'Nómina de alumnas',
        TipoExportacion.participacion => 'Participación y ejercicios',
      };
}

/// Filtros del formulario de exportación (US-21, US-22)
@immutable
class FiltroExportacion {
  final TipoExportacion tipo;
  final String? sedeId;
  final String? cursoId;
  final DateTime? desde;
  final DateTime? hasta;
  final String formato; // 'CSV' | 'XLSX'
  final bool disociado;

  const FiltroExportacion({
    required this.tipo,
    this.sedeId,
    this.cursoId,
    this.desde,
    this.hasta,
    this.formato = 'CSV',
    this.disociado = false,
  });
}

/// Contenido de una exportación (mockup: no se descarga un archivo real) (US-21, US-22)
@immutable
class ResultadoExportacion {
  final String nombreArchivo;
  final List<String> encabezados;
  final List<List<String>> filas;

  const ResultadoExportacion({
    required this.nombreArchivo,
    required this.encabezados,
    required this.filas,
  });
}

/// Vista agregada del portal móvil de la alumna (US-25, US-26, US-29, US-35)
@immutable
class PortalAlumnaData {
  final Alumna alumna;
  final Curso curso;
  final List<SesionClase> sesiones;

  /// Clase de hoy según la planificación del curso (null si hoy no hay clase)
  final SesionClase? sesionHoy;
  final List<RegistroAsistencia> asistencias;
  final List<Justificativo> justificativos;
  final int podiosPrimerLugar;
  final int podiosSegundoLugar;
  final int podiosTercerLugar;
  final int totalEjerciciosResueltos;
  final double umbralAprobacion;
  final int clasesRecuperadasPorEjercicios;

  const PortalAlumnaData({
    required this.alumna,
    required this.curso,
    required this.sesiones,
    this.sesionHoy,
    required this.asistencias,
    required this.justificativos,
    required this.podiosPrimerLugar,
    required this.podiosSegundoLugar,
    required this.podiosTercerLugar,
    required this.totalEjerciciosResueltos,
    required this.umbralAprobacion,
    required this.clasesRecuperadasPorEjercicios,
  });
}
