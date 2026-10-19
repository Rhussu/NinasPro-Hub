import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../repositories/hub_repository.dart';
import '../../services/health_service.dart';
import '../../widgets/db_health_checker.dart';
import '../../widgets/ninaspro_mobile_shell.dart';
import 'alumna/portal_alumna_screen.dart';
import 'directorio/directorio_mobile_screen.dart';
import 'tutora/pase_lista_screen.dart';

/// Contenedor maestro del Mockup de NiñasPro Hub.
///
/// Permite alternar entre los 3 roles fundamentales del sistema:
/// 1. 🏛️ Directorio & Gestión (Operación, sedes, nómina, alertas, justificativos)
/// 2. 👩‍🏫 Tutora (Pase de lista táctil rápido, ejercicios en aula, evidencia fotográfica)
/// 3. 👧 Portal de la Alumna (Progreso de asistencia %, sábados de clase, Kahoot)
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
  int _currentRoleIndex = 1; // Inicia en Tutora (el flujo más táctil e interactivo)
  bool _mostrarHealthChecker = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final childScreen = Scaffold(
      appBar: AppBar(
        title: Row(
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
            const Flexible(
              child: Text(
                'NiñasPro Hub',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: NinasProColors.brandPink.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'MOCKUP',
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
        actions: [
          // Alternador de salud de base de datos
          IconButton(
            tooltip: 'Estado de conexión Supabase',
            icon: Icon(
              Icons.cloud_done_rounded,
              size: 20,
              color: _mostrarHealthChecker
                  ? NinasProColors.brandPink
                  : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
            ),
            onPressed: () {
              setState(() {
                _mostrarHealthChecker = !_mostrarHealthChecker;
              });
            },
          ),
          // Alternador de Modo Oscuro / Claro
          if (widget.themeNotifier != null)
            IconButton(
              tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
              ),
              onPressed: () {
                widget.themeNotifier!.value =
                    isDark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Vista principal según rol seleccionado
          IndexedStack(
            index: _currentRoleIndex,
            children: [
              DirectorioMobileScreen(repository: widget.repository),
              PaseListaScreen(repository: widget.repository),
              PortalAlumnaScreen(repository: widget.repository),
            ],
          ),

          // Healthchecker desplegable opcional (mantiene total compatibilidad)
          if (_mostrarHealthChecker)
            Positioned(
              bottom: 16,
              right: 16,
              child: DbHealthChecker(healthService: widget.healthService),
            ),
        ],
      ),
      // Barra de navegación inferior móvil (ergonomía de pulgar)
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentRoleIndex,
        height: 64,
        onDestinationSelected: (index) {
          setState(() {
            _currentRoleIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: NinasProColors.brandPink),
            label: 'Gestión',
          ),
          NavigationDestination(
            icon: Icon(Icons.how_to_reg_outlined),
            selectedIcon: Icon(Icons.how_to_reg_rounded, color: NinasProColors.brandPink),
            label: 'Tutora',
          ),
          NavigationDestination(
            icon: Icon(Icons.face_outlined),
            selectedIcon: Icon(Icons.face_rounded, color: NinasProColors.brandPink),
            label: 'Alumna',
          ),
        ],
      ),
    );

    return NinasProMobileShell(child: childScreen);
  }
}
