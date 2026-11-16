import 'package:ninas_pro_hub/models/hub_models.dart';
import 'package:ninas_pro_hub/repositories/alumnas_repository.dart';
import 'package:ninas_pro_hub/utils/rut.dart';

/// [AlumnasRepository] en memoria con las reglas principales de la base:
/// RUT con módulo 11, RUT repetido en la planilla, contacto del apoderado
/// obligatorio, ficha única por RUT, activación con el consentimiento y
/// revocación solo de canales autorizados.
class FakeAlumnasRepository implements AlumnasRepository {
  final List<Curso> listaInstancias;
  final Map<String, FichaAlumna> fichas = {};
  final List<InscripcionNomina> inscripciones = [];

  /// Respaldos subidos: ruta -> nombre original
  final Map<String, String> respaldos = {};

  /// Si no es null, las escrituras responden con este error
  String? errorEscritura;

  var _id = 1;

  FakeAlumnasRepository({List<Curso>? instancias})
    : listaInstancias =
          instancias ??
          const [
            Curso(
              id: 'inst-a',
              codigo: 'PCB-2026-S2-BEAUCHEF',
              nombre: 'Programación Competitiva Básica',
              sedeId: 'sede-a',
              sedeNombre: 'Sede Beauchef',
              anio: 2026,
              semestre: 2,
              totalSesiones: 18,
            ),
            Curso(
              id: 'inst-b',
              codigo: 'PCB-2026-S2-VALPARAISO',
              nombre: 'Programación Competitiva Básica',
              sedeId: 'sede-b',
              sedeNombre: 'Sede Valparaíso',
              anio: 2026,
              semestre: 2,
              totalSesiones: 18,
            ),
          ];

  /// Agrega una alumna inscrita (preinscrita salvo que tenga el consentimiento)
  FichaAlumna agregar({
    required String rut,
    required String nombres,
    required String apellidos,
    String instanciaId = 'inst-a',
    ConsentimientoDatos consentimiento = ConsentimientoDatos.pendiente,
    Map<CanalImagen, bool> canales = const {},
    String? documento,
    int sesionesTranscurridas = 0,
    int clasesAsistidas = 0,
    int clasesComputables = 0,
  }) {
    final id = 'alumna-${_id++}';
    final ficha = FichaAlumna(
      id: id,
      rut: formatearRut(rut),
      nombres: nombres,
      apellidos: apellidos,
      fechaNacimiento: DateTime(2011, 4, 15),
      apoderado: const ApoderadoFicha(
        nombres: 'Marcela',
        apellidos: 'Morales',
        telefono: '+56 9 8765 4321',
        correo: 'marcela@correo.cl',
        parentesco: 'Madre',
      ),
      autorizaciones: AutorizacionesFicha(
        tratamientoDatos: consentimiento,
        canales: canales,
        documento: documento,
        actualizadoEn: consentimiento == ConsentimientoDatos.pendiente ? null : DateTime(2026, 3, 28),
        registradoPor: consentimiento == ConsentimientoDatos.pendiente ? null : 'Directiva Nacional',
      ),
    );
    fichas[id] = ficha;
    _inscribir(ficha, instanciaId, sesionesTranscurridas, clasesAsistidas, clasesComputables);
    return ficha;
  }

  void _inscribir(FichaAlumna ficha, String instanciaId, [int sesiones = 0, int asistidas = 0, int computables = 0]) {
    final inst = listaInstancias.firstWhere((c) => c.id == instanciaId);
    final consentimiento = ficha.autorizaciones.tratamientoDatos;
    inscripciones.add(InscripcionNomina(
      inscripcionId: 'insc-${_id++}',
      alumnaId: ficha.id,
      rut: ficha.rut,
      nombres: ficha.nombres,
      apellidos: ficha.apellidos,
      instanciaId: inst.id,
      sedeId: inst.sedeId,
      sedeNombre: inst.sedeNombre,
      cursoCodigo: inst.codigo,
      cursoNombre: inst.nombre,
      estado: consentimiento == ConsentimientoDatos.otorgado ? 'activa' : 'preinscrita',
      fechaInscripcion: DateTime(2026, 8, 1),
      consentimiento: consentimiento,
      autorizaFotos: consentimiento == ConsentimientoDatos.otorgado && ficha.autorizaciones.canales.values.any((v) => v),
      sesionesTranscurridas: sesiones,
      regularizacionUrgente: consentimiento != ConsentimientoDatos.otorgado && sesiones >= 2,
      clasesAsistidas: asistidas,
      clasesComputables: computables,
    ));
  }

