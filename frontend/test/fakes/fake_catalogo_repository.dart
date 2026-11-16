import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/catalogo_repository.dart';
import 'package:ninas_pro_hub/utils/calendario.dart';

/// [CatalogoRepository] en memoria con las mismas reglas que la base:
/// nombres y códigos únicos, fechas válidas, secciones paralelas confirmadas
/// y suspensión solo de sesiones programadas.
class FakeCatalogoRepository implements CatalogoRepository {
  final List<Sede> listaSedes;
  final List<CursoCatalogo> listaCursos;
  final List<Curso> listaInstancias;
  final Map<String, List<SesionClase>> sesionesPorInstancia;

  /// Si no es null, las escrituras responden con este error (ej. el 403 de la base)
  String? errorEscritura;

  var _siguienteId = 1;

  FakeCatalogoRepository({
    List<Sede>? sedes,
    List<CursoCatalogo>? cursos,
    List<Curso>? instancias,
    Map<String, List<SesionClase>>? sesiones,
  })  : listaSedes = sedes ??
            [
              const Sede(
                id: 'sede-a',
                nombre: 'Sede Beauchef',
                universidad: 'Universidad de Chile (FCFM)',
                region: 'Región Metropolitana',
                modalidad: 'Presencial',
                coordinadoraNombre: 'Camila Sepúlveda Rivas',
              ),
            ],
        listaCursos = cursos ??
            [const CursoCatalogo(id: 'cat-pcb', codigo: 'PCB', nombre: 'Programación Competitiva Básica (Python)')],
        listaInstancias = instancias ?? [],
        sesionesPorInstancia = sesiones ?? {};

  String _id(String prefijo) => '$prefijo-${_siguienteId++}';

  @override
  Future<List<Sede>> sedes() async => List.of(listaSedes);

  bool _nombreSedeUsado(String nombre, {String? excepto}) =>
      listaSedes.any((s) => s.id != excepto && s.nombre.toLowerCase() == nombre.trim().toLowerCase());

