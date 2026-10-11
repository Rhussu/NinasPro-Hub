import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninas_pro_hub/config/app_config.dart';
import 'package:ninas_pro_hub/services/health_service.dart';

void main() {
  group('HealthService tests', () {
    test('returns connected when HTTP 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"status": "ok"}', 200);
      });

      final service = HealthService(client: mockClient);
      final result = await service.checkDatabaseHealth(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      expect(result.state, DbHealthState.connected);
      expect(result.statusCode, 200);
      expect(result.message, contains('Conectada'));
      expect(result.latencyMs, isNotNull);
      service.dispose();
    });

    test('returns unauthenticated when HTTP 401 and empty anonKey', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"message":"No API key found in request"}', 401);
      });

      final service = HealthService(client: mockClient);
      final result = await service.checkDatabaseHealth(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: '',
      );

      expect(result.state, DbHealthState.unauthenticated);
      expect(result.statusCode, 401);
      expect(result.message, contains('Requiere SUPABASE_ANON_KEY'));
    });

    test('returns error when HTTP 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = HealthService(client: mockClient);
      final result = await service.checkDatabaseHealth(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'key',
      );

      expect(result.state, DbHealthState.error);
      expect(result.statusCode, 500);
      expect(result.message, 'Error HTTP 500');
    });

    test('returns error on timeout', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response('ok', 200);
      });

      final service = HealthService(client: mockClient);
      final result = await service.checkDatabaseHealth(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'key',
        timeout: const Duration(milliseconds: 10),
      );

      expect(result.state, DbHealthState.error);
      expect(result.message, contains('Tiempo de espera agotado'));
    });

    test('returns error on client exception', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable');
      });

      final service = HealthService(client: mockClient);
      final result = await service.checkDatabaseHealth(
        supabaseUrl: 'https://test.supabase.co',
        anonKey: 'key',
      );

      expect(result.state, DbHealthState.error);
      expect(result.message, 'Fallo de conexión');
      expect(result.details, contains('Network unreachable'));
    });

    test('DbHealthResult.checking factory initializes properly', () {
      final result = DbHealthResult.checking('https://example.com');
      expect(result.state, DbHealthState.checking);
      expect(result.endpoint, 'https://example.com');
    });

    test('AppConfig has expected defaults', () {
      expect(AppConfig.supabaseUrl, isNotEmpty);
      expect(AppConfig.supabaseAnonKey, isNotEmpty);
      expect(AppConfig.defaultHealthPath, '/auth/v1/health');
    });
  });
}
