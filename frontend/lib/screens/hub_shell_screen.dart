import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/accesos_repository.dart';
import '../../repositories/alertas_repository.dart';
import '../../repositories/alumnas_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/evidencias_repository.dart';
import '../../repositories/justificativos_repository.dart';
import '../../repositories/portal_repository.dart';
import '../../repositories/reportes_repository.dart';
import '../../repositories/roles_repository.dart';
import '../../repositories/voluntariado_repository.dart';
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
  final SesionUsuario sesion;
  final HealthService? healthService;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;

  /// Autorización de correos (vista "Accesos" de Directiva y Gestión)
  final AccesosRepository? accesosRepository;

  /// Catálogo de sedes y cursos, instancias y calendario de clases (US-01..03)
  final CatalogoRepository? catalogoRepository;

  /// Nómina, fichas, cargas masivas y autorizaciones de alumnas (US-07..12)
  final AlumnasRepository? alumnasRepository;

  /// La clase en el aula con su cola sin conexión (US-13..15, US-28, US-29, US-33, US-34)
  final ClaseRepository? claseRepository;

  /// Justificativos de inasistencia: bandeja de Gestión y envío de la alumna (US-16, US-17, US-35..38)
  final JustificativosRepository? justificativosRepository;

  /// Fotos de evidencia de las clases (US-18..US-20)
  final EvidenciasRepository? evidenciasRepository;

  /// Fichas del voluntariado y asignación a cursos (US-30..US-32)
  final VoluntariadoRepository? voluntariadoRepository;

  /// Catálogo de roles y roles de cada clase (US-43, US-44)
  final RolesRepository? rolesRepository;

  /// Dashboard, exportación y auditoría (US-21..US-25)
  final ReportesRepository? reportesRepository;

  /// Alertas de deserción y contacto preventivo (US-39, US-40)
  final AlertasRepository? alertasRepository;

  /// Portal de la alumna autenticada (US-25..US-27)
  final PortalRepository? portalRepository;

  const HubShellScreen({
    super.key,
    required this.sesion,
    this.healthService,
    this.themeNotifier,
    this.onCerrarSesion,
    this.accesosRepository,
    this.catalogoRepository,
    this.alumnasRepository,
    this.claseRepository,
    this.justificativosRepository,
    this.evidenciasRepository,
    this.voluntariadoRepository,
    this.rolesRepository,
    this.reportesRepository,
    this.alertasRepository,
    this.portalRepository,
  });

  @override
  State<HubShellScreen> createState() => _HubShellScreenState();
}

class _HubShellScreenState extends State<HubShellScreen> {
  bool _mostrarHealthChecker = false;

  RolUsuario get _rol => widget.sesion.rol;

  // La nubecita muestra la cola de la clase; sin ella, todo está al día
  FuenteSincronizacion get _sincronizacion => widget.claseRepository ?? const SinCambiosPendientes();

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
            NinasProIndicadorSync(repository: _sincronizacion),
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
            DirectorioDesktopScreen(
              reportesRepository: widget.reportesRepository,
              alumnasRepository: widget.alumnasRepository,
              voluntariadoRepository: widget.voluntariadoRepository,
              catalogoRepository: widget.catalogoRepository,
            ),
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
          NinasProIndicadorSync(repository: _sincronizacion),
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
    final clase = widget.claseRepository;
    if (clase == null && (_rol == RolUsuario.equipoGestion || _rol == RolUsuario.tutora)) {
      return const Center(child: Text('La clase necesita la conexión con la base de datos.'));
    }
    return switch (_rol) {
      RolUsuario.equipoGestion => GestionMobileScreen(
        clase: clase!,
        sesion: widget.sesion,
        justificativos: widget.justificativosRepository,
        evidencias: widget.evidenciasRepository,
        roles: widget.rolesRepository,
        alertas: widget.alertasRepository,
      ),
      RolUsuario.tutora => TutoraMobileScreen(
        clase: clase!,
        sesion: widget.sesion,
        evidencias: widget.evidenciasRepository,
        roles: widget.rolesRepository,
      ),
      RolUsuario.alumna => switch (widget.portalRepository) {
        final portal? => PortalAlumnaScreen(repository: portal, justificativos: widget.justificativosRepository),
        null => const Center(child: Text('Tu portal necesita la conexión con la base de datos.')),
      },
      _ => _RolSinVista(sesion: widget.sesion, onCerrarSesion: widget.onCerrarSesion),
    };
  }

  Widget? _buildAjustesRol() {
    return switch (_rol) {
      RolUsuario.directorio => AjustesDirectivaScreen(
          sesion: widget.sesion,
          themeNotifier: widget.themeNotifier,
          onCerrarSesion: widget.onCerrarSesion,
          accesosRepository: widget.accesosRepository,
          catalogoRepository: widget.catalogoRepository,
          rolesRepository: widget.rolesRepository,
        ),
      RolUsuario.equipoGestion => AjustesGestionScreen(
          sesion: widget.sesion,
          voluntariado: widget.voluntariadoRepository,
          clase: widget.claseRepository,
          themeNotifier: widget.themeNotifier,
          onCerrarSesion: widget.onCerrarSesion,
          catalogoRepository: widget.catalogoRepository,
        ),
      RolUsuario.tutora => AjustesTutoraScreen(
          sesion: widget.sesion,
          voluntariado: widget.voluntariadoRepository,
          clase: widget.claseRepository,
          themeNotifier: widget.themeNotifier,
          onCerrarSesion: widget.onCerrarSesion,
        ),
      RolUsuario.alumna => switch (widget.portalRepository) {
          final portal? => AjustesAlumnaScreen(
              repository: portal,
              themeNotifier: widget.themeNotifier,
              onCerrarSesion: widget.onCerrarSesion,
            ),
          null => null,
        },
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
