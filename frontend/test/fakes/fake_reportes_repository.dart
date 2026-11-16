import 'package:ninas_pro_hub/repositories/justificativos_repository.dart' show Resultado;
import 'package:ninas_pro_hub/repositories/reportes_repository.dart';

/// [ReportesRepository] en memoria: tres sedes con su asistencia, un reporte
/// con dos alumnas y la bitácora. Cada exportación queda en [exportaciones] y
/// en la auditoría, como en `exportar_reporte`.
class FakeReportesRepository implements ReportesRepository {
  final List<ResumenSedeReporte> resumen;
  final List<SerieAsistencia> series;
  final List<EventoAuditoria> eventos;

  /// Exportaciones registradas (la vista previa no cuenta)
  final exportaciones = <(FiltroReporte, FormatoExportacion)>[];

  /// Filtros de cada vista previa pedida
  final vistasPrevias = <FiltroReporte>[];

  /// Si no es null, la base rechaza los reportes con este mensaje
  String? rechazo;

  /// Si es true, falla la conexión al leer
  bool sinConexion = false;

  /// Si es true, los reportes no tienen filas
  bool vacio = false;

  FakeReportesRepository({
    List<ResumenSedeReporte>? resumen,
    List<SerieAsistencia>? series,
    List<EventoAuditoria>? eventos,
  }) : resumen = resumen ?? _resumenDemo,
       series = series ?? seriesDemo(),
       eventos = eventos ?? eventosDemo();

  static const _resumenDemo = [
    ResumenSedeReporte(
      sedeId: 'sede-beauchef',
      nombre: 'Sede Beauchef',
      institucion: 'Universidad de Chile (FCFM)',
      cursos: 1,
      alumnasActivas: 8,
      asistenciaPromedio: 78.6,
      voluntariasActivas: 9,
    ),
    ResumenSedeReporte(
      sedeId: 'sede-sj',
      nombre: 'Sede San Joaquín',
      institucion: 'Pontificia Universidad Católica de Chile',
      cursos: 1,
      alumnasActivas: 3,
      asistenciaPromedio: 85.0,
      voluntariasActivas: 3,
    ),
    ResumenSedeReporte(
      sedeId: 'sede-valpo',
      nombre: 'Sede Valparaíso',
      activa: false,
      cursos: 0,
      alumnasActivas: 0,
      voluntariasActivas: 0,
    ),
  ];

  static List<SerieAsistencia> seriesDemo() => [
    SerieAsistencia(
      sedeId: 'sede-beauchef',
      sedeNombre: 'Sede Beauchef',
      puntos: [
        for (var i = 0; i < 4; i++)
          PuntoAsistencia(fecha: DateTime(2026, 10, 3 + 7 * i), presentes: 6 + i % 2, total: 8),
      ],
    ),
    SerieAsistencia(
      sedeId: 'sede-sj',
      sedeNombre: 'Sede San Joaquín',
      puntos: [
        for (var i = 0; i < 4; i++)
          PuntoAsistencia(fecha: DateTime(2026, 10, 3 + 7 * i), presentes: 2 + i % 2, total: 3),
      ],
    ),
  ];

  static List<EventoAuditoria> eventosDemo() => [
    EventoAuditoria(
      id: 'ev-1',
      fecha: DateTime(2026, 11, 14, 12, 30),
      tipo: TipoEventoAuditoria.modificacion,
      usuariaNombre: 'Daniela Valenzuela Castro',
      usuariaCorreo: 'daniela.valenzuela@ninaspro.cl',
      sedeNombre: 'Sede Beauchef',
      descripcion: 'Asistencia de alumna: estado: ausente → presente',
      alumnaRut: '22.341.890-2',
      alumnaNombre: 'Valentina Soto Morales',
      detalle: const {
        'tabla': 'asistencia_alumnas',
        'anterior': {'estado': 'ausente'},
        'nuevo': {'estado': 'presente'},
      },
    ),
    EventoAuditoria(
      id: 'ev-2',
      fecha: DateTime(2026, 11, 13, 9),
      tipo: TipoEventoAuditoria.accesoDenegado,
      usuariaNombre: 'Fernanda Pizarro León',
      usuariaCorreo: 'fernanda.pizarro@ninaspro.cl',
      descripcion: 'Acceso denegado: pase de lista de otra sede',
      detalle: const {'recurso': 'lista_asistencia_clase'},
    ),
    EventoAuditoria(
      id: 'ev-3',
      fecha: DateTime(2026, 11, 12, 18),
      tipo: TipoEventoAuditoria.seguridad,
      usuariaNombre: 'intruso@correo.cl',
      descripcion: 'Registro rechazado: el correo no estaba autorizado',
    ),
  ];

