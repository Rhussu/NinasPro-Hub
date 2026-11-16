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

  /// Filas recibidas por la última confirmación (para revisar lo que envió la app)
  List<Map<String, Object?>>? ultimasFilas;

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

  ResultadoImportacion _clasificar(String instanciaId, String nombreArchivo, List<Map<String, Object?>> filas) {
    String texto(Map<String, Object?> f, String clave) => (f[clave] as String? ?? '').trim();
    final ruts = [for (final f in filas) normalizarRut(texto(f, 'rut'))];
    return ResultadoImportacion(
      nombreArchivo: nombreArchivo,
      filas: [
        for (final f in filas)
          () {
            final rut = texto(f, 'rut');
            final existente = _porRut(rut);
            final motivos = [
              if (rut.isEmpty) 'Falta el RUT de la alumna' else if (!validarRut(rut)) 'RUT de la alumna inválido (dígito verificador)',
              if (rut.isNotEmpty && ruts.where((r) => r == normalizarRut(rut)).length > 1) 'RUT repetido en la planilla',
              if (existente != null &&
                  inscripciones.any((i) => i.alumnaId == existente.id && i.instanciaId == instanciaId))
                'Ya está inscrita en este curso',
              if (texto(f, 'telefono_apoderado').isEmpty || texto(f, 'correo_apoderado').isEmpty)
                'El correo y el teléfono del apoderado/a son obligatorios por protocolo institucional',
            ];
            return FilaImportacion(
              numeroFila: (f['fila'] as num).toInt(),
              nombre: '${texto(f, 'nombres')} ${texto(f, 'apellidos')}'.trim(),
              rut: validarRut(rut) ? formatearRut(rut) : rut,
              detalle: '${texto(f, 'nombres_apoderado')} ${texto(f, 'apellidos_apoderado')}'.trim(),
              estado: motivos.isNotEmpty
                  ? EstadoFilaImportacion.invalida
                  : (existente != null ? EstadoFilaImportacion.existente : EstadoFilaImportacion.nueva),
              motivo: motivos.isEmpty ? null : motivos.join('. '),
            );
          }(),
      ],
    );
  }

  @override
  Future<ResultadoAlumnas<ResultadoImportacion>> previsualizarImportacion({
    required String instanciaId,
    required String nombreArchivo,
    required List<Map<String, Object?>> filas,
  }) async {
    if (errorEscritura != null) return ResultadoAlumnas.error(errorEscritura);
    return ResultadoAlumnas.ok(_clasificar(instanciaId, nombreArchivo, filas));
  }

  @override
  Future<ResultadoAlumnas<({int inscritas, ResultadoImportacion detalle})>> confirmarImportacion({
    required String instanciaId,
    required String nombreArchivo,
    required List<Map<String, Object?>> filas,
  }) async {
    if (errorEscritura != null) return ResultadoAlumnas.error(errorEscritura);
    ultimasFilas = filas;
    final detalle = _clasificar(instanciaId, nombreArchivo, filas);
    var inscritas = 0;
    for (var i = 0; i < filas.length; i++) {
      final fila = detalle.filas[i];
      if (fila.estado == EstadoFilaImportacion.invalida) continue;
      final f = filas[i];
      final ficha =
          _porRut(fila.rut) ??
          agregarFicha(rut: fila.rut, nombres: f['nombres'] as String, apellidos: f['apellidos'] as String);
      _inscribir(ficha, instanciaId);
      inscritas++;
    }
    return ResultadoAlumnas.ok((inscritas: inscritas, detalle: detalle));
  }

  FichaAlumna agregarFicha({required String rut, required String nombres, required String apellidos}) {
    final ficha = FichaAlumna(id: 'alumna-${_id++}', rut: formatearRut(rut), nombres: nombres, apellidos: apellidos);
    fichas[ficha.id] = ficha;
    return ficha;
  }

  @override
  Future<ResultadoAlumnas<void>> inscribir({required String instanciaId, required DatosAlumna datos}) async {
    final r = await confirmarImportacion(instanciaId: instanciaId, nombreArchivo: '', filas: [datos.fila]);
    final fila = r.valor?.detalle.filas.first;
    if (r.error != null) return ResultadoAlumnas.error(r.error);
    return fila!.estado == EstadoFilaImportacion.invalida ? ResultadoAlumnas.error(fila.motivo) : const ResultadoAlumnas.ok();
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
