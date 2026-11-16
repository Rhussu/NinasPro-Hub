import 'package:ninas_pro_hub/repositories/justificativos_repository.dart' show Resultado;
import 'package:ninas_pro_hub/repositories/voluntariado_repository.dart';
import 'package:ninas_pro_hub/utils/rut.dart';

/// Fichas de ejemplo: una tutora apta con cuenta, una sin adhesión, una autorizada
/// sin cuenta y una retirada
List<FichaVoluntaria> fichasDemo() => [
  FichaVoluntaria(
    id: 'vol-daniela',
    perfilId: 'perfil-daniela',
    rut: '19.876.543-0',
    nombres: 'Daniela',
    apellidos: 'Valenzuela Castro',
    correo: 'daniela.valenzuela@ninaspro.cl',
    institucion: 'Licenciatura en Ciencias de la Computación, U. de Chile',
    sedeId: 'sede-beauchef',
    sedeNombre: 'Sede Beauchef',
    fechaIngreso: DateTime(2023, 3, 3),
    adhesionFirmada: true,
    fechaFirmaAdhesion: DateTime(2026, 3, 14),
    cuenta: CuentaVoluntaria.activa,
    cursos: const [
      CursoTrayectoria(
        instanciaId: 'inst-pcb',
        cursoCodigo: 'PCB',
        cursoNombre: 'Programación Competitiva Básica',
        sedeId: 'sede-beauchef',
        sedeNombre: 'Sede Beauchef',
        periodo: '2026-2',
      ),
    ],
    sedeIds: const {'sede-beauchef'},
  ),
  FichaVoluntaria(
    id: 'vol-francisca',
    perfilId: 'perfil-francisca',
    rut: '16.543.210-K',
    nombres: 'Francisca',
    apellidos: 'Herrera Rojas',
    correo: 'francisca.herrera@ninaspro.cl',
    sedeId: 'sede-beauchef',
    sedeNombre: 'Sede Beauchef',
    fechaIngreso: DateTime(2025, 3, 4),
    cuenta: CuentaVoluntaria.activa,
    sedeIds: const {'sede-beauchef'},
  ),
  FichaVoluntaria(
    id: 'vol-sofia',
    rut: '20.123.456-5',
    nombres: 'Sofía',
    apellidos: 'Araya Medina',
    correo: 'sofia.araya@ninaspro.cl',
    rol: RolVoluntaria.equipoGestion,
    sedeId: 'sede-valpo',
    sedeNombre: 'Sede Valparaíso',
    fechaIngreso: DateTime(2026, 11, 1),
    adhesionFirmada: true,
    fechaFirmaAdhesion: DateTime(2026, 11, 1),
    cuenta: CuentaVoluntaria.autorizada,
    autorizacionExpiraEn: DateTime(2026, 12, 1),
    sedeIds: const {'sede-valpo'},
  ),
  FichaVoluntaria(
    id: 'vol-ignacia',
    rut: '18.987.654-8',
    nombres: 'Ignacia',
    apellidos: 'Morales Fuentes',
    correo: 'ignacia.morales@ninaspro.cl',
    sedeId: 'sede-beauchef',
    sedeNombre: 'Sede Beauchef',
    fechaIngreso: DateTime(2023, 3, 4),
    fechaSalida: DateTime(2025, 12, 15),
    adhesionFirmada: true,
    cuenta: CuentaVoluntaria.sinAutorizacion,
    sedeIds: const {'sede-beauchef'},
  ),
];

/// [VoluntariadoRepository] en memoria con las reglas de la migración 19.
class FakeVoluntariadoRepository implements VoluntariadoRepository {
  final List<FichaVoluntaria> lista;

  /// Nombre de cada curso asignable (instancia -> (código, sede))
  final Map<String, (String, String, String)> cursos;

  /// Cada operación que llegó a la "base"
  final llamadas = <String>[];

  /// Si no es null, la base rechaza las escrituras con este mensaje
  String? rechazo;

  var _secuencia = 0;

  FakeVoluntariadoRepository({List<FichaVoluntaria>? fichas, Map<String, (String, String, String)>? cursos})
    : lista = fichas ?? fichasDemo(),
      cursos =
          cursos ??
          const {
            'inst-pcb': ('PCB', 'sede-beauchef', 'Sede Beauchef'),
            'inst-web': ('WEB', 'sede-valpo', 'Sede Valparaíso'),
          };

  FichaVoluntaria porId(String id) => lista.firstWhere((f) => f.id == id);

  void _reemplazar(FichaVoluntaria f) => lista[lista.indexWhere((x) => x.id == f.id)] = f;

