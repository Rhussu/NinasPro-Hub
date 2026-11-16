import 'package:ninas_pro_hub/config/ninaspro_theme.dart';
import 'package:ninas_pro_hub/repositories/justificativos_repository.dart';

import 'fake_clase_repository.dart';

/// [JustificativosRepository] en memoria con las reglas de las RPC de la
/// migración 18: un vigente por clase y alumna, el rechazo exige observación,
/// solo se resuelve un pendiente y lo aprobado justifica la asistencia del
/// [FakeClaseRepository] (si se le pasa).
class FakeJustificativosRepository implements JustificativosRepository {
  final FakeClaseRepository? clase;

  /// Lo que la usuaria ve (la alumna, los suyos; Gestión, los de su sede)
  final List<JustificativoDetalle> lista;

  /// Clases para la alumna (US-35)
  final List<ClaseJustificable> clases;

  /// Si no es null, la base rechaza las escrituras con este mensaje
  String? rechazo;

  var _secuencia = 0;

  FakeJustificativosRepository({this.clase, List<JustificativoDetalle>? lista, List<ClaseJustificable>? clases})
    : lista = lista ?? [],
      clases = clases ?? [];

  JustificativoDetalle porId(String id) => lista.firstWhere((j) => j.id == id);

  @override
  Future<List<JustificativoDetalle>> justificativos() async => List.of(lista);

  @override
  Future<List<ClaseJustificable>> clasesParaJustificar() async => List.of(clases);

  Resultado<void>? _validar({required String claseId, required String inscripcionId, required String explicacion}) {
    if (rechazo != null) return Resultado.error(rechazo);
    if (explicacion.trim().isEmpty) return const Resultado.error('Escribe la explicación de la inasistencia.');
    final vigente = lista.where(
      (j) => j.claseId == claseId && j.inscripcionId == inscripcionId && j.estado != EstadoJustificativo.rechazado,
    );
    if (vigente.any((j) => j.estado == EstadoJustificativo.pendiente)) {
      return const Resultado.error('Ya hay un justificativo pendiente para esa clase.');
    }
    if (vigente.isNotEmpty) return const Resultado.error('La inasistencia de esa clase ya está justificada.');
    return null;
  }

  JustificativoDetalle _nuevo({
    required String claseId,
    required String inscripcionId,
    required MotivoJustificativo motivo,
    required String explicacion,
    required EstadoJustificativo estado,
    required bool porAlumna,
    String alumnaNombre = 'Valentina Soto Morales',
    int numeroSesion = 4,
  }) {
    return JustificativoDetalle(
      id: 'just-${++_secuencia}',
      claseId: claseId,
      inscripcionId: inscripcionId,
      alumnaId: 'alumna-$inscripcionId',
      alumnaNombre: alumnaNombre,
      alumnaRut: '',
      numeroSesion: numeroSesion,
      claseFecha: DateTime(2026, 11, 21),
      cursoNombre: 'Programación Competitiva Básica (Python)',
      sedeNombre: 'Sede Beauchef',
      motivo: motivo,
      explicacion: explicacion.trim().isEmpty ? null : explicacion.trim(),
      estado: estado,
      enviadoPorAlumna: porAlumna,
      creadoEn: DateTime.now(),
    );
  }

  @override
  Future<Resultado<void>> enviar({
    required ClaseJustificable clase,
    required MotivoJustificativo motivo,
    required String explicacion,
  }) async {
    final error = _validar(claseId: clase.claseId, inscripcionId: clase.inscripcionId, explicacion: explicacion);
    if (error != null) return error;
    lista.insert(
      0,
      _nuevo(
        claseId: clase.claseId,
        inscripcionId: clase.inscripcionId,
        motivo: motivo,
        explicacion: explicacion,
        estado: EstadoJustificativo.pendiente,
        porAlumna: true,
        numeroSesion: clase.numeroSesion,
      ),
    );
    final i = clases.indexWhere((c) => c.claseId == clase.claseId);
    if (i != -1) {
      final c = clases[i];
      clases[i] = ClaseJustificable(
        claseId: c.claseId,
        inscripcionId: c.inscripcionId,
        numeroSesion: c.numeroSesion,
        fecha: c.fecha,
        tema: c.tema,
        cursoNombre: c.cursoNombre,
        asistencia: c.asistencia,
        justificativo: EstadoJustificativo.pendiente,
      );
    }
    return const Resultado.ok();
  }

