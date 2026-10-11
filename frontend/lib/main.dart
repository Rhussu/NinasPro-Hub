import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
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

class NinasProApp extends StatelessWidget {
  final HealthService? healthService;

  const NinasProApp({super.key, this.healthService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NiñasPro Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B2CBF),
          primary: const Color(0xFF7B2CBF),
          secondary: const Color(0xFF9D4EDD),
          surface: const Color(0xFFFAF8FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF8FF),
      ),
      home: DevelopmentHomeScreen(healthService: healthService),
    );
  }
}

class DevelopmentHomeScreen extends StatelessWidget {
  final HealthService? healthService;

  const DevelopmentHomeScreen({super.key, this.healthService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('💜', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            const Text(
              'NiñasPro Hub',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: Color(0xFF240046),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'v0.1.0',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6D28D9),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background subtle gradient glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC77DFF).withValues(alpha: 0.15),
                    const Color(0xFFFAF8FF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B2CBF).withValues(alpha: 0.1),
                    const Color(0xFFFAF8FF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Central content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Badge En Desarrollo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.construction_rounded, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 6),
                          Text(
                            'EN DESARROLLO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Central Glowing Icon Container
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B2CBF).withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      'Plataforma en Construcción',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1035),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'Estamos construyendo el nuevo NiñasPro Hub para la gestión integral de talleres, asistencia académica, voluntariado y seguimiento estudiantil.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Status Cards Grid
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: const [
                        _FeaturePill(icon: Icons.school_rounded, label: 'Talleres & Sedes'),
                        _FeaturePill(icon: Icons.how_to_reg_rounded, label: 'Asistencia Digital'),
                        _FeaturePill(icon: Icons.groups_rounded, label: 'Red de Tutoras'),
                        _FeaturePill(icon: Icons.security_rounded, label: 'PostgreSQL + RLS'),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Footer note
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(Icons.favorite_rounded, size: 14, color: Colors.purple.shade400),
                        const SizedBox(width: 6),
                        Text(
                          'NiñasPro • Empoderando a niñas y jóvenes en tecnología',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom-Right Healthchecker Widget
          Positioned(
            bottom: 20,
            right: 20,
            child: DbHealthChecker(healthService: healthService),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7B2CBF)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF240046),
            ),
          ),
        ],
      ),
    );
  }
}
