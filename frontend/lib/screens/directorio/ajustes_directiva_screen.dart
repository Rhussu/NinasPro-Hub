import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../repositories/accesos_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/roles_repository.dart';
import '../../models/sesion_usuario.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../accesos/accesos_view.dart';
import 'ajustes/ajustes_cursos_view.dart';
import 'ajustes/ajustes_instancias_view.dart';
import 'ajustes/ajustes_roles_view.dart';
import 'ajustes/ajustes_sedes_view.dart';
import 'directorio_widgets.dart';

/// Ajustes de la Directiva Nacional (vista Desktop), con su propio menú lateral:
/// - Perfil: cabecera, Apariencia y Cuenta (los mismos bloques de [AjustesScreen])
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

  /// Catálogo de roles de las tutoras (US-43)
  final RolesRepository? rolesRepository;

  const AjustesDirectivaScreen({
    super.key,
    this.themeNotifier,
    this.sesion,
    this.onCerrarSesion,
    this.accesosRepository,
    this.catalogoRepository,
    this.rolesRepository,
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
      (const OpcionMenuLateral(Icons.person_rounded, 'Perfil'), _buildPerfil),
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

  Widget _buildPerfil() {
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