  FichaVoluntaria _copia(
    FichaVoluntaria f, {
    RolVoluntaria? rol,
    bool? adhesionFirmada,
    DateTime? fechaFirmaAdhesion,
    bool limpiarFirma = false,
    DateTime? fechaSalida,
    bool limpiarSalida = false,
    CuentaVoluntaria? cuenta,
    DateTime? autorizacionExpiraEn,
    List<CursoTrayectoria>? cursos,
  }) => FichaVoluntaria(
    id: f.id,
    perfilId: f.perfilId,
    rut: f.rut,
    nombres: f.nombres,
    apellidos: f.apellidos,
    correo: f.correo,
    telefono: f.telefono,
    institucion: f.institucion,
    rol: rol ?? f.rol,
    sedeId: f.sedeId,
    sedeNombre: f.sedeNombre,
    fechaIngreso: f.fechaIngreso,
    fechaSalida: limpiarSalida ? null : fechaSalida ?? f.fechaSalida,
    adhesionFirmada: adhesionFirmada ?? f.adhesionFirmada,
    fechaFirmaAdhesion: limpiarFirma ? null : fechaFirmaAdhesion ?? f.fechaFirmaAdhesion,
    cuenta: cuenta ?? f.cuenta,
    autorizacionExpiraEn: autorizacionExpiraEn ?? f.autorizacionExpiraEn,
    cursos: cursos ?? f.cursos,
    sedeIds: {...f.sedeIds, for (final c in cursos ?? f.cursos) c.sedeId},
  );

  @override
  Future<List<FichaVoluntaria>> fichas() async => List.of(lista);

  @override
  Future<FichaVoluntaria?> miFicha(String perfilId) async => lista.where((f) => f.perfilId == perfilId).firstOrNull;

  RevisionVoluntariado _revisar(String sedeId, List<Map<String, Object?>> filas, {required bool guardar}) {
    final revisadas = <FilaVoluntariado>[];
    final ruts = [for (final f in filas) normalizarRut('${f['rut']}')];
    var creadas = 0, actualizadas = 0, rechazadas = 0;
    for (final f in filas) {
      final rut = '${f['rut'] ?? ''}'.trim();
      final correo = '${f['correo'] ?? ''}'.trim().toLowerCase();
      final nombre = '${f['nombres'] ?? ''} ${f['apellidos'] ?? ''}'.trim();
      final existente = lista.where((x) => normalizarRut(x.rut) == normalizarRut(rut)).firstOrNull;
      final String? motivo = !validarRut(rut)
          ? 'RUT inválido (dígito verificador)'
          : ruts.where((r) => r == normalizarRut(rut)).length > 1
          ? 'RUT repetido en la planilla'
          : !correo.endsWith('@ninaspro.cl')
          ? 'El voluntariado usa su correo institucional @ninaspro.cl'
          : null;
      final estado = motivo != null ? 'invalida' : (existente != null ? 'existente' : 'nueva');
      String? fichaId = existente?.id;
      if (estado == 'invalida') {
        rechazadas++;
      } else if (estado == 'existente') {
        actualizadas++;
      } else {
        creadas++;
        if (guardar) {
          fichaId = 'vol-nueva-${++_secuencia}';
          lista.add(
            FichaVoluntaria(
              id: fichaId,
              rut: formatearRut(rut),
              nombres: '${f['nombres']}',
              apellidos: '${f['apellidos']}',
              correo: correo,
              rol: f['rol'] == 'equipo_gestion' ? RolVoluntaria.equipoGestion : RolVoluntaria.tutora,
              sedeId: sedeId,
              sedeNombre: sedeId,
              fechaIngreso: DateTime.now(),
              cuenta: CuentaVoluntaria.autorizada,
              autorizacionExpiraEn: DateTime.now().add(const Duration(days: 30)),
              sedeIds: {sedeId},
            ),
          );
        }
      }
      revisadas.add(
        FilaVoluntariado(
          fila: (f['fila'] as int?) ?? 0,
          rut: rut,
          nombre: nombre,
          correo: correo,
          estado: estado,
          motivo: motivo,
          fichaId: guardar && estado != 'invalida' ? fichaId : null,
        ),
      );
    }
    return RevisionVoluntariado(filas: revisadas, creadas: creadas, actualizadas: actualizadas, rechazadas: rechazadas);
  }

  @override
  Future<Resultado<RevisionVoluntariado>> revisarImportacion({
    required String sedeId,
    required List<Map<String, Object?>> filas,
  }) async {
    llamadas.add('revisar:$sedeId');
    if (rechazo != null) return Resultado.error(rechazo);
    return Resultado.ok(_revisar(sedeId, filas, guardar: false));
  }

