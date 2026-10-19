import 'package:flutter/foundation.dart';
import '../config/ninaspro_theme.dart';

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
  final int alumnasActivas;
  final int capacidadTotal;
  final String coordinadoraNombre;
  final String estado;

  const Sede({
    required this.id,
    required this.nombre,
    required this.universidad,
    required this.region,
    required this.modalidad,
    required this.alumnasActivas,
    required this.capacidadTotal,
    required this.coordinadoraNombre,
    this.estado = 'activa',
  });
}

/// Curso formativo ofrecido por NiñasPro
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

  const Curso({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.anio,
    required this.semestre,
    required this.totalSesiones,
  });
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
  final String estado; // 'activa' | 'retirada' | 'egresada'
  final String? motivoRetiro;

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
    this.estado = 'activa',
    this.motivoRetiro,
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
    String? estado,
    String? motivoRetiro,
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
      estado: estado ?? this.estado,
      motivoRetiro: motivoRetiro ?? this.motivoRetiro,
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
  final String estado; // 'programada' | 'realizada'
  final List<RecursoEducativo> recursos;
  final PodioKahootSesion? podioKahoot;

  const SesionClase({
    required this.id,
    required this.cursoId,
    required this.numeroSesion,
    required this.fecha,
    required this.tema,
    required this.estado,
    this.recursos = const [],
    this.podioKahoot,
  });

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
    );
  }
}

/// Registro de asistencia de una alumna en una sesión (US-13)
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

  const RegistroAsistencia({
    required this.id,
    required this.sesionId,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.alumnaRut,
    required this.estado,
    this.horaMarcado,
    required this.autorizaImagen,
  });

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
    );
  }
}

/// Participación de clase y ejercicios resueltos en aula (US-28)
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

/// Tutora voluntaria del equipo pedagógico (US-33, US-43)
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

  const Tutora({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.sedeId,
    required this.sedeNombre,
    required this.adhesionFirmada,
    required this.presenteClaseActual,
    this.esEquipoGestion = false,
  });

  Tutora copyWith({
    String? id,
    String? nombre,
    String? rol,
    String? sedeId,
    String? sedeNombre,
    bool? adhesionFirmada,
    bool? presenteClaseActual,
    bool? esEquipoGestion,
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
    );
  }
}

/// Vista agregada del portal móvil de la alumna (US-25, US-26, US-29, US-35)
@immutable
class PortalAlumnaData {
  final Alumna alumna;
  final Curso curso;
  final List<SesionClase> sesiones;
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
