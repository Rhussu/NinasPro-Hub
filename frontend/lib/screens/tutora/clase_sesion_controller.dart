import 'package:flutter/foundation.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/clase_repository.dart';

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// La clase ya llegó a su fecha y no está suspendida: admite pase de lista
bool sesionRegistrable(SesionClase sesion, DateTime hoy) => !sesion.suspendida && !_dia(sesion.fecha).isAfter(_dia(hoy));

/// Clase que se opera hoy: la última no suspendida cuya fecha ya llegó (la de
/// hoy, o la de la semana mientras no llegue la siguiente). Si el curso aún no
/// empieza, la primera.
SesionClase? elegirSesionActual(List<SesionClase> sesiones, DateTime hoy) {
  final activas = sesiones.where((s) => !s.suspendida).toList();
  return activas.where((s) => sesionRegistrable(s, hoy)).lastOrNull ?? activas.firstOrNull ?? sesiones.firstOrNull;
}

/// Lugares del podio Kahoot según las presentes: hasta 3 (con una sola, queda primera)
int lugaresPodio(int presentes) => presentes.clamp(0, 3);

/// Regla US-13: la tutora solo alterna Presente ↔ Ausente.
/// Devuelve null si la alumna está Justificada (la gestiona el Equipo de Gestión).
EstadoAsistencia? alternarEstado(EstadoAsistencia estado) => switch (estado) {
  EstadoAsistencia.justificada => null,
  EstadoAsistencia.presente => EstadoAsistencia.ausente,
  _ => EstadoAsistencia.presente,
};

/// Estado con que entra una alumna al pase de lista que aún no se guarda:
/// presente, o justificada si tiene un justificativo aprobado (US-13 escenario 1, US-16 escenario 2)
RegistroAsistencia precargarRegistro(RegistroAsistencia r) => r.estado != EstadoAsistencia.pendiente
    ? r
    : r.copyWith(estado: r.justificadaPorAdelantado ? EstadoAsistencia.justificada : EstadoAsistencia.presente);

/// Estado compartido de la clase en curso (asistencia, ejercicios, fotos y podio Kahoot).
///
/// Lo usan tanto la Tutora ([TutoraMobileScreen]) como el Equipo de Gestión,
/// ya que ambos roles operan la misma clase en el aula. La clase en curso es
/// la de hoy del curso elegido (ver [elegirSesionActual]).
class ClaseSesionController extends ChangeNotifier {
  final ClaseRepository repository;

  /// Si no es null, solo los cursos asignados a esta tutora; si es null, los de la sede (Gestión)
  final String? tutoraId;

  /// Fecha de hoy (las pruebas la fijan)
  final DateTime Function() hoy;

  ClaseSesionController({required this.repository, this.tutoraId, DateTime Function()? hoy})
    : hoy = hoy ?? DateTime.now {
    repository.cambiosPendientes.addListener(_alCambiarPendientes);
  }

  bool cargando = true;
  String? error;

  List<Curso> cursos = [];
  Curso? curso;
  List<SesionClase> sesiones = [];
  SesionClase? _sesionActual;

  /// Pase de lista de la clase en curso, con los cambios aún sin guardar
  List<RegistroAsistencia> registros = [];

  /// Último pase de lista guardado (en la nube o en el dispositivo)
  List<RegistroAsistencia> _guardados = [];
  bool tienePaseLista = false;

  /// Hay cambios de esta clase guardados solo en el dispositivo (US-14 escenario 1)
  bool pendienteDeEnvio = false;

  List<ParticipacionClase> participaciones = [];

  /// Podio Kahoot de la sesión: ids de alumna del 1° lugar en adelante (1 a 3)
  List<String> podioAlumnas = const [];

  SesionClase? get sesionActual => _sesionActual;
  String get sesionId => _sesionActual?.id ?? '';

  /// La clase en curso ya admite el pase de lista
  bool get puedeRegistrar => _sesionActual != null && sesionRegistrable(_sesionActual!, hoy());

