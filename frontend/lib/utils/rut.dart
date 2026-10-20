// Utilidades del RUT chileno (US-08).

/// Quita puntos, guion y espacios, y deja el DV en mayúscula: '12.345.678-k' -> '12345678K'
String normalizarRut(String rut) =>
    rut.replaceAll(RegExp(r'[.\-\s]'), '').toUpperCase();

/// Dígito verificador (módulo 11) del cuerpo numérico de un RUT
String calcularDvRut(String cuerpo) {
  var suma = 0;
  var multiplicador = 2;
  for (var i = cuerpo.length - 1; i >= 0; i--) {
    suma += int.parse(cuerpo[i]) * multiplicador;
    multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
  }
  final resto = 11 - (suma % 11);
  if (resto == 11) return '0';
  if (resto == 10) return 'K';
  return '$resto';
}

/// true si el RUT tiene formato válido y su dígito verificador cumple el módulo 11
bool validarRut(String rut) {
  final limpio = normalizarRut(rut);
  if (!RegExp(r'^\d{7,8}[0-9K]$').hasMatch(limpio)) return false;
  final cuerpo = limpio.substring(0, limpio.length - 1);
  return calcularDvRut(cuerpo) == limpio[limpio.length - 1];
}

/// Formato de presentación: '12345678K' -> '12.345.678-K'
String formatearRut(String rut) {
  final limpio = normalizarRut(rut);
  if (limpio.length < 2) return rut;
  final cuerpo = limpio.substring(0, limpio.length - 1);
  final dv = limpio[limpio.length - 1];
  final conPuntos = cuerpo.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return '$conPuntos-$dv';
}
