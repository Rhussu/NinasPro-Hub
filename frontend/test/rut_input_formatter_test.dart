import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninas_pro_hub/utils/rut_input_formatter.dart';

const _formateador = RutInputFormatter();

/// Simula escribir [texto] carácter a carácter al final del campo
TextEditingValue _escribir(String texto, [TextEditingValue inicial = TextEditingValue.empty]) {
  var valor = inicial;
  for (final c in texto.split('')) {
    final nuevoTexto = valor.text + c;
    valor = _formateador.formatEditUpdate(
      valor,
      TextEditingValue(text: nuevoTexto, selection: TextSelection.collapsed(offset: nuevoTexto.length)),
    );
  }
  return valor;
}

/// Simula presionar retroceso con el cursor al final
TextEditingValue _borrar(TextEditingValue valor) {
  final nuevoTexto = valor.text.substring(0, valor.text.length - 1);
  return _formateador.formatEditUpdate(
    valor,
    TextEditingValue(text: nuevoTexto, selection: TextSelection.collapsed(offset: nuevoTexto.length)),
  );
}

void main() {
  group('RutInputFormatter', () {
    test('da formato progresivo mientras se escribe', () {
      expect(_escribir('1').text, '1');
      expect(_escribir('12').text, '1-2');
      expect(_escribir('12345').text, '1.234-5');
      expect(_escribir('123456785').text, '12.345.678-5');
      expect(_escribir('76543210k').text, '76.543.210-K');
    });

    test('ignora caracteres no válidos y recorta a 9 caracteres', () {
      expect(_escribir('12.345.678-5').text, '12.345.678-5');
      expect(_escribir('12a34x5').text, '1.234-5');
      expect(_escribir('1234567890').text, '12.345.678-9');
    });

    test('solo acepta la K como dígito verificador', () {
      expect(_escribir('12K3').text, '12-3');
    });

    test('da formato a un RUT pegado y deja el cursor al final', () {
      final valor = _formateador.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12345678-5', selection: TextSelection.collapsed(offset: 10)),
      );
      expect(valor.text, '12.345.678-5');
      expect(valor.selection.end, valor.text.length);
    });

    test('al borrar el guion también borra el dígito anterior', () {
      // '1.234-5' -> borrar '5' -> '123-4'
      var valor = _borrar(_escribir('12345'));
      expect(valor.text, '123-4');
      // Borrar con el cursor justo después del guion
      final conGuion = TextEditingValue(
        text: valor.text,
        selection: const TextSelection.collapsed(offset: 4),
      );
      valor = _formateador.formatEditUpdate(
        conGuion,
        const TextEditingValue(text: '1234', selection: TextSelection.collapsed(offset: 3)),
      );
      expect(valor.text, '12-4');
      expect(valor.selection.end, 2);
    });

    testWidgets('formatea el texto dentro de un TextField', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TextField(controller: controller, inputFormatters: const [RutInputFormatter()]),
        ),
      ));
      await tester.enterText(find.byType(TextField), '123456785');
      expect(controller.text, '12.345.678-5');
    });
  });
}
