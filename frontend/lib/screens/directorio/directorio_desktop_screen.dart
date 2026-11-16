import 'package:flutter/material.dart';
import '../../repositories/alumnas_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/reportes_repository.dart';
import '../../repositories/voluntariado_repository.dart';
import '../ajustes/accesos_rol.dart';
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
/// Registra en [accesos] cada sección y sus acciones principales: desde Ajustes,
/// la entrada cierra Ajustes y abre esa sección de la consola.
class DirectorioDesktopScreen extends StatefulWidget {
  /// Dashboard, exportación y auditoría (US-21..US-25)
  final ReportesRepository? reportesRepository;

  /// Nómina real de alumnas (US-07..US-12); sin ella la sección pide conexión
  final AlumnasRepository? alumnasRepository;

  /// Fichas del voluntariado (US-30..US-32) y el catálogo para sus sedes y cursos
  final VoluntariadoRepository? voluntariadoRepository;
  final CatalogoRepository? catalogoRepository;

  /// Entradas de Ajustes de la Directiva
  final RegistroAccesos? accesos;

  const DirectorioDesktopScreen({
    super.key,
    this.reportesRepository,
    this.alumnasRepository,
    this.voluntariadoRepository,
    this.catalogoRepository,
    this.accesos,
  });

  @override
  State<DirectorioDesktopScreen> createState() => _DirectorioDesktopScreenState();
}

/// Secciones de la barra lateral, en orden
enum SeccionDirectorio { dashboard, alumnas, voluntariado, exportar, auditoria }

class _DirectorioDesktopScreenState extends State<DirectorioDesktopScreen> {
  SeccionDirectorio _seccion = SeccionDirectorio.dashboard;

  // Acción que la sección abre apenas carga (llegando desde Ajustes)
  AccionAlumnas? _accionAlumnas;
  AccionVoluntariado? _accionVoluntariado;

  // Cambia en cada llegada desde Ajustes: la sección se vuelve a abrir aunque ya estuviera elegida
  int _llegada = 0;

  @override
  void initState() {
    super.initState();
    widget.accesos?.registrar(_construirAccesos);
  }

  @override
  void dispose() {
    widget.accesos?.retirar(_construirAccesos);
    super.dispose();
  }

  static const _opciones = [
    OpcionMenuLateral(Icons.space_dashboard_rounded, 'Dashboard'),
    OpcionMenuLateral(Icons.school_rounded, 'Alumnas'),
    OpcionMenuLateral(Icons.volunteer_activism_rounded, 'Voluntariado'),
    OpcionMenuLateral(Icons.file_download_rounded, 'Exportar'),
    OpcionMenuLateral(Icons.policy_rounded, 'Auditoría'),
  ];

  void _irA(SeccionDirectorio seccion) => setState(() {
    _seccion = seccion;
    _accionAlumnas = null;
    _accionVoluntariado = null;
  });

  // Desde Ajustes: vuelve a la consola y abre la sección (y su acción)
  void _irDesdeAjustes(SeccionDirectorio seccion, {AccionAlumnas? alumnas, AccionVoluntariado? voluntariado}) {
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    setState(() {
      _seccion = seccion;
      _accionAlumnas = alumnas;
      _accionVoluntariado = voluntariado;
      _llegada++;
    });
  }

