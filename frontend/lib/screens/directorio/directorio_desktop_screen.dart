import 'package:flutter/material.dart';
import '../../repositories/alumnas_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/hub_repository.dart';
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
  final HubRepository repository;

  /// Nómina real de alumnas (US-07..US-12); sin ella la sección pide conexión
  final AlumnasRepository? alumnasRepository;

  /// Fichas del voluntariado (US-30..US-32) y el catálogo para sus sedes y cursos
  final VoluntariadoRepository? voluntariadoRepository;
  final CatalogoRepository? catalogoRepository;

  const DirectorioDesktopScreen({
    super.key,
    required this.repository,
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
      SeccionDirectorio.dashboard => DirectorioDashboardView(repository: widget.repository, onNavegar: _irA),
      SeccionDirectorio.alumnas => switch (widget.alumnasRepository) {
        final alumnas? => DirectorioAlumnasView(repository: alumnas),
        null => const Center(child: Text('La nómina de alumnas necesita la conexión con la base de datos.')),
      },
      SeccionDirectorio.voluntariado => switch ((widget.voluntariadoRepository, widget.catalogoRepository)) {
        (final voluntariado?, final catalogo?) => DirectorioVoluntariadoView(repository: voluntariado, catalogo: catalogo),
        _ => const Center(child: Text('El voluntariado necesita la conexión con la base de datos.')),
      },
      SeccionDirectorio.exportar => DirectorioExportarView(repository: widget.repository),
      SeccionDirectorio.auditoria => DirectorioAuditoriaView(repository: widget.repository),
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