  @override
  void dispose() {
    repository.cambiosPendientes.removeListener(_alCambiarPendientes);
    super.dispose();
  }

  // Al subirse los pendientes, la lista deja de figurar "pendiente de envío" (US-14 escenario 3)
  void _alCambiarPendientes() {
    if (pendienteDeEnvio && repository.cambiosPendientes.value == 0) {
      pendienteDeEnvio = false;
      notifyListeners();
    }
  }

  /// Carga los cursos, elige el de la clase de hoy y su pase de lista
  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      cursos = await repository.instancias(tutoraId: tutoraId);
      curso = cursos.where((c) => c.id == curso?.id).firstOrNull ?? _cursoVigente(cursos);
      await _cargarCurso();
    } catch (_) {
      error = 'No pudimos cargar la clase. Revisa tu conexión y desliza hacia abajo para reintentar.';
    }
    cargando = false;
    notifyListeners();
  }

  /// Cambia de curso (tutoras o sedes con más de un curso vigente)
  Future<void> elegirCurso(String instanciaId) async {
    if (instanciaId == curso?.id) return;
    curso = cursos.where((c) => c.id == instanciaId).firstOrNull;
    await cargarCursoActual();
  }

  Future<void> cargarCursoActual() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      await _cargarCurso();
    } catch (_) {
      error = 'No pudimos cargar la clase. Revisa tu conexión y desliza hacia abajo para reintentar.';
    }
    cargando = false;
    notifyListeners();
  }

  // El curso que está en curso hoy; si no hay, el más reciente
  Curso? _cursoVigente(List<Curso> lista) {
    final dia = _dia(hoy());
    return lista.where((c) {
          final inicio = c.fechaInicio, termino = c.fechaTermino;
          return inicio != null && termino != null && !_dia(inicio).isAfter(dia) && !_dia(termino).isBefore(dia);
        }).firstOrNull ??
        lista.firstOrNull;
  }

  Future<void> _cargarCurso() async {
    final c = curso;
    sesiones = c == null ? [] : await repository.sesiones(c.id);
    _sesionActual = elegirSesionActual(sesiones, hoy());
    final s = _sesionActual;
    _aplicarLista(s == null ? const ListaClase() : await repository.lista(s.id));
  }

  void _aplicarLista(ListaClase lista) {
    tienePaseLista = lista.tienePaseLista;
    pendienteDeEnvio = lista.conPendientes;
    _guardados = lista.registros;
    // Sin pase de lista, todas parten presentes salvo las justificadas (US-13 escenario 1)
    registros = [for (final r in lista.registros) puedeRegistrar ? precargarRegistro(r) : r];
    participaciones = List.of(lista.participaciones);
    podioAlumnas = lista.podioAlumnas;
  }

  /// Pase de lista de otra clase del curso (historial)
  Future<ListaClase> listaDeSesion(String id) => repository.lista(id);

  int _contar(Iterable<RegistroAsistencia> lista, EstadoAsistencia estado) => lista.where((r) => r.estado == estado).length;

  int get totalPresentes => _contar(registros, EstadoAsistencia.presente);
  int get totalAusentes => _contar(registros, EstadoAsistencia.ausente);
  int get totalJustificadas => _contar(registros, EstadoAsistencia.justificada);

  /// Presentes según el último pase de lista guardado
  int get presentesGuardadas => tienePaseLista ? _contar(_guardados, EstadoAsistencia.presente) : 0;

  /// Alumnas presentes del pase de lista guardado: las únicas con ejercicios, fotos y podio (US-28, US-29)
  List<RegistroAsistencia> get alumnasPresentes =>
      tienePaseLista ? _guardados.where((r) => r.estado == EstadoAsistencia.presente).toList() : const [];

  /// Alterna Presente ↔ Ausente. Devuelve `false` si la alumna está Justificada (bloqueada).
  bool ciclarEstado(int index) {
    final reg = registros[index];
    final nuevo = alternarEstado(reg.estado);
    if (nuevo == null) return false;
    registros[index] = reg.copyWith(estado: nuevo, horaMarcado: DateTime.now());
    notifyListeners();
    return true;
  }

  /// Guarda el pase de lista de la clase en curso (US-13, US-14)
  Future<ResultadoGuardado> guardarAsistencia() => guardarAsistenciaDe(sesionId, registros);

  /// Guarda el pase de lista de una clase del curso: la de hoy o una corrección del historial (US-15)
  Future<ResultadoGuardado> guardarAsistenciaDe(String claseId, List<RegistroAsistencia> lista) async {
    final resultado = await repository.guardarAsistencia(claseId, lista);
    if (resultado.rechazado) return resultado;

    // El primer pase de lista deja la clase realizada (US-13 escenario 4)
    sesiones = [for (final s in sesiones) s.id == claseId && s.estado == 'programada' ? s.copyWith(estado: 'realizada') : s];
    if (claseId == sesionId) {
      _sesionActual = sesiones.where((s) => s.id == claseId).firstOrNull;
      await _refrescarLista(lista);
      if (resultado.pendiente) pendienteDeEnvio = true;
    }
    notifyListeners();
    return resultado;
  }

  // Relee la lista (trae la autora y las justificadas que se mantuvieron); sin conexión usa lo guardado
  Future<void> _refrescarLista(List<RegistroAsistencia> guardada) async {
    try {
      _aplicarLista(await repository.lista(sesionId));
    } catch (_) {
      _guardados = List.of(guardada);
      registros = List.of(guardada);
      tienePaseLista = true;
    }
  }

  /// Participación registrada de la alumna, o una nueva en cero
  ParticipacionClase participacionDe(RegistroAsistencia registro) =>
      participaciones.where((p) => p.id == registro.id).firstOrNull ??
      ParticipacionClase(
        id: registro.id,
        sesionId: registro.sesionId,
        alumnaId: registro.alumnaId,
        alumnaNombre: registro.alumnaNombre,
        ejerciciosResueltos: 0,
        participacionActiva: false,
      );

  void actualizarParticipacion(ParticipacionClase part) {
    final idx = participaciones.indexWhere((p) => p.id == part.id);
    if (idx != -1) {
      participaciones[idx] = part;
    } else {
      participaciones.add(part);
    }
    notifyListeners();
  }

  /// Guarda los ejercicios y la participación de las presentes (US-28)
  Future<ResultadoGuardado> guardarParticipacion() async {
    final lista = [for (final r in alumnasPresentes) participacionDe(r)];
    final resultado = await repository.guardarParticipacion(sesionId, lista);
    if (resultado.pendiente) pendienteDeEnvio = true;
    notifyListeners();
    return resultado;
  }

  /// Guarda el podio con los ids de alumna en orden, del 1° lugar en adelante (US-29).
  /// Lleva tantos lugares como presentes haya, hasta 3: con una sola, queda primera.
  Future<ResultadoGuardado> guardarPodioKahoot(List<String> alumnaIds) async {
    final esperados = lugaresPodio(alumnasPresentes.length);
    if (esperados == 0) {
      return const ResultadoGuardado(EstadoGuardado.rechazado, 'No hay alumnas presentes para el podio.');
    }
    if (alumnaIds.length != esperados || alumnaIds.toSet().length != alumnaIds.length) {
      return const ResultadoGuardado(EstadoGuardado.rechazado, 'Elige una alumna distinta para cada lugar del podio.');
    }
    String inscripcion(String alumnaId) => alumnasPresentes.firstWhere((r) => r.alumnaId == alumnaId).id;
    final inscripciones = [for (final id in alumnaIds) inscripcion(id)];
    final resultado = await repository.guardarPodio(sesionId, inscripciones);
    if (!resultado.rechazado) {
      podioAlumnas = List.unmodifiable(alumnaIds);
      if (resultado.pendiente) pendienteDeEnvio = true;
    }
    notifyListeners();
    return resultado;
  }
}
