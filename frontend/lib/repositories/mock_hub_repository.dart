import '../config/ninaspro_theme.dart';
import '../models/hub_models.dart';
import 'hub_repository.dart';

/// Implementación sintética y en memoria de [HubRepository] con datos chilenos realistas y coherentes.
///
/// Permite validar todos los flujos de las 4 clasificaciones (Directiva, Gestión, Tutora, Alumna).
class MockHubRepository implements HubRepository {
  late List<Sede> _sedes;
  late List<Curso> _cursos;
  late List<Alumna> _alumnas;
  late List<SesionClase> _sesiones;
  late Map<String, List<RegistroAsistencia>> _asistenciasPorSesion;
  late Map<String, List<ParticipacionClase>> _participacionesPorSesion;
  late List<AlertaDesercion> _alertas;
  late List<Justificativo> _justificativos;
  late List<Tutora> _tutoras;
  late List<RolTutorConfig> _rolesConfig;
  late List<AsignacionSemanalTutora> _asignacionesSemanales;

  MockHubRepository() {
    _initData();
  }

  void _initData() {
    _sedes = [
      const Sede(
        id: 'sede-beauchef',
        nombre: 'Sede Beauchef',
        universidad: 'Universidad de Chile (FCFM)',
        region: 'Región Metropolitana',
        modalidad: 'Presencial',
        alumnasActivas: 78,
        capacidadTotal: 90,
        coordinadoraNombre: 'Camila Sepúlveda',
        estado: 'activa',
      ),
      const Sede(
        id: 'sede-san-joaquin',
        nombre: 'Sede San Joaquín',
        universidad: 'Pontificia Universidad Católica de Chile',
        region: 'Región Metropolitana',
        modalidad: 'Presencial',
        alumnasActivas: 65,
        capacidadTotal: 80,
        coordinadoraNombre: 'Valeria Troncoso',
        estado: 'activa',
      ),
      const Sede(
        id: 'sede-valparaiso',
        nombre: 'Sede Valparaíso',
        universidad: 'Universidad Técnica Federico Santa María',
        region: 'Valparaíso',
        modalidad: 'Presencial',
        alumnasActivas: 46,
        capacidadTotal: 60,
        coordinadoraNombre: 'Paula Gutiérrez',
        estado: 'activa',
      ),
    ];

    _cursos = [
      const Curso(
        id: 'curso-pcb-stgo',
        codigo: 'PCB-2026-STGO',
        nombre: 'Programación Competitiva Básica (Python)',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        anio: 2026,
        semestre: 1,
        totalSesiones: 10,
      ),
    ];

    _alumnas = [
      const Alumna(
        id: 'alumna-1',
        nombre: 'Valentina Soto Morales',
        rut: '22.341.890-4',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 87.5, // 7 de 8 clases realizadas
        asistenciasCount: 7,
        autorizaFoto: true,
        apoderadoNombre: 'Marcela Morales Gómez',
        apoderadoTelefono: '+56 9 8765 4321',
        estado: 'activa',
      ),
      const Alumna(
        id: 'alumna-2',
        nombre: 'Florencia Muñoz Tapia',
        rut: '21.904.331-K',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 62.5, // 5 de 8 clases (alerta)
        asistenciasCount: 5,
        autorizaFoto: false,
        apoderadoNombre: 'Claudio Muñoz Pavez',
        apoderadoTelefono: '+56 9 7654 3210',
        estado: 'activa',
      ),
      const Alumna(
        id: 'alumna-3',
        nombre: 'Catalina Reyes Navarrete',
        rut: '22.019.452-8',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 100.0, // 8 de 8
        asistenciasCount: 8,
        autorizaFoto: true,
        apoderadoNombre: 'Patricia Navarrete L.',
        apoderadoTelefono: '+56 9 6543 2109',
        estado: 'activa',
      ),
      const Alumna(
        id: 'alumna-4',
        nombre: 'Sofía Araya Bravo',
        rut: '21.876.543-2',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 37.5, // 3 de 8 (riesgo de deserción)
        asistenciasCount: 3,
        autorizaFoto: true,
        apoderadoNombre: 'Rodrigo Araya Silva',
        apoderadoTelefono: '+56 9 5432 1098',
        estado: 'activa',
      ),
      const Alumna(
        id: 'alumna-5',
        nombre: 'Martina Castro Díaz',
        rut: '22.145.678-9',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 87.5,
        asistenciasCount: 7,
        autorizaFoto: true,
        apoderadoNombre: 'Loreto Díaz Vega',
        apoderadoTelefono: '+56 9 4321 0987',
        estado: 'activa',
      ),
      const Alumna(
        id: 'alumna-6',
        nombre: 'Isidora Silva Vargas',
        rut: '21.998.765-1',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 75.0,
        asistenciasCount: 6,
        autorizaFoto: false,
        apoderadoNombre: 'Verónica Vargas Cruz',
        apoderadoTelefono: '+56 9 3210 9876',
        estado: 'activa',
      ),
      const Alumna(
        id: 'alumna-7',
        nombre: 'Emilia Morales Parra',
        rut: '22.456.123-0',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 100.0,
        asistenciasCount: 8,
        autorizaFoto: true,
        apoderadoNombre: 'Mauricio Morales B.',
        apoderadoTelefono: '+56 9 2109 8765',
        estado: 'activa',
      ),
      const Alumna(
        id: 'alumna-8',
        nombre: 'Amanda Contreras Lagos',
        rut: '21.789.012-3',
        cursoId: 'curso-pcb-stgo',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        porcentajeAsistencia: 87.5,
        asistenciasCount: 7,
        autorizaFoto: true,
        apoderadoNombre: 'Gloria Lagos Ruiz',
        apoderadoTelefono: '+56 9 1098 7654',
        estado: 'activa',
      ),
    ];

    // 10 sesiones: 8 realizadas, 2 programadas (US-26)
    _sesiones = [
      SesionClase(
        id: 'sesion-1',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 1,
        fecha: DateTime(2026, 4, 4),
        tema: 'Introducción a Algoritmos y Variables en Python',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-1-1',
            titulo: 'Diapositivas: Variables y Tipos de Datos',
            tipo: 'slides',
            url: 'https://slides.ninaspro.cl/pcb-clase-01',
          ),
          RecursoEducativo(
            id: 'rec-1-2',
            titulo: 'Google Colab: Práctica Guiada de Sintaxis',
            tipo: 'codigo',
            url: 'https://colab.research.google.com/drive/ninaspro-pcb-clase01',
          ),
        ],
        podioKahoot: const PodioKahootSesion(
          primerLugarAlumnaId: 'alumna-1',
          primerLugarNombre: 'Valentina Soto Morales',
          segundoLugarAlumnaId: 'alumna-3',
          segundoLugarNombre: 'Catalina Reyes Navarrete',
          tercerLugarAlumnaId: 'alumna-7',
          tercerLugarNombre: 'Emilia Morales Parra',
        ),
      ),
      SesionClase(
        id: 'sesion-2',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 2,
        fecha: DateTime(2026, 4, 11),
        tema: 'Estructuras de Control Condicionales (if/elif/else)',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-2-1',
            titulo: 'Guía PDF: Toma de Decisiones en Algoritmos',
            tipo: 'guia',
            url: 'https://materiales.ninaspro.cl/guias/guia-02-condicionales.pdf',
          ),
        ],
        podioKahoot: const PodioKahootSesion(
          primerLugarAlumnaId: 'alumna-7',
          primerLugarNombre: 'Emilia Morales Parra',
          segundoLugarAlumnaId: 'alumna-1',
          segundoLugarNombre: 'Valentina Soto Morales',
          tercerLugarAlumnaId: 'alumna-5',
          tercerLugarNombre: 'Martina Castro Díaz',
        ),
      ),
      SesionClase(
        id: 'sesion-3',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 3,
        fecha: DateTime(2026, 4, 18),
        tema: 'Bucles e Iteraciones (for y while)',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-3-1',
            titulo: 'Colab Notebook: Patrones y Ciclos Anidados',
            tipo: 'codigo',
            url: 'https://colab.research.google.com/drive/ninaspro-pcb-clase03',
          ),
        ],
        podioKahoot: const PodioKahootSesion(
          primerLugarAlumnaId: 'alumna-3',
          primerLugarNombre: 'Catalina Reyes Navarrete',
          segundoLugarAlumnaId: 'alumna-8',
          segundoLugarNombre: 'Amanda Contreras Lagos',
          tercerLugarAlumnaId: 'alumna-1',
          tercerLugarNombre: 'Valentina Soto Morales',
        ),
      ),
      SesionClase(
        id: 'sesion-4',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 4,
        fecha: DateTime(2026, 4, 25),
        tema: 'Funciones y Modularización del Código',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-4-1',
            titulo: 'Diapositivas: Alcance de Variables y Parámetros',
            tipo: 'slides',
            url: 'https://slides.ninaspro.cl/pcb-clase-04',
          ),
        ],
      ),
      SesionClase(
        id: 'sesion-5',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 5,
        fecha: DateTime(2026, 5, 2),
        tema: 'Listas, Tuplas y Métodos de Secuencia',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-5-1',
            titulo: 'Guía de Desafíos: Manipulación de Listas',
            tipo: 'guia',
            url: 'https://materiales.ninaspro.cl/guias/guia-05-listas.pdf',
          ),
        ],
      ),
      SesionClase(
        id: 'sesion-6',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 6,
        fecha: DateTime(2026, 5, 9),
        tema: 'Cadenas de Texto y Procesamiento de Caracteres',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-6-1',
            titulo: 'Colab: Criptografía y Cifrado César',
            tipo: 'codigo',
            url: 'https://colab.research.google.com/drive/ninaspro-pcb-clase06',
          ),
        ],
      ),
      SesionClase(
        id: 'sesion-7',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 7,
        fecha: DateTime(2026, 5, 16),
        tema: 'Diccionarios y Colecciones Clave-Valor',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-7-1',
            titulo: 'Video Sesión Grabada: Tablas Hash en Python',
            tipo: 'video',
            url: 'https://video.ninaspro.cl/grabaciones/sesion-07',
          ),
        ],
      ),
      SesionClase(
        id: 'sesion-8',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 8,
        fecha: DateTime(2026, 5, 23),
        tema: 'Técnicas de Búsqueda y Algoritmos Simples',
        estado: 'realizada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-8-1',
            titulo: 'Diapositivas: Búsqueda Lineal vs Binaria',
            tipo: 'slides',
            url: 'https://slides.ninaspro.cl/pcb-clase-08',
          ),
        ],
      ),
      SesionClase(
        id: 'sesion-9',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 9,
        fecha: DateTime(2026, 5, 30),
        tema: 'Simulacro de Competencia y Trabajo en Parejas',
        estado: 'programada',
        recursos: const [
          RecursoEducativo(
            id: 'rec-9-1',
            titulo: 'Reglamento y Pauta de Competencia',
            tipo: 'guia',
            url: 'https://materiales.ninaspro.cl/reglamentos/torneo-2026.pdf',
          ),
        ],
      ),
      SesionClase(
        id: 'sesion-10',
        cursoId: 'curso-pcb-stgo',
        numeroSesion: 10,
        fecha: DateTime(2026, 6, 6),
        tema: 'Torneo Final de Programación y Graduación',
        estado: 'programada',
        recursos: const [],
      ),
    ];

    // Asistencias coherentes para cada sesión
    _asistenciasPorSesion = {};
    for (final s in _sesiones) {
      if (s.estado == 'realizada') {
        _asistenciasPorSesion[s.id] = _alumnas.map((a) {
          // Valentina (alumna-1): ausente solo en sesión 3
          EstadoAsistencia estado = EstadoAsistencia.presente;
          if (a.id == 'alumna-1' && s.id == 'sesion-3') {
            estado = EstadoAsistencia.ausente;
          } else if (a.id == 'alumna-2') {
            // Florencia: justificada en sesion 2, ausente en 4 y 6
            if (s.id == 'sesion-2') {
              estado = EstadoAsistencia.justificada;
            } else if (s.id == 'sesion-4' || s.id == 'sesion-6') {
              estado = EstadoAsistencia.ausente;
            }
          } else if (a.id == 'alumna-4') {
            // Sofía: ausente en sesiones 5, 6, 7, 8 (alerta activa)
            if (['sesion-5', 'sesion-6', 'sesion-7', 'sesion-8'].contains(s.id)) {
              estado = EstadoAsistencia.ausente;
            }
          }

          return RegistroAsistencia(
            id: 'asist-${s.id}-${a.id}',
            sesionId: s.id,
            alumnaId: a.id,
            alumnaNombre: a.nombre,
            alumnaRut: a.rut,
            estado: estado,
            horaMarcado: DateTime.now(),
            autorizaImagen: a.autorizaFoto,
          );
        }).toList();
      } else {
        _asistenciasPorSesion[s.id] = _alumnas.map((a) {
          return RegistroAsistencia(
            id: 'asist-${s.id}-${a.id}',
            sesionId: s.id,
            alumnaId: a.id,
            alumnaNombre: a.nombre,
            alumnaRut: a.rut,
            estado: EstadoAsistencia.pendiente,
            autorizaImagen: a.autorizaFoto,
          );
        }).toList();
      }
    }

    _participacionesPorSesion = {
      'sesion-4': _alumnas.map((a) {
        return ParticipacionClase(
          id: 'part-s4-${a.id}',
          sesionId: 'sesion-4',
          alumnaId: a.id,
          alumnaNombre: a.nombre,
          ejerciciosResueltos: a.id == 'alumna-1' ? 4 : 3,
          participacionActiva: true,
        );
      }).toList(),
    };

    _alertas = [
      const AlertaDesercion(
        id: 'alerta-1',
        alumnaId: 'alumna-4',
        alumnaNombre: 'Sofía Araya Bravo',
        sedeNombre: 'Sede Beauchef',
        inasistenciasConsecutivas: 4,
        apoderadoContacto: 'Rodrigo Araya (+56 9 5432 1098)',
        estado: 'activa',
      ),
      const AlertaDesercion(
        id: 'alerta-2',
        alumnaId: 'alumna-2',
        alumnaNombre: 'Florencia Muñoz Tapia',
        sedeNombre: 'Sede Beauchef',
        inasistenciasConsecutivas: 2,
        apoderadoContacto: 'Claudio Muñoz (+56 9 7654 3210)',
        estado: 'contactada',
        observacionesContacto: 'Contacto por WhatsApp: justificó tope escolar y repasará con Colab.',
      ),
    ];

    _justificativos = [
      Justificativo(
        id: 'just-1',
        alumnaId: 'alumna-2',
        alumnaNombre: 'Florencia Muñoz Tapia',
        sesionId: 'sesion-2',
        sesionFecha: DateTime(2026, 4, 11),
        motivoTipificado: 'Salud',
        detalle: 'Cuadro febril con reposo de fin de semana.',
        estado: 'aprobado',
        observacionesResolucion: 'Certificado de atención primaria validado por coordinación.',
      ),
      Justificativo(
        id: 'just-2',
        alumnaId: 'alumna-1',
        alumnaNombre: 'Valentina Soto Morales',
        sesionId: 'sesion-3',
        sesionFecha: DateTime(2026, 4, 18),
        motivoTipificado: 'Familiar',
        detalle: 'Viaje familiar fuera de Santiago.',
        estado: 'pendiente',
      ),
    ];

    // Tutoras con flag esEquipoGestion (US-43)
    _tutoras = [
      const Tutora(
        id: 'tutora-1',
        nombre: 'Camila Sepúlveda Rivas',
        rol: 'Coordinadora de Sede & Tutora',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: true,
      ),
      const Tutora(
        id: 'tutora-2',
        nombre: 'Valeria Troncoso Morales',
        rol: 'Tutora Líder de Aula',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: true,
      ),
      const Tutora(
        id: 'tutora-3',
        nombre: 'Daniela Valenzuela Castro',
        rol: 'Tutora de Acompañamiento',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: false,
      ),
      const Tutora(
        id: 'tutora-4',
        nombre: 'Francisca Herrera Rojas',
        rol: 'Tutora de Apoyo Técnico',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: false,
        presenteClaseActual: false,
        esEquipoGestion: false,
      ),
    ];

    // Catálogo de roles dinámicos (US-43)
    _rolesConfig = [
      const RolTutorConfig(
        codigo: 'facilitadora',
        nombre: 'Facilitadora Principal',
        descripcion: 'Lidera la explicación en pizarra y guía la sesión',
        colorHex: '#79207E',
        esRequerido: true,
      ),
      const RolTutorConfig(
        codigo: 'co_facilitadora',
        nombre: 'Co-facilitadora',
        descripcion: 'Acompaña a las alumnas resolviendo dudas en sala',
        colorHex: '#FF3593',
        esRequerido: true,
      ),
      const RolTutorConfig(
        codigo: 'soporte_tecnico',
        nombre: 'Soporte Técnico',
        descripcion: 'Resuelve problemas de computadores, internet y Python',
        colorHex: '#4A90E2',
        esRequerido: false,
      ),
      const RolTutorConfig(
        codigo: 'logistica_materiales',
        nombre: 'Logística y Registro',
        descripcion: 'Control de colaciones, credenciales y asistencia',
        colorHex: '#00A86B',
        esRequerido: false,
      ),
    ];

    _asignacionesSemanales = [
      const AsignacionSemanalTutora(
        tutoraId: 'tutora-1',
        tutoraNombre: 'Camila Sepúlveda Rivas',
        semanaNumero: 4,
        rolCodigo: 'facilitadora',
      ),
      const AsignacionSemanalTutora(
        tutoraId: 'tutora-2',
        tutoraNombre: 'Valeria Troncoso Morales',
        semanaNumero: 4,
        rolCodigo: 'co_facilitadora',
      ),
      const AsignacionSemanalTutora(
        tutoraId: 'tutora-3',
        tutoraNombre: 'Daniela Valenzuela Castro',
        semanaNumero: 4,
        rolCodigo: 'soporte_tecnico',
      ),
    ];
  }

  @override
  Future<List<Sede>> getSedes() async => List.unmodifiable(_sedes);

  @override
  Future<List<Curso>> getCursos({String? sedeId}) async {
    if (sedeId == null) return List.unmodifiable(_cursos);
    return _cursos.where((c) => c.sedeId == sedeId).toList();
  }

  @override
  Future<List<Alumna>> getAlumnas({String? cursoId, String? sedeId}) async {
    return _alumnas.where((a) {
      final matchCurso = cursoId == null || a.cursoId == cursoId;
      final matchSede = sedeId == null || a.sedeId == sedeId;
      return matchCurso && matchSede;
    }).toList();
  }

  @override
  Future<Alumna?> getAlumnaById(String alumnaId) async {
    return _alumnas.where((a) => a.id == alumnaId).firstOrNull;
  }

  @override
  Future<bool> registrarRetiroAlumna({
    required String alumnaId,
    required String motivo,
  }) async {
    final idx = _alumnas.indexWhere((a) => a.id == alumnaId);
    if (idx == -1) return false;
    _alumnas[idx] = _alumnas[idx].copyWith(
      estado: 'retirada',
      motivoRetiro: motivo,
    );
    return true;
  }

  @override
  Future<List<SesionClase>> getSesiones({required String cursoId}) async {
    return _sesiones.where((s) => s.cursoId == cursoId).toList();
  }

  @override
  Future<List<RegistroAsistencia>> getAsistenciaSesion({
    required String sesionId,
  }) async {
    return _asistenciasPorSesion[sesionId] ?? [];
  }

  @override
  Future<bool> guardarAsistencia({
    required String sesionId,
    required List<RegistroAsistencia> registros,
  }) async {
    _asistenciasPorSesion[sesionId] = List.from(registros);
    return true;
  }

  @override
  Future<List<ParticipacionClase>> getParticipacionSesion({
    required String sesionId,
  }) async {
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
  Future<bool> guardarPodioKahoot({
    required String sesionId,
    required String primerLugarAlumnaId,
    required String segundoLugarAlumnaId,
    required String tercerLugarAlumnaId,
  }) async {
    final idx = _sesiones.indexWhere((s) => s.id == sesionId);
    if (idx == -1) return false;

    final n1 = _alumnas.where((a) => a.id == primerLugarAlumnaId).firstOrNull?.nombre ?? 'Alumna 1';
    final n2 = _alumnas.where((a) => a.id == segundoLugarAlumnaId).firstOrNull?.nombre ?? 'Alumna 2';
    final n3 = _alumnas.where((a) => a.id == tercerLugarAlumnaId).firstOrNull?.nombre ?? 'Alumna 3';

    _sesiones[idx] = _sesiones[idx].copyWith(
      podioKahoot: PodioKahootSesion(
        primerLugarAlumnaId: primerLugarAlumnaId,
        primerLugarNombre: n1,
        segundoLugarAlumnaId: segundoLugarAlumnaId,
        segundoLugarNombre: n2,
        tercerLugarAlumnaId: tercerLugarAlumnaId,
        tercerLugarNombre: n3,
      ),
    );
    return true;
  }

  @override
  Future<List<AlertaDesercion>> getAlertasDesercion({String? sedeId}) async {
    return List.unmodifiable(_alertas);
  }

  @override
  Future<bool> contactarAlerta({
    required String alertaId,
    required String observacionesContacto,
  }) async {
    final idx = _alertas.indexWhere((a) => a.id == alertaId);
    if (idx == -1) return false;
    _alertas[idx] = _alertas[idx].copyWith(
      estado: 'contactada',
      observacionesContacto: observacionesContacto,
    );
    return true;
  }

  @override
  Future<List<Justificativo>> getJustificativos() async => List.unmodifiable(_justificativos);

  @override
  Future<bool> enviarJustificativo({
    required String alumnaId,
    required String sesionId,
    required String motivoTipificado,
    required String detalle,
  }) async {
    final alumna = await getAlumnaById(alumnaId);
    if (alumna == null) return false;

    final sesion = _sesiones.where((s) => s.id == sesionId).firstOrNull;
    final fecha = sesion?.fecha ?? DateTime.now();

    final nuevo = Justificativo(
      id: 'just-${DateTime.now().millisecondsSinceEpoch}',
      alumnaId: alumnaId,
      alumnaNombre: alumna.nombre,
      sesionId: sesionId,
      sesionFecha: fecha,
      motivoTipificado: motivoTipificado,
      detalle: detalle,
      estado: 'pendiente',
    );
    _justificativos.insert(0, nuevo);
    return true;
  }

  @override
  Future<bool> resolverJustificativo({
    required String justificativoId,
    required bool aprobado,
    String? observaciones,
  }) async {
    final idx = _justificativos.indexWhere((j) => j.id == justificativoId);
    if (idx == -1) return false;
    _justificativos[idx] = _justificativos[idx].copyWith(
      estado: aprobado ? 'aprobado' : 'rechazado',
      observacionesResolucion: observaciones,
    );
    return true;
  }

  @override
  Future<PortalAlumnaData> getPortalAlumnaData({required String alumnaId}) async {
    final alumna = _alumnas.firstWhere(
      (a) => a.id == alumnaId,
      orElse: () => _alumnas.first,
    );
    final curso = _cursos.firstWhere((c) => c.id == alumna.cursoId);
    final sesiones = _sesiones.where((s) => s.cursoId == curso.id).toList();

    // Asistencias de la alumna
    final asistencias = <RegistroAsistencia>[];
    for (final s in sesiones) {
      final reg = _asistenciasPorSesion[s.id]?.where((r) => r.alumnaId == alumnaId).firstOrNull;
      if (reg != null) asistencias.add(reg);
    }

    final justs = _justificativos.where((j) => j.alumnaId == alumnaId).toList();

    // Conteo de podios Kahoot históricos (US-29)
    int primer = 0;
    int segundo = 0;
    int tercer = 0;
    for (final s in sesiones) {
      if (s.podioKahoot?.primerLugarAlumnaId == alumnaId) primer++;
      if (s.podioKahoot?.segundoLugarAlumnaId == alumnaId) segundo++;
      if (s.podioKahoot?.tercerLugarAlumnaId == alumnaId) tercer++;
    }

    // Regla de ejercicios: 25 ejercicios = 1 clase recuperable, 50 ejercicios = 2 clases (máx 2)
    final totalEjercicios = alumnaId == 'alumna-1' ? 48 : (alumnaId == 'alumna-2' ? 52 : 30);
    final clasesRecuperadas = (totalEjercicios ~/ 25).clamp(0, 2);

    // Umbral de aprobación: 80% base, o 70% si cuenta con al menos 1 justificativo aprobado
    final tieneJustificativoAprobado = justs.any((j) => j.estado == 'aprobado');
    final umbral = tieneJustificativoAprobado ? 70.0 : 80.0;

    return PortalAlumnaData(
      alumna: alumna,
      curso: curso,
      sesiones: sesiones,
      asistencias: asistencias,
      justificativos: justs,
      podiosPrimerLugar: primer,
      podiosSegundoLugar: segundo,
      podiosTercerLugar: tercer,
      totalEjerciciosResueltos: totalEjercicios,
      umbralAprobacion: umbral,
      clasesRecuperadasPorEjercicios: clasesRecuperadas,
    );
  }

  @override
  Future<List<Tutora>> getTutoras() async => List.unmodifiable(_tutoras);

  @override
  Future<bool> actualizarAsistenciaTutora({
    required String tutoraId,
    required bool presente,
  }) async {
    final idx = _tutoras.indexWhere((t) => t.id == tutoraId);
    if (idx == -1) return false;
    _tutoras[idx] = _tutoras[idx].copyWith(presenteClaseActual: presente);
    return true;
  }

  @override
  Future<List<RolTutorConfig>> getRolesTutora() async => List.unmodifiable(_rolesConfig);

  @override
  Future<bool> crearRolTutora(RolTutorConfig rol) async {
    _rolesConfig.add(rol);
    return true;
  }

  @override
  Future<bool> actualizarRolTutora(RolTutorConfig rol) async {
    final idx = _rolesConfig.indexWhere((r) => r.codigo == rol.codigo);
    if (idx == -1) return false;
    _rolesConfig[idx] = rol;
    return true;
  }

  @override
  Future<List<AsignacionSemanalTutora>> getAsignacionesSemanales({
    required int semanaNumero,
  }) async {
    return _asignacionesSemanales.where((a) => a.semanaNumero == semanaNumero).toList();
  }

  @override
  Future<bool> asignarRolSemanal({
    required String tutoraId,
    required int semanaNumero,
    required String rolCodigo,
  }) async {
    final tutora = _tutoras.where((t) => t.id == tutoraId).firstOrNull;
    if (tutora == null) return false;

    _asignacionesSemanales.removeWhere(
      (a) => a.tutoraId == tutoraId && a.semanaNumero == semanaNumero,
    );
    _asignacionesSemanales.add(
      AsignacionSemanalTutora(
        tutoraId: tutoraId,
        tutoraNombre: tutora.nombre,
        semanaNumero: semanaNumero,
        rolCodigo: rolCodigo,
      ),
    );
    return true;
  }
}
