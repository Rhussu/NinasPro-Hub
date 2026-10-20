import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../repositories/hub_repository.dart';
import '../../services/health_service.dart';
import '../../widgets/db_health_checker.dart';
import '../../widgets/ninaspro_mobile_shell.dart';
import '../../widgets/ninaspro_sync_indicator.dart';
import 'alumna/ajustes_alumna_screen.dart';
import 'alumna/portal_alumna_screen.dart';
import 'directorio/ajustes_directiva_screen.dart';
import 'directorio/directorio_desktop_screen.dart';
import 'gestion/ajustes_gestion_screen.dart';
import 'gestion/gestion_mobile_screen.dart';
import 'tutora/ajustes_tutora_screen.dart';
import 'tutora/tutora_mobile_screen.dart';

/// Contenedor maestro del Mockup de NiñasPro Hub.
///
/// Soporta los 4 roles acordados:
/// 0. 🏛️ Directiva Nacional (Exclusivamente Desktop Web / Pantalla completa)
/// 1. 📋 Equipo de Gestión (Mobile-first: aprobación de justificativos, roles semanales US-43)
/// 2. 👩‍🏫 Tutora (Mobile-first: pase de lista P/A, podio Kahoot, ejercicios)
/// 3. 👧 Portal de la Alumna (Mobile-first: asistencia, recursos US-26, justificaciones sin advertencia médica)
///
/// Además incorpora alternancia de tema claro/oscuro e indicador de salud de base de datos.
class HubShellScreen extends StatefulWidget {
  final HubRepository repository;
  final HealthService? healthService;
  final ValueNotifier<ThemeMode>? themeNotifier;

  const HubShellScreen({
    super.key,
    required this.repository,
    this.healthService,
    this.themeNotifier,
  });

  @override
  State<HubShellScreen> createState() => _HubShellScreenState();
}

class _HubShellScreenState extends State<HubShellScreen> {
  int _currentRoleIndex = 0; // Inicia en Tutora (el flujo más interactivo y dinámico)
  bool _mostrarHealthChecker = false;

  void _cambiarRol(int nuevoRol) {
    setState(() {
      _currentRoleIndex = nuevoRol;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Si el rol es 0 (Directiva Nacional), renderizamos la vista Desktop de ancho completo sin NinasProMobileShell
    if (_currentRoleIndex == 0) {
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
                'NiñasPro Hub · Directiva Desktop',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: NinasProColors.brandPink.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'DESKTOP WEB',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: NinasProColors.brandPink,
                  ),
                ),
              ),
            ],
          ),
          ),
          actions: [
            // Selector rápido de Rol
            _buildRoleSwitcher(isDark),
            const SizedBox(width: 8),
            // Estado de sincronización con la nube
            NinasProIndicadorSync(repository: widget.repository),
            // Alternador de salud de base de datos (herramienta de desarrollo)
            IconButton(
              tooltip: 'Estado de conexión Supabase',
              icon: Icon(
                Icons.dns_rounded,
                size: 20,
                color: _mostrarHealthChecker
                    ? NinasProColors.brandPink
                    : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
              ),
              onPressed: () {
                setState(() => _mostrarHealthChecker = !_mostrarHealthChecker);
              },
            ),
            // Ajustes de la Directiva (incluye el modo claro/oscuro)
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
              Positioned(
                bottom: 20,
                right: 20,
                child: DbHealthChecker(healthService: widget.healthService),
              ),
          ],
        ),
      );
    }

    // Para los roles 1, 2 y 3 (Gestión, Tutora, Alumna), renderizamos vista móvil envuelta en NinasProMobileShell
    final childScreen = Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NiñasPro Hub',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(width: 4),
              Text(
                'MOBILE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: NinasProColors.brandPink,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Selector de Rol
          _buildRoleSwitcher(isDark),
          // Estado de sincronización con la nube
          NinasProIndicadorSync(repository: widget.repository),
          // Ajustes del rol (incluye el modo claro/oscuro); si el rol aún no tiene, alternador de tema
          if (_buildAjustesRol() != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Ajustes',
              icon: const Icon(Icons.settings_rounded, size: 19),
              onPressed: _abrirAjustes,
            )
          else if (widget.themeNotifier != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 19,
              ),
              onPressed: () {
                widget.themeNotifier!.value =
                    isDark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentRoleIndex - 1, // Offset 1 ya que 0 es Directiva
            children: [
              GestionMobileScreen(repository: widget.repository),
              TutoraMobileScreen(repository: widget.repository),
              PortalAlumnaScreen(repository: widget.repository),
            ],
          ),
          if (_mostrarHealthChecker)
            Positioned(
              bottom: 16,
              right: 16,
              child: DbHealthChecker(healthService: widget.healthService),
            ),
        ],
      ),
      
    );

    return NinasProMobileShell(child: childScreen);
  }

  /// Pantalla de Ajustes de cada rol. Para habilitar la de otro rol, agrega su `case` aquí.
  Widget? _buildAjustesRol() {
    switch (_currentRoleIndex) {
      case 0:
        return AjustesDirectivaScreen(
          repository: widget.repository,
          themeNotifier: widget.themeNotifier,
        );
      case 1:
        return AjustesGestionScreen(
          repository: widget.repository,
          themeNotifier: widget.themeNotifier,
        );
      case 2:
        return AjustesTutoraScreen(
          repository: widget.repository,
          themeNotifier: widget.themeNotifier,
        );
      case 3:
        return AjustesAlumnaScreen(
          repository: widget.repository,
          themeNotifier: widget.themeNotifier,
        );
      default:
        return null;
    }
  }

  void _abrirAjustes() {
    final ajustes = _buildAjustesRol();
    if (ajustes == null) return;

    // Directiva (0) es Desktop; los demás roles se ven dentro del marco de teléfono
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _currentRoleIndex == 0 ? ajustes : NinasProMobileShell(child: ajustes),
      ),
    );
  }

  Widget _buildRoleSwitcher(bool isDark) {
    return PopupMenuButton<int>(
      tooltip: 'Cambiar Rol de Usuario',
      initialValue: _currentRoleIndex,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      onSelected: _cambiarRol,
      itemBuilder: (ctx) => [
        const PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Text('🏛️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Directiva (Desktop)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: [
              Text('📋', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gestión (Móvil)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<int>(
          value: 2,
          child: Row(
            children: [
              Text('👩‍🏫', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tutora (Móvil)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<int>(
          value: 3,
          child: Row(
            children: [
              Text('👧', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alumna (Móvil)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
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
            Text(_getRolEmoji(_currentRoleIndex), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              _getRolNombreCorto(_currentRoleIndex),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: NinasProColors.brandPink,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: NinasProColors.brandPink),
          ],
        ),
      ),
    );
  }

  String _getRolEmoji(int rol) {
    switch (rol) {
      case 0:
        return '🏛️';
      case 1:
        return '📋';
      case 2:
        return '👩‍🏫';
      case 3:
        return '👧';
      default:
        return '💜';
    }
  }

  String _getRolNombreCorto(int rol) {
    switch (rol) {
      case 0:
        return 'Directiva';
      case 1:
        return 'Gestión';
      case 2:
        return 'Tutora';
      case 3:
        return 'Alumna';
      default:
        return 'Rol';
    }
  }
}
