import '../config/ninaspro_theme.dart';
import '../models/hub_models.dart';
import 'hub_repository.dart';

/// Implementación sintética y en memoria de [HubRepository] con datos chilenos realistas.
///
/// Permite probar y validar con stakeholders todos los flujos de las historias de usuario
/// sin necesidad de conectarse a la base de datos real.
class MockHubRepository implements HubRepository {
  // Estado en memoria mutable para permitir interactividad en el mockup
  late List<Sede> _sedes;
  late List<Curso> _cursos;
  late List<Alumna> _alumnas;
  late List<SesionClase> _sesiones;
  late Map<String, List<RegistroAsistencia>> _asistenciasPorSesion;
  late Map<String, List<ParticipacionClase>> _participacionesPorSesion;
  late List<AlertaDesercion> _alertas;
  late List<Justificativo> _justificativos;
  late List<Tutora> _tutoras;

  MockHubRepository() {
    _initData();
  }

  void _initData() {
    _sedes = [
      const Sede(
        id: 'sede-santiago',
        nombre: 'Santiago - Beauchef',
        modalidad: 'Presencial',
        institucion: 'Universidad de Chile (FCFM)',
        direccion: 'Beauchef 850, Santiago',
        cursosActivos: 3,
        alumnasTotales: 78,
        tutorasActivas: 14,
      ),
      const Sede(
        id: 'sede-valparaiso',
        nombre: 'Valparaíso',
        modalidad: 'Presencial',
        institucion: 'Universidad Técnica Federico Santa María',
        direccion: 'Av. España 1680, Valparaíso',
        cursosActivos: 2,
        alumnasTotales: 46,
        tutorasActivas: 8,
      ),
      const Sede(
        id: 'sede-concepcion',
        nombre: 'Concepción',
        modalidad: 'Presencial',
        institucion: 'Universidad de Concepción',
        direccion: 'Víctor Lamas 1290, Concepción',
        cursosActivos: 2,
        alumnasTotales: 50,
        tutorasActivas: 9,
      ),
      const Sede(
        id: 'sede-online',
        nombre: 'Modalidad Online Nacional',
        modalidad: 'Online',
        institucion: 'Plataforma Virtual NiñasPro',
        direccion: 'Discord + Google Meet',
        cursosActivos: 4,
        alumnasTotales: 120,
        tutorasActivas: 18,
      ),
    ];

    _cursos = [
      const Curso(
        id: 'curso-pcb-stgo',
        codigo: 'PCB-2026-STGO',
        nombre: 'Pensamiento Computacional en Python (Básico)',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        anio: 2026,
        semestre: 1,
        totalSesiones: 12,
        sesionesRealizadas: 4,
      ),
      const Curso(
        id: 'curso-pca-valpo',
        codigo: 'PCA-2026-VALP',
        nombre: 'Algoritmos y Estructuras de Datos (Avanzado)',
        sedeId: 'sede-valparaiso',
        sedeNombre: 'Valparaíso',
        anio: 2026,
        semestre: 1,
        totalSesiones: 12,
        sesionesRealizadas: 3,
      ),
      const Curso(
        id: 'curso-web-online',
        codigo: 'WEB-2026-ONL',
        nombre: 'Desarrollo Web Frontend y Ciencia de Datos',
        sedeId: 'sede-online',
        sedeNombre: 'Modalidad Online Nacional',
        anio: 2026,
        semestre: 1,
        totalSesiones: 12,
        sesionesRealizadas: 4,
      ),
    ];

    _alumnas = [
      Alumna(
        id: 'alumna-1',
        rut: '21.589.412-4',
        nombre: 'Valentina',
        apellido: 'Soto Morales',
        email: 'valentina.soto@colegio.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 87.5,
        asistenciasCount: 7,
        inasistenciasCount: 1,
        justificadasCount: 0,
        estadoMatricula: 'Activa',
        autorizaImagen: true,
        nombreApoderado: 'Claudia Morales Ruiz',
        telefonoApoderado: '+56 9 8451 2290',
        emailApoderado: 'claudia.morales@gmail.com',
        fechaInscripcion: DateTime(2026, 3, 5),
        historialCursosPrevios: const ['Robótica Educativa 2025 (Sede Santiago)'],
      ),
      Alumna(
        id: 'alumna-2',
        rut: '22.312.981-8',
        nombre: 'Isidora',
        apellido: 'Fuentes Carrasco',
        email: 'isidora.fuentes@liceo.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 100.0,
        asistenciasCount: 8,
        inasistenciasCount: 0,
        justificadasCount: 0,
        estadoMatricula: 'Activa',
        autorizaImagen: true,
        nombreApoderado: 'Jorge Fuentes Baeza',
        telefonoApoderado: '+56 9 9234 1189',
        emailApoderado: 'jorge.fuentes@empresa.cl',
        fechaInscripcion: DateTime(2026, 3, 6),
      ),
      Alumna(
        id: 'alumna-3',
        rut: '21.904.331-K',
        nombre: 'Florencia',
        apellido: 'Muñoz Tapia',
        email: 'florencia.munoz@colegio.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 50.0,
        asistenciasCount: 3,
        inasistenciasCount: 3,
        justificadasCount: 0,
        estadoMatricula: 'Condicionada',
        autorizaImagen: false,
        nombreApoderado: 'Marcela Tapia Lagos',
        telefonoApoderado: '+56 9 7112 4589',
        emailApoderado: 'marcela.tapia@outlook.cl',
        fechaInscripcion: DateTime(2026, 3, 8),
      ),
      Alumna(
        id: 'alumna-4',
        rut: '22.045.672-1',
        nombre: 'Catalina',
        apellido: 'Reyes Navarrete',
        email: 'catalina.reyes@escuela.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 75.0,
        asistenciasCount: 6,
        inasistenciasCount: 1,
        justificadasCount: 1,
        estadoMatricula: 'Activa',
        autorizaImagen: true,
        nombreApoderado: 'Pedro Reyes Ortiz',
        telefonoApoderado: '+56 9 6543 9081',
        emailApoderado: 'pedro.reyes@gmail.com',
        fechaInscripcion: DateTime(2026, 3, 9),
      ),
      Alumna(
        id: 'alumna-5',
        rut: '21.782.119-0',
        nombre: 'Martina',
        apellido: 'Araya Valenzuela',
        email: 'martina.araya@liceo.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 87.5,
        asistenciasCount: 7,
        inasistenciasCount: 1,
        justificadasCount: 0,
        estadoMatricula: 'Activa',
        autorizaImagen: true,
        nombreApoderado: 'Elena Valenzuela Silva',
        telefonoApoderado: '+56 9 8812 3456',
        emailApoderado: 'elena.valenzuela@vtr.net',
        fechaInscripcion: DateTime(2026, 3, 10),
      ),
      Alumna(
        id: 'alumna-6',
        rut: '22.883.190-7',
        nombre: 'Sofía',
        apellido: 'Contreras Pinto',
        email: 'sofia.contreras@colegio.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 100.0,
        asistenciasCount: 8,
        inasistenciasCount: 0,
        justificadasCount: 0,
        estadoMatricula: 'Activa',
        autorizaImagen: false, // Sin autorización de foto (US-19)
        nombreApoderado: 'Carolina Pinto Soto',
        telefonoApoderado: '+56 9 9123 7741',
        emailApoderado: 'carolina.pinto@gmail.com',
        fechaInscripcion: DateTime(2026, 3, 11),
      ),
      Alumna(
        id: 'alumna-7',
        rut: '21.654.891-3',
        nombre: 'Emilia',
        apellido: 'Vargas Silva',
        email: 'emilia.vargas@liceo.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 87.5,
        asistenciasCount: 7,
        inasistenciasCount: 0,
        justificadasCount: 1,
        estadoMatricula: 'Activa',
        autorizaImagen: true,
        nombreApoderado: 'Andrés Vargas Díaz',
        telefonoApoderado: '+56 9 7654 3210',
        emailApoderado: 'andres.vargas@empresa.com',
        fechaInscripcion: DateTime(2026, 3, 11),
      ),
      Alumna(
        id: 'alumna-8',
        rut: '22.190.542-5',
        nombre: 'Antonia',
        apellido: 'Gómez Castro',
        email: 'antonia.gomez@colegio.cl',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        porcentajeAsistencia: 100.0,
        asistenciasCount: 8,
        inasistenciasCount: 0,
        justificadasCount: 0,
        estadoMatricula: 'Activa',
        autorizaImagen: true,
        nombreApoderado: 'Lucía Castro Morales',
        telefonoApoderado: '+56 9 8221 4409',
        emailApoderado: 'lucia.castro@gmail.com',
        fechaInscripcion: DateTime(2026, 3, 12),
      ),
    ];

    _sesiones = [
      SesionClase(
        id: 'sesion-1',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        numeroSesion: 1,
        fecha: DateTime(2026, 4, 4),
        tema: 'Introducción a Algoritmos, Lógica y Scratch',
        estado: 'realizada',
        evidenciaSubida: true,
        fotosAptas: true,
      ),
      SesionClase(
        id: 'sesion-2',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        numeroSesion: 2,
        fecha: DateTime(2026, 4, 11),
        tema: 'Variables, Tipos de Datos y Operaciones en Python',
        estado: 'realizada',
        evidenciaSubida: true,
        fotosAptas: true,
      ),
      SesionClase(
        id: 'sesion-3',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        numeroSesion: 3,
        fecha: DateTime(2026, 4, 18),
        tema: 'Estructuras Condicionales: If, Elif y Else',
        estado: 'realizada',
        evidenciaSubida: true,
        fotosAptas: false, // Hubo foto pendiente de revisión
      ),
      SesionClase(
        id: 'sesion-4',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        numeroSesion: 4,
        fecha: DateTime(2026, 4, 25),
        tema: 'Bucles While y For con Listas Interactivas',
        estado: 'programada', // Sesión activa para pase de lista en el mockup
        evidenciaSubida: false,
        fotosAptas: true,
      ),
      SesionClase(
        id: 'sesion-5',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        numeroSesion: 5,
        fecha: DateTime(2026, 5, 2),
        tema: 'Funciones y Modularización de Código',
        estado: 'programada',
      ),
      SesionClase(
        id: 'sesion-6',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        numeroSesion: 6,
        fecha: DateTime(2026, 5, 9),
        tema: 'Desafío Intermedio: Juego de Adivinanzas',
        estado: 'programada',
      ),
    ];

    // Asistencias iniciales para la sesión activa (Clase 04)
    // Todas parten como presentes por defecto según US-13
    final registrosClase4 = _alumnas.map((a) {
      // Dejar a Florencia como ausente para demostrar la marcación rápida
      final esFlorencia = a.id == 'alumna-3';
      return RegistroAsistencia(
        id: 'asist-s4-${a.id}',
        sesionId: 'sesion-4',
        alumnaId: a.id,
        alumnaNombre: a.nombreCompleto,
        alumnaRut: a.rut,
        estado: esFlorencia ? EstadoAsistencia.ausente : EstadoAsistencia.presente,
        autorizaImagen: a.autorizaImagen,
        horaMarcado: DateTime.now(),
        registradaPor: 'Camila Sepúlveda (Tutora)',
      );
    }).toList();

    _asistenciasPorSesion = {
      'sesion-4': registrosClase4,
    };

    // Participaciones iniciales para sesión activa
    _participacionesPorSesion = {
      'sesion-4': _alumnas
          .where((a) => a.id != 'alumna-3') // solo presentes
          .map((a) => ParticipacionClase(
                id: 'part-s4-${a.id}',
                sesionId: 'sesion-4',
                alumnaId: a.id,
                alumnaNombre: a.nombreCompleto,
                ejerciciosResueltos: a.id == 'alumna-1' ? 4 : (a.id == 'alumna-2' ? 5 : 3),
                participacionActiva: true,
                podioKahoot: a.id == 'alumna-2' ? 1 : (a.id == 'alumna-1' ? 2 : null),
              ))
          .toList(),
    };

    // Alertas preventivas (US-39, US-40)
    _alertas = [
      AlertaDesercion(
        id: 'alerta-1',
        alumnaId: 'alumna-3',
        alumnaNombre: 'Florencia Muñoz Tapia',
        alumnaRut: '21.904.331-K',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        inasistenciasConsecutivas: 3,
        fechaGenerada: DateTime(2026, 4, 20),
        atendida: false,
      ),
    ];

    // Justificativos presentados (US-37)
    _justificativos = [
      Justificativo(
        id: 'just-1',
        alumnaId: 'alumna-4',
        alumnaNombre: 'Catalina Reyes Navarrete',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Pensamiento Computacional en Python',
        sesionId: 'sesion-3',
        fechaSesion: DateTime(2026, 4, 18),
        motivoTipificado: 'Salud',
        detalle: 'Presenté cuadro febril y reposo médico certificado durante el fin de semana.',
        fechaEnvio: DateTime(2026, 4, 19),
        estado: 'pendiente',
      ),
    ];

    // Red de voluntarias (US-30, US-32, US-33)
    _tutoras = [
      const Tutora(
        id: 'tutora-1',
        rut: '18.945.120-3',
        nombre: 'Camila Sepúlveda Rivas',
        email: 'camila.sepulveda@ninaspro.cl',
        telefono: '+56 9 8123 4567',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        rol: 'Coordinadora de Sede',
        adhesionFirmada: true,
        presenteClaseActual: true,
      ),
      const Tutora(
        id: 'tutora-2',
        rut: '19.231.890-5',
        nombre: 'Sofía Alarcón Medina',
        email: 'sofia.alarcon@ninaspro.cl',
        telefono: '+56 9 7234 5678',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        rol: 'Docente Guía',
        adhesionFirmada: true,
        presenteClaseActual: true,
      ),
      const Tutora(
        id: 'tutora-3',
        rut: '19.890.432-1',
        nombre: 'Mariana Loyola Castillo',
        email: 'mariana.loyola@ninaspro.cl',
        telefono: '+56 9 6345 6789',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        rol: 'Tutora de Sala',
        adhesionFirmada: true,
        presenteClaseActual: false,
      ),
      const Tutora(
        id: 'tutora-4',
        rut: '20.112.784-K',
        nombre: 'Constanza Rojas Beltrán',
        email: 'constanza.rojas@ninaspro.cl',
        telefono: '+56 9 9456 7890',
        sedeId: 'sede-santiago',
        sedeNombre: 'Santiago - Beauchef',
        rol: 'Tutora de Sala',
        adhesionFirmada: true,
        presenteClaseActual: true,
      ),
    ];
  }

