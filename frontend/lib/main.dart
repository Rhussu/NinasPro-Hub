import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/ninaspro_theme.dart';
import 'repositories/accesos_repository.dart';
import 'repositories/alertas_repository.dart';
import 'repositories/alumnas_repository.dart';
import 'repositories/catalogo_repository.dart';
import 'repositories/clase_repository.dart';
import 'repositories/evidencias_repository.dart';
import 'repositories/justificativos_repository.dart';
import 'repositories/portal_repository.dart';
import 'repositories/reportes_repository.dart';
import 'repositories/roles_repository.dart';
import 'repositories/voluntariado_repository.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/hub_shell_screen.dart';
import 'services/auth_service.dart';
import 'services/health_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    // Sin SUPABASE_URL / SUPABASE_ANON_KEY no hay autenticación posible
    runApp(_ErrorConfiguracionApp(detalle: '$e'));
    return;
  }

  runApp(NinasProApp(
    authService: SupabaseAuthService(
      Supabase.instance.client,
      // Los enlaces de confirmación y recuperación vuelven a esta misma app
      redirectTo: kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : null,
    ),
    accesosRepository: SupabaseAccesosRepository(Supabase.instance.client),
    catalogoRepository: SupabaseCatalogoRepository(Supabase.instance.client),
    alumnasRepository: SupabaseAlumnasRepository(Supabase.instance.client),
    claseRepository: SupabaseClaseRepository.enNavegador(Supabase.instance.client),
    justificativosRepository: SupabaseJustificativosRepository(Supabase.instance.client),
    evidenciasRepository: SupabaseEvidenciasRepository(Supabase.instance.client),
    voluntariadoRepository: SupabaseVoluntariadoRepository(Supabase.instance.client),
    rolesRepository: SupabaseRolesRepository(Supabase.instance.client),
    reportesRepository: SupabaseReportesRepository(Supabase.instance.client),
    alertasRepository: SupabaseAlertasRepository(Supabase.instance.client),
    portalRepository: SupabasePortalRepository(Supabase.instance.client),
  ));
}

class NinasProApp extends StatefulWidget {
  final AuthService authService;
  final HealthService? healthService;
  final ThemeMode initialThemeMode;
  final AccesosRepository? accesosRepository;
  final CatalogoRepository? catalogoRepository;
  final AlumnasRepository? alumnasRepository;
  final ClaseRepository? claseRepository;
  final JustificativosRepository? justificativosRepository;
  final EvidenciasRepository? evidenciasRepository;
  final VoluntariadoRepository? voluntariadoRepository;
  final RolesRepository? rolesRepository;
  final ReportesRepository? reportesRepository;
  final AlertasRepository? alertasRepository;
  final PortalRepository? portalRepository;

  const NinasProApp({
    super.key,
    required this.authService,
    this.healthService,
    this.initialThemeMode = ThemeMode.dark, // Estética ninaspro.cl cósmica por defecto
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
  State<NinasProApp> createState() => _NinasProAppState();
}

class _NinasProAppState extends State<NinasProApp> {
  late final ValueNotifier<ThemeMode> _themeNotifier;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier(widget.initialThemeMode);
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    widget.authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'NiñasPro Hub',
          debugShowCheckedModeBanner: false,
          theme: NinasProTheme.light,
          darkTheme: NinasProTheme.dark,
          themeMode: currentMode,
          home: AuthGate(
            authService: widget.authService,
            builder: (context, sesion) => HubShellScreen(
              sesion: sesion,
              healthService: widget.healthService,
              themeNotifier: _themeNotifier,
              onCerrarSesion: widget.authService.cerrarSesion,
              accesosRepository: widget.accesosRepository,
              catalogoRepository: widget.catalogoRepository,
              alumnasRepository: widget.alumnasRepository,
              claseRepository: widget.claseRepository,
              justificativosRepository: widget.justificativosRepository,
              evidenciasRepository: widget.evidenciasRepository,
              voluntariadoRepository: widget.voluntariadoRepository,
              rolesRepository: widget.rolesRepository,
              reportesRepository: widget.reportesRepository,
              alertasRepository: widget.alertasRepository,
              portalRepository: widget.portalRepository,
            ),
          ),
        );
      },
    );
  }
}

/// Se muestra si la app se compiló sin la configuración de Supabase.
class _ErrorConfiguracionApp extends StatelessWidget {
  final String detalle;

  const _ErrorConfiguracionApp({required this.detalle});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NinasProTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('NiñasPro Hub no está configurado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Falta SUPABASE_URL o SUPABASE_ANON_KEY (--dart-define).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(detalle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
