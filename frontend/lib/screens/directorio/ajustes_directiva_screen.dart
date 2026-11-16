import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../repositories/accesos_repository.dart';
import '../../repositories/alertas_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/justificativos_repository.dart';
import '../../repositories/roles_repository.dart';
import '../../models/sesion_usuario.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../accesos/accesos_view.dart';
import '../ajustes/accesos_rol.dart';
import '../calendario/calendario_screen.dart';
import '../gestion/alertas_desercion_view.dart';
import '../tutora/inicio_tutora_widgets.dart' show abrirPantallaSecundaria;
import 'ajustes/ajustes_cursos_view.dart';
import 'ajustes/ajustes_instancias_view.dart';
import 'ajustes/ajustes_roles_view.dart';
import 'ajustes/ajustes_sedes_view.dart';
import 'directorio_widgets.dart';
import 'gestion_todas_las_sedes.dart';

/// Ajustes de la Directiva Nacional (vista Desktop), con su propio menú lateral:
/// - Inicio: acceso a todo lo que la Directiva puede ver o hacer. La consola
///   ([accesos], la registra [DirectorioDesktopScreen]), el catálogo y, aparte,
///   lo de Gestión en todas las sedes; al final Apariencia y Cuenta.
/// - Sedes y Cursos del catálogo (US-01)
/// - Instancias y sesiones, con su calendario (US-02, US-03)
/// - Roles de tutoras: catálogo de roles semanales (US-43)
/// - Accesos: correos autorizados para crear su cuenta (US-04)
class AjustesDirectivaScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode>? themeNotifier;

  /// Usuaria autenticada; sin sesión se muestra el perfil genérico de la Directiva
  final SesionUsuario? sesion;
  final VoidCallback? onCerrarSesion;
  final AccesosRepository? accesosRepository;
  final CatalogoRepository? catalogoRepository;

  /// Catálogo de roles de las tutoras (US-43) y roles de cada clase (US-44)
  final RolesRepository? rolesRepository;

  /// Lo de Gestión en todas las sedes: clases, justificativos y alertas
  final ClaseRepository? claseRepository;
  final JustificativosRepository? justificativosRepository;
  final AlertasRepository? alertasRepository;

  /// Secciones de la consola (dashboard, alumnas, voluntariado, exportar y auditoría)
  final RegistroAccesos? accesos;

  const AjustesDirectivaScreen({
    super.key,
    this.themeNotifier,
    this.sesion,
    this.onCerrarSesion,
    this.accesosRepository,
    this.catalogoRepository,
    this.rolesRepository,
    this.claseRepository,
    this.justificativosRepository,
    this.alertasRepository,
    this.accesos,
  });

  @override
  State<AjustesDirectivaScreen> createState() => _AjustesDirectivaScreenState();
}

class _AjustesDirectivaScreenState extends State<AjustesDirectivaScreen> {
  int _seccion = 0;

  /// "Accesos" solo aparece con una sesión real (necesita la base de datos)
  bool get _conAccesos => widget.accesosRepository != null && widget.sesion != null;