  /// Rehace las filas de la nómina de una alumna tras cambiar su ficha
  void _sincronizar(String alumnaId) {
    final ficha = fichas[alumnaId]!;
    final a = ficha.autorizaciones;
    for (var i = 0; i < inscripciones.length; i++) {
      final x = inscripciones[i];
      if (x.alumnaId != alumnaId) continue;
      final estado = switch (x.estado) {
        'preinscrita' when a.tratamientoDatos == ConsentimientoDatos.otorgado => 'activa',
        'activa' when a.tratamientoDatos != ConsentimientoDatos.otorgado => 'preinscrita',
        final e => e,
      };
      inscripciones[i] = InscripcionNomina(
        inscripcionId: x.inscripcionId,
        alumnaId: x.alumnaId,
        rut: x.rut,
        nombres: x.nombres,
        apellidos: x.apellidos,
        instanciaId: x.instanciaId,
        sedeId: x.sedeId,
        sedeNombre: x.sedeNombre,
        cursoCodigo: x.cursoCodigo,
        cursoNombre: x.cursoNombre,
        estado: estado,
        fechaInscripcion: x.fechaInscripcion,
        fechaRetiro: x.fechaRetiro,
        motivoRetiro: x.motivoRetiro,
        consentimiento: a.tratamientoDatos,
        autorizaFotos: a.tratamientoDatos == ConsentimientoDatos.otorgado && a.canales.values.any((v) => v),
        sesionesTranscurridas: x.sesionesTranscurridas,
        regularizacionUrgente: estado == 'preinscrita' && x.sesionesTranscurridas >= 2,
        clasesAsistidas: x.clasesAsistidas,
        clasesComputables: x.clasesComputables,
      );
    }
  }

  FichaAlumna? _porRut(String rut) =>
      fichas.values.where((f) => normalizarRut(f.rut) == normalizarRut(rut)).firstOrNull;

  @override
  Future<List<InscripcionNomina>> nomina({String? sedeId}) async =>
      inscripciones.where((i) => sedeId == null || i.sedeId == sedeId).toList();

  @override
  Future<List<Curso>> instancias() async => List.of(listaInstancias);

  @override
  Future<FichaAlumna?> ficha(String alumnaId) async {
    final f = fichas[alumnaId];
    if (f == null) return null;
    return FichaAlumna(
      id: f.id,
      rut: f.rut,
      nombres: f.nombres,
      apellidos: f.apellidos,
      fechaNacimiento: f.fechaNacimiento,
      correo: f.correo,
      apoderado: f.apoderado,
      autorizaciones: f.autorizaciones,
      inscripciones: inscripciones.where((i) => i.alumnaId == alumnaId).toList(),
    );
  }

  /// Pendientes guardados al confirmar cargas con conflictos
  final List<ConflictoImportacion> pendientes = [];

