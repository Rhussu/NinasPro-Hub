import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/utils/rut.dart';

void main() {
  group('RUT chileno (US-08)', () {
    test('valida el dígito verificador con módulo 11', () {
      expect(validarRut('22.341.890-2'), isTrue);
      expect(validarRut('21.998.765-k'), isTrue);
      expect(validarRut('22341890-1'), isFalse);
      expect(validarRut('abc'), isFalse);
      expect(formatearRut('219987651'), '21.998.765-1');
      expect(normalizarRut('21.998.765-k'), '21998765K');
    });
  });
}
