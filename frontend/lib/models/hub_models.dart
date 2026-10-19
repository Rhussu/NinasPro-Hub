import 'package:flutter/foundation.dart';
import '../config/ninaspro_theme.dart';

/// Sede territorial o modalidad de NiñasPro
@immutable
class Sede {
  final String id;
  final String nombre;
  final String modalidad; // 'Presencial' | 'Online'
  final String institucion;
  final String direccion;
  final int cursosActivos;
  final int alumnasTotales;
  final int tutorasActivas;

  const Sede({
    required this.id,
    required this.nombre,
    required this.modalidad,
    required this.institucion,
    required this.direccion,
    this.cursosActivos = 0,
    this.alumnasTotales = 0,
    this.tutorasActivas = 0,
  });

  Sede copyWith({
    String? id,
    String? nombre,
    String? modalidad,
    String? institucion,
    String? direccion,
    int? cursosActivos,
    int? alumnasTotales,
    int? tutorasActivas,
  }) {
    return Sede(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      modalidad: modalidad ?? this.modalidad,
      institucion: institucion ?? this.institucion,
      direccion: direccion ?? this.direccion,
      cursosActivos: cursosActivos ?? this.cursosActivos,
      alumnasTotales: alumnasTotales ?? this.alumnasTotales,
      tutorasActivas: tutorasActivas ?? this.tutorasActivas,
    );
  }
}

/// Curso formativo ofrecido por NiñasPro (ej: Pensamiento Computacional)
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
  final int sesionesRealizadas;

  const Curso({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.anio,
    this.semestre = 1,
    this.totalSesiones = 12,
    this.sesionesRealizadas = 4,
  });
}

/// Ficha de Alumna de NiñasPro Hub
@immutable
class Alumna {
  final String id;
  final String rut;
  final String nombre;
  final String apellido;
  final String email;
  final String cursoId;
  final String cursoNombre;
  final String sedeId;
  final String sedeNombre;
  final double porcentajeAsistencia;
  final int asistenciasCount;
  final int inasistenciasCount;
  final int justificadasCount;
  final String estadoMatricula; // 'Activa' | 'Condicionada' | 'Retirada'
  final bool autorizaImagen;
  final String nombreApoderado;
  final String telefonoApoderado;
  final String emailApoderado;
  final DateTime fechaInscripcion;
  final bool retirado;
  final String? motivoRetiro;
  final List<String> historialCursosPrevios;

  const Alumna({
    required this.id,
    required this.rut,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.cursoId,
    required this.cursoNombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.porcentajeAsistencia,
    this.asistenciasCount = 0,
    this.inasistenciasCount = 0,
    this.justificadasCount = 0,
    this.estadoMatricula = 'Activa',
    required this.autorizaImagen,
    required this.nombreApoderado,
    required this.telefonoApoderado,
    required this.emailApoderado,
    required this.fechaInscripcion,
    this.retirado = false,
    this.motivoRetiro,
    this.historialCursosPrevios = const [],
  });

  String get nombreCompleto => '$nombre $apellido';

  Alumna copyWith({
    String? id,
    String? rut,
    String? nombre,
    String? apellido,
    String? email,
    String? cursoId,
    String? cursoNombre,
    String? sedeId,
    String? sedeNombre,
    double? porcentajeAsistencia,
    int? asistenciasCount,
    int? inasistenciasCount,
    int? justificadasCount,
    String? estadoMatricula,
    bool? autorizaImagen,
    String? nombreApoderado,
    String? telefonoApoderado,
    String? emailApoderado,
    DateTime? fechaInscripcion,
    bool? retirado,
    String? motivoRetiro,
    List<String>? historialCursosPrevios,
  }) {
    return Alumna(
      id: id ?? this.id,
      rut: rut ?? this.rut,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email ?? this.email,
      cursoId: cursoId ?? this.cursoId,
      cursoNombre: cursoNombre ?? this.cursoNombre,
      sedeId: sedeId ?? this.sedeId,
      sedeNombre: sedeNombre ?? this.sedeNombre,
      porcentajeAsistencia: porcentajeAsistencia ?? this.porcentajeAsistencia,
      asistenciasCount: asistenciasCount ?? this.asistenciasCount,
      inasistenciasCount: inasistenciasCount ?? this.inasistenciasCount,
      justificadasCount: justificadasCount ?? this.justificadasCount,
      estadoMatricula: estadoMatricula ?? this.estadoMatricula,
      autorizaImagen: autorizaImagen ?? this.autorizaImagen,
      nombreApoderado: nombreApoderado ?? this.nombreApoderado,
      telefonoApoderado: telefonoApoderado ?? this.telefonoApoderado,
      emailApoderado: emailApoderado ?? this.emailApoderado,
      fechaInscripcion: fechaInscripcion ?? this.fechaInscripcion,
      retirado: retirado ?? this.retirado,
      motivoRetiro: motivoRetiro ?? this.motivoRetiro,
      historialCursosPrevios: historialCursosPrevios ?? this.historialCursosPrevios,
    );
  }
}