  @override
  Future<List<Sede>> getSedes() async {
    return List.unmodifiable(_sedes);
  }

  @override
  Future<List<Curso>> getCursos({String? sedeId}) async {
    if (sedeId != null) {
      return _cursos.where((c) => c.sedeId == sedeId).toList();
    }
    return List.unmodifiable(_cursos);
  }

  @override
  Future<List<Alumna>> getAlumnas({String? cursoId, String? sedeId}) async {
    var resultado = _alumnas;
    if (cursoId != null) {
      resultado = resultado.where((a) => a.cursoId == cursoId).toList();
    }
    if (sedeId != null) {
      resultado = resultado.where((a) => a.sedeId == sedeId).toList();
    }
    return List.unmodifiable(resultado);
  }

  @override
  Future<Alumna?> getAlumnaById(String alumnaId) async {
    try {
      return _alumnas.firstWhere((a) => a.id == alumnaId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> registrarRetiroAlumna({required String alumnaId, required String motivo}) async {
    final idx = _alumnas.indexWhere((a) => a.id == alumnaId);
    if (idx != -1) {
      _alumnas[idx] = _alumnas[idx].copyWith(
        estadoMatricula: 'Retirada',
        retirado: true,
        motivoRetiro: motivo,
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<SesionClase>> getSesiones({required String cursoId}) async {
    return _sesiones.where((s) => s.cursoId == cursoId).toList();
  }

  @override
  Future<List<RegistroAsistencia>> getAsistenciaSesion({required String sesionId}) async {
    if (!_asistenciasPorSesion.containsKey(sesionId)) {
      // Crear estado inicial con todas presentes
      _asistenciasPorSesion[sesionId] = _alumnas.map((a) {
        return RegistroAsistencia(
          id: 'asist-$sesionId-${a.id}',
          sesionId: sesionId,
          alumnaId: a.id,
          alumnaNombre: a.nombreCompleto,
          alumnaRut: a.rut,
          estado: EstadoAsistencia.presente,
          autorizaImagen: a.autorizaImagen,
          horaMarcado: DateTime.now(),
          registradaPor: 'Tutora en Sala',
        );
      }).toList();
    }
    return List.unmodifiable(_asistenciasPorSesion[sesionId]!);
  }

  @override
  Future<bool> guardarAsistencia({
    required String sesionId,
    required List<RegistroAsistencia> registros,
  }) async {
    _asistenciasPorSesion[sesionId] = List.from(registros);

    // Marcar sesión como realizada si estaba programada (US-13 Escenario 3)
    final idxSesion = _sesiones.indexWhere((s) => s.id == sesionId);
    if (idxSesion != -1) {
      _sesiones[idxSesion] = _sesiones[idxSesion].copyWith(estado: 'realizada');
    }

    // Actualizar contadores de las alumnas
    for (final reg in registros) {
      final idxAlumna = _alumnas.indexWhere((a) => a.id == reg.alumnaId);
      if (idxAlumna != -1) {
        final a = _alumnas[idxAlumna];
        final total = a.asistenciasCount + (reg.estado == EstadoAsistencia.presente ? 1 : 0);
        final inas = a.inasistenciasCount + (reg.estado == EstadoAsistencia.ausente ? 1 : 0);
        final just = a.justificadasCount + (reg.estado == EstadoAsistencia.justificada ? 1 : 0);
        final suma = total + inas + just;
        final porc = suma > 0 ? ((total + just) / suma) * 100 : 100.0;
        _alumnas[idxAlumna] = a.copyWith(
          asistenciasCount: total,
          inasistenciasCount: inas,
          justificadasCount: just,
          porcentajeAsistencia: double.parse(porc.toStringAsFixed(1)),
        );
      }
    }

    return true;
  }

  @override
  Future<List<ParticipacionClase>> getParticipacionSesion({required String sesionId}) async {
    return _participacionesPorSesion[sesionId] ?? [];
  }

  @override
  Future<bool> guardarParticipacion({
    required String sesionId,
    required List<ParticipacionClase> participaciones,
  }) async {
    _participacionesPorSesion[sesionId] = List.from(participaciones);
    return true;
  }

  @override
  Future<List<AlertaDesercion>> getAlertasDesercion({String? sedeId}) async {
    if (sedeId != null) {
      return _alertas.where((al) => al.sedeId == sedeId).toList();
    }
    return List.unmodifiable(_alertas);
  }

  @override
  Future<bool> atenderAlertaDesercion({
    required String alertaId,
    required String observacion,
  }) async {
    final idx = _alertas.indexWhere((al) => al.id == alertaId);
    if (idx != -1) {
      _alertas[idx] = _alertas[idx].copyWith(
        atendida: true,
        fechaContacto: DateTime.now(),
        observacionGestion: observacion,
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<Justificativo>> getJustificativos({String? sedeId}) async {
    return List.unmodifiable(_justificativos);
  }

  @override
  Future<bool> resolverJustificativo({
    required String justificativoId,
    required String nuevoEstado,
    String? respuestaGestion,
  }) async {
    final idx = _justificativos.indexWhere((j) => j.id == justificativoId);
    if (idx != -1) {
      _justificativos[idx] = _justificativos[idx].copyWith(
        estado: nuevoEstado,
        respuestaGestion: respuestaGestion,
      );
      return true;
    }
    return false;
  }

  @override
  Future<PortalAlumnaData> getPortalAlumnaData({required String alumnaId}) async {
    final alumna = _alumnas.firstWhere(
      (a) => a.id == alumnaId,
      orElse: () => _alumnas.first,
    );
    final curso = _cursos.firstWhere(
      (c) => c.id == alumna.cursoId,
      orElse: () => _cursos.first,
    );
    final sesionesCurso = _sesiones.where((s) => s.cursoId == curso.id).toList();

    // Obtener asistencias históricas de la alumna
    final List<RegistroAsistencia> asistencias = [];
    for (final s in sesionesCurso) {
      final lista = _asistenciasPorSesion[s.id];
      if (lista != null) {
        final reg = lista.where((r) => r.alumnaId == alumna.id).firstOrNull;
        if (reg != null) asistencias.add(reg);
      }
    }

    final justs = _justificativos.where((j) => j.alumnaId == alumna.id).toList();

    return PortalAlumnaData(
      alumna: alumna,
      curso: curso,
      sesiones: sesionesCurso,
      asistencias: asistencias,
      participaciones: const [],
      justificativos: justs,
      posicionKahoot: 2,
      totalEjerciciosResueltos: 32,
    );
  }

  @override
  Future<bool> enviarJustificativo({
    required String alumnaId,
    required String sesionId,
    required String motivoTipificado,
    required String detalle,
  }) async {
    final alumna = await getAlumnaById(alumnaId);
    if (alumna == null) return false;

    final nuevoJust = Justificativo(
      id: 'just-${DateTime.now().millisecondsSinceEpoch}',
      alumnaId: alumnaId,
      alumnaNombre: alumna.nombreCompleto,
      cursoId: alumna.cursoId,
      cursoNombre: alumna.cursoNombre,
      sesionId: sesionId,
      fechaSesion: DateTime.now(),
      motivoTipificado: motivoTipificado,
      detalle: detalle,
      fechaEnvio: DateTime.now(),
      estado: 'pendiente',
    );
    _justificativos.add(nuevoJust);
    return true;
  }

  @override
  Future<List<Tutora>> getTutoras({String? sedeId}) async {
    if (sedeId != null) {
      return _tutoras.where((t) => t.sedeId == sedeId).toList();
    }
    return List.unmodifiable(_tutoras);
  }

  @override
  Future<bool> actualizarAsistenciaTutora({
    required String tutoraId,
    required bool presente,
  }) async {
    final idx = _tutoras.indexWhere((t) => t.id == tutoraId);
    if (idx != -1) {
      _tutoras[idx] = _tutoras[idx].copyWith(presenteClaseActual: presente);
      return true;
    }
    return false;
  }
}