  FilaNomina _diagnosticar(String instanciaId, FilaNomina f, List<FilaNomina> todas) {
    String texto(String clave) => '${f.datos[clave] ?? ''}'.trim();
    final rut = texto('rut');
    final res = f.resolucion;
    final base = (
      nombre: '${texto('nombres')} ${texto('apellidos')}'.trim(),
      rut: validarRut(rut) ? formatearRut(rut) : rut,
      apoderado: '${texto('nombres_apoderado')} ${texto('apellidos_apoderado')}'.trim(),
    );
    FilaNomina con(EstadoFilaNomina estado, {List<String> motivos = const [], List<TipoConflicto> conflictos = const [],
            List<DiferenciaFicha> diferencias = const [], List<int> repetidas = const []}) =>
        FilaNomina(
          numero: f.numero,
          datos: f.datos,
          nombre: base.nombre,
          rut: base.rut,
          apoderado: base.apoderado,
          estado: estado,
          motivo: motivos.isEmpty ? null : motivos.join('. '),
          conflictos: conflictos,
          diferencias: diferencias,
          filasRepetidas: repetidas,
          resolucion: res,
          conflictoId: f.conflictoId,
        );

    if (res == ResolucionFila.descartar) return con(EstadoFilaNomina.descartada);
    final existente = validarRut(rut) ? _porRut(rut) : null;
    if (existente != null && inscripciones.any((i) => i.alumnaId == existente.id && i.instanciaId == instanciaId)) {
      return con(EstadoFilaNomina.inscrita, motivos: const ['Ya está inscrita en este curso']);
    }
    final errores = [
      if (rut.isEmpty) 'Falta el RUT de la alumna' else if (!validarRut(rut)) 'RUT de la alumna inválido (dígito verificador)',
      if (texto('telefono_apoderado').isEmpty || texto('correo_apoderado').isEmpty)
        'El correo y el teléfono del apoderado/a son obligatorios por protocolo institucional',
    ];
    final repetidas = [
      for (final o in todas)
        if (o.resolucion != ResolucionFila.descartar && rut.isNotEmpty && normalizarRut('${o.datos['rut'] ?? ''}') == normalizarRut(rut))
          o.numero,
    ];
    final correo = res == ResolucionFila.sinCorreo ? '' : texto('correo');
    final diferencias = [
      if (existente != null && res == null && texto('nombres').isNotEmpty && texto('nombres') != existente.nombres)
        DiferenciaFicha(campo: 'Nombres', ficha: existente.nombres, planilla: texto('nombres')),
    ];
    final conflictos = [
      if (repetidas.length > 1) TipoConflicto.rutRepetido,
      if (diferencias.isNotEmpty) TipoConflicto.fichaDistinta,
      if (correo.isNotEmpty && correosEnUso.contains(correo)) TipoConflicto.correoEnUso,
    ];
    final motivosConflicto = [
      if (repetidas.length > 1) 'RUT repetido en la planilla (filas ${repetidas.join(', ')}): elige qué fila vale',
      if (diferencias.isNotEmpty) 'El RUT ya tiene ficha con datos distintos: mantén la ficha o actualízala',
      if (conflictos.contains(TipoConflicto.correoEnUso)) 'El correo de la alumna ya lo usa otra persona',
    ];
    if (errores.isNotEmpty) {
      return con(EstadoFilaNomina.invalida, motivos: [...errores, ...motivosConflicto], conflictos: conflictos);
    }
    if (conflictos.isNotEmpty) {
      return con(
        EstadoFilaNomina.conflicto,
        motivos: motivosConflicto,
        conflictos: conflictos,
        diferencias: diferencias,
        repetidas: repetidas.length > 1 ? repetidas : const [],
      );
    }
    return con(existente == null ? EstadoFilaNomina.nueva : EstadoFilaNomina.existente);
  }

  /// Correos que ya usa otra persona
  final Set<String> correosEnUso = {};

  /// Filas enviadas en la última confirmación (para revisar lo que mandó la app)
  List<FilaNomina>? ultimasFilasEnviadas;

  @override
  Future<ResultadoAlumnas<RevisionNomina>> revisarImportacion({
    required String instanciaId,
    required String archivo,
    required List<FilaNomina> filas,
  }) async {
    if (errorEscritura != null) return ResultadoAlumnas.error(errorEscritura);
    return ResultadoAlumnas.ok(
      RevisionNomina(archivo: archivo, filas: [for (final f in filas) _diagnosticar(instanciaId, f, filas)]),
    );
  }