  @override
  Future<ResultadoCatalogo<void>> crearSede(DatosSede d) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    if (_nombreSedeUsado(d.nombre)) return ResultadoCatalogo.error('Ya existe una sede llamada "${d.nombre.trim()}".');
    listaSedes.add(Sede(
      id: _id('sede'),
      nombre: d.nombre.trim(),
      universidad: d.institucion.trim(),
      region: d.region.trim(),
      modalidad: d.modalidad,
      coordinadoraNombre: '',
    ));
    return const ResultadoCatalogo.ok();
  }

  @override
  Future<ResultadoCatalogo<void>> actualizarSede(String id, DatosSede d) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    if (_nombreSedeUsado(d.nombre, excepto: id)) {
      return ResultadoCatalogo.error('Ya existe una sede llamada "${d.nombre.trim()}".');
    }
    final i = listaSedes.indexWhere((s) => s.id == id);
    listaSedes[i] = listaSedes[i].copyWith(
      nombre: d.nombre.trim(),
      universidad: d.institucion.trim(),
      region: d.region.trim(),
      modalidad: d.modalidad,
      estado: d.activa ? 'activa' : 'inactiva',
    );
    return const ResultadoCatalogo.ok();
  }

  @override
  Future<List<CursoCatalogo>> cursos() async => List.of(listaCursos);

  bool _codigoUsado(String codigo, {String? excepto}) =>
      listaCursos.any((c) => c.id != excepto && c.codigo == codigo.trim().toUpperCase());

  @override
  Future<ResultadoCatalogo<void>> crearCurso(DatosCurso d) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    if (_codigoUsado(d.codigo)) {
      return ResultadoCatalogo.error('El código "${d.codigo.trim().toUpperCase()}" ya está en uso.');
    }
    listaCursos.add(CursoCatalogo(
      id: _id('cat'),
      codigo: d.codigo.trim().toUpperCase(),
      nombre: d.nombre.trim(),
      descripcion: d.descripcion.trim(),
    ));
    return const ResultadoCatalogo.ok();
  }

  @override
  Future<ResultadoCatalogo<void>> actualizarCurso(String id, DatosCurso d) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    if (_codigoUsado(d.codigo, excepto: id)) {
      return ResultadoCatalogo.error('El código "${d.codigo.trim().toUpperCase()}" ya está en uso.');
    }
    final i = listaCursos.indexWhere((c) => c.id == id);
    listaCursos[i] =
        listaCursos[i].copyWith(codigo: d.codigo.trim().toUpperCase(), nombre: d.nombre.trim(), descripcion: d.descripcion);
    return const ResultadoCatalogo.ok();
  }

  @override
  Future<List<Curso>> instancias({String? sedeId}) async =>
      listaInstancias.where((c) => sedeId == null || c.sedeId == sedeId).toList();

  @override
  Future<ResultadoCatalogo<Curso>> crearInstancia(SolicitudInstancia s, {bool nuevaSeccion = false}) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    if (!s.termino.isAfter(s.inicio)) {
      return const ResultadoCatalogo.error('La fecha de término debe ser posterior a la de inicio.');
    }
    final fechas = fechasSesiones(s.inicio, s.termino, s.diaSemana);
    if (fechas.isEmpty) return const ResultadoCatalogo.error('No hay ninguna clase entre esas fechas.');

    final periodo = periodoAcademico(s.inicio);
    final previas = listaInstancias
        .where((c) => c.catalogoId == s.catalogoId && c.sedeId == s.sedeId && '${c.anio}-${c.semestre}' == periodo)
        .toList();
    if (previas.isNotEmpty && !nuevaSeccion) {
      return ResultadoCatalogo.error(
        'Ya existe una instancia de este curso en esta sede para el período $periodo.',
        duplicada: true,
      );
    }

    final catalogo = listaCursos.firstWhere((c) => c.id == s.catalogoId);
    final sede = listaSedes.firstWhere((x) => x.id == s.sedeId);
    final partes = partesPeriodo(periodo, s.inicio);
    final seccion = previas.length + 1;
    final instancia = Curso(
      id: _id('inst'),
      codigo: codigoInstancia(
        codigoCurso: catalogo.codigo,
        sedeNombre: sede.nombre,
        anio: partes.anio,
        semestre: partes.semestre,
        seccion: seccion,
      ),
      nombre: catalogo.nombre,
      sedeId: sede.id,
      sedeNombre: sede.nombre,
      anio: partes.anio,
      semestre: partes.semestre,
      totalSesiones: fechas.length,
      catalogoId: catalogo.id,
      fechaInicio: s.inicio,
      fechaTermino: s.termino,
      diaSemana: s.diaSemana,
      seccion: seccion,
      horaInicio: s.horaInicio,
      horaFin: s.horaFin,
    );
    listaInstancias.insert(0, instancia);
    sesionesPorInstancia[instancia.id] = [
      for (var i = 0; i < fechas.length; i++)
        SesionClase(
          id: '${instancia.id}-s${i + 1}',
          cursoId: instancia.id,
          numeroSesion: i + 1,
          fecha: fechas[i],
          tema: '',
          estado: 'programada',
          horaInicio: s.horaInicio,
          horaFin: s.horaFin,
        ),
    ];
    return ResultadoCatalogo.ok(instancia);
  }

  @override
  Future<List<SesionClase>> sesiones(String instanciaId) async =>
      List.of(sesionesPorInstancia[instanciaId] ?? const <SesionClase>[])..sort((a, b) => a.fecha.compareTo(b.fecha));

  (List<SesionClase>, int) _buscar(String sesionId) {
    for (final lista in sesionesPorInstancia.values) {
      final i = lista.indexWhere((s) => s.id == sesionId);
      if (i >= 0) return (lista, i);
    }
    throw StateError('Sesión $sesionId no existe');
  }

  SesionClase _conEstado(SesionClase s, String estado, String? motivo) => SesionClase(
        id: s.id,
        cursoId: s.cursoId,
        numeroSesion: s.numeroSesion,
        fecha: s.fecha,
        tema: s.tema,
        estado: estado,
        motivoSuspension: motivo,
        esEspecial: s.esEspecial,
        horaInicio: s.horaInicio,
        horaFin: s.horaFin,
      );

  @override
  Future<ResultadoCatalogo<void>> suspenderSesion(String sesionId, String motivo) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    final (lista, i) = _buscar(sesionId);
    if (lista[i].estado == 'realizada') {
      return const ResultadoCatalogo.error('No se puede suspender una clase que ya tiene asistencia registrada.');
    }
    lista[i] = _conEstado(lista[i], 'suspendida', motivo.trim());
    return const ResultadoCatalogo.ok();
  }

  @override
  Future<ResultadoCatalogo<void>> reanudarSesion(String sesionId) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    final (lista, i) = _buscar(sesionId);
    lista[i] = _conEstado(lista[i], 'programada', null);
    return const ResultadoCatalogo.ok();
  }

  @override
  Future<ResultadoCatalogo<SesionClase>> agregarSesionEspecial({
    required String instanciaId,
    required DateTime fecha,
    required String horaInicio,
    required String horaFin,
  }) async {
    if (errorEscritura != null) return ResultadoCatalogo.error(errorEscritura);
    final lista = sesionesPorInstancia.putIfAbsent(instanciaId, () => []);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    if (lista.any((s) => s.fecha == dia)) {
      return ResultadoCatalogo.error('El curso ya tiene una sesión el ${dia.day}-${dia.month}-${dia.year}.');
    }
    final numero = lista.fold<int>(0, (m, s) => s.numeroSesion > m ? s.numeroSesion : m) + 1;
    final sesion = SesionClase(
      id: '$instanciaId-s$numero',
      cursoId: instanciaId,
      numeroSesion: numero,
      fecha: dia,
      tema: '',
      estado: 'programada',
      esEspecial: true,
      horaInicio: horaInicio,
      horaFin: horaFin,
    );
    lista.add(sesion);
    return ResultadoCatalogo.ok(sesion);
  }
}
