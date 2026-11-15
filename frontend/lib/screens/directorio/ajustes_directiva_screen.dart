import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../repositories/hub_repository.dart';
import '../../models/sesion_usuario.dart';
import '../../widgets/ninaspro_ajustes.dart';
import 'ajustes/ajustes_cursos_view.dart';
import 'ajustes/ajustes_instancias_view.dart';
import 'ajustes/ajustes_roles_view.dart';
import 'ajustes/ajustes_sedes_view.dart';
import 'directorio_widgets.dart';

/// Ajustes de la Directiva Nacional (vista Desktop), con su propio menú lateral:
/// - Perfil: cabecera, Apariencia y Cuenta (los mismos bloques de [AjustesScreen])
/// - Sedes y Cursos del catálogo (US-01)
/// - Instancias y sesiones (US-02)
/// - Roles de tutoras: catálogo de roles semanales (US-43)
class AjustesDirectivaScreen extends StatefulWidget {
  final HubRepository repository;
  final ValueNotifier<ThemeMode>? themeNotifier;

  /// Usuaria autenticada; sin sesión se muestra el perfil genérico de la Directiva
  final SesionUsuario? sesion;
  final VoidCallback? onCerrarSesion;

  const AjustesDirectivaScreen({
    super.key,
    required this.repository,
    this.themeNotifier,
    this.sesion,
    this.onCerrarSesion,
  });

  @override
  State<AjustesDirectivaScreen> createState() => _AjustesDirectivaScreenState();
}

class _AjustesDirectivaScreenState extends State<AjustesDirectivaScreen> {
  int _seccion = 0;

  static const _opciones = [
    OpcionMenuLateral(Icons.person_rounded, 'Perfil'),
    OpcionMenuLateral(Icons.location_city_rounded, 'Sedes'),
    OpcionMenuLateral(Icons.menu_book_rounded, 'Cursos'),
    OpcionMenuLateral(Icons.event_note_rounded, 'Instancias y sesiones'),
    OpcionMenuLateral(Icons.assignment_ind_rounded, 'Roles de tutoras'),
  ];

  @override
  Widget build(BuildContext context) {
    final contenido = switch (_seccion) {
      1 => AjustesSedesView(repository: widget.repository),
      2 => AjustesCursosView(repository: widget.repository),
      3 => AjustesInstanciasView(repository: widget.repository),
      4 => AjustesRolesView(repository: widget.repository),
      _ => _buildPerfil(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DirectorioMenuLateral(
            opciones: _opciones,
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
