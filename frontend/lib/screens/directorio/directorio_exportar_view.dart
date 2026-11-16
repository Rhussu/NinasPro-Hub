import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart' show Curso, Sede;
import '../../repositories/catalogo_repository.dart';
import '../../repositories/reportes_repository.dart';
import '../../utils/exportacion.dart';
import 'directorio_widgets.dart';

/// Exportación filtrada de reportes en CSV o XLSX con modo disociado (US-21, US-22).
///
/// La base arma el reporte con el alcance de quien exporta y registra cada
/// descarga en la auditoría. Con [sedeFijaId] (Gestión de una sede) el selector
/// de sede queda fijo (US-21 E3); la nómina la exporta solo la Directiva.
class DirectorioExportarView extends StatefulWidget {
  final ReportesRepository repository;
  final CatalogoRepository catalogo;

  /// Sede de Gestión: no se puede cambiar
  final String? sedeFijaId;

  /// La nómina (con consentimientos) es de la Directiva
  final bool permiteNomina;

  const DirectorioExportarView({
    super.key,
    required this.repository,
    required this.catalogo,
    this.sedeFijaId,
    this.permiteNomina = true,
  });

  @override
  State<DirectorioExportarView> createState() => _DirectorioExportarViewState();
}

class _DirectorioExportarViewState extends State<DirectorioExportarView> {
  List<Sede> _sedes = [];
  List<Curso> _cursos = [];
  Reporte? _vistaPrevia;
  String? _error;
  bool _exportando = false;

  // Evita que una vista previa vieja reemplace a la del último filtro
  int _consulta = 0;

  TipoReporte _tipo = TipoReporte.asistencia;
  String? _sedeId;
  String? _cursoId;
  DateTime? _desde;
  DateTime? _hasta;
  FormatoExportacion _formato = FormatoExportacion.xlsx;
  bool _disociado = false;

  List<TipoReporte> get _tipos => [
    for (final t in TipoReporte.values)
      if (t != TipoReporte.nomina || widget.permiteNomina) t,
  ];

  FiltroReporte get _filtro => FiltroReporte(
    tipo: _tipo,
    sedeId: _sedeId,
    instanciaId: _cursoId,
    desde: _desde,
    hasta: _hasta,
    disociado: _disociado,
  );

