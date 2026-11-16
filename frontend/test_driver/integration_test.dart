import 'package:integration_test/integration_test_driver.dart';

// Guarda en build/integration_response_data.json lo que la prueba deja en
// binding.reportData (tiempos de las tareas E2E).
Future<void> main() => integrationDriver();
