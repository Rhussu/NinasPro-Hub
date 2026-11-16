import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../repositories/reportes_repository.dart';
import '../../widgets/ninaspro_planificacion_hoy.dart' show formatearFechaClase;
import '../../widgets/ninaspro_stat_card.dart';
import 'directorio_desktop_screen.dart';
import 'directorio_grafico_asistencia.dart';
import 'directorio_widgets.dart';

/// Dashboard nacional de la Directiva: indicadores totales, gráfico de asistencia clase a clase,
/// tabla por sede y accesos rápidos.
/// Las alertas de deserción y los justificativos los ve el Equipo de Gestión de cada sede.
class DirectorioDashboardView extends StatefulWidget {
  final ReportesRepository repository;
  final ValueChanged<SeccionDirectorio> onNavegar;

  const DirectorioDashboardView({super.key, required this.repository, required this.onNavegar});

  @override
  State<DirectorioDashboardView> createState() => _DirectorioDashboardViewState();
}

class _DirectorioDashboardViewState extends State<DirectorioDashboardView> {
  bool _cargando = true;
  String? _error;
  List<ResumenSedeReporte> _resumen = [];
  List<SerieAsistencia> _asistencia = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final resumen = await widget.repository.resumenSedes();
      final asistencia = await widget.repository.asistenciaPorClase();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _asistencia = asistencia;
        _error = null;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los indicadores. Revisa la conexión e inténtalo nuevamente.';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _cargando = true);
                _cargarDatos();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final alumnas = _resumen.fold(0, (t, r) => t + r.alumnasActivas);
    final voluntarias = _resumen.fold(0, (t, r) => t + r.voluntariasActivas);
    final sedesActivas = _resumen.where((r) => r.activa).length;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Dashboard nacional',
          subtitulo: '$sedesActivas ${sedesActivas == 1 ? 'sede activa' : 'sedes activas'} · '
              '${formatearFechaClase(DateTime.now())}',
        ),
        _buildKpis(alumnas, voluntarias),
        const SizedBox(height: 20),
        DirectorioPanel(
          titulo: 'Asistencia por clase',
          child: _asistencia.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aún no hay clases realizadas con asistencia registrada.'),
                )
              : GraficoAsistencia(series: _asistencia),
        ),
        const SizedBox(height: 20),
        DirectorioPanel(
          titulo: 'Indicadores por sede',
          child: _buildTablaSedes(),
        ),
        const SizedBox(height: 20),
        _buildAccesosRapidos(),
      ],
    );
  }

  Widget _buildKpis(int alumnas, int voluntarias) {
    final tarjetas = [
      NinasProStatCard(
        title: 'Alumnas activas',
        value: '$alumnas',
        subtitle: 'En ${_resumen.fold(0, (t, r) => t + r.cursos)} cursos activos',
        icon: Icons.school_rounded,
        onTap: () => widget.onNavegar(SeccionDirectorio.alumnas),
      ),
      NinasProStatCard(
        title: 'Voluntarias activas',
        value: '$voluntarias',
        subtitle: 'Tutoras y Equipo de Gestión',
        icon: Icons.volunteer_activism_rounded,
        accentColor: NinasProColors.accent700,
        onTap: () => widget.onNavegar(SeccionDirectorio.voluntariado),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 600 ? 2 : 1;
        final ancho = (constraints.maxWidth - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
        );
      },
    );
  }

  Widget _buildTablaSedes() {
    return DirectorioTabla(
      columnas: const ['Sede', 'Institución', 'Cursos', 'Alumnas', 'Asistencia', 'Voluntarias'],
      filas: [
        for (final r in _resumen)
          DataRow(cells: [
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (!r.activa) ...[
                  const SizedBox(width: 8),
                  DirectorioChip(etiquetaEstado('inactiva'), tono: tonoEstado('inactiva')),
                ],
              ],
            )),
            DataCell(Text(r.institucion ?? '—')),
            DataCell(Text('${r.cursos}')),
            DataCell(Text('${r.alumnasActivas}')),
            DataCell(switch (r.asistenciaPromedio) {
              null => const DirectorioChip('—', tono: TonoChip.neutro),
              final p => DirectorioChip(
                  '${p.toStringAsFixed(1)}%',
                  tono: p >= 80 ? TonoChip.exito : TonoChip.advertencia,
                ),
            }),
            DataCell(Text('${r.voluntariasActivas}')),
          ]),
      ],
    );
  }

  Widget _buildAccesosRapidos() {
    Widget acceso(IconData icono, String texto, SeccionDirectorio seccion) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onPressed: () => widget.onNavegar(seccion),
            icon: Icon(icono, size: 18),
            label: Text(texto),
          ),
        );

    return DirectorioPanel(
      titulo: 'Accesos rápidos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          acceso(Icons.upload_file_rounded, 'Cargar nómina de alumnas', SeccionDirectorio.alumnas),
          acceso(Icons.person_add_alt_1_rounded, 'Registrar voluntarias', SeccionDirectorio.voluntariado),
          acceso(Icons.file_download_rounded, 'Exportar reportes', SeccionDirectorio.exportar),
          acceso(Icons.policy_rounded, 'Revisar la auditoría', SeccionDirectorio.auditoria),
          const SizedBox(height: 4),
          const Text(
            'Las sedes, los cursos, las instancias y los roles de tutoras se administran desde Ajustes (⚙️).',
            style: TextStyle(fontSize: 12, color: NinasProColors.neutral500),
          ),
        ],
      ),
    );
  }
}
