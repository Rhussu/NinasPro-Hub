import 'package:flutter/material.dart';
import '../../models/hub_models.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../ajustes/ajustes_screen.dart';

/// Ajustes de la Alumna: perfil, curso y apoderado/a.
/// La estructura común (apariencia, cerrar sesión) la aporta [AjustesScreen].
class AjustesAlumnaScreen extends StatefulWidget {
  final HubRepository repository;
  final String alumnaId;
  final ValueNotifier<ThemeMode>? themeNotifier;

  const AjustesAlumnaScreen({
    super.key,
    required this.repository,
    this.alumnaId = 'alumna-1', // Misma alumna por defecto que PortalAlumnaScreen
    this.themeNotifier,
  });

  @override
  State<AjustesAlumnaScreen> createState() => _AjustesAlumnaScreenState();
}

class _AjustesAlumnaScreenState extends State<AjustesAlumnaScreen> {
  PortalAlumnaData? _data;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final data = await widget.repository.getPortalAlumnaData(alumnaId: widget.alumnaId);
    if (!mounted) return;
    setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final alumna = _data?.alumna;

    return AjustesScreen(
      cargando: _data == null,
      themeNotifier: widget.themeNotifier,
      perfil: alumna == null
          ? null
          : AjustesPerfil(
              nombre: alumna.nombre,
              detalle: alumna.cursoNombre,
              rolEtiqueta: 'Alumna',
              rolEmoji: '👧',
            ),
      secciones: alumna == null ? const [] : _buildSecciones(alumna),
    );
  }

  List<Widget> _buildSecciones(Alumna alumna) {
    return [
      AjustesSeccion(
        titulo: 'Mi perfil',
        children: [
          AjustesTile(icono: Icons.badge_rounded, titulo: 'RUT', subtitulo: alumna.rut),
          AjustesTile(icono: Icons.school_rounded, titulo: 'Curso', subtitulo: alumna.cursoNombre),
          AjustesTile(icono: Icons.location_on_rounded, titulo: 'Sede', subtitulo: alumna.sedeNombre),
        ],
      ),
      AjustesSeccion(
        titulo: 'Apoderado/a',
        children: [
          AjustesTile(icono: Icons.person_rounded, titulo: 'Nombre', subtitulo: alumna.apoderadoNombre),
          AjustesTile(icono: Icons.phone_rounded, titulo: 'Teléfono', subtitulo: alumna.apoderadoTelefono),
        ],
      ),
    ];
  }
}