  @override
  Future<ResultadoAlumnas<({int inscritas, int pendientes, RevisionNomina revision})>> confirmarImportacion({
    required String instanciaId,
    required String archivo,
    required List<FilaNomina> filas,
  }) async {
    if (errorEscritura != null) return ResultadoAlumnas.error(errorEscritura);
    ultimasFilasEnviadas = filas;
    final diagnostico = [for (final f in filas) _diagnosticar(instanciaId, f, filas)];
    var inscritas = 0;
    var enPendiente = 0;
    final resultado = <FilaNomina>[];
    for (final d in diagnostico) {
      if (d.conflictoId != null) pendientes.removeWhere((c) => c.id == d.conflictoId);
      if (d.estado.porResolver) {
        pendientes.add(ConflictoImportacion(
          id: 'conflicto-${_id++}',
          instanciaId: instanciaId,
          cursoEtiqueta: listaInstancias.firstWhere((c) => c.id == instanciaId).codigo,
          archivo: archivo,
          numeroFila: d.numero,
          datos: d.datos,
          motivo: d.motivo ?? '',
          creadoEn: DateTime(2026, 11, 16),
        ));
        enPendiente++;
        resultado.add(FilaNomina(numero: d.numero, datos: d.datos, nombre: d.nombre, rut: d.rut, estado: EstadoFilaNomina.pendiente, motivo: d.motivo));
        continue;
      }
      if (d.estado.seInscribe) {
        final ficha = _porRut(d.rut) ??
            agregarFicha(rut: d.rut, nombres: d.datos['nombres'] as String, apellidos: d.datos['apellidos'] as String);
        if (d.resolucion == ResolucionFila.actualizarFicha) {
          fichas[ficha.id] = FichaAlumna(
            id: ficha.id,
            rut: ficha.rut,
            nombres: d.datos['nombres'] as String,
            apellidos: d.datos['apellidos'] as String,
            apoderado: ficha.apoderado,
            autorizaciones: ficha.autorizaciones,
          );
        }
        _inscribir(fichas[ficha.id]!, instanciaId);
        inscritas++;
      }
      resultado.add(d);
    }
    return ResultadoAlumnas.ok((
      inscritas: inscritas,
      pendientes: enPendiente,
      revision: RevisionNomina(archivo: archivo, filas: resultado),
    ));
  }

  FichaAlumna agregarFicha({required String rut, required String nombres, required String apellidos}) {
    final ficha = FichaAlumna(id: 'alumna-${_id++}', rut: formatearRut(rut), nombres: nombres, apellidos: apellidos);
    fichas[ficha.id] = ficha;
    return ficha;
  }

  @override
  Future<ResultadoAlumnas<FilaNomina>> inscribir({
    required String instanciaId,
    required DatosAlumna datos,
    ResolucionFila? resolucion,
  }) async {
    final fila = FilaNomina(numero: 1, datos: datos.fila, resolucion: resolucion);
    final revisada = _diagnosticar(instanciaId, fila, [fila]);
    if (!revisada.estado.seInscribe) return ResultadoAlumnas.ok(revisada);
    final r = await confirmarImportacion(instanciaId: instanciaId, archivo: '', filas: [fila]);
    return r.ok ? ResultadoAlumnas.ok(r.valor!.revision.filas.first) : ResultadoAlumnas.error(r.error);
  }

  @override
  Future<List<ConflictoImportacion>> conflictosPendientes() async => List.of(pendientes);

  @override
  Future<ResultadoAlumnas<List<FilaNomina>>> revisarConflictos(List<ConflictoImportacion> conflictos) async {
    final filas = [for (final c in conflictos) c.fila];
    return ResultadoAlumnas.ok([
      for (final (i, c) in conflictos.indexed)
        _diagnosticar(c.instanciaId, filas[i], [for (final o in conflictos) if (o.instanciaId == c.instanciaId) o.fila]),
    ]);
  }

  @override
  Future<ResultadoAlumnas<FilaNomina>> resolverConflicto(ConflictoImportacion conflicto, FilaNomina fila) async {
    final enviada = FilaNomina(numero: conflicto.numeroFila, datos: fila.datos, resolucion: fila.resolucion, conflictoId: conflicto.id);
    final r = await confirmarImportacion(instanciaId: conflicto.instanciaId, archivo: conflicto.archivo ?? '', filas: [enviada]);
    return r.ok ? ResultadoAlumnas.ok(r.valor!.revision.filas.first) : ResultadoAlumnas.error(r.error);
  }

  @override
  Future<ResultadoAlumnas<void>> descartarConflicto(String conflictoId) async {
    pendientes.removeWhere((c) => c.id == conflictoId);
    return const ResultadoAlumnas.ok();
  }

  void _reemplazarAutorizaciones(String alumnaId, AutorizacionesFicha a) {
    final f = fichas[alumnaId]!;
    fichas[alumnaId] = FichaAlumna(
      id: f.id,
      rut: f.rut,
      nombres: f.nombres,
      apellidos: f.apellidos,
      fechaNacimiento: f.fechaNacimiento,
      correo: f.correo,
      apoderado: f.apoderado,
      autorizaciones: a,
    );
    _sincronizar(alumnaId);
  }