/// Sesión de clase (generalmente los sábados)
@immutable
class SesionClase {
  final String id;
  final String cursoId;
  final String cursoNombre;
  final int numeroSesion;
  final DateTime fecha;
  final String tema;
  final String estado; // 'programada' | 'realizada' | 'suspendida'
  final String? motivoSuspension;
  final bool evidenciaSubida;
  final bool fotosAptas;

  const SesionClase({
    required this.id,
    required this.cursoId,
    required this.cursoNombre,
    required this.numeroSesion,
    required this.fecha,
    required this.tema,
    this.estado = 'programada',
    this.motivoSuspension,
    this.evidenciaSubida = false,
    this.fotosAptas = true,
  });

  SesionClase copyWith({
    String? id,
    String? cursoId,
    String? cursoNombre,
    int? numeroSesion,
    DateTime? fecha,
    String? tema,
    String? estado,
    String? motivoSuspension,
    bool? evidenciaSubida,
    bool? fotosAptas,
  }) {
    return SesionClase(
      id: id ?? this.id,
      cursoId: cursoId ?? this.cursoId,
      cursoNombre: cursoNombre ?? this.cursoNombre,
      numeroSesion: numeroSesion ?? this.numeroSesion,
      fecha: fecha ?? this.fecha,
      tema: tema ?? this.tema,
      estado: estado ?? this.estado,
      motivoSuspension: motivoSuspension ?? this.motivoSuspension,
      evidenciaSubida: evidenciaSubida ?? this.evidenciaSubida,
      fotosAptas: fotosAptas ?? this.fotosAptas,
    );
  }
}

/// Registro individual de asistencia para una alumna en una clase
@immutable
class RegistroAsistencia {
  final String id;
  final String sesionId;
  final String alumnaId;
  final String alumnaNombre;
  final String alumnaRut;
  final EstadoAsistencia estado;
  final bool autorizaImagen;
  final DateTime horaMarcado;
  final String registradaPor;

  const RegistroAsistencia({
    required this.id,
    required this.sesionId,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.alumnaRut,
    required this.estado,
    required this.autorizaImagen,
    required this.horaMarcado,
    required this.registradaPor,
  });

  RegistroAsistencia copyWith({
    String? id,
    String? sesionId,
    String? alumnaId,
    String? alumnaNombre,
    String? alumnaRut,
    EstadoAsistencia? estado,
    bool? autorizaImagen,
    DateTime? horaMarcado,
    String? registradaPor,
  }) {
    return RegistroAsistencia(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      alumnaRut: alumnaRut ?? this.alumnaRut,
      estado: estado ?? this.estado,
      autorizaImagen: autorizaImagen ?? this.autorizaImagen,
      horaMarcado: horaMarcado ?? this.horaMarcado,
      registradaPor: registradaPor ?? this.registradaPor,
    );
  }
}

/// Registro pedagógico de ejercicios y participación activa por sesión
@immutable
class ParticipacionClase {
  final String id;
  final String sesionId;
  final String alumnaId;
  final String alumnaNombre;
  final int ejerciciosResueltos;
  final bool participacionActiva;
  final int? podioKahoot;
  final String? observacion;

  const ParticipacionClase({
    required this.id,
    required this.sesionId,
    required this.alumnaId,
    required this.alumnaNombre,
    this.ejerciciosResueltos = 0,
    this.participacionActiva = false,
    this.podioKahoot,
    this.observacion,
  });

  ParticipacionClase copyWith({
    String? id,
    String? sesionId,
    String? alumnaId,
    String? alumnaNombre,
    int? ejerciciosResueltos,
    bool? participacionActiva,
    int? podioKahoot,
    String? observacion,
  }) {
    return ParticipacionClase(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      ejerciciosResueltos: ejerciciosResueltos ?? this.ejerciciosResueltos,
      participacionActiva: participacionActiva ?? this.participacionActiva,
      podioKahoot: podioKahoot ?? this.podioKahoot,
      observacion: observacion ?? this.observacion,
    );
  }
}

/// Registro de Tutora / Voluntaria de NiñasPro
@immutable
class Tutora {
  final String id;
  final String rut;
  final String nombre;
  final String email;
  final String telefono;
  final String sedeId;
  final String sedeNombre;
  final String rol; // 'Coordinadora de Sede' | 'Docente Guía' | 'Tutora de Sala'
  final bool adhesionFirmada;
  final bool presenteClaseActual;

  const Tutora({
    required this.id,
    required this.rut,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.sedeId,
    required this.sedeNombre,
    required this.rol,
    required this.adhesionFirmada,
    this.presenteClaseActual = true,
  });

