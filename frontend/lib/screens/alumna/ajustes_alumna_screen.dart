import 'package:flutter/material.dart';
import '../../repositories/portal_repository.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../ajustes/ajustes_screen.dart';

/// Ajustes de la Alumna: perfil, curso y apoderado/a de la cuenta autenticada.
/// La estructura común (apariencia, cerrar sesión) la aporta [AjustesScreen].
class AjustesAlumnaScreen extends StatefulWidget {
  final PortalRepository repository;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;

  const AjustesAlumnaScreen({
    super.key,
    required this.repository,
    this.themeNotifier,
    this.onCerrarSesion,
  });

  @override
  State<AjustesAlumnaScreen> createState() => _AjustesAlumnaScreenState();
}

class _AjustesAlumnaScreenState extends State<AjustesAlumnaScreen> {
  PortalAlumna? _portal;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    PortalAlumna? portal;
    try {
      portal = await widget.repository.portal();
    } catch (_) {
      // Sin datos se muestran solo la apariencia y el cierre de sesión
    }
    if (!mounted) return;
    setState(() {
      _portal = portal;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final portal = _portal;
    final curso = portal?.curso;

    return AjustesScreen(
      cargando: _cargando,
      themeNotifier: widget.themeNotifier,
      onCerrarSesion: widget.onCerrarSesion,
      // Sin datos se muestra igual la apariencia y el cierre de sesión
      perfil: portal == null
          ? const AjustesPerfil(
              nombre: 'Alumna',
              detalle: 'No pudimos cargar tu ficha. Revisa tu conexión.',
              rolEtiqueta: 'Alumna',
              rolEmoji: '👧',
            )
          : AjustesPerfil(
              nombre: portal.nombreCompleto,
              detalle: curso?.nombre ?? 'Sin curso asignado',
              rolEtiqueta: 'Alumna',
              rolEmoji: '👧',
            ),
      secciones: portal == null
          ? const []
          : [
              AjustesSeccion(
                titulo: 'Mi perfil',
                children: [
                  AjustesTile(icono: Icons.badge_rounded, titulo: 'RUT', subtitulo: portal.rut),
                  AjustesTile(icono: Icons.school_rounded, titulo: 'Curso', subtitulo: curso?.nombre ?? '—'),
                  AjustesTile(icono: Icons.location_on_rounded, titulo: 'Sede', subtitulo: curso?.sedeNombre ?? '—'),
                ],
              ),
              AjustesSeccion(
                titulo: 'Apoderado/a',
                children: [
                  AjustesTile(icono: Icons.person_rounded, titulo: 'Nombre', subtitulo: portal.apoderadoNombre),
                  AjustesTile(icono: Icons.phone_rounded, titulo: 'Teléfono', subtitulo: portal.apoderadoTelefono),
                ],
              ),
            ],
    );
  }
}