  @override
  void initState() {
    super.initState();
    _sedeId = widget.sedeFijaId;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final sedes = await widget.catalogo.sedes();
      final cursos = await widget.catalogo.instancias(sedeId: widget.sedeFijaId);
      if (!mounted) return;
      setState(() {
        _sedes = sedes;
        _cursos = cursos;
      });
    } catch (_) {
      // Sin catálogo se puede exportar igual, sin filtrar por sede ni curso
    }
    await _actualizarVistaPrevia();
  }

  Future<void> _actualizarVistaPrevia() async {
    final consulta = ++_consulta;
    setState(() => _vistaPrevia = null);
    final resultado = await widget.repository.vistaPrevia(_filtro);
    if (!mounted || consulta != _consulta) return;
    setState(() {
      _vistaPrevia = resultado.valor;
      _error = resultado.error;
    });
  }

  void _cambiar(VoidCallback cambio) {
    setState(cambio);
    _actualizarVistaPrevia();
  }

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    final filtro = _filtro;
    final resultado = await widget.repository.exportar(filtro, _formato);
    if (!mounted) return;
    setState(() => _exportando = false);
    final reporte = resultado.valor;
    if (reporte == null) {
      mostrarAviso(context, resultado.error ?? 'No pudimos exportar el reporte.');
      return;
    }
    final nombre = filtro.nombreArchivo(DateTime.now());
    exportarTabla(
      nombreBase: nombre,
      hoja: filtro.tipo.etiqueta,
      encabezados: reporte.encabezados,
      filas: reporte.filas,
      formato: _formato,
    );
    mostrarAviso(
      context,
      reporte.filas.isEmpty
          ? '📄 $nombre.${_formato.extension} se descargó solo con los encabezados: no hay registros con estos filtros.'
          : '📄 $nombre.${_formato.extension} se descargó con ${reporte.filas.length} filas. '
                'La descarga quedó registrada en la auditoría.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vista = _vistaPrevia;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const DirectorioEncabezado(
          titulo: 'Exportar reportes',
          subtitulo: 'Asistencia, nómina o participación en CSV o XLSX. Toda descarga queda en la auditoría.',
        ),
        DirectorioPanel(
          titulo: 'Filtros',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<TipoReporte>(
                showSelectedIcon: false,
                segments: [for (final t in _tipos) ButtonSegment(value: t, label: Text(t.etiqueta))],
                selected: {_tipo},
                onSelectionChanged: (s) => _cambiar(() => _tipo = s.first),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.sedeFijaId == null)
                    FiltroDesplegable<String>(
                      etiqueta: 'Sede',
                      valor: _sedeId,
                      opciones: {for (final s in _sedes) s.id: s.nombre},
                      onChanged: (v) => _cambiar(() {
                        _sedeId = v;
                        _cursoId = null;
                      }),
                    )
                  else
                    Chip(
                      avatar: const Icon(Icons.location_on_rounded, size: 16),
                      label: Text(
                        _sedes.where((s) => s.id == widget.sedeFijaId).firstOrNull?.nombre ?? 'Tu sede',
                      ),
                    ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Curso',
                    valor: _cursoId,
                    ancho: 260,
                    opciones: {
                      for (final c in _cursos.where((c) => _sedeId == null || c.sedeId == _sedeId))
                        c.id: _etiquetaCurso(c),
                    },
                    onChanged: (v) => _cambiar(() => _cursoId = v),
                  ),
                  _BotonFecha(etiqueta: 'Desde', fecha: _desde, onChanged: (f) => _cambiar(() => _desde = f)),
                  _BotonFecha(etiqueta: 'Hasta', fecha: _hasta, onChanged: (f) => _cambiar(() => _hasta = f)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<FormatoExportacion>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: FormatoExportacion.csv, label: Text('CSV')),
                      ButtonSegment(value: FormatoExportacion.xlsx, label: Text('XLSX')),
                    ],
                    selected: {_formato},
                    onSelectionChanged: (s) => setState(() => _formato = s.first),
                  ),
                  SizedBox(
                    width: 420,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Exportar con datos disociados (anonimizado)'),
                      subtitle: const Text('Reemplaza nombres y RUT por ALUMNA-001, ALUMNA-002…'),
                      value: _disociado,
                      onChanged: (v) => _cambiar(() => _disociado = v ?? false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        DirectorioPanel(
          titulo: 'Vista previa',
          accion: FilledButton.icon(
            onPressed: vista == null || _exportando ? null : _exportar,
            icon: _exportando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_rounded, size: 18),
            label: Text('Exportar ${_formato.extension.toUpperCase()}'),
          ),
          child: _buildVistaPrevia(vista),
        ),
      ],
    );
  }

  Widget _buildVistaPrevia(Reporte? vista) {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: NinasProColors.error700));
    }
    if (vista == null) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            vista.total == 0
                ? 'ℹ️ No hay registros con estos filtros. El archivo saldrá solo con los encabezados.'
                : 'Mostrando ${vista.filas.length} de ${vista.total} filas',
            style: TextStyle(
              fontSize: 12,
              color: vista.total == 0 ? NinasProColors.info700 : NinasProColors.neutral500,
            ),
          ),
        ),
        DirectorioTabla(
          columnas: vista.encabezados,
          mensajeVacio: 'Sin filas',
          filas: [
            for (final fila in vista.filas) DataRow(cells: [for (final celda in fila) DataCell(Text(celda))]),
          ],
        ),
      ],
    );
  }

  static String _etiquetaCurso(Curso c) {
    final periodo = '${c.anio}-${c.semestre}';
    final seccion = c.seccion > 1 ? ' ${c.seccionLetra}' : '';
    return '${c.codigo}$seccion · $periodo · ${c.sedeNombre}';
  }
}

class _BotonFecha extends StatelessWidget {
  final String etiqueta;
  final DateTime? fecha;
  final ValueChanged<DateTime?> onChanged;

  const _BotonFecha({required this.etiqueta, required this.fecha, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final elegida = await elegirFecha(context, inicial: fecha);
            if (elegida != null) onChanged(elegida);
          },
          icon: const Icon(Icons.event_rounded, size: 18),
          label: Text(fecha == null ? etiqueta : '$etiqueta: ${formatearFecha(fecha)}'),
        ),
        if (fecha != null)
          IconButton(
            tooltip: 'Quitar fecha',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
      ],
    );
  }
}
