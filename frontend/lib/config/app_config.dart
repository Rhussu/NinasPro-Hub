import 'package:flutter/foundation.dart';

class AppConfig {
  /// URL de desarrollo local de Supabase CLI (Docker)
  static const String localSupabaseUrl = 'http://127.0.0.1:54321';

  /// Clave anon pública predeterminada de Supabase CLI local (Dummy local key)
  static const String localAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  /// Path del endpoint de salud estándar en Supabase
  static const String defaultHealthPath = '/auth/v1/health';

  /// Resuelve la URL de Supabase de forma segura sin exponer credenciales:
  /// 1. Prioriza variable inyectada vía --dart-define=SUPABASE_URL=...
  /// 2. En modo Debug (desarrollo local), usa localSupabaseUrl (http://127.0.0.1:54321)
  /// 3. En modo Release, devuelve la variable inyectada o cadena vacía si no se configuró.
  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return kDebugMode ? localSupabaseUrl : '';
  }

  /// Resuelve la clave anónima de Supabase de forma segura:
  /// 1. Prioriza variable inyectada vía --dart-define=SUPABASE_ANON_KEY=...
  /// 2. En modo Debug (desarrollo local), usa localAnonKey
  /// 3. En modo Release, devuelve la variable inyectada o cadena vacía si no se configuró.
  static String get supabaseAnonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return kDebugMode ? localAnonKey : '';
  }
}
