import 'package:flutter/foundation.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';

/// Estado compartido de la clase en curso (asistencia, ejercicios, fotos y podio Kahoot).
///
/// Lo usan tanto la Tutora ([TutoraMobileScreen]) como el Equipo de Gestión,
/// ya que ambos roles operan la misma clase en el aula.
class ClaseSesionController extends ChangeNotifier {
  final HubRepository repository;
  final String sesionId;
  final String cursoId;

  ClaseSesionController({
    required this.repository,
    this.sesionId = 'sesion-4',
    this.cursoId = 'curso-pcb-stgo',
  });

  bool cargando = true;
  List<SesionClase> sesiones = [];
  List<RegistroAsistencia> registros = [];
  List<ParticipacionClase> participaciones = [];
  bool fotoSubida = false;

  // Podio Kahoot de la sesión
  String? primerLugarId;
  String? segundoLugarId;
  String? tercerLugarId;

  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    final reg = await repository.getAsistenciaSesion(sesionId: sesionId);
    final part = await repository.getParticipacionSesion(sesionId: sesionId);
    final ses = await repository.getSesiones(cursoId: cursoId);

    sesiones = ses;
    registros = List.from(reg);
    participaciones = List.from(part);
    cargando = false;
    notifyListeners();
  }

  /// Clase en curso dentro del cronograma del curso
  SesionClase? get sesionActual => sesiones.where((s) => s.id == sesionId).firstOrNull;

  /// Pase de lista guardado de otra clase del curso (solo lectura en el historial)
  Future<List<RegistroAsistencia>> registrosDeSesion(String id) async {
    if (id == sesionId) return registros;
    return repository.getAsistenciaSesion(sesionId: id);
  }

  int get totalPresentes =>
      registros.where((r) => r.estado == EstadoAsistencia.presente).length;

  int get totalAusentes =>
      registros.where((r) => r.estado == EstadoAsistencia.ausente).length;

  int get totalJustificadas =>
      registros.where((r) => r.estado == EstadoAsistencia.justificada).length;

  List<RegistroAsistencia> get alumnasPresentes =>
      registros.where((r) => r.estado == EstadoAsistencia.presente).toList();

  /// Regla US-13: solo alterna Presente ↔ Ausente.
  /// Devuelve `false` si la alumna está Justificada (bloqueada).
  bool ciclarEstado(int index) {
    final reg = registros[index];
    if (reg.estado == EstadoAsistencia.justificada) return false;

    final nuevo = reg.estado == EstadoAsistencia.presente
        ? EstadoAsistencia.ausente
        : EstadoAsistencia.presente;

    registros[index] = reg.copyWith(estado: nuevo, horaMarcado: DateTime.now());
    notifyListeners();
    return true;
  }

  /// Guarda la asistencia y devuelve el tiempo que tomó en milisegundos.
  Future<int> guardarAsistencia() async {
    final stopwatch = Stopwatch()..start();
    await repository.guardarAsistencia(sesionId: sesionId, registros: registros);
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  void actualizarParticipacion(ParticipacionClase part) {
    final idx = participaciones.indexWhere((p) => p.alumnaId == part.alumnaId);
    if (idx != -1) {
      participaciones[idx] = part;
    } else {
      participaciones.add(part);
    }
    notifyListeners();
  }

  void marcarFotoSubida() {
    fotoSubida = true;
    notifyListeners();
  }

  Future<void> guardarPodioKahoot({
    required String primerId,
    required String segundoId,
    required String tercerId,
  }) async {
    await repository.guardarPodioKahoot(
      sesionId: sesionId,
      primerLugarAlumnaId: primerId,
      segundoLugarAlumnaId: segundoId,
      tercerLugarAlumnaId: tercerId,
    );
    primerLugarId = primerId;
    segundoLugarId = segundoId;
    tercerLugarId = tercerId;
    notifyListeners();
  }
}