  /// Entradas de Ajustes: cada sección de la consola y sus acciones principales
  List<SeccionAccesos> _construirAccesos() {
    const sinConexion = 'Necesita la conexión con la base de datos.';
    final reportes = widget.reportesRepository != null;
    final alumnas = widget.alumnasRepository != null;
    final voluntariado = widget.voluntariadoRepository != null && widget.catalogoRepository != null;
    final exportar = reportes && widget.catalogoRepository != null;
    AccesoRol entrada(
      IconData icono,
      String titulo,
      String subtitulo,
      SeccionDirectorio seccion, {
      required bool disponible,
      AccionAlumnas? accionAlumnas,
      AccionVoluntariado? accionVoluntariado,
    }) => AccesoRol(
      icono: icono,
      titulo: titulo,
      subtitulo: subtitulo,
      sinConexion: sinConexion,
      abrir: disponible
          ? () => _irDesdeAjustes(seccion, alumnas: accionAlumnas, voluntariado: accionVoluntariado)
          : null,
    );
    return [
      SeccionAccesos('Consola', [
        entrada(
          Icons.space_dashboard_rounded,
          'Dashboard',
          'Alumnas, asistencia y voluntarias de cada sede',
          SeccionDirectorio.dashboard,
          disponible: reportes,
        ),
        entrada(
          Icons.file_download_rounded,
          'Exportar',
          'Asistencia, participación y nómina en CSV o XLSX',
          SeccionDirectorio.exportar,
          disponible: exportar,
        ),
        entrada(
          Icons.policy_rounded,
          'Auditoría',
          'Cambios, descargas y accesos denegados',
          SeccionDirectorio.auditoria,
          disponible: reportes,
        ),
      ]),
      SeccionAccesos('Alumnas', [
        entrada(
          Icons.school_rounded,
          'Nómina de alumnas',
          'Fichas, autorizaciones y retiros',
          SeccionDirectorio.alumnas,
          disponible: alumnas,
        ),
        entrada(
          Icons.person_add_alt_1_rounded,
          'Inscribir alumna',
          'Una alumna a la vez',
          SeccionDirectorio.alumnas,
          disponible: alumnas,
          accionAlumnas: AccionAlumnas.inscribir,
        ),
        entrada(
          Icons.upload_file_rounded,
          'Carga masiva de alumnas',
          'Desde una planilla CSV o XLSX',
          SeccionDirectorio.alumnas,
          disponible: alumnas,
          accionAlumnas: AccionAlumnas.cargaMasiva,
        ),
        entrada(
          Icons.rule_rounded,
          'Conflictos de importación',
          'Las filas que quedaron por resolver',
          SeccionDirectorio.alumnas,
          disponible: alumnas,
          accionAlumnas: AccionAlumnas.conflictos,
        ),
      ]),
      SeccionAccesos('Voluntariado', [
        entrada(
          Icons.volunteer_activism_rounded,
          'Fichas del voluntariado',
          'Adhesión, rol, asignación a cursos, salida y exportación',
          SeccionDirectorio.voluntariado,
          disponible: voluntariado,
        ),
        entrada(
          Icons.person_add_alt_1_rounded,
          'Nueva voluntaria',
          'Su ficha y su correo autorizado',
          SeccionDirectorio.voluntariado,
          disponible: voluntariado,
          accionVoluntariado: AccionVoluntariado.nuevaVoluntaria,
        ),
        entrada(
          Icons.upload_file_rounded,
          'Carga masiva de voluntariado',
          'Desde una planilla CSV o XLSX',
          SeccionDirectorio.voluntariado,
          disponible: voluntariado,
          accionVoluntariado: AccionVoluntariado.cargaMasiva,
        ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Cada sección carga sus datos al abrirse, así siempre muestra lo último editado
    final contenido = switch (_seccion) {
      SeccionDirectorio.dashboard => switch (widget.reportesRepository) {
        final reportes? => DirectorioDashboardView(repository: reportes, onNavegar: _irA),
        null => const _SinConexion('El dashboard necesita la conexión con la base de datos.'),
      },
      SeccionDirectorio.alumnas => switch (widget.alumnasRepository) {
        final alumnas? => DirectorioAlumnasView(repository: alumnas, accionInicial: _accionAlumnas),
        null => const _SinConexion('La nómina de alumnas necesita la conexión con la base de datos.'),
      },
      SeccionDirectorio.voluntariado => switch ((widget.voluntariadoRepository, widget.catalogoRepository)) {
        (final voluntariado?, final catalogo?) => DirectorioVoluntariadoView(
          repository: voluntariado,
          catalogo: catalogo,
          accionInicial: _accionVoluntariado,
        ),
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
        Expanded(child: KeyedSubtree(key: ValueKey((_seccion, _llegada)), child: contenido)),
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
