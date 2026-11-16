import 'package:flutter/material.dart';
import '../../repositories/alumnas_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/reportes_repository.dart';
import '../../repositories/voluntariado_repository.dart';
import 'directorio_alumnas_view.dart';
import 'directorio_auditoria_view.dart';
import 'directorio_dashboard_view.dart';
import 'directorio_exportar_view.dart';
import 'directorio_voluntariado_view.dart';
import 'directorio_widgets.dart';

/// Pantalla Desktop / Web para la Directiva Nacional en NiñasPro Hub.
///
/// Vista nacional de todas las sedes con barra lateral:
/// Dashboard, Alumnas (US-07, 08, 09, 10, 12), Voluntariado (US-30, 31, 32),
/// Exportar (US-21, 22) y Auditoría (US-24).
/// El catálogo (sedes, cursos, instancias y roles de tutoras) se administra desde Ajustes.
class DirectorioDesktopScreen extends StatefulWidget {
  /// Dashboard, exportación y auditoría (US-21..US-25)
  final ReportesRepository? reportesRepository;

  /// Nómina real de alumnas (US-07..US-12); sin ella la sección pide conexión
  final AlumnasRepository? alumnasRepository;

  /// Fichas del voluntariado (US-30..US-32) y el catálogo para sus sedes y cursos
  final VoluntariadoRepository? voluntariadoRepository;
  final CatalogoRepository? catalogoRepository;

  const DirectorioDesktopScreen({
    super.key,
    this.reportesRepository,
    this.alumnasRepository,
    this.voluntariadoRepository,
    this.catalogoRepository,
  });

  @override
  State<DirectorioDesktopScreen> createState() => _DirectorioDesktopScreenState();
}

/// Secciones de la barra lateral, en orden
enum SeccionDirectorio { dashboard, alumnas, voluntariado, exportar, auditoria }

class _DirectorioDesktopScreenState extends State<DirectorioDesktopScreen> {
  SeccionDirectorio _seccion = SeccionDirectorio.dashboard;

  static const _opciones = [
    OpcionMenuLateral(Icons.space_dashboard_rounded, 'Dashboard'),
    OpcionMenuLateral(Icons.school_rounded, 'Alumnas'),
    OpcionMenuLateral(Icons.volunteer_activism_rounded, 'Voluntariado'),
    OpcionMenuLateral(Icons.file_download_rounded, 'Exportar'),
    OpcionMenuLateral(Icons.policy_rounded, 'Auditoría'),
  ];

  void _irA(SeccionDirectorio seccion) => setState(() => _seccion = seccion);

  @override
  Widget build(BuildContext context) {
    // Cada sección carga sus datos al abrirse, así siempre muestra lo último editado
    final contenido = switch (_seccion) {
      SeccionDirectorio.dashboard => switch (widget.reportesRepository) {
        final reportes? => DirectorioDashboardView(repository: reportes, onNavegar: _irA),
        null => const _SinConexion('El dashboard necesita la conexión con la base de datos.'),
      },
      SeccionDirectorio.alumnas => switch (widget.alumnasRepository) {
        final alumnas? => DirectorioAlumnasView(repository: alumnas),
        null => const _SinConexion('La nómina de alumnas necesita la conexión con la base de datos.'),
      },
      SeccionDirectorio.voluntariado => switch ((widget.voluntariadoRepository, widget.catalogoRepository)) {
        (final voluntariado?, final catalogo?) => DirectorioVoluntariadoView(repository: voluntariado, catalogo: catalogo),
        _ => const _SinConexion('El voluntariado necesita la conexión con la base de datos.'),
      },
      SeccionDirectorio.exportar => switch ((widget.reportesRepository, widget.catalogoRepository)) {
        (final reportes?, final catalogo?) => DirectorioExportarView(repository: reportes, catalogo: catalogo),
        _ => const _SinConexion('La exportación necesita la conexión con la base de datos.'),
      },
      SeccionDirectorio.auditoria => switch (widget.reportesRepository) {
        final reportes? => DirectorioAuditoriaView(repository: reportes),
        null => const _SinConexion('La auditoría necesita la conexión con la base de datos.'),
      },
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DirectorioMenuLateral(
          opciones: _opciones,
          seleccionada: _seccion.index,
          onSeleccionar: (i) => _irA(SeccionDirectorio.values[i]),
        ),
        Expanded(child: KeyedSubtree(key: ValueKey(_seccion), child: contenido)),
      ],
    );
  }
}

class _SinConexion extends StatelessWidget {
  final String mensaje;

  const _SinConexion(this.mensaje);

  @override
  Widget build(BuildContext context) => Center(child: Text(mensaje));
}
