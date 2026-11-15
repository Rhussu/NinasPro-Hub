import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/ninaspro_theme.dart';
import 'repositories/hub_repository.dart';
import 'repositories/mock_hub_repository.dart';
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
  ));
}

class NinasProApp extends StatefulWidget {
  final AuthService authService;
  final HealthService? healthService;
  final HubRepository? repository;
  final ThemeMode initialThemeMode;

  const NinasProApp({
    super.key,
    required this.authService,
    this.healthService,
    this.repository,
    this.initialThemeMode = ThemeMode.dark, // Estética ninaspro.cl cósmica por defecto
  });

  @override
  State<NinasProApp> createState() => _NinasProAppState();
}

class _NinasProAppState extends State<NinasProApp> {
  late final ValueNotifier<ThemeMode> _themeNotifier;
  // TODO(mvp): reemplazar por SupabaseHubRepository al conectar los datos reales
  late final HubRepository _repository;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier(widget.initialThemeMode);
    _repository = widget.repository ?? MockHubRepository();
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
              repository: _repository,
              sesion: sesion,
              healthService: widget.healthService,
              themeNotifier: _themeNotifier,
              onCerrarSesion: widget.authService.cerrarSesion,
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