  /// Secciones del menú lateral en orden. Sedes, Cursos e Instancias usan la
  /// base de datos y aparecen solo si hay [CatalogoRepository].
  List<(OpcionMenuLateral, Widget Function())> get _secciones {
    final catalogo = widget.catalogoRepository;
    return [
      (const OpcionMenuLateral(Icons.home_rounded, 'Inicio'), _buildInicio),
      if (catalogo != null) ...[
        (const OpcionMenuLateral(Icons.location_city_rounded, 'Sedes'), () => AjustesSedesView(repository: catalogo)),
        (const OpcionMenuLateral(Icons.menu_book_rounded, 'Cursos'), () => AjustesCursosView(repository: catalogo)),
        (
          const OpcionMenuLateral(Icons.event_note_rounded, 'Instancias y sesiones'),
          () => AjustesInstanciasView(repository: catalogo),
        ),
      ],
      if (widget.rolesRepository case final roles?)
        (const OpcionMenuLateral(Icons.assignment_ind_rounded, 'Roles de tutoras'), () => AjustesRolesView(repository: roles)),
      if (_conAccesos)
        (
          const OpcionMenuLateral(Icons.how_to_reg_rounded, 'Accesos'),
          () => AccesosView(repository: widget.accesosRepository!, sesion: widget.sesion!),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final secciones = _secciones;
    final contenido = secciones[_seccion.clamp(0, secciones.length - 1)].$2();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DirectorioMenuLateral(
            opciones: [for (final s in secciones) s.$1],
            seleccionada: _seccion,
            onSeleccionar: (i) => setState(() => _seccion = i),
          ),
          Expanded(child: KeyedSubtree(key: ValueKey(_seccion), child: contenido)),
        ],
      ),
    );
  }

  // Elige una sección del menú lateral por su etiqueta
  void _irASeccion(String etiqueta) {
    final i = _secciones.indexWhere((s) => s.$1.etiqueta == etiqueta);
    if (i >= 0) setState(() => _seccion = i);
  }

  bool _enMenu(String etiqueta) => _secciones.any((s) => s.$1.etiqueta == etiqueta);

  /// Sedes, cursos, instancias, calendario, roles de tutoras y accesos
  SeccionAccesos _seccionCatalogo() {
    final catalogo = widget.catalogoRepository;
    AccesoRol aSeccion(IconData icono, String etiqueta, String subtitulo) => AccesoRol(
      icono: icono,
      titulo: etiqueta,
      subtitulo: subtitulo,
      abrir: _enMenu(etiqueta) ? () => _irASeccion(etiqueta) : null,
    );
    return SeccionAccesos('Catálogo y equipo', [
      aSeccion(Icons.location_city_rounded, 'Sedes', 'Las sedes del programa'),
      aSeccion(Icons.menu_book_rounded, 'Cursos', 'El catálogo de cursos'),
      aSeccion(Icons.event_note_rounded, 'Instancias y sesiones', 'Cada curso en su sede y período, con sus clases'),
      AccesoRol(
        icono: Icons.calendar_month_rounded,
        titulo: 'Calendario de clases',
        subtitulo: 'Suspende sesiones o agrega clases de recuperación',
        abrir: catalogo == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalendarioScreen(repository: catalogo))),
      ),
      aSeccion(Icons.assignment_ind_rounded, 'Roles de tutoras', 'El catálogo de roles de la clase'),
      aSeccion(Icons.how_to_reg_rounded, 'Accesos', 'Correos autorizados para crear su cuenta'),
    ]);
  }

  /// Lo de Gestión en todas las sedes: secundario, porque la Directiva puede hacer todo
  SeccionAccesos _seccionGestion() {
    final justificativos = widget.justificativosRepository;
    final alertas = widget.alertasRepository;
    final roles = widget.rolesRepository;
    final clase = widget.claseRepository;
    return SeccionAccesos('Gestión en todas las sedes', [
      AccesoRol(
        icono: Icons.assignment_turned_in_rounded,
        titulo: 'Justificativos',
        subtitulo: 'Aprueba, rechaza o ingresa el aviso de una apoderada, con filtro por sede',
        abrir: justificativos == null
            ? null
            : () => abrirPantallaSecundaria(
                context,
                'Justificativos',
                JustificativosTodasLasSedesView(repository: justificativos, clase: clase),
              ),
      ),
      AccesoRol(
        icono: Icons.notifications_active_rounded,
        titulo: 'Alertas de deserción',
        subtitulo: 'Por contactar y contactadas, con filtro por sede',
        abrir: alertas == null
            ? null
            : () => abrirPantallaSecundaria(context, 'Alertas de deserción', AlertasDesercionView(repository: alertas)),
      ),
      AccesoRol(
        icono: Icons.groups_2_rounded,
        titulo: 'Roles de la clase',
        subtitulo: 'Elige el curso y asigna o marca los roles de sus tutoras',
        abrir: roles == null || clase == null || widget.sesion == null
            ? null
            : () => abrirPantallaSecundaria(
                context,
                'Roles de la clase',
                RolesTodasLasSedesView(clase: clase, roles: roles, perfilId: widget.sesion!.perfilId),
              ),
      ),
    ]);
  }

  Widget _buildInicio() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            AjustesPerfilHeader(
              nombre: widget.sesion?.nombreCompleto ?? 'Directiva Nacional',
              detalle: widget.sesion?.correo ?? 'NiñasPro · Todas las sedes',
              rolEtiqueta: 'Directiva',
              rolEmoji: '🏛️',
            ),
            const SizedBox(height: 20),
            if (widget.accesos case final accesos?) AjustesAccesos(registro: accesos),
            SeccionAccesosAjustes(seccion: _seccionCatalogo()),
            SeccionAccesosAjustes(seccion: _seccionGestion()),
            if (widget.themeNotifier != null) AjustesApariencia(themeNotifier: widget.themeNotifier!),
            AjustesCuenta(onCerrarSesion: widget.onCerrarSesion),
            const Center(
              child: Text(
                'NiñasPro Hub · v1.0.0',
                style: TextStyle(fontSize: 11, color: NinasProColors.neutral500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
