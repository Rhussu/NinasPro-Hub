import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/utils/nombres.dart';

void main() {
  test('la clave ignora mayúsculas, tildes, espacios y signos como la base', () {
    expect(claveNombre(' Sede  San Joaquín. '), 'sedesanjoaquin');
    expect(claveNombre('Ñuñoa Ç'), 'nunoac');
    expect(claveNombre('PCB-2026'), 'pcb2026');
    expect(claveNombre('...'), isEmpty);
  });

  test('detecta el nombre que la base consideraría repetido', () {
    final sedes = ['Sede Valparaíso', 'Sede Beauchef'];
    expect(nombreRepetido('sede valparaiso', sedes), 'Sede Valparaíso');
    expect(nombreRepetido('Sede Valparaíso.', sedes), 'Sede Valparaíso');
    expect(nombreRepetido('Sede Viña del Mar', sedes), isNull);
    expect(nombreRepetido('  ', sedes), isNull);
  });

  test('avisa por errores de tipeo y por el prefijo "Sede"', () {
    final sedes = ['Sede Concepción', 'Sede Beauchef', 'Sede San Joaquín', 'Sede Talca'];
    expect(nombresParecidos('Sede Concepcón', sedes), ['Sede Concepción']);
    expect(nombresParecidos('Concepción', sedes), ['Sede Concepción']);
    expect(nombresParecidos('Sede San Joakin', sedes), ['Sede San Joaquín']);
    expect(nombresParecidos('Sede Talcahuano', sedes), isEmpty);
    expect(nombresParecidos('Sede Temuco', sedes), isEmpty);
    // El mismo nombre no es "parecido": ese caso lo cubre nombreRepetido
    expect(nombresParecidos('sede concepcion', sedes), isEmpty);
    expect(nombresParecidos('ab', sedes), isEmpty);
  });

  test('la distancia de edición cuenta inserciones, borrados y cambios', () {
    expect(distanciaEdicion('concepcion', 'concepcion'), 0);
    expect(distanciaEdicion('concepcion', 'concepcon'), 1);
    expect(distanciaEdicion('talca', 'talcahuano'), 5);
    expect(distanciaEdicion('', 'abc'), 3);
    expect(distanciaEdicion('abc', ''), 3);
    expect(distanciaEdicion('gato', 'pato'), 1);
  });
}
