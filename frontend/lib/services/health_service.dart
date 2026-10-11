import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

enum DbHealthState {
  checking,
  connected,
  unauthenticated, // Servidor responde pero falta anon_key
  error,
}

class DbHealthResult {
  final DbHealthState state;
  final int? latencyMs;
  final int? statusCode;
  final DateTime timestamp;
  final String message;
  final String endpoint;
  final String? details;

  const DbHealthResult({
    required this.state,
    this.latencyMs,
    this.statusCode,
    required this.timestamp,
    required this.message,
    required this.endpoint,
    this.details,
  });

  factory DbHealthResult.checking(String endpoint) {
    return DbHealthResult(
      state: DbHealthState.checking,
      timestamp: DateTime.now(),
      message: 'Comprobando conexión...',
      endpoint: endpoint,
    );
  }
}

class HealthService {
  final http.Client _client;

  HealthService({http.Client? client}) : _client = client ?? http.Client();

  /// Comprueba la conectividad de la base de datos Supabase
  Future<DbHealthResult> checkDatabaseHealth({
    String? supabaseUrl,
    String? anonKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final baseUrl = (supabaseUrl ?? AppConfig.supabaseUrl).replaceAll(RegExp(r'/+$'), '');
    final key = anonKey ?? AppConfig.supabaseAnonKey;
    final targetUrl = '$baseUrl${AppConfig.defaultHealthPath}';

    final stopwatch = Stopwatch()..start();

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
      };

      if (key.trim().isNotEmpty) {
        headers['apikey'] = key.trim();
        headers['Authorization'] = 'Bearer ${key.trim()}';
      }

      final response = await _client
          .get(Uri.parse(targetUrl), headers: headers)
          .timeout(timeout);

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final isCloud = baseUrl.contains('supabase.co');
        return DbHealthResult(
          state: DbHealthState.connected,
          latencyMs: latency,
          statusCode: response.statusCode,
          timestamp: DateTime.now(),
          message: isCloud ? 'Nube Supabase Conectada' : 'Base de datos local conectada',
          endpoint: targetUrl,
          details: 'Supabase BaaS / Base de datos respondiendo correctamente (HTTP ${response.statusCode})',
        );
      }
 else if (response.statusCode == 401 && key.trim().isEmpty) {
        return DbHealthResult(
          state: DbHealthState.unauthenticated,
          latencyMs: latency,
          statusCode: response.statusCode,
          timestamp: DateTime.now(),
          message: 'En línea (Requiere SUPABASE_ANON_KEY)',
          endpoint: targetUrl,
          details: 'El servicio Supabase responde, pero falta la clave anónima pública.',
        );
      } else {
        return DbHealthResult(
          state: DbHealthState.error,
          latencyMs: latency,
          statusCode: response.statusCode,
          timestamp: DateTime.now(),
          message: 'Error HTTP ${response.statusCode}',
          endpoint: targetUrl,
          details: response.body.isNotEmpty ? response.body : 'Sin respuesta detallada',
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      return DbHealthResult(
        state: DbHealthState.error,
        latencyMs: stopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
        message: 'Tiempo de espera agotado (> ${timeout.inSeconds}s)',
        endpoint: targetUrl,
        details: 'El servidor no respondió dentro del tiempo límite.',
      );
    } catch (e) {
      stopwatch.stop();
      return DbHealthResult(
        state: DbHealthState.error,
        latencyMs: stopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
        message: 'Fallo de conexión',
        endpoint: targetUrl,
        details: e.toString(),
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
