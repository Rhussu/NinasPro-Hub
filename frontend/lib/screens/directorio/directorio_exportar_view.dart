import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import 'directorio_widgets.dart';

/// Exportación filtrada de reportes en CSV/XLSX con modo disociado (US-21, US-22).
///
/// Mockup: muestra una vista previa y un aviso; no descarga un archivo real.
/// Cada exportación queda registrada en la auditoría.
class DirectorioExportarView extends StatefulWidget {
  final HubRepository repository;

  const DirectorioExportarView({super.key, required this.repository});

  @override
  State<DirectorioExportarView> createState() => _DirectorioExportarViewState();
}

class _DirectorioExportarViewState extends State<DirectorioExportarView> {
  static const _filasVistaPrevia = 10;

  List<Sede> _sedes = [];
  List<Curso> _cursos = [];
  ResultadoExportacion? _vistaPrevia;

  TipoExportacion _tipo = TipoExportacion.asistencia;
  String? _sedeId;
  String? _cursoId;
  DateTime? _desde;
  DateTime? _hasta;
  String _formato = 'XLSX';
  bool _disociado = false;

  FiltroExportacion get _filtro => FiltroExportacion(
        tipo: _tipo,
        sedeId: _sedeId,
        cursoId: _cursoId,
        desde: _desde,
        hasta: _hasta,
        formato: _formato,
        disociado: _disociado,
      );

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final sedes = await widget.repository.getSedes();
    final cursos = await widget.repository.getCursos();
    if (!mounted) return;
    setState(() {
      _sedes = sedes;
      _cursos = cursos;
    });
    _actualizarVistaPrevia();
  }

  Future<void> _actualizarVistaPrevia() async {
    final vista = await widget.repository.previsualizarExportacion(_filtro);
    if (mounted) setState(() => _vistaPrevia = vista);
  }

  void _cambiar(VoidCallback cambio) {
    setState(cambio);
    _actualizarVistaPrevia();
  }

  Future<void> _exportar() async {
    final resultado = await widget.repository.exportarDatos(_filtro);
    if (!mounted) return;
    mostrarAviso(
      context,
      resultado.filas.isEmpty
          ? '📄 ${resultado.nombreArchivo} generado solo con encabezados: no hay registros para estos filtros.'
          : '📄 ${resultado.nombreArchivo} generado con ${resultado.filas.length} filas. '
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
              SegmentedButton<TipoExportacion>(
                showSelectedIcon: false,
                segments: [
                  for (final t in TipoExportacion.values) ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => _cambiar(() => _tipo = s.first),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FiltroDesplegable<String>(
                    etiqueta: 'Sede',
                    valor: _sedeId,
                    opciones: {for (final s in _sedes) s.id: s.nombre},
                    onChanged: (v) => _cambiar(() {
                      _sedeId = v;
                      _cursoId = null;
                    }),
                  ),
                  FiltroDesplegable<String>(
                    etiqueta: 'Curso',
                    valor: _cursoId,
                    ancho: 240,
                    opciones: {
                      for (final c in _cursos.where((c) => _sedeId == null || c.sedeId == _sedeId)) c.id: c.codigo,
                    },
                    onChanged: (v) => _cambiar(() => _cursoId = v),
                  ),
                  _BotonFecha(
                    etiqueta: 'Desde',
                    fecha: _desde,
                    onChanged: (f) => _cambiar(() => _desde = f),
                  ),
                  _BotonFecha(
                    etiqueta: 'Hasta',
                    fecha: _hasta,
                    onChanged: (f) => _cambiar(() => _hasta = f),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'CSV', label: Text('CSV')),
                      ButtonSegment(value: 'XLSX', label: Text('XLSX')),
                    ],
                    selected: {_formato},
                    onSelectionChanged: (s) => _cambiar(() => _formato = s.first),
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
          titulo: vista == null ? 'Vista previa' : 'Vista previa · ${vista.nombreArchivo}',
          accion: FilledButton.icon(
            onPressed: vista == null ? null : _exportar,
            icon: const Icon(Icons.file_download_rounded, size: 18),
            label: Text('Exportar $_formato'),
          ),
          child: vista == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vista.filas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'ℹ️ No hay registros con estos filtros. El archivo saldrá solo con los encabezados.',
                          style: TextStyle(color: NinasProColors.info700),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Mostrando ${vista.filas.length < _filasVistaPrevia ? vista.filas.length : _filasVistaPrevia} '
                          'de ${vista.filas.length} filas',
                          style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500),
                        ),
                      ),
                    DirectorioTabla(
                      columnas: vista.encabezados,
                      mensajeVacio: 'Sin filas',
                      filas: [
                        for (final fila in vista.filas.take(_filasVistaPrevia))
                          DataRow(cells: [for (final celda in fila) DataCell(Text(celda))]),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
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
