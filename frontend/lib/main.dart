import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/ninaspro_theme.dart';
import 'repositories/hub_repository.dart';
import 'repositories/mock_hub_repository.dart';
import 'screens/hub_shell_screen.dart';
import 'services/health_service.dart';
import 'widgets/db_health_checker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Aviso: Supabase no inicializado en arranque: $e');
  }

  runApp(const NinasProApp());
}

/// Acceso seguro al cliente de Supabase en cualquier parte de la aplicación
SupabaseClient? get supabaseClient {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

class NinasProApp extends StatefulWidget {
  final HealthService? healthService;
  final HubRepository? repository;
  final ThemeMode initialThemeMode;

  const NinasProApp({
    super.key,
    this.healthService,
    this.repository,
    this.initialThemeMode = ThemeMode.dark, // Estética ninaspro.cl cósmica por defecto
  });

  @override
  State<NinasProApp> createState() => _NinasProAppState();
}

class _NinasProAppState extends State<NinasProApp> {
  late final ValueNotifier<ThemeMode> _themeNotifier;
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
          home: HubShellScreen(
            repository: _repository,
            healthService: widget.healthService,
            themeNotifier: _themeNotifier,
          ),
        );
      },
    );
  }
}

/// Pantalla histórica de desarrollo mantenida para compatibilidad
class DevelopmentHomeScreen extends StatelessWidget {
  final HealthService? healthService;

  const DevelopmentHomeScreen({super.key, this.healthService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NiñasPro Hub')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('EN DESARROLLO'),
            const SizedBox(height: 8),
            const Text('Plataforma en Construcción'),
            const SizedBox(height: 16),
            DbHealthChecker(healthService: healthService),
          ],
        ),
      ),
    );
  }
}
