import 'package:flutter/foundation.dart';
import '../config/ninaspro_theme.dart';
import '../models/hub_models.dart';
import '../utils/rut.dart';
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
  late Map<String, List<RegistroAsistenciaTutora>> _asistenciaTutorasPorSesion;
  late List<CursoCatalogo> _catalogoCursos;
  late List<EventoAuditoria> _eventosAuditoria;
  var _contadorIds = 0;

  // Clase en curso del mockup (Sábado 25 de Abril)
  static const _sesionActualId = 'sesion-4';

  /// Tiempo simulado que tarda una recarga o la subida de los cambios pendientes
  static const demoraSincronizacion = Duration(seconds: 1);

  final _estadoSincronizacion = ValueNotifier(EstadoSincronizacion.sincronizado);
  final _cambiosPendientes = ValueNotifier(0);
  var _conectado = true;

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
        coordinadoraNombre: 'Camila Sepúlveda',
        estado: 'activa',
      ),
      const Sede(
        id: 'sede-san-joaquin',
        nombre: 'Sede San Joaquín',
        universidad: 'Pontificia Universidad Católica de Chile',
        region: 'Región Metropolitana',
        modalidad: 'Presencial',
        coordinadoraNombre: 'Valeria Troncoso',
        estado: 'activa',
      ),
      const Sede(
        id: 'sede-valparaiso',
        nombre: 'Sede Valparaíso',
        universidad: 'Universidad Técnica Federico Santa María',
        region: 'Valparaíso',
        modalidad: 'Presencial',
        coordinadoraNombre: 'Paula Gutiérrez',
        estado: 'activa',
      ),
    ];

    // Catálogo general de cursos (US-01)
    _catalogoCursos = [
      const CursoCatalogo(
        id: 'cat-pcb',
        codigo: 'PCB',
        nombre: 'Programación Competitiva Básica (Python)',
        descripcion: 'Fundamentos de algoritmos y Python orientados a competencias.',
      ),
      const CursoCatalogo(
        id: 'cat-web',
        codigo: 'WEB',
        nombre: 'Desarrollo Web Inicial',
        descripcion: 'HTML, CSS y JavaScript para crear el primer sitio propio.',
      ),
      const CursoCatalogo(
        id: 'cat-pci',
        codigo: 'PCI',
        nombre: 'Programación Competitiva Intermedia',
        descripcion: 'Estructuras de datos y técnicas para olimpiadas de programación.',
      ),
    ];

    // Una instancia de curso por sede, con un Classroom y un VJudge cada una
    _cursos = [
      Curso(
        id: 'curso-pcb-stgo',
        codigo: 'PCB-2026-STGO',
        nombre: 'Programación Competitiva Básica (Python)',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        anio: 2026,
        semestre: 1,
        totalSesiones: 10,
        classroomUrl: 'https://classroom.google.com/c/NjQ5ODcyMzQ1Njc4',
        juezVirtualUrl: 'https://vjudge.net/group/ninaspro-pcb-2026',
        catalogoId: 'cat-pcb',
        fechaInicio: DateTime(2026, 4, 4),
        fechaTermino: DateTime(2026, 6, 6),
      ),
      Curso(
        id: 'curso-pcb-sj',
        codigo: 'PCB-2026-SJ',
        nombre: 'Programación Competitiva Básica (Python)',
        sedeId: 'sede-san-joaquin',
        sedeNombre: 'Sede San Joaquín',
        anio: 2026,
        semestre: 1,
        totalSesiones: 10,
        classroomUrl: 'https://classroom.google.com/c/NzE2MzQ1OTg3MjEw',
        juezVirtualUrl: 'https://vjudge.net/group/ninaspro-pcb-sj-2026',
        catalogoId: 'cat-pcb',
        fechaInicio: DateTime(2026, 4, 4),
        fechaTermino: DateTime(2026, 6, 6),
      ),
      Curso(
        id: 'curso-web-valpo',
        codigo: 'WEB-2026-VALPO',
        nombre: 'Desarrollo Web Inicial',
        sedeId: 'sede-valparaiso',
        sedeNombre: 'Sede Valparaíso',
        anio: 2026,
        semestre: 1,
        totalSesiones: 8,
        classroomUrl: 'https://classroom.google.com/c/ODg0NTEyMzY5ODc0',
        juezVirtualUrl: 'https://vjudge.net/group/ninaspro-web-valpo-2026',
        catalogoId: 'cat-web',
        fechaInicio: DateTime(2026, 4, 4),
        fechaTermino: DateTime(2026, 5, 23),
      ),
    ];

    _alumnas = [
      const Alumna(
        id: 'alumna-1',
        nombre: 'Valentina Soto Morales',
        rut: '22.341.890-2',
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
        rut: '21.904.331-7',
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
        rut: '22.019.452-3',
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
        rut: '22.145.678-5',
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
        rut: '21.998.765-K',
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
        rut: '22.456.123-7',
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
        rut: '21.789.012-8',
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
      // Sede San Joaquín
      const Alumna(
        id: 'alumna-9',
        nombre: 'Josefa Ñancupil Rojas',
        rut: '22.567.301-2',
        cursoId: 'curso-pcb-sj',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-san-joaquin',
        sedeNombre: 'Sede San Joaquín',
        porcentajeAsistencia: 100.0,
        asistenciasCount: 4,
        autorizaFoto: true,
        apoderadoNombre: 'Ximena Rojas Peña',
        apoderadoTelefono: '+56 9 8123 4567',
      ),
      const Alumna(
        id: 'alumna-10',
        nombre: 'Agustina Pérez Ulloa',
        rut: '22.678.412-8',
        cursoId: 'curso-pcb-sj',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-san-joaquin',
        sedeNombre: 'Sede San Joaquín',
        porcentajeAsistencia: 75.0,
        asistenciasCount: 3,
        autorizaFoto: true,
        apoderadoNombre: 'Andrés Pérez Lillo',
        apoderadoTelefono: '+56 9 8234 5678',
      ),
      const Alumna(
        id: 'alumna-11',
        nombre: 'Trinidad González Mella',
        rut: '22.789.523-3',
        cursoId: 'curso-pcb-sj',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-san-joaquin',
        sedeNombre: 'Sede San Joaquín',
        porcentajeAsistencia: 50.0,
        asistenciasCount: 2,
        autorizaFoto: false,
        apoderadoNombre: 'Carolina Mella Soto',
        apoderadoTelefono: '+56 9 8345 6789',
      ),
      // Retirada: su ficha se reutiliza si vuelve a inscribirse (US-09)
      Alumna(
        id: 'alumna-12',
        nombre: 'Renata Ibáñez Cortés',
        rut: '22.890.634-4',
        cursoId: 'curso-pcb-sj',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-san-joaquin',
        sedeNombre: 'Sede San Joaquín',
        porcentajeAsistencia: 25.0,
        asistenciasCount: 1,
        autorizaFoto: true,
        apoderadoNombre: 'Pablo Ibáñez Ruiz',
        apoderadoTelefono: '+56 9 8456 7890',
        estado: 'retirada',
        motivoRetiro: 'Cambio de domicilio a otra región',
        fechaRetiro: DateTime(2026, 4, 20),
      ),
      // Sede Valparaíso
      const Alumna(
        id: 'alumna-13',
        nombre: 'Maite Olivares Brito',
        rut: '22.301.745-2',
        cursoId: 'curso-web-valpo',
        cursoNombre: 'Desarrollo Web Inicial',
        sedeId: 'sede-valparaiso',
        sedeNombre: 'Sede Valparaíso',
        porcentajeAsistencia: 100.0,
        asistenciasCount: 4,
        autorizaFoto: true,
        apoderadoNombre: 'Daniela Brito Vera',
        apoderadoTelefono: '+56 9 8567 8901',
      ),
      const Alumna(
        id: 'alumna-14',
        nombre: 'Colomba Fernández Aguirre',
        rut: '22.412.856-8',
        cursoId: 'curso-web-valpo',
        cursoNombre: 'Desarrollo Web Inicial',
        sedeId: 'sede-valparaiso',
        sedeNombre: 'Sede Valparaíso',
        porcentajeAsistencia: 75.0,
        asistenciasCount: 3,
        autorizaFoto: true,
        apoderadoNombre: 'Héctor Fernández Saa',
        apoderadoTelefono: '+56 9 8678 9012',
      ),
      const Alumna(
        id: 'alumna-15',
        nombre: 'Ignacia Muñoz Vergara',
        rut: '22.523.967-3',
        cursoId: 'curso-web-valpo',
        cursoNombre: 'Desarrollo Web Inicial',
        sedeId: 'sede-valparaiso',
        sedeNombre: 'Sede Valparaíso',
        porcentajeAsistencia: 25.0,
        asistenciasCount: 1,
        autorizaFoto: false,
        apoderadoNombre: 'Rosa Vergara Pinto',
        apoderadoTelefono: '+56 9 8789 0123',
      ),
    ];

    // Correo del apoderado y autorizaciones derivadas de autorizaFoto (US-10)
    _alumnas = _alumnas.map((a) {
      final correo = '${_slug(a.apoderadoNombre.split(' ').take(2).join('.'))}@correo.cl';
      return a.copyWith(
        apoderadoCorreo: correo,
        autorizaciones: AutorizacionesAlumna(
          tratamientoDatos: true,
          canales: a.autorizaFoto
              ? {for (final c in CanalImagen.values) c: EstadoAutorizacion.otorgada}
              : const {},
          respaldoNombre: 'autorizacion_${a.id}.pdf',
          fechaRegistro: DateTime(2026, 3, 28),
        ),
      );
    }).toList();

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
        podioKahoot: const PodioKahootSesion(
          primerLugarAlumnaId: 'alumna-7',
          primerLugarNombre: 'Emilia Morales Parra',
          segundoLugarAlumnaId: 'alumna-1',
          segundoLugarNombre: 'Valentina Soto Morales',
          tercerLugarAlumnaId: 'alumna-2',
          tercerLugarNombre: 'Florencia Muñoz Tapia',
        ),
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
        podioKahoot: const PodioKahootSesion(
          primerLugarAlumnaId: 'alumna-3',
          primerLugarNombre: 'Catalina Reyes Navarrete',
          segundoLugarAlumnaId: 'alumna-1',
          segundoLugarNombre: 'Valentina Soto Morales',
          tercerLugarAlumnaId: 'alumna-8',
          tercerLugarNombre: 'Amanda Contreras Lagos',
        ),
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
        podioKahoot: const PodioKahootSesion(
          primerLugarAlumnaId: 'alumna-5',
          primerLugarNombre: 'Martina Castro Díaz',
          segundoLugarAlumnaId: 'alumna-1',
          segundoLugarNombre: 'Valentina Soto Morales',
          tercerLugarAlumnaId: 'alumna-3',
          tercerLugarNombre: 'Catalina Reyes Navarrete',
        ),
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
        podioKahoot: const PodioKahootSesion(
          primerLugarAlumnaId: 'alumna-7',
          primerLugarNombre: 'Emilia Morales Parra',
          segundoLugarAlumnaId: 'alumna-4',
          segundoLugarNombre: 'Sofía Araya Bravo',
          tercerLugarAlumnaId: 'alumna-8',
          tercerLugarNombre: 'Amanda Contreras Lagos',
        ),
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

    // Sesiones de las otras sedes: realizadas hasta la clase de hoy (25 de abril)
    const temasWeb = [
      'Cómo funciona la Web y primer HTML',
      'Estructura de páginas con HTML semántico',
      'Estilos con CSS: colores y tipografías',
      'Diseño con Flexbox',
      'Primeros pasos con JavaScript',
      'Eventos e interacción en la página',
      'Publicar mi sitio en Internet',
      'Feria de proyectos y graduación',
    ];
    final temasPcb = _sesiones.map((s) => s.tema).toList();
    for (final curso in _cursos.where((c) => c.id != 'curso-pcb-stgo')) {
      final temas = curso.catalogoId == 'cat-web' ? temasWeb : temasPcb;
      for (var n = 1; n <= curso.totalSesiones; n++) {
        _sesiones.add(
          SesionClase(
            id: 'sesion-${curso.id}-$n',
            cursoId: curso.id,
            numeroSesion: n,
            fecha: DateTime(2026, 4, 4 + 7 * (n - 1)),
            tema: temas[(n - 1) % temas.length],
            estado: n <= 4 ? 'realizada' : 'programada',
          ),
        );
      }
    }

    // Asistencias coherentes para cada sesión
    _asistenciasPorSesion = {};
    for (final s in _sesiones.where((s) => s.cursoId != 'curso-pcb-stgo')) {
      final alumnasCurso = _alumnas.where((a) => a.cursoId == s.cursoId).toList();
      _asistenciasPorSesion[s.id] = [
        for (final a in alumnasCurso)
          RegistroAsistencia(
            id: 'asist-${s.id}-${a.id}',
            sesionId: s.id,
            alumnaId: a.id,
            alumnaNombre: a.nombre,
            alumnaRut: a.rut,
            // Ausencias según el % de asistencia de cada alumna
            estado: s.estado != 'realizada'
                ? EstadoAsistencia.pendiente
                : (s.numeroSesion <= a.asistenciasCount
                    ? EstadoAsistencia.presente
                    : EstadoAsistencia.ausente),
            horaMarcado: s.estado == 'realizada' ? s.fecha : null,
            autorizaImagen: a.autorizaFoto,
          ),
      ];
    }
    final alumnasBeauchef = _alumnas.where((a) => a.cursoId == 'curso-pcb-stgo').toList();
    for (final s in _sesiones.where((s) => s.cursoId == 'curso-pcb-stgo')) {
      if (s.estado == 'realizada') {
        _asistenciasPorSesion[s.id] = alumnasBeauchef.map((a) {
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
        _asistenciasPorSesion[s.id] = alumnasBeauchef.map((a) {
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
      'sesion-4': alumnasBeauchef.map((a) {
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
      const AlertaDesercion(
        id: 'alerta-3',
        alumnaId: 'alumna-15',
        alumnaNombre: 'Ignacia Muñoz Vergara',
        sedeNombre: 'Sede Valparaíso',
        inasistenciasConsecutivas: 3,
        apoderadoContacto: 'Rosa Vergara (+56 9 8789 0123)',
        estado: 'activa',
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
      Justificativo(
        id: 'just-3',
        alumnaId: 'alumna-11',
        alumnaNombre: 'Trinidad González Mella',
        sesionId: 'sesion-curso-pcb-sj-3',
        sesionFecha: DateTime(2026, 4, 18),
        motivoTipificado: 'Académico',
        detalle: 'Prueba de nivel en su colegio el mismo sábado.',
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
      const Tutora(
        id: 'tutora-5',
        nombre: 'Javiera Muñoz Pizarro',
        rol: 'Tutora de Acompañamiento',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: false,
      ),
      const Tutora(
        id: 'tutora-6',
        nombre: 'Antonia Reyes Fuentes',
        rol: 'Tutora de Contenidos',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: false,
      ),
      const Tutora(
        id: 'tutora-7',
        nombre: 'Catalina Soto Navarro',
        rol: 'Tutora de Acompañamiento',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: false,
      ),
      const Tutora(
        id: 'tutora-8',
        nombre: 'Martina Lagos Vidal',
        rol: 'Tutora de Apoyo Técnico',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        adhesionFirmada: true,
        presenteClaseActual: false,
        esEquipoGestion: false,
      ),
    ];

    // Voluntarias de las otras sedes
    _tutoras.addAll(const [
      Tutora(
        id: 'tutora-9',
        nombre: 'Valeria Troncoso Fuentes',
        rol: 'Coordinadora de Sede & Tutora',
        sedeId: 'sede-san-joaquin',
        sedeNombre: 'Sede San Joaquín',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: true,
      ),
      Tutora(
        id: 'tutora-10',
        nombre: 'Fernanda Pizarro León',
        rol: 'Tutora de Acompañamiento',
        sedeId: 'sede-san-joaquin',
        sedeNombre: 'Sede San Joaquín',
        adhesionFirmada: true,
        presenteClaseActual: true,
      ),
      Tutora(
        id: 'tutora-11',
        nombre: 'Paula Gutiérrez Saavedra',
        rol: 'Coordinadora de Sede & Tutora',
        sedeId: 'sede-valparaiso',
        sedeNombre: 'Sede Valparaíso',
        adhesionFirmada: true,
        presenteClaseActual: true,
        esEquipoGestion: true,
      ),
      Tutora(
        id: 'tutora-12',
        nombre: 'Constanza Vidal Orellana',
        rol: 'Tutora de Contenidos',
        sedeId: 'sede-valparaiso',
        sedeNombre: 'Sede Valparaíso',
        adhesionFirmada: false,
        presenteClaseActual: false,
      ),
    ]);

    // Ficha de voluntariado (US-30, US-31, US-32): RUT, correo, institución y trayectoria
    const rutsTutoras = [
      '17.654.321-3', '18.765.432-7', '19.876.543-0', '16.543.210-K', '15.432.109-8', '18.234.567-9',
      '19.345.678-2', '17.456.789-1', '16.567.890-7', '18.678.901-6', '19.789.012-6', '17.890.123-0',
    ];
    const instituciones = [
      'Ingeniería Civil en Computación, U. de Chile',
      'Ingeniería Civil Industrial, U. de Chile',
      'Licenciatura en Ciencias de la Computación, U. de Chile',
      'Desarrolladora de software',
    ];
    final cursoPorSede = {for (final c in _cursos) c.sedeId: c.id};
    _tutoras = [
      for (var i = 0; i < _tutoras.length; i++)
        _tutoras[i].copyWith(
          rut: rutsTutoras[i],
          correo: '${_slug(_tutoras[i].nombre.split(' ').take(2).join('.'))}@ninaspro.cl',
          institucion: instituciones[i % instituciones.length],
          fechaIngreso: DateTime(2025 - i % 3, 3, 1 + i),
          fechaFirmaAdhesion: _tutoras[i].adhesionFirmada ? DateTime(2026, 3, 14) : null,
          cursoIds: [cursoPorSede[_tutoras[i].sedeId]!],
        ),
    ];

    // Catálogo de roles dinámicos (US-43)
    _rolesConfig = [
      const RolTutorConfig(
        codigo: 'recepcion_alumnas',
        nombre: 'Recepción de Alumnas',
        descripcion: 'Recibe a las alumnas en la entrada y las acompaña a la sala',
        colorHex: '#FF78CF',
        esRequerido: true,
      ),
      const RolTutorConfig(
        codigo: 'presentar_clase',
        nombre: 'Presentar la Clase',
        descripcion: 'Expone los contenidos del día y guía la sesión',
        colorHex: '#8B3295',
        esRequerido: true,
      ),
      const RolTutorConfig(
        codigo: 'actividad_practica',
        nombre: 'Coordinar Actividad Práctica',
        descripcion: 'Organiza el desarrollo de la actividad práctica y resuelve dudas en sala',
        colorHex: '#5A3295',
        esRequerido: true,
      ),
      const RolTutorConfig(
        codigo: 'foto_asistencia',
        nombre: 'Foto y Asistencia',
        descripcion: 'Pasa lista a las alumnas y toma la foto de evidencia de la clase',
        colorHex: '#1D5CA5',
        esRequerido: true,
      ),
      const RolTutorConfig(
        codigo: 'preparar_kahoot',
        nombre: 'Preparar el Kahoot',
        descripcion: 'Arma las preguntas del Kahoot según los contenidos de la clase',
        colorHex: '#E28F12',
        esRequerido: false,
      ),
      const RolTutorConfig(
        codigo: 'presentar_kahoot',
        nombre: 'Presentar el Kahoot',
        descripcion: 'Dirige el Kahoot en sala y registra el podio',
        colorHex: '#975F0C',
        esRequerido: false,
      ),
      const RolTutorConfig(
        codigo: 'subir_classroom',
        nombre: 'Subir Clase a Classroom',
        descripcion: 'Publica el material y la grabación de la clase en Google Classroom',
        colorHex: '#1D7C4D',
        esRequerido: false,
      ),
      const RolTutorConfig(
        codigo: 'inventario',
        nombre: 'Inventario',
        descripcion: 'Guarda los equipos y materiales al cierre y revisa el inventario',
        colorHex: '#72637E',
        esRequerido: false,
      ),
    ];

    // Asignaciones semanas 1-4: rotación de roles entre tutoras.
    // Semana 4 (actual) queda incompleta para mostrar tutoras sin rol asignado.
    _asignacionesSemanales = [];
    final tutorasBeauchef = _tutoras.where((t) => t.sedeId == 'sede-beauchef').toList();
    for (var semana = 1; semana <= 4; semana++) {
      for (var i = 0; i < tutorasBeauchef.length; i++) {
        final tutora = tutorasBeauchef[i];
        if (semana == 4 && (tutora.id == 'tutora-4' || tutora.id == 'tutora-8')) continue;
        _asignacionesSemanales.add(
          AsignacionSemanalTutora(
            tutoraId: tutora.id,
            tutoraNombre: tutora.nombre,
            semanaNumero: semana,
            rolCodigo: _rolesConfig[(i + semana - 1) % _rolesConfig.length].codigo,
          ),
        );
      }
    }

    // Pase de lista de tutoras por clase: clases realizadas con historial, programadas pendientes
    const ausenciasTutoras = {
      'sesion-2': ['tutora-4'],
      'sesion-3': ['tutora-8'],
      'sesion-6': ['tutora-4', 'tutora-6'],
      'sesion-5': ['tutora-1'],
      'sesion-7': ['tutora-5'],
    };
    _asistenciaTutorasPorSesion = {};
    final sedePorCurso = {for (final c in _cursos) c.id: c.sedeId};
    for (final s in _sesiones) {
      final tutorasSede = _tutoras.where((t) => t.sedeId == sedePorCurso[s.cursoId]);
      _asistenciaTutorasPorSesion[s.id] = tutorasSede.map((t) {
        EstadoAsistencia estado;
        if (s.estado != 'realizada') {
          estado = EstadoAsistencia.pendiente;
        } else if (s.id == _sesionActualId) {
          estado = t.presenteClaseActual ? EstadoAsistencia.presente : EstadoAsistencia.ausente;
        } else {
          estado = (ausenciasTutoras[s.id] ?? const []).contains(t.id)
              ? EstadoAsistencia.ausente
              : EstadoAsistencia.presente;
        }
        return RegistroAsistenciaTutora(
          sesionId: s.id,
          tutoraId: t.id,
          tutoraNombre: t.nombre,
          esEquipoGestion: t.esEquipoGestion,
          estado: estado,
        );
      }).toList();
    }

    // Bitácora de auditoría con actividad sintética de abril (US-23, US-24)
    EventoAuditoria evento(
      int n,
      DateTime fecha,
      String usuaria,
      String correo,
      String sede,
      TipoAccionAuditoria tipo,
      String descripcion, [
      String? rut,
    ]) =>
        EventoAuditoria(
          id: 'audit-$n',
          fecha: fecha,
          usuariaNombre: usuaria,
          usuariaCorreo: correo,
          sedeNombre: sede,
          tipo: tipo,
          descripcion: descripcion,
          alumnaRut: rut,
        );
    const camila = 'Camila Sepúlveda Rivas';
    const camilaCorreo = 'camila.sepulveda@ninaspro.cl';
    const daniela = 'Daniela Valenzuela Castro';
    const danielaCorreo = 'daniela.valenzuela@ninaspro.cl';
    const valeria = 'Valeria Troncoso Fuentes';
    const valeriaCorreo = 'valeria.troncoso@ninaspro.cl';
    const paula = 'Paula Gutiérrez Saavedra';
    const paulaCorreo = 'paula.gutierrez@ninaspro.cl';
    const beauchef = 'Sede Beauchef';
    const sj = 'Sede San Joaquín';
    const valpo = 'Sede Valparaíso';
    _eventosAuditoria = [
      evento(1, DateTime(2026, 4, 4, 9, 2), camila, camilaCorreo, beauchef, TipoAccionAuditoria.acceso,
          'Inicio de sesión desde la app móvil'),
      evento(2, DateTime(2026, 4, 4, 10, 15), daniela, danielaCorreo, beauchef,
          TipoAccionAuditoria.modificacion, 'Pase de lista de la clase 1 guardado'),
      evento(3, DateTime(2026, 4, 4, 10, 40), valeria, valeriaCorreo, sj, TipoAccionAuditoria.modificacion,
          'Pase de lista de la clase 1 guardado'),
      evento(4, DateTime(2026, 4, 6, 18, 30), camila, camilaCorreo, beauchef, TipoAccionAuditoria.consulta,
          'Consulta de la ficha de la alumna Florencia Muñoz Tapia', '21.904.331-7'),
      evento(5, DateTime(2026, 4, 11, 10, 20), daniela, danielaCorreo, beauchef,
          TipoAccionAuditoria.modificacion, 'Pase de lista de la clase 2 guardado'),
      evento(6, DateTime(2026, 4, 12, 20, 5), camila, camilaCorreo, beauchef,
          TipoAccionAuditoria.modificacion, 'Justificativo de Florencia Muñoz Tapia aprobado', '21.904.331-7'),
      evento(7, DateTime(2026, 4, 13, 9, 45), paula, paulaCorreo, valpo, TipoAccionAuditoria.exportacion,
          'Exportación CSV de asistencia · Desarrollo Web Inicial · 12 filas'),
      evento(8, DateTime(2026, 4, 18, 10, 12), daniela, danielaCorreo, beauchef,
          TipoAccionAuditoria.modificacion, 'Pase de lista de la clase 3 guardado'),
      evento(9, DateTime(2026, 4, 18, 11, 30), daniela, danielaCorreo, beauchef,
          TipoAccionAuditoria.consulta, 'Consulta de autorizaciones de imagen para la foto de la clase 3',
          '22.341.890-2'),
      evento(10, DateTime(2026, 4, 19, 17, 0), valeria, valeriaCorreo, sj, TipoAccionAuditoria.consulta,
          'Consulta de la ficha de la alumna Renata Ibáñez Cortés', '22.890.634-4'),
      evento(11, DateTime(2026, 4, 20, 12, 10), valeria, valeriaCorreo, sj, TipoAccionAuditoria.modificacion,
          'Retiro registrado de Renata Ibáñez Cortés: cambio de domicilio', '22.890.634-4'),
      evento(12, DateTime(2026, 4, 21, 19, 25), camila, camilaCorreo, beauchef,
          TipoAccionAuditoria.modificacion, 'Contacto preventivo con el apoderado de Sofía Araya Bravo',
          '21.876.543-2'),
      evento(13, DateTime(2026, 4, 22, 8, 50), paula, paulaCorreo, valpo, TipoAccionAuditoria.acceso,
          'Inicio de sesión desde el navegador'),
      evento(14, DateTime(2026, 4, 23, 16, 40), camila, camilaCorreo, beauchef,
          TipoAccionAuditoria.exportacion, 'Exportación XLSX de la nómina · Sede Beauchef · 8 filas'),
      evento(15, DateTime(2026, 4, 24, 21, 15), paula, paulaCorreo, valpo, TipoAccionAuditoria.consulta,
          'Consulta de la ficha de la alumna Ignacia Muñoz Vergara', '22.523.967-3'),
      evento(16, DateTime(2026, 4, 25, 9, 5), daniela, danielaCorreo, beauchef, TipoAccionAuditoria.acceso,
          'Inicio de sesión desde la app móvil'),
    ];
  }

  // ─── Utilidades internas ──────────────────────────────────────────────────

  /// Usuaria que firma las acciones hechas desde la vista de escritorio
  static const _usuariaDirectiva = 'Directiva Nacional';
  static const _correoDirectiva = 'directiva@ninaspro.cl';

  String _nuevoId(String prefijo) => '$prefijo-${DateTime.now().microsecondsSinceEpoch}-${_contadorIds++}';

  /// Minúsculas sin tildes ni espacios, para correos y códigos sintéticos
  static String _slug(String texto) {
    const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
    return texto
        .toLowerCase()
        .split('')
        .map((c) => tildes[c] ?? c)
        .join()
        .replaceAll(RegExp(r'[^a-z0-9.]+'), '_');
  }

  String _nombreSede(String sedeId) =>
      _sedes.where((s) => s.id == sedeId).firstOrNull?.nombre ?? 'Todas las sedes';

  void _registrarAuditoria(
    TipoAccionAuditoria tipo,
    String descripcion, {
    String sedeNombre = 'Todas las sedes',
    String? alumnaRut,
  }) {
    _eventosAuditoria.add(
      EventoAuditoria(
        id: _nuevoId('audit'),
        fecha: DateTime.now(),
        usuariaNombre: _usuariaDirectiva,
        usuariaCorreo: _correoDirectiva,
        sedeNombre: sedeNombre,
        tipo: tipo,
        descripcion: descripcion,
        alumnaRut: alumnaRut,
      ),
    );
  }

  @override
  ValueListenable<EstadoSincronizacion> get estadoSincronizacion => _estadoSincronizacion;

  @override
  ValueListenable<int> get cambiosPendientes => _cambiosPendientes;

  @override
  Future<void> recargar() async {
    await Future.delayed(demoraSincronizacion);
  }

  /// true si la conexión simulada con la nube está disponible
  bool get conectado => _conectado;

  /// Mockup: simula perder o recuperar internet. Al volver la conexión,
  /// los cambios pendientes se suben (~1 s) y el estado vuelve a "sincronizado".
  Future<void> simularConexion(bool conectado) async {
    _conectado = conectado;
    if (!conectado) {
      _estadoSincronizacion.value = EstadoSincronizacion.sinConexion;
      return;
    }
    if (_cambiosPendientes.value > 0) {
      _estadoSincronizacion.value = EstadoSincronizacion.sincronizando;
      await Future.delayed(demoraSincronizacion);
      // Pudo perderse otra vez la conexión mientras subía
      if (!_conectado) return;
      _cambiosPendientes.value = 0;
    }
    _estadoSincronizacion.value = EstadoSincronizacion.sincronizado;
  }

  // Con conexión el cambio se sube al instante; sin conexión queda pendiente en el dispositivo
  void _marcarCambioLocal() {
    if (_conectado) return;
    _cambiosPendientes.value++;
  }

  @override
  Future<List<Sede>> getSedes() async => List.unmodifiable(_sedes);

  bool _nombreSedeEnUso(String nombre, {String? exceptoId}) {
    final clave = nombre.trim().toLowerCase();
    return _sedes.any((s) => s.id != exceptoId && s.nombre.trim().toLowerCase() == clave);
  }

  @override
  Future<bool> crearSede({
    required String nombre,
    required String universidad,
    required String region,
    required String modalidad,
    required String coordinadoraNombre,
  }) async {
    if (nombre.trim().isEmpty || _nombreSedeEnUso(nombre)) return false;
    _marcarCambioLocal();
    _sedes.add(
      Sede(
        id: 'sede-${_slug(nombre.trim())}',
        nombre: nombre.trim(),
        universidad: universidad.trim(),
        region: region.trim(),
        modalidad: modalidad,
        coordinadoraNombre: coordinadoraNombre.trim(),
      ),
    );
    _registrarAuditoria(TipoAccionAuditoria.modificacion, 'Sede creada: ${nombre.trim()}',
        sedeNombre: nombre.trim());
    return true;
  }

  @override
  Future<bool> actualizarSede(Sede sede) async {
    final idx = _sedes.indexWhere((s) => s.id == sede.id);
    if (idx == -1 || sede.nombre.trim().isEmpty || _nombreSedeEnUso(sede.nombre, exceptoId: sede.id)) {
      return false;
    }
    _marcarCambioLocal();
    final nombreAnterior = _sedes[idx].nombre;
    _sedes[idx] = sede;

    // El nombre de la sede va copiado en cursos, alumnas, tutoras y alertas
    if (nombreAnterior != sede.nombre) {
      _cursos = [for (final c in _cursos) c.sedeId == sede.id ? c.copyWith(sedeNombre: sede.nombre) : c];
      _alumnas = [for (final a in _alumnas) a.sedeId == sede.id ? a.copyWith(sedeNombre: sede.nombre) : a];
      _tutoras = [for (final t in _tutoras) t.sedeId == sede.id ? t.copyWith(sedeNombre: sede.nombre) : t];
      _alertas = [
        for (final a in _alertas) a.sedeNombre == nombreAnterior ? a.copyWith(sedeNombre: sede.nombre) : a,
      ];
    }
    _registrarAuditoria(TipoAccionAuditoria.modificacion, 'Sede actualizada: ${sede.nombre}',
        sedeNombre: sede.nombre);
    return true;
  }

  @override
  Future<List<ResumenSede>> getResumenSedes() async {
    return [
      for (final sede in _sedes)
        () {
          final activas = _alumnas.where((a) => a.sedeId == sede.id && a.estado == 'activa').toList();
          return ResumenSede(
            sede: sede,
            cursos: _cursos.where((c) => c.sedeId == sede.id).length,
            alumnasActivas: activas.length,
            asistenciaPromedio: activas.isEmpty
                ? 0
                : activas.map((a) => a.porcentajeAsistencia).reduce((x, y) => x + y) / activas.length,
            voluntariasActivas: _tutoras.where((t) => t.sedeId == sede.id && t.estado == 'activa').length,
          );
        }(),
    ];
  }

  @override
  Future<List<SerieAsistencia>> getAsistenciaPorClase() async {
    return [
      for (final sede in _sedes)
        () {
          final cursoIds = _cursos.where((c) => c.sedeId == sede.id).map((c) => c.id).toSet();
          // Agrupa por fecha: una sede puede tener más de un curso el mismo día
          final porFecha = <DateTime, (int, int)>{};
          for (final s in _sesiones.where((s) => cursoIds.contains(s.cursoId) && s.estado == 'realizada')) {
            final registros = (_asistenciasPorSesion[s.id] ?? const <RegistroAsistencia>[])
                .where((r) => r.estado != EstadoAsistencia.pendiente);
            final presentes = registros.where((r) => r.estado == EstadoAsistencia.presente).length;
            final (p, t) = porFecha[s.fecha] ?? (0, 0);
            porFecha[s.fecha] = (p + presentes, t + registros.length);
          }
          final fechas = porFecha.keys.toList()..sort();
          return SerieAsistencia(
            sedeId: sede.id,
            sedeNombre: sede.nombre,
            puntos: [
              for (final f in fechas)
                if (porFecha[f]!.$2 > 0) PuntoAsistencia(fecha: f, presentes: porFecha[f]!.$1, total: porFecha[f]!.$2),
            ],
          );
        }(),
    ];
  }

  @override
  Future<List<CursoCatalogo>> getCatalogoCursos() async => List.unmodifiable(_catalogoCursos);

  bool _catalogoValido(String codigo, String nombre, {String? exceptoId}) {
    final clave = codigo.trim().toUpperCase();
    if (clave.isEmpty || nombre.trim().isEmpty) return false;
    return !_catalogoCursos.any((c) => c.id != exceptoId && c.codigo.toUpperCase() == clave);
  }

  @override
  Future<bool> crearCursoCatalogo({
    required String codigo,
    required String nombre,
    String descripcion = '',
  }) async {
    if (!_catalogoValido(codigo, nombre)) return false;
    _marcarCambioLocal();
    _catalogoCursos.add(
      CursoCatalogo(
        id: 'cat-${_slug(codigo.trim())}',
        codigo: codigo.trim().toUpperCase(),
        nombre: nombre.trim(),
        descripcion: descripcion.trim(),
      ),
    );
    _registrarAuditoria(TipoAccionAuditoria.modificacion, 'Curso agregado al catálogo: ${nombre.trim()}');
    return true;
  }

  @override
  Future<bool> actualizarCursoCatalogo(CursoCatalogo curso) async {
    final idx = _catalogoCursos.indexWhere((c) => c.id == curso.id);
    if (idx == -1 || !_catalogoValido(curso.codigo, curso.nombre, exceptoId: curso.id)) return false;
    _marcarCambioLocal();
    _catalogoCursos[idx] = curso.copyWith(
      codigo: curso.codigo.trim().toUpperCase(),
      nombre: curso.nombre.trim(),
    );
    return true;
  }

  @override
  Future<List<Curso>> getCursos({String? sedeId}) async {
    if (sedeId == null) return List.unmodifiable(_cursos);
    return _cursos.where((c) => c.sedeId == sedeId).toList();
  }

  @override
  Future<bool> existeInstancia({
    required String catalogoId,
    required String sedeId,
    required int anio,
    required int semestre,
  }) async {
    return _cursos.any((c) =>
        c.catalogoId == catalogoId && c.sedeId == sedeId && c.anio == anio && c.semestre == semestre);
  }

  @override
  Future<Curso?> crearInstanciaCurso({
    required String catalogoId,
    required String sedeId,
    required DateTime inicio,
    required DateTime termino,
    required int diaSemana,
  }) async {
    final catalogo = _catalogoCursos.where((c) => c.id == catalogoId).firstOrNull;
    final sede = _sedes.where((s) => s.id == sedeId).firstOrNull;
    if (catalogo == null || sede == null || !termino.isAfter(inicio)) return null;

    // Fechas de clase: cada [diaSemana] entre inicio y término (ambos incluidos)
    final fechas = <DateTime>[];
    var dia = DateTime(inicio.year, inicio.month, inicio.day);
    while (dia.weekday != diaSemana) {
      dia = DateTime(dia.year, dia.month, dia.day + 1);
    }
    while (!dia.isAfter(termino)) {
      fechas.add(dia);
      dia = DateTime(dia.year, dia.month, dia.day + 7);
    }
    if (fechas.isEmpty) return null;

    _marcarCambioLocal();
    final semestre = inicio.month >= 7 ? 2 : 1;
    final sufijo = _slug(sede.nombre.replaceFirst('Sede ', '')).toUpperCase();
    final curso = Curso(
      id: _nuevoId('curso'),
      codigo: '${catalogo.codigo}-${inicio.year}-S$semestre-$sufijo',
      nombre: catalogo.nombre,
      sedeId: sede.id,
      sedeNombre: sede.nombre,
      anio: inicio.year,
      semestre: semestre,
      totalSesiones: fechas.length,
      catalogoId: catalogo.id,
      fechaInicio: inicio,
      fechaTermino: termino,
      diaSemana: diaSemana,
    );
    _cursos.add(curso);
    for (var i = 0; i < fechas.length; i++) {
      _sesiones.add(
        SesionClase(
          id: 'sesion-${curso.id}-${i + 1}',
          cursoId: curso.id,
          numeroSesion: i + 1,
          fecha: fechas[i],
          tema: 'Clase ${i + 1} (tema por definir)',
          estado: 'programada',
        ),
      );
    }
    _registrarAuditoria(
      TipoAccionAuditoria.modificacion,
      'Instancia creada: ${curso.codigo} con ${fechas.length} sesiones',
      sedeNombre: sede.nombre,
    );
    return curso;
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
    DateTime? fecha,
  }) async {
    _marcarCambioLocal();
    final idx = _alumnas.indexWhere((a) => a.id == alumnaId);
    if (idx == -1) return false;
    _alumnas[idx] = _alumnas[idx].copyWith(
      estado: 'retirada',
      motivoRetiro: motivo,
      fechaRetiro: fecha ?? DateTime.now(),
    );
    _registrarAuditoria(
      TipoAccionAuditoria.modificacion,
      'Retiro registrado de ${_alumnas[idx].nombre}: $motivo',
      sedeNombre: _alumnas[idx].sedeNombre,
      alumnaRut: _alumnas[idx].rut,
    );
    return true;
  }

  @override
  Future<bool> inscribirAlumna({
    required String cursoId,
    required String nombre,
    required String rut,
    required String apoderadoNombre,
    required String apoderadoTelefono,
    required String apoderadoCorreo,
  }) async {
    final curso = _cursos.where((c) => c.id == cursoId).firstOrNull;
    if (curso == null || nombre.trim().isEmpty || !validarRut(rut)) return false;

    final rutNormalizado = normalizarRut(rut);
    final idx = _alumnas.indexWhere((a) => normalizarRut(a.rut) == rutNormalizado);
    if (idx != -1 && _alumnas[idx].cursoId == cursoId && _alumnas[idx].estado != 'retirada') return false;

    _marcarCambioLocal();
    if (idx != -1) {
      // Ficha única: misma alumna, nueva inscripción; la anterior pasa al historial (US-09)
      final anterior = _alumnas[idx];
      _alumnas[idx] = anterior.copyWith(
        cursoId: curso.id,
        cursoNombre: curso.nombre,
        sedeId: curso.sedeId,
        sedeNombre: curso.sedeNombre,
        estado: 'preinscrita',
        porcentajeAsistencia: 0,
        asistenciasCount: 0,
        historialInscripciones: [
          ...anterior.historialInscripciones,
          '${anterior.cursoNombre} · ${anterior.sedeNombre} (${anterior.estado})',
        ],
      );
    } else {
      _alumnas.add(
        Alumna(
          id: _nuevoId('alumna'),
          nombre: nombre.trim(),
          rut: formatearRut(rut),
          cursoId: curso.id,
          cursoNombre: curso.nombre,
          sedeId: curso.sedeId,
          sedeNombre: curso.sedeNombre,
          porcentajeAsistencia: 0,
          asistenciasCount: 0,
          autorizaFoto: false,
          apoderadoNombre: apoderadoNombre.trim(),
          apoderadoTelefono: apoderadoTelefono.trim(),
          apoderadoCorreo: apoderadoCorreo.trim(),
          estado: 'preinscrita',
        ),
      );
    }
    _registrarAuditoria(
      TipoAccionAuditoria.modificacion,
      'Inscripción de ${nombre.trim()} en ${curso.codigo}',
      sedeNombre: curso.sedeNombre,
      alumnaRut: formatearRut(rut),
    );
    return true;
  }

  // Planilla de ejemplo para la carga masiva simulada de alumnas (US-07, US-08):
  // nombre, rut, apoderado, teléfono, correo
  static const _planillaAlumnas = [
    ['Antonia Núñez Ríos', '22.634.078-5', 'Sandra Ríos Paz', '+56 9 7111 2233', 'sandra.rios@correo.cl'],
    ['Florencia Güell Araya', '22.745.189-0', 'Tomás Güell Mora', '+56 9 7222 3344', 'tomas.guell@correo.cl'],
    ['Renata Ibáñez Cortés', '22.890.634-4', 'Pablo Ibáñez Ruiz', '+56 9 8456 7890', 'pablo.ibanez@correo.cl'],
    ['Amparo Sánchez Toro', '22.856.290-1', 'Lucía Toro Vial', '+56 9 7333 4455', 'lucia.toro@correo.cl'],
    ['Belén Cáceres Muñoz', '22.634.078-5', 'Jorge Cáceres Paz', '+56 9 7444 5566', 'jorge.caceres@correo.cl'],
    ['Julieta Ñanco Huenchul', '22.856.290-4', 'Mónica Huenchul Lagos', '', ''],
    ['Catalina Peña Valdés', '23.012.345-4', 'Rodrigo Peña Soto', '+56 9 7555 6677', 'rodrigo.pena@correo.cl'],
  ];

  List<FilaImportacion> _procesarPlanillaAlumnas(String cursoId) {
    final filas = <FilaImportacion>[];
    final rutsVistos = <String, int>{};
    for (var i = 0; i < _planillaAlumnas.length; i++) {
      final [nombre, rut, apoderado, telefono, correo] = _planillaAlumnas[i];
      final numero = i + 2; // la fila 1 es la cabecera
      final clave = normalizarRut(rut);
      String? motivo;
      if (!validarRut(rut)) {
        motivo = 'RUT con dígito verificador inválido';
      } else if (rutsVistos.containsKey(clave)) {
        motivo = 'RUT repetido en la planilla (fila ${rutsVistos[clave]})';
      } else if (telefono.isEmpty || correo.isEmpty) {
        motivo = 'Faltan el teléfono y el correo del apoderado';
      }
      rutsVistos.putIfAbsent(clave, () => numero);

      final existente = _alumnas.where((a) => normalizarRut(a.rut) == clave).firstOrNull;
      final yaEnCurso = existente != null && existente.cursoId == cursoId && existente.estado != 'retirada';
      if (motivo == null && yaEnCurso) motivo = 'Ya está inscrita en este curso';
      filas.add(
        FilaImportacion(
          numeroFila: numero,
          nombre: nombre,
          rut: rut,
          detalle: apoderado,
          estado: motivo != null
              ? EstadoFilaImportacion.invalida
              : (existente != null ? EstadoFilaImportacion.existente : EstadoFilaImportacion.nueva),
          motivo: motivo ?? (existente != null ? 'Se reutiliza su ficha de ${existente.sedeNombre}' : null),
        ),
      );
    }
    return filas;
  }

  @override
  Future<ResultadoImportacion> previsualizarImportacionAlumnas({
    required String cursoId,
    bool columnasValidas = true,
  }) async {
    if (!columnasValidas) {
      return const ResultadoImportacion(
        nombreArchivo: 'nomina_formato_antiguo.xlsx',
        errorColumnas: 'La planilla no coincide con la plantilla. Faltan las columnas '
            '"telefono_apoderado" y "correo_apoderado"; la columna "Nombre Completo" debe llamarse "nombre".',
      );
    }
    return ResultadoImportacion(
      nombreArchivo: 'nomina_alumnas_2026.csv',
      filas: _procesarPlanillaAlumnas(cursoId),
    );
  }

  @override
  Future<int> confirmarImportacionAlumnas({required String cursoId}) async {
    var inscritas = 0;
    for (final fila in _procesarPlanillaAlumnas(cursoId)) {
      if (fila.estado == EstadoFilaImportacion.invalida) continue;
      final datos = _planillaAlumnas[fila.numeroFila - 2];
      final ok = await inscribirAlumna(
        cursoId: cursoId,
        nombre: datos[0],
        rut: datos[1],
        apoderadoNombre: datos[2],
        apoderadoTelefono: datos[3],
        apoderadoCorreo: datos[4],
      );
      if (ok) inscritas++;
    }
    return inscritas;
  }

  @override
  Future<bool> actualizarAutorizaciones({
    required String alumnaId,
    required AutorizacionesAlumna autorizaciones,
  }) async {
    final idx = _alumnas.indexWhere((a) => a.id == alumnaId);
    if (idx == -1) return false;
    _marcarCambioLocal();
    _alumnas[idx] = _alumnas[idx].copyWith(
      autorizaciones: autorizaciones,
      autorizaFoto: autorizaciones.permiteFotos,
    );
    _registrarAuditoria(
      TipoAccionAuditoria.modificacion,
      'Autorizaciones del apoderado registradas para ${_alumnas[idx].nombre}',
      sedeNombre: _alumnas[idx].sedeNombre,
      alumnaRut: _alumnas[idx].rut,
    );
    return true;
  }

  @override
  Future<bool> revocarAutorizacionImagen({
    required String alumnaId,
    required List<CanalImagen> canales,
    required DateTime fecha,
    required String motivo,
  }) async {
    final idx = _alumnas.indexWhere((a) => a.id == alumnaId);
    if (idx == -1 || canales.isEmpty || motivo.trim().isEmpty) return false;
    _marcarCambioLocal();

    final alumna = _alumnas[idx];
    final actuales = alumna.autorizaciones;
    final autorizaciones = AutorizacionesAlumna(
      tratamientoDatos: actuales.tratamientoDatos,
      canales: {
        ...actuales.canales,
        for (final c in canales) c: EstadoAutorizacion.revocada,
      },
      revocaciones: {
        ...actuales.revocaciones,
        for (final c in canales) c: RevocacionImagen(fecha: fecha, motivo: motivo.trim()),
      },
      respaldoNombre: actuales.respaldoNombre,
      fechaRegistro: actuales.fechaRegistro,
    );
    _alumnas[idx] = alumna.copyWith(
      autorizaciones: autorizaciones,
      autorizaFoto: autorizaciones.permiteFotos,
    );

    // Las clases desde la fecha de revocación dejan de considerarla apta para fotos (RB-4);
    // las anteriores se conservan intactas
    if (!autorizaciones.permiteFotos) {
      for (final s in _sesiones.where((s) => s.cursoId == alumna.cursoId && !s.fecha.isBefore(fecha))) {
        final registros = _asistenciasPorSesion[s.id];
        final r = registros?.indexWhere((x) => x.alumnaId == alumnaId) ?? -1;
        if (registros != null && r != -1) {
          registros[r] = registros[r].copyWith(autorizaImagen: false);
        }
      }
    }
    _registrarAuditoria(
      TipoAccionAuditoria.modificacion,
      'Revocación de imagen (${canales.map((c) => c.label).join(', ')}) para ${alumna.nombre}',
      sedeNombre: alumna.sedeNombre,
      alumnaRut: alumna.rut,
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
    _marcarCambioLocal();
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
    _marcarCambioLocal();
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
    _marcarCambioLocal();
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
    if (sedeId == null) return List.unmodifiable(_alertas);
    final ids = _alumnas.where((a) => a.sedeId == sedeId).map((a) => a.id).toSet();
    return _alertas.where((a) => ids.contains(a.alumnaId)).toList();
  }

  @override
  Future<bool> contactarAlerta({
    required String alertaId,
    required String observacionesContacto,
  }) async {
    _marcarCambioLocal();
    final idx = _alertas.indexWhere((a) => a.id == alertaId);
    if (idx == -1) return false;
    _alertas[idx] = _alertas[idx].copyWith(
      estado: 'contactada',
      observacionesContacto: observacionesContacto,
    );
    return true;
  }

  @override
  Future<List<Justificativo>> getJustificativos({String? sedeId}) async {
    if (sedeId == null) return List.unmodifiable(_justificativos);
    final ids = _alumnas.where((a) => a.sedeId == sedeId).map((a) => a.id).toSet();
    return _justificativos.where((j) => ids.contains(j.alumnaId)).toList();
  }

  @override
  Future<bool> enviarJustificativo({
    required String alumnaId,
    required String sesionId,
    required String motivoTipificado,
    required String detalle,
  }) async {
    _marcarCambioLocal();
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
    _marcarCambioLocal();
    final idx = _justificativos.indexWhere((j) => j.id == justificativoId);
    if (idx == -1) return false;
    _justificativos[idx] = _justificativos[idx].copyWith(
      estado: aprobado ? 'aprobado' : 'rechazado',
      observacionesResolucion: observaciones,
    );
    return true;
  }

  @override
  Future<bool> registrarJustificativoManual({
    required String alumnaId,
    required String sesionId,
    required String detalle,
  }) async {
    _marcarCambioLocal();
    final alumna = await getAlumnaById(alumnaId);
    final sesion = _sesiones.where((s) => s.id == sesionId).firstOrNull;
    if (alumna == null || sesion == null || detalle.trim().isEmpty) return false;

    _justificativos.insert(
      0,
      Justificativo(
        id: 'just-${DateTime.now().millisecondsSinceEpoch}',
        alumnaId: alumnaId,
        alumnaNombre: alumna.nombre,
        sesionId: sesionId,
        sesionFecha: sesion.fecha,
        motivoTipificado: 'Ingreso manual',
        detalle: detalle.trim(),
        estado: 'aprobado',
        observacionesResolucion: 'Registrado y aprobado directamente por el Equipo de Gestión.',
      ),
    );

    // Si ya hay pase de lista para esa clase, la asistencia queda Justificada
    final registros = _asistenciasPorSesion[sesionId];
    if (registros != null) {
      final idx = registros.indexWhere((r) => r.alumnaId == alumnaId);
      if (idx != -1) {
        registros[idx] = registros[idx].copyWith(estado: EstadoAsistencia.justificada);
      }
    }
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
      sesionHoy: sesiones.where((s) => s.id == _sesionActualId).firstOrNull,
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
  Future<List<Tutora>> getTutoras({String? sedeId}) async {
    if (sedeId == null) return List.unmodifiable(_tutoras);
    return _tutoras.where((t) => t.sedeId == sedeId).toList();
  }

  @override
  Future<bool> crearVoluntaria({
    required String nombre,
    required String rut,
    required String correo,
    required String institucion,
    required String sedeId,
    required bool esEquipoGestion,
  }) async {
    final sede = _sedes.where((s) => s.id == sedeId).firstOrNull;
    if (sede == null || nombre.trim().isEmpty || !validarRut(rut)) return false;
    if (_tutoras.any((t) => normalizarRut(t.rut) == normalizarRut(rut))) return false;
    _marcarCambioLocal();
    _tutoras.add(
      Tutora(
        id: _nuevoId('tutora'),
        nombre: nombre.trim(),
        rol: esEquipoGestion ? 'Equipo de Gestión' : 'Tutora',
        sedeId: sede.id,
        sedeNombre: sede.nombre,
        adhesionFirmada: false,
        presenteClaseActual: false,
        esEquipoGestion: esEquipoGestion,
        rut: formatearRut(rut),
        correo: correo.trim(),
        institucion: institucion.trim(),
        fechaIngreso: DateTime.now(),
      ),
    );
    _registrarAuditoria(TipoAccionAuditoria.modificacion, 'Ficha de voluntariado creada: ${nombre.trim()}',
        sedeNombre: sede.nombre);
    return true;
  }

  @override
  Future<bool> actualizarVoluntaria(Tutora voluntaria) async {
    final idx = _tutoras.indexWhere((t) => t.id == voluntaria.id);
    if (idx == -1) return false;
    final ingreso = voluntaria.fechaIngreso;
    final salida = voluntaria.fechaSalida;
    if (ingreso != null && salida != null && salida.isBefore(ingreso)) return false;
    _marcarCambioLocal();
    _tutoras[idx] = voluntaria;
    _registrarAuditoria(TipoAccionAuditoria.modificacion, 'Ficha de voluntariado actualizada: ${voluntaria.nombre}',
        sedeNombre: voluntaria.sedeNombre);
    return true;
  }

  @override
  Future<bool> asignarVoluntariaACurso({
    required String tutoraId,
    required String cursoId,
  }) async {
    final idx = _tutoras.indexWhere((t) => t.id == tutoraId);
    final curso = _cursos.where((c) => c.id == cursoId).firstOrNull;
    if (idx == -1 || curso == null) return false;
    final tutora = _tutoras[idx];
    // Sin declaración de adhesión firmada no puede hacer clases (US-31)
    if (!tutora.adhesionFirmada || tutora.estado != 'activa') return false;
    _marcarCambioLocal();
    _tutoras[idx] = tutora.copyWith(
      sedeId: curso.sedeId,
      sedeNombre: curso.sedeNombre,
      cursoIds: [...tutora.cursoIds.where((id) => id != cursoId), cursoId],
    );
    _registrarAuditoria(TipoAccionAuditoria.modificacion, '${tutora.nombre} asignada a ${curso.codigo}',
        sedeNombre: curso.sedeNombre);
    return true;
  }

  // Planilla de ejemplo para la carga masiva simulada de voluntariado (US-30):
  // nombre, rut, correo, institución, rol
  static const _planillaVoluntariado = [
    ['Ignacia Bravo Lillo', '17.901.234-0', 'ignacia.bravo@ninaspro.cl', 'Ingeniería Civil, U. de Chile', 'Tutora'],
    ['Sofía Castillo Ortega', '18.012.345-8', 'sofia.castillo@ninaspro.cl', 'Ingeniería de Software, PUC', 'Tutora'],
    ['Fernanda Pizarro León', '18.678.901-6', 'fernanda.pizarro@ninaspro.cl', 'Ingeniería Civil Industrial, U. de Chile', 'Tutora'],
    ['Josefina Rivas Mora', '19.123.456-7', 'josefina.rivas@ninaspro.cl', 'Ingeniería Informática, USM', 'Tutora'],
    ['Carla Méndez Vío', '16.234.567-1', 'carla.mendez@ninaspro.cl', 'Desarrolladora de software', 'Equipo de Gestión'],
    ['Lorena Tapia Gil', '20.345.678-6', 'lorena.tapia@ninaspro.cl', 'Licenciatura en Matemáticas, USM', 'Tutora'],
    ['Macarena Ruiz Paz', '16.234.567-2', 'macarena.ruiz@ninaspro.cl', 'Analista de datos', 'Equipo de Gestión'],
    ['Daniela Soto Vega', '19.123.456-1', 'daniela.soto@ninaspro.cl', 'Ingeniería Civil en Computación, U. de Chile', 'Tutora'],
  ];

  List<FilaImportacion> _procesarPlanillaVoluntariado() {
    final filas = <FilaImportacion>[];
    final rutsVistos = <String, int>{};
    for (var i = 0; i < _planillaVoluntariado.length; i++) {
      final [nombre, rut, _, institucion, _] = _planillaVoluntariado[i];
      final numero = i + 2; // la fila 1 es la cabecera
      final clave = normalizarRut(rut);
      String? motivo;
      if (!validarRut(rut)) {
        motivo = 'RUT con dígito verificador inválido';
      } else if (rutsVistos.containsKey(clave)) {
        motivo = 'RUT repetido en la planilla (fila ${rutsVistos[clave]})';
      }
      rutsVistos.putIfAbsent(clave, () => numero);
      final existente = _tutoras.where((t) => normalizarRut(t.rut) == clave).firstOrNull;
      filas.add(
        FilaImportacion(
          numeroFila: numero,
          nombre: nombre,
          rut: rut,
          detalle: institucion,
          estado: motivo != null
              ? EstadoFilaImportacion.invalida
              : (existente != null ? EstadoFilaImportacion.existente : EstadoFilaImportacion.nueva),
          motivo: motivo ?? (existente != null ? 'Ya tiene ficha en ${existente.sedeNombre}; se mantiene' : null),
        ),
      );
    }
    return filas;
  }

  @override
  Future<ResultadoImportacion> previsualizarImportacionVoluntariado({bool columnasValidas = true}) async {
    if (!columnasValidas) {
      return const ResultadoImportacion(
        nombreArchivo: 'voluntarias_formulario_google.xlsx',
        errorColumnas: 'La planilla no coincide con la plantilla. Falta la columna "rut" y '
            'sobra la columna "Marca temporal".',
      );
    }
    return ResultadoImportacion(
      nombreArchivo: 'voluntariado_2026.csv',
      filas: _procesarPlanillaVoluntariado(),
    );
  }

  @override
  Future<int> confirmarImportacionVoluntariado({required String sedeId}) async {
    var creadas = 0;
    for (final fila in _procesarPlanillaVoluntariado()) {
      if (fila.estado != EstadoFilaImportacion.nueva) continue;
      final datos = _planillaVoluntariado[fila.numeroFila - 2];
      final ok = await crearVoluntaria(
        nombre: datos[0],
        rut: datos[1],
        correo: datos[2],
        institucion: datos[3],
        sedeId: sedeId,
        esEquipoGestion: datos[4] == 'Equipo de Gestión',
      );
      if (ok) creadas++;
    }
    return creadas;
  }

  @override
  Future<bool> actualizarAsistenciaTutora({
    required String tutoraId,
    required bool presente,
  }) async {
    _marcarCambioLocal();
    final idx = _tutoras.indexWhere((t) => t.id == tutoraId);
    if (idx == -1) return false;
    _tutoras[idx] = _tutoras[idx].copyWith(presenteClaseActual: presente);

    // Mantiene coherente el pase de lista de la clase en curso
    final registros = _asistenciaTutorasPorSesion[_sesionActualId];
    final r = registros?.indexWhere((x) => x.tutoraId == tutoraId) ?? -1;
    if (registros != null && r != -1) {
      registros[r] = registros[r].copyWith(
        estado: presente ? EstadoAsistencia.presente : EstadoAsistencia.ausente,
      );
    }
    return true;
  }

  @override
  Future<List<RegistroAsistenciaTutora>> getAsistenciaTutoras({required String sesionId}) async {
    return List.of(_asistenciaTutorasPorSesion[sesionId] ?? const []);
  }

  @override
  Future<bool> guardarAsistenciaTutoras({
    required String sesionId,
    required List<RegistroAsistenciaTutora> registros,
  }) async {
    _marcarCambioLocal();
    if (!_asistenciaTutorasPorSesion.containsKey(sesionId)) return false;
    _asistenciaTutorasPorSesion[sesionId] = List.of(registros);

    // En la clase en curso también se refleja en "Tutoras en aula"
    if (sesionId == _sesionActualId) {
      for (final reg in registros) {
        final idx = _tutoras.indexWhere((t) => t.id == reg.tutoraId);
        if (idx != -1) {
          _tutoras[idx] = _tutoras[idx].copyWith(
            presenteClaseActual: reg.estado == EstadoAsistencia.presente,
          );
        }
      }
    }
    return true;
  }

  @override
  Future<List<RolTutorConfig>> getRolesTutora() async => List.unmodifiable(_rolesConfig);

  @override
  Future<bool> crearRolTutora(RolTutorConfig rol) async {
    if (rol.nombre.trim().isEmpty || _rolesConfig.any((r) => r.codigo == rol.codigo)) return false;
    _marcarCambioLocal();
    _rolesConfig.add(rol);
    return true;
  }

  @override
  Future<bool> actualizarRolTutora(RolTutorConfig rol) async {
    _marcarCambioLocal();
    final idx = _rolesConfig.indexWhere((r) => r.codigo == rol.codigo);
    if (idx == -1) return false;
    _rolesConfig[idx] = rol;
    return true;
  }

  @override
  Future<bool> eliminarRolTutora(String codigo) async {
    final idx = _rolesConfig.indexWhere((r) => r.codigo == codigo);
    if (idx == -1) return false;
    _marcarCambioLocal();
    _rolesConfig.removeAt(idx);
    _asignacionesSemanales.removeWhere((a) => a.rolCodigo == codigo);
    return true;
  }

  @override
  Future<int> contarAsignacionesRol(String codigo) async =>
      _asignacionesSemanales.where((a) => a.rolCodigo == codigo).length;

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
    _marcarCambioLocal();
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

  ResultadoExportacion _armarExportacion(FiltroExportacion filtro) {
    final cursoIds = _cursos
        .where((c) =>
            (filtro.sedeId == null || c.sedeId == filtro.sedeId) &&
            (filtro.cursoId == null || c.id == filtro.cursoId))
        .map((c) => c.id)
        .toSet();
    final alumnas = {for (final a in _alumnas.where((a) => cursoIds.contains(a.cursoId))) a.id: a};
    final sesiones = _sesiones.where((s) =>
        cursoIds.contains(s.cursoId) &&
        (filtro.desde == null || !s.fecha.isBefore(filtro.desde!)) &&
        (filtro.hasta == null || !s.fecha.isAfter(filtro.hasta!)));

    // Modo disociado: identificador sintético consistente por alumna, sin RUT (US-22)
    final ids = alumnas.keys.toList();
    final sinteticos = {
      for (var i = 0; i < ids.length; i++) ids[i]: 'ALUMNA-${'${i + 1}'.padLeft(3, '0')}',
    };
    String nombre(Alumna a) => filtro.disociado ? sinteticos[a.id]! : a.nombre;
    String rut(Alumna a) => filtro.disociado ? '—' : a.rut;
    String fecha(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

    final List<String> encabezados;
    final filas = <List<String>>[];
    switch (filtro.tipo) {
      case TipoExportacion.nomina:
        encabezados = ['alumna', 'rut', 'sede', 'curso', 'estado', 'asistencia_%'];
        for (final a in alumnas.values) {
          filas.add([
            nombre(a),
            rut(a),
            a.sedeNombre,
            a.cursoNombre,
            a.estado,
            a.porcentajeAsistencia.toStringAsFixed(1),
          ]);
        }
      case TipoExportacion.asistencia:
        // Una fila por alumna y clase realizada (US-21)
        encabezados = ['alumna', 'rut', 'sede', 'clase', 'fecha', 'estado'];
        for (final s in sesiones.where((s) => s.estado == 'realizada')) {
          for (final r in _asistenciasPorSesion[s.id] ?? const <RegistroAsistencia>[]) {
            final a = alumnas[r.alumnaId];
            if (a == null) continue;
            filas.add([nombre(a), rut(a), a.sedeNombre, '${s.numeroSesion}', fecha(s.fecha), r.estado.label]);
          }
        }
      case TipoExportacion.participacion:
        encabezados = ['alumna', 'rut', 'clase', 'fecha', 'ejercicios', 'participacion_activa'];
        for (final s in sesiones) {
          for (final p in _participacionesPorSesion[s.id] ?? const <ParticipacionClase>[]) {
            final a = alumnas[p.alumnaId];
            if (a == null) continue;
            filas.add([
              nombre(a),
              rut(a),
              '${s.numeroSesion}',
              fecha(s.fecha),
              '${p.ejerciciosResueltos}',
              p.participacionActiva ? 'sí' : 'no',
            ]);
          }
        }
    }

    final alcance = filtro.cursoId != null
        ? _cursos.firstWhere((c) => c.id == filtro.cursoId).codigo.toLowerCase()
        : (filtro.sedeId != null ? _slug(_nombreSede(filtro.sedeId!)) : 'nacional');
    final sufijo = filtro.disociado ? '_disociado' : '';
    return ResultadoExportacion(
      nombreArchivo: '${filtro.tipo.name}_$alcance$sufijo.${filtro.formato.toLowerCase()}',
      encabezados: encabezados,
      filas: filas,
    );
  }

  @override
  Future<ResultadoExportacion> previsualizarExportacion(FiltroExportacion filtro) async =>
      _armarExportacion(filtro);

  @override
  Future<ResultadoExportacion> exportarDatos(FiltroExportacion filtro) async {
    final resultado = _armarExportacion(filtro);
    // Toda descarga queda registrada en la auditoría (US-22)
    final curso = _cursos.where((c) => c.id == filtro.cursoId).firstOrNull;
    final detalleCurso = curso == null ? '' : ' · ${curso.codigo}';
    final detalleDisociado = filtro.disociado ? ' · disociada' : '';
    _registrarAuditoria(
      TipoAccionAuditoria.exportacion,
      'Exportación ${filtro.formato} de ${filtro.tipo.label.toLowerCase()}$detalleCurso'
      ' · ${resultado.filas.length} filas$detalleDisociado',
      sedeNombre: filtro.sedeId == null ? 'Todas las sedes' : _nombreSede(filtro.sedeId!),
    );
    return resultado;
  }

  @override
  Future<List<EventoAuditoria>> getEventosAuditoria({
    DateTime? desde,
    DateTime? hasta,
    String? usuaria,
    TipoAccionAuditoria? tipo,
    String? rutAlumna,
  }) async {
    final textoUsuaria = usuaria?.trim().toLowerCase() ?? '';
    final rutBuscado = rutAlumna == null ? '' : normalizarRut(rutAlumna);
    // [hasta] incluye todo ese día
    final hastaExclusivo = hasta == null ? null : DateTime(hasta.year, hasta.month, hasta.day + 1);
    final eventos = _eventosAuditoria.where((e) {
      if (desde != null && e.fecha.isBefore(desde)) return false;
      if (hastaExclusivo != null && !e.fecha.isBefore(hastaExclusivo)) return false;
      if (tipo != null && e.tipo != tipo) return false;
      if (textoUsuaria.isNotEmpty &&
          !e.usuariaNombre.toLowerCase().contains(textoUsuaria) &&
          !e.usuariaCorreo.toLowerCase().contains(textoUsuaria)) {
        return false;
      }
      if (rutBuscado.isNotEmpty && (e.alumnaRut == null || normalizarRut(e.alumnaRut!) != rutBuscado)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return eventos;
  }
}
