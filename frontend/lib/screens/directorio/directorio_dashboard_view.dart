import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_stat_card.dart';
import 'directorio_desktop_screen.dart';
import 'directorio_grafico_asistencia.dart';
import 'directorio_widgets.dart';

/// Dashboard nacional de la Directiva: indicadores totales, gráfico de asistencia clase a clase,
/// tabla por sede y accesos rápidos.
/// Las alertas de deserción y los justificativos los ve el Equipo de Gestión de cada sede.
class DirectorioDashboardView extends StatefulWidget {
  final HubRepository repository;
  final ValueChanged<SeccionDirectorio> onNavegar;

  const DirectorioDashboardView({super.key, required this.repository, required this.onNavegar});

  @override
  State<DirectorioDashboardView> createState() => _DirectorioDashboardViewState();
}

class _DirectorioDashboardViewState extends State<DirectorioDashboardView> {
  bool _cargando = true;
  List<ResumenSede> _resumen = [];
  List<SerieAsistencia> _asistencia = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final resumen = await widget.repository.getResumenSedes();
    final asistencia = await widget.repository.getAsistenciaPorClase();
    if (!mounted) return;
    setState(() {
      _resumen = resumen;
      _asistencia = asistencia;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final alumnas = _resumen.fold(0, (t, r) => t + r.alumnasActivas);
    final voluntarias = _resumen.fold(0, (t, r) => t + r.voluntariasActivas);
    final sedesActivas = _resumen.where((r) => r.sede.estado == 'activa').length;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        DirectorioEncabezado(
          titulo: 'Dashboard nacional',
          subtitulo: '$sedesActivas sedes activas · Clase de hoy: sábado 25 de abril',
        ),
        _buildKpis(alumnas, voluntarias),
        const SizedBox(height: 20),
        DirectorioPanel(
          titulo: 'Asistencia por clase',
          child: GraficoAsistencia(series: _asistencia),
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
        subtitle: 'En ${_resumen.fold(0, (t, r) => t + r.cursos)} cursos',
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
                Text(r.sede.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (r.sede.estado != 'activa') ...[
                  const SizedBox(width: 8),
                  DirectorioChip(etiquetaEstado(r.sede.estado), tono: tonoEstado(r.sede.estado)),
                ],
              ],
            )),
            DataCell(Text(r.sede.universidad)),
            DataCell(Text('${r.cursos}')),
            DataCell(Text('${r.alumnasActivas}')),
            DataCell(DirectorioChip(
              r.alumnasActivas == 0 ? '—' : '${r.asistenciaPromedio.toStringAsFixed(1)}%',
              tono: r.alumnasActivas == 0
                  ? TonoChip.neutro
                  : (r.asistenciaPromedio >= 80 ? TonoChip.exito : TonoChip.advertencia),
            )),
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