  Reporte _reporte(FiltroReporte f, {required bool completo}) {
    const identificables = ['RUT', 'Nombres', 'Apellidos'];
    final encabezados = [
      'Sede',
      'Curso',
      if (f.disociado) 'Alumna' else ...identificables,
      f.tipo == TipoReporte.participacion ? 'Ejercicios' : 'Estado',
    ];
    final alumnas = [('22.341.890-2', 'Valentina', 'Soto Morales'), ('21.904.331-7', 'Florencia', 'Muñoz Tapia')];
    final sinFilas = vacio;
    final filas = sinFilas
        ? <List<String>>[]
        : [
            for (var i = 0; i < 12; i++)
              [
                'Sede Beauchef',
                'PCB',
                if (f.disociado)
                  'ALUMNA-00${i % 2 + 1}'
                else ...[
                  alumnas[i % 2].$1,
                  alumnas[i % 2].$2,
                  alumnas[i % 2].$3,
                ],
                f.tipo == TipoReporte.participacion ? '${i + 1}' : (i % 3 == 0 ? 'Ausente' : 'Presente'),
              ],
          ];
    return Reporte(encabezados: encabezados, filas: completo ? filas : filas.take(10).toList(), total: filas.length);
  }

  @override
  Future<List<ResumenSedeReporte>> resumenSedes() async {
    if (sinConexion) throw Exception('sin conexión');
    return List.of(resumen);
  }

  @override
  Future<List<SerieAsistencia>> asistenciaPorClase() async => List.of(series);

  @override
  Future<Resultado<Reporte>> vistaPrevia(FiltroReporte filtro) async {
    vistasPrevias.add(filtro);
    if (rechazo != null) return Resultado.error(rechazo);
    return Resultado.ok(_reporte(filtro, completo: false));
  }

  @override
  Future<Resultado<Reporte>> exportar(FiltroReporte filtro, FormatoExportacion formato) async {
    if (rechazo != null) return Resultado.error(rechazo);
    final reporte = _reporte(filtro, completo: true);
    exportaciones.add((filtro, formato));
    eventos.insert(
      0,
      EventoAuditoria(
        id: 'ev-exp-${exportaciones.length}',
        fecha: DateTime.now(),
        tipo: TipoEventoAuditoria.exportacion,
        usuariaNombre: 'Directiva Nacional',
        usuariaCorreo: 'directiva@ninaspro.cl',
        descripcion:
            'Exportó ${filtro.tipo.name} en ${formato.extension.toUpperCase()}: ${reporte.total} filas'
            '${filtro.disociado ? ', disociado' : ''}',
      ),
    );
    return Resultado.ok(reporte);
  }

  @override
  Future<List<EventoAuditoria>> auditoria({
    DateTime? desde,
    DateTime? hasta,
    String? usuaria,
    TipoEventoAuditoria? tipo,
    String? rutAlumna,
  }) async {
    if (sinConexion) throw Exception('sin conexión');
    String limpio(String s) => s.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    final u = usuaria?.trim().toLowerCase() ?? '';
    final rut = limpio(rutAlumna ?? '');
    return [
      for (final e in eventos)
        if ((tipo == null || e.tipo == tipo) &&
            (u.isEmpty ||
                e.usuariaNombre.toLowerCase().contains(u) ||
                (e.usuariaCorreo ?? '').toLowerCase().contains(u)) &&
            (rut.isEmpty || limpio(e.alumnaRut ?? '') == rut) &&
            (desde == null || !e.fecha.isBefore(desde)) &&
            (hasta == null || e.fecha.isBefore(hasta.add(const Duration(days: 1)))))
          e,
    ];
  }
}