  @override
  Future<Resultado<void>> registrar({
    required String claseId,
    required String inscripcionId,
    required MotivoJustificativo motivo,
    required String explicacion,
  }) async {
    final error = _validar(claseId: claseId, inscripcionId: inscripcionId, explicacion: explicacion);
    if (error != null) return error;
    final nombre = clase?.alumnas.where((a) => a.id == inscripcionId).firstOrNull?.nombre;
    lista.insert(
      0,
      _nuevo(
        claseId: claseId,
        inscripcionId: inscripcionId,
        motivo: motivo,
        explicacion: explicacion,
        estado: EstadoJustificativo.aceptado,
        porAlumna: false,
        alumnaNombre: nombre ?? 'Alumna',
      ),
    );
    clase?.fijarJustificativo(claseId, inscripcionId, EstadoJustificativo.aceptado, motivo: motivo);
    return const Resultado.ok();
  }

  JustificativoDetalle _conEstado(JustificativoDetalle j, EstadoJustificativo estado, String? observacion) =>
      JustificativoDetalle(
        id: j.id,
        claseId: j.claseId,
        inscripcionId: j.inscripcionId,
        alumnaId: j.alumnaId,
        alumnaNombre: j.alumnaNombre,
        alumnaRut: j.alumnaRut,
        numeroSesion: j.numeroSesion,
        claseFecha: j.claseFecha,
        claseTema: j.claseTema,
        cursoNombre: j.cursoNombre,
        sedeNombre: j.sedeNombre,
        motivo: j.motivo,
        explicacion: j.explicacion,
        estado: estado,
        observacion: observacion,
        resueltoPor: 'Camila Sepúlveda Rivas',
        fechaResolucion: DateTime.now(),
        enviadoPorAlumna: j.enviadoPorAlumna,
        creadoEn: j.creadoEn,
      );

  @override
  Future<Resultado<void>> resolver(String id, {required bool aprobar, String? observacion}) async {
    if (rechazo != null) return Resultado.error(rechazo);
    final i = lista.indexWhere((j) => j.id == id);
    final j = lista[i];
    if (j.estado != EstadoJustificativo.pendiente) return const Resultado.error('El justificativo ya fue resuelto.');
    final obs = observacion?.trim();
    if (!aprobar && (obs == null || obs.isEmpty)) {
      return const Resultado.error('Indica el motivo del rechazo para que la alumna lo sepa.');
    }
    final estado = aprobar ? EstadoJustificativo.aceptado : EstadoJustificativo.rechazado;
    lista[i] = _conEstado(j, estado, obs == null || obs.isEmpty ? null : obs);
    clase?.fijarJustificativo(j.claseId, j.inscripcionId, estado, motivo: j.motivo);
    return const Resultado.ok();
  }

  @override
  Future<Resultado<void>> eliminar(String id) async {
    if (rechazo != null) return Resultado.error(rechazo);
    final j = porId(id);
    lista.remove(j);
    clase?.quitarJustificativo(j.claseId, j.inscripcionId);
    return const Resultado.ok();
  }
}

/// Clase de la alumna para justificar en las pruebas
ClaseJustificable claseJustificable(
  int numero, {
  DateTime? fecha,
  EstadoAsistencia asistencia = EstadoAsistencia.pendiente,
  EstadoJustificativo? justificativo,
}) => ClaseJustificable(
  claseId: 'clase-$numero',
  inscripcionId: 'insc-1',
  numeroSesion: numero,
  // La clase 4 es hoy, como en [FakeClaseRepository]
  fecha:
      fecha ??
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(Duration(days: 7 * (numero - 4))),
  tema: 'Tema de la clase $numero',
  cursoNombre: 'Programación Competitiva Básica (Python)',
  asistencia: asistencia,
  justificativo: justificativo,
);
