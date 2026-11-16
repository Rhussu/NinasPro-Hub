import 'package:flutter/services.dart';

import 'rut.dart';

/// Da formato al RUT mientras se escribe: '123456785' -> '12.345.678-5'.
///
/// Solo acepta dígitos y una K final como dígito verificador, con un máximo de
/// 9 caracteres. El cursor se mantiene junto al mismo carácter aunque cambien los
/// puntos y el guion, y al borrar un separador se borra el dígito anterior.
class RutInputFormatter extends TextInputFormatter {
  static const _maxCaracteres = 9;

  const RutInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var texto = newValue.text;
    var cursor = newValue.selection.isValid ? newValue.selection.end : texto.length;

    // Se borró solo un punto o el guion: se borra también el dígito anterior
    final borroSeparador = texto.length == oldValue.text.length - 1 &&
        _significativos(texto) == _significativos(oldValue.text);
    if (borroSeparador) {
      final previo = _ultimoSignificativoAntes(texto, cursor);
      if (previo >= 0) {
        texto = texto.substring(0, previo) + texto.substring(previo + 1);
        cursor = previo;
      }
    }

    final antesDelCursor = _limpiar(texto.substring(0, cursor.clamp(0, texto.length))).length;
    final limpio = _limpiar(texto);
    final formateado = limpio.length < 2 ? limpio : formatearRut(limpio);

    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(
        offset: _posicionTras(formateado, antesDelCursor.clamp(0, limpio.length)),
      ),
    );
  }

  /// Deja solo dígitos y, como último carácter, una K; recorta a 9 caracteres
  static String _limpiar(String texto) {
    final caracteres = texto.toUpperCase().replaceAll(RegExp(r'[^0-9K]'), '');
    final soloK = caracteres.replaceAll(RegExp(r'K(?=.)'), '');
    return soloK.length > _maxCaracteres ? soloK.substring(0, _maxCaracteres) : soloK;
  }

  static String _significativos(String texto) =>
      texto.toUpperCase().replaceAll(RegExp(r'[^0-9K]'), '');

  static int _ultimoSignificativoAntes(String texto, int cursor) {
    for (var i = cursor.clamp(0, texto.length) - 1; i >= 0; i--) {
      if (RegExp(r'[0-9kK]').hasMatch(texto[i])) return i;
    }
    return -1;
  }

  /// Posición en el texto formateado justo después de [n] caracteres significativos
  static int _posicionTras(String formateado, int n) {
    if (n == 0) return 0;
    var vistos = 0;
    for (var i = 0; i < formateado.length; i++) {
      if (RegExp(r'[0-9K]').hasMatch(formateado[i])) vistos++;
      if (vistos == n) return i + 1;
    }
    return formateado.length;
  }
}