  Tutora copyWith({
    String? id,
    String? rut,
    String? nombre,
    String? email,
    String? telefono,
    String? sedeId,
    String? sedeNombre,
    String? rol,
    bool? adhesionFirmada,
    bool? presenteClaseActual,
  }) {
    return Tutora(
      id: id ?? this.id,
      rut: rut ?? this.rut,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      sedeId: sedeId ?? this.sedeId,
      sedeNombre: sedeNombre ?? this.sedeNombre,
      rol: rol ?? this.rol,
      adhesionFirmada: adhesionFirmada ?? this.adhesionFirmada,
      presenteClaseActual: presenteClaseActual ?? this.presenteClaseActual,
    );
  }
}

/// Alerta de riesgo de deserción escolar por 3 inasistencias
@immutable
class AlertaDesercion {
  final String id;
  final String alumnaId;
  final String alumnaNombre;
  final String alumnaRut;
  final String cursoId;
  final String cursoNombre;
  final String sedeId;
  final String sedeNombre;
  final int inasistenciasConsecutivas;
  final DateTime fechaGenerada;
  final bool atendida;
  final DateTime? fechaContacto;
  final String? observacionGestion;

  const AlertaDesercion({
    required this.id,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.alumnaRut,
    required this.cursoId,
    required this.cursoNombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.inasistenciasConsecutivas,
    required this.fechaGenerada,
    this.atendida = false,
    this.fechaContacto,
    this.observacionGestion,
  });

  AlertaDesercion copyWith({
    String? id,
    String? alumnaId,
    String? alumnaNombre,
    String? alumnaRut,
    String? cursoId,
    String? cursoNombre,
    String? sedeId,
    String? sedeNombre,
    int? inasistenciasConsecutivas,
    DateTime? fechaGenerada,
    bool? atendida,
    DateTime? fechaContacto,
    String? observacionGestion,
  }) {
    return AlertaDesercion(
      id: id ?? this.id,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      alumnaRut: alumnaRut ?? this.alumnaRut,
      cursoId: cursoId ?? this.cursoId,
      cursoNombre: cursoNombre ?? this.cursoNombre,
      sedeId: sedeId ?? this.sedeId,
      sedeNombre: sedeNombre ?? this.sedeNombre,
      inasistenciasConsecutivas: inasistenciasConsecutivas ?? this.inasistenciasConsecutivas,
      fechaGenerada: fechaGenerada ?? this.fechaGenerada,
      atendida: atendida ?? this.atendida,
      fechaContacto: fechaContacto ?? this.fechaContacto,
      observacionGestion: observacionGestion ?? this.observacionGestion,
    );
  }
}

/// Justificativo de inasistencia enviado desde el portal
@immutable
class Justificativo {
  final String id;
  final String alumnaId;
  final String alumnaNombre;
  final String cursoId;
  final String cursoNombre;
  final String sesionId;
  final DateTime fechaSesion;
  final String motivoTipificado; // 'Salud' | 'Familiar' | 'Escolar' | 'Transporte' | 'Otro'
  final String detalle;
  final DateTime fechaEnvio;
  final String estado; // 'pendiente' | 'aprobado' | 'rechazado'
  final String? respuestaGestion;

  const Justificativo({
    required this.id,
    required this.alumnaId,
    required this.alumnaNombre,
    required this.cursoId,
    required this.cursoNombre,
    required this.sesionId,
    required this.fechaSesion,
    required this.motivoTipificado,
    required this.detalle,
    required this.fechaEnvio,
    this.estado = 'pendiente',
    this.respuestaGestion,
  });

  Justificativo copyWith({
    String? id,
    String? alumnaId,
    String? alumnaNombre,
    String? cursoId,
    String? cursoNombre,
    String? sesionId,
    DateTime? fechaSesion,
    String? motivoTipificado,
    String? detalle,
    DateTime? fechaEnvio,
    String? estado,
    String? respuestaGestion,
  }) {
    return Justificativo(
      id: id ?? this.id,
      alumnaId: alumnaId ?? this.alumnaId,
      alumnaNombre: alumnaNombre ?? this.alumnaNombre,
      cursoId: cursoId ?? this.cursoId,
      cursoNombre: cursoNombre ?? this.cursoNombre,
      sesionId: sesionId ?? this.sesionId,
      fechaSesion: fechaSesion ?? this.fechaSesion,
      motivoTipificado: motivoTipificado ?? this.motivoTipificado,
      detalle: detalle ?? this.detalle,
      fechaEnvio: fechaEnvio ?? this.fechaEnvio,
      estado: estado ?? this.estado,
      respuestaGestion: respuestaGestion ?? this.respuestaGestion,
    );
  }
}

/// Datos agregados para el portal personal de la estudiante
@immutable
class PortalAlumnaData {
  final Alumna alumna;
  final Curso curso;
  final List<SesionClase> sesiones;
  final List<RegistroAsistencia> asistencias;
  final List<ParticipacionClase> participaciones;
  final List<Justificativo> justificativos;
  final int posicionKahoot;
  final int totalEjerciciosResueltos;

  const PortalAlumnaData({
    required this.alumna,
    required this.curso,
    required this.sesiones,
    required this.asistencias,
    required this.participaciones,
    required this.justificativos,
    required this.posicionKahoot,
    required this.totalEjerciciosResueltos,
  });
}
