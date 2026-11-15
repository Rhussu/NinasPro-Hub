import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/hub_repository.dart';
import '../../services/health_service.dart';
import '../../widgets/db_health_checker.dart';
import '../../widgets/ninaspro_sync_indicator.dart';
import '../../widgets/ninaspro_vista_centrada.dart';
import 'alumna/ajustes_alumna_screen.dart';
import 'alumna/portal_alumna_screen.dart';
import 'directorio/ajustes_directiva_screen.dart';
import 'directorio/directorio_desktop_screen.dart';
import 'gestion/ajustes_gestion_screen.dart';
import 'gestion/gestion_mobile_screen.dart';
import 'tutora/ajustes_tutora_screen.dart';
import 'tutora/tutora_mobile_screen.dart';

/// Contenedor principal de NiñasPro Hub para la usuaria autenticada.
///
/// La vista depende del rol de la sesión:
/// - 🏛️ Directiva Nacional: consola Desktop Web de pantalla completa
/// - 📋 Equipo de Gestión: justificativos, alertas, roles semanales
/// - 👩‍🏫 Tutora: pase de lista, participación, podio Kahoot
/// - 👧 Alumna: asistencia, recursos, justificativos
///
/// Gestión, Tutora y Alumna son vistas responsivas pensadas primero para el
/// celular; en pantallas anchas se centran con un ancho máximo legible.
class HubShellScreen extends StatefulWidget {
  final HubRepository repository;
  final SesionUsuario sesion;
  final HealthService? healthService;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;

  const HubShellScreen({
    super.key,
    required this.repository,
    required this.sesion,
    this.healthService,
    this.themeNotifier,
    this.onCerrarSesion,
  });

  @override
  State<HubShellScreen> createState() => _HubShellScreenState();
}

class _HubShellScreenState extends State<HubShellScreen> {
  bool _mostrarHealthChecker = false;

  RolUsuario get _rol => widget.sesion.rol;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.sesion.usaVistaEscritorio) {
      return Scaffold(
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: NinasProColors.primary700.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('💜', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'NiñasPro Hub · Directiva',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.4),
                ),
              ],
            ),
          ),
          actions: [
            _ChipUsuaria(sesion: widget.sesion),
            const SizedBox(width: 8),
            // Estado de sincronización con la nube
            NinasProIndicadorSync(repository: widget.repository),
            // Estado de la conexión con Supabase (diagnóstico)
            IconButton(
              tooltip: 'Estado de conexión Supabase',
              icon: Icon(
                Icons.dns_rounded,
                size: 20,
                color: _mostrarHealthChecker
                    ? NinasProColors.brandPink
                    : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
              ),
              onPressed: () => setState(() => _mostrarHealthChecker = !_mostrarHealthChecker),
            ),
            IconButton(
              tooltip: 'Ajustes',
              icon: const Icon(Icons.settings_rounded, size: 20),
              onPressed: _abrirAjustes,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Stack(
          children: [
            DirectorioDesktopScreen(repository: widget.repository),
            if (_mostrarHealthChecker)
              Positioned(bottom: 20, right: 20, child: DbHealthChecker(healthService: widget.healthService)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('NiñasPro Hub', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.4)),
        ),
        actions: [
          _ChipUsuaria(sesion: widget.sesion),
          // Estado de sincronización con la nube
          NinasProIndicadorSync(repository: widget.repository),
          if (_buildAjustesRol() != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Ajustes',
              icon: const Icon(Icons.settings_rounded, size: 19),
              onPressed: _abrirAjustes,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: NinasProVistaCentrada(child: _buildVistaMovil()),
    );
  }

  Widget _buildVistaMovil() {
    return switch (_rol) {
      RolUsuario.equipoGestion => GestionMobileScreen(repository: widget.repository),
      RolUsuario.tutora => TutoraMobileScreen(repository: widget.repository),
      RolUsuario.alumna => PortalAlumnaScreen(repository: widget.repository),
      _ => _RolSinVista(sesion: widget.sesion, onCerrarSesion: widget.onCerrarSesion),
    };
  }

  Widget? _buildAjustesRol() {
    return switch (_rol) {
      RolUsuario.directorio => AjustesDirectivaScreen(
          repository: widget.repository,
          sesion: widget.sesion,
          themeNotifier: widget.themeNotifier,
          onCerrarSesion: widget.onCerrarSesion,
        ),
      RolUsuario.equipoGestion => AjustesGestionScreen(
          repository: widget.repository,
          themeNotifier: widget.themeNotifier,
          onCerrarSesion: widget.onCerrarSesion,
        ),
      RolUsuario.tutora => AjustesTutoraScreen(
          repository: widget.repository,
          themeNotifier: widget.themeNotifier,
          onCerrarSesion: widget.onCerrarSesion,
        ),
      RolUsuario.alumna => AjustesAlumnaScreen(
          repository: widget.repository,
          themeNotifier: widget.themeNotifier,
          onCerrarSesion: widget.onCerrarSesion,
        ),
      RolUsuario.comunicacion => null,
    };
  }

  void _abrirAjustes() {
    final ajustes = _buildAjustesRol();
    if (ajustes == null) return;

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ajustes));
  }
}

/// Nombre y rol de la usuaria autenticada en la barra superior.
class _ChipUsuaria extends StatelessWidget {
  final SesionUsuario sesion;

  const _ChipUsuaria({required this.sesion});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${sesion.nombreCompleto} · ${sesion.correo}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: NinasProColors.primary700.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NinasProColors.brandPink.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sesion.rol.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              sesion.rol.etiqueta,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: NinasProColors.brandPink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Roles sin vista propia en el MVP (ej. Comunicación).
class _RolSinVista extends StatelessWidget {
  final SesionUsuario sesion;
  final VoidCallback? onCerrarSesion;

  const _RolSinVista({required this.sesion, this.onCerrarSesion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sesion.rol.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'Hola, ${sesion.nombres}. Tu rol (${sesion.rol.etiqueta}) aún no tiene una vista en NiñasPro Hub.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (onCerrarSesion != null) OutlinedButton(onPressed: onCerrarSesion, child: const Text('Cerrar sesión')),
          ],
        ),
      ),
    );
  }
}