  @override
  Future<ResultadoAlumnas<void>> registrarAutorizaciones({
    required String alumnaId,
    required ConsentimientoDatos tratamientoDatos,
    required Map<CanalImagen, bool> canales,
    ArchivoAdjunto? respaldo,
    DateTime? fechaFirma,
  }) async {
    if (errorEscritura != null) return ResultadoAlumnas.error(errorEscritura);
    final actual = fichas[alumnaId]!.autorizaciones;
    final documento = respaldo == null ? actual.documento : '$alumnaId/1_${respaldo.nombre}';
    if (respaldo != null) respaldos[documento!] = respaldo.nombre;
    if ((tratamientoDatos == ConsentimientoDatos.otorgado || canales.values.any((v) => v)) && documento == null) {
      return const ResultadoAlumnas.error('Adjunta el documento firmado por el apoderado/a para registrar lo que autorizó.');
    }
    _reemplazarAutorizaciones(
      alumnaId,
      AutorizacionesFicha(
        tratamientoDatos: tratamientoDatos,
        canales: {for (final c in CanalImagen.values) c: canales[c] ?? false},
        revocaciones: {
          for (final e in actual.revocaciones.entries)
            if (!(canales[e.key] ?? false)) e.key: e.value,
        },
        documento: documento,
        fechaFirma: fechaFirma ?? DateTime(2026, 8, 1),
        actualizadoEn: DateTime(2026, 8, 2),
        registradoPor: 'Camila Sepúlveda',
      ),
    );
    return const ResultadoAlumnas.ok();
  }

  @override
  Future<ResultadoAlumnas<void>> revocarImagen({
    required String alumnaId,
    required List<CanalImagen> canales,
    required DateTime fecha,
    required String motivo,
  }) async {
    final a = fichas[alumnaId]!.autorizaciones;
    if (canales.any((c) => !a.autorizado(c))) {
      return const ResultadoAlumnas.error('Solo se revocan canales autorizados.');
    }
    if (motivo.trim().isEmpty) return const ResultadoAlumnas.error('Indica el motivo de la revocación.');
    _reemplazarAutorizaciones(
      alumnaId,
      AutorizacionesFicha(
        tratamientoDatos: a.tratamientoDatos,
        canales: {...a.canales, for (final c in canales) c: false},
        revocaciones: {...a.revocaciones, for (final c in canales) c: RevocacionImagen(fecha: fecha, motivo: motivo.trim())},
        documento: a.documento,
        fechaFirma: a.fechaFirma,
        actualizadoEn: a.actualizadoEn,
        registradoPor: a.registradoPor,
      ),
    );
    return const ResultadoAlumnas.ok();
  }

  @override
  Future<ResultadoAlumnas<void>> retirar({
    required String inscripcionId,
    required DateTime fecha,
    required String motivo,
  }) async {
    final i = inscripciones.indexWhere((x) => x.inscripcionId == inscripcionId);
    final x = inscripciones[i];
    if (!x.vigente) return ResultadoAlumnas.error('La inscripción ya está ${x.estado}.');
    inscripciones[i] = InscripcionNomina(
      inscripcionId: x.inscripcionId,
      alumnaId: x.alumnaId,
      rut: x.rut,
      nombres: x.nombres,
      apellidos: x.apellidos,
      instanciaId: x.instanciaId,
      sedeId: x.sedeId,
      sedeNombre: x.sedeNombre,
      cursoCodigo: x.cursoCodigo,
      cursoNombre: x.cursoNombre,
      estado: 'retirada',
      fechaInscripcion: x.fechaInscripcion,
      fechaRetiro: fecha,
      motivoRetiro: motivo.trim(),
      consentimiento: x.consentimiento,
      autorizaFotos: x.autorizaFotos,
      clasesAsistidas: x.clasesAsistidas,
      clasesComputables: x.clasesComputables,
    );
    return const ResultadoAlumnas.ok();
  }

  @override
  Future<ResultadoAlumnas<String>> urlRespaldo(String documento) async =>
      ResultadoAlumnas.ok('https://almacenamiento.test/$documento?token=firmado');
}