  @override
  Future<Resultado<RevisionVoluntariado>> confirmarImportacion({
    required String sedeId,
    required List<Map<String, Object?>> filas,
  }) async {
    llamadas.add('importar:$sedeId');
    if (rechazo != null) return Resultado.error(rechazo);
    return Resultado.ok(_revisar(sedeId, filas, guardar: true));
  }

  @override
  Future<Resultado<FilaVoluntariado>> alta({required String sedeId, required DatosVoluntaria datos}) async {
    llamadas.add('alta:$sedeId');
    if (rechazo != null) return Resultado.error(rechazo);
    final fila = _revisar(sedeId, [MapeoVoluntariado.filaAlta(datos)], guardar: true).filas.single;
    return fila.invalida ? Resultado.error(fila.motivo) : Resultado.ok(fila);
  }

  @override
  Future<Resultado<void>> registrarAdhesion(String id, {required bool firmada, DateTime? fecha}) async {
    llamadas.add('adhesion:$id:$firmada');
    if (rechazo != null) return Resultado.error(rechazo);
    if (firmada && fecha == null) return const Resultado.error('Indica la fecha en que firmó la declaración.');
    _reemplazar(_copia(porId(id), adhesionFirmada: firmada, fechaFirmaAdhesion: fecha, limpiarFirma: !firmada));
    return const Resultado.ok();
  }

  @override
  Future<Resultado<void>> cambiarRol(String id, RolVoluntaria rol) async {
    llamadas.add('rol:$id:${rol.db}');
    if (rechazo != null) return Resultado.error(rechazo);
    _reemplazar(_copia(porId(id), rol: rol));
    return const Resultado.ok();
  }

  @override
  Future<Resultado<void>> registrarSalida(String id, DateTime fecha) async {
    llamadas.add('salida:$id');
    if (rechazo != null) return Resultado.error(rechazo);
    final f = porId(id);
    if (fecha.isBefore(f.fechaIngreso)) {
      return const Resultado.error('La fecha de salida no puede ser anterior al ingreso.');
    }
    _reemplazar(
      _copia(
        f,
        fechaSalida: fecha,
        cuenta: f.perfilId == null ? CuentaVoluntaria.sinAutorizacion : CuentaVoluntaria.inactiva,
      ),
    );
    return const Resultado.ok();
  }

  @override
  Future<Resultado<void>> reincorporar(String id) async {
    llamadas.add('reincorporar:$id');
    if (rechazo != null) return Resultado.error(rechazo);
    final f = porId(id);
    _reemplazar(
      _copia(
        f,
        limpiarSalida: true,
        cuenta: f.perfilId == null ? CuentaVoluntaria.autorizada : CuentaVoluntaria.activa,
      ),
    );
    return const Resultado.ok();
  }

  @override
  Future<Resultado<DateTime>> renovarAutorizacion(String id) async {
    llamadas.add('renovar:$id');
    if (rechazo != null) return Resultado.error(rechazo);
    final expira = DateTime.now().add(const Duration(days: 30));
    _reemplazar(_copia(porId(id), cuenta: CuentaVoluntaria.autorizada, autorizacionExpiraEn: expira));
    return Resultado.ok(expira);
  }

  @override
  Future<Resultado<void>> asignarCurso(String id, String instanciaId) async {
    llamadas.add('asignar:$id:$instanciaId');
    if (rechazo != null) return Resultado.error(rechazo);
    final f = porId(id);
    if (!f.adhesionFirmada) {
      return const Resultado.error(
        'Para asignarla a un curso, la voluntaria debe tener firmada la declaración de adhesión.',
      );
    }
    final (codigo, sedeId, sede) = cursos[instanciaId]!;
    _reemplazar(
      _copia(
        f,
        cursos: [
          ...f.cursos,
          CursoTrayectoria(
            instanciaId: instanciaId,
            cursoCodigo: codigo,
            cursoNombre: codigo,
            sedeId: sedeId,
            sedeNombre: sede,
            periodo: '2026-2',
          ),
        ],
      ),
    );
    return const Resultado.ok();
  }

  @override
  Future<Resultado<void>> quitarCurso(String id, String instanciaId) async {
    llamadas.add('quitar:$id:$instanciaId');
    if (rechazo != null) return Resultado.error(rechazo);
    final f = porId(id);
    _reemplazar(_copia(f, cursos: f.cursos.where((c) => c.instanciaId != instanciaId).toList()));
    return const Resultado.ok();
  }
}
