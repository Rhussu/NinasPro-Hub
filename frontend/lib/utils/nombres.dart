// Comparación de nombres del catálogo (US-01).
//
// claveNombre replica la función SQL public.clave_nombre(): dos nombres con la
// misma clave son el mismo para la base y no se pueden repetir. nombresParecidos
// detecta los que no son iguales pero probablemente se refieren a lo mismo
// (un error de tipeo o el prefijo "Sede"), para avisar antes de guardar.

const _sinTilde = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

/// 'Sede San Joaquín' -> 'sedesanjoaquin': sin mayúsculas, tildes, espacios ni signos
String claveNombre(String texto) =>
    texto.toLowerCase().split('').map((c) => _sinTilde[c] ?? c).join().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Clave sin palabras genéricas del catálogo ("sede", "curso de")
String _claveNucleo(String texto) =>
    claveNombre(texto.replaceAll(RegExp(r'^\s*(sede|curso)(\s+de)?\s+', caseSensitive: false), ''));

/// Cantidad mínima de ediciones (insertar, borrar o cambiar una letra) entre [a] y [b]
int distanciaEdicion(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previa = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final actual = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final costo = a[i - 1] == b[j - 1] ? 0 : 1;
      actual[j] = [previa[j] + 1, actual[j - 1] + 1, previa[j - 1] + costo].reduce((x, y) => x < y ? x : y);
    }
    previa = actual;
  }
  return previa[b.length];
}

/// El nombre de [existentes] que la base consideraría igual a [nuevo], si lo hay
String? nombreRepetido(String nuevo, Iterable<String> existentes) {
  final clave = claveNombre(nuevo);
  if (clave.isEmpty) return null;
  for (final e in existentes) {
    if (claveNombre(e) == clave) return e;
  }
  return null;
}

/// Nombres de [existentes] distintos de [nuevo] pero muy parecidos: un error de
/// tipeo (1 letra de diferencia, o 2 desde 8 letras) o el mismo nombre con o
/// sin "Sede" adelante.
List<String> nombresParecidos(String nuevo, Iterable<String> existentes) {
  final clave = claveNombre(nuevo);
  final nucleo = _claveNucleo(nuevo);
  if (clave.length < 3) return const [];
  return [
    for (final e in existentes)
      if (claveNombre(e) != clave && _parecidos(nucleo, _claveNucleo(e))) e,
  ];
}

bool _parecidos(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  final largo = a.length < b.length ? a.length : b.length;
  final tolerancia = largo >= 8 ? 2 : (largo >= 4 ? 1 : 0);
  return distanciaEdicion(a, b) <= tolerancia;
}
