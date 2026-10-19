// Niñas Pro Hub · Tokens de color
//
// Base: paleta análoga (primary 294°, secondary 324°, accent 264°, saturación 50 %)
// + escalas semánticas + neutros teñidos hacia el lila.
//
// Reglas de uso (contrastes verificados con WCAG 2.1):
// - Texto blanco solo sobre los 700 y 900 (≥ 5,2:1). Nunca sobre los 500.
// - Chips/badges: texto 900 sobre fondo 100 de la misma familia (≥ 9,4:1).
// - Texto secundario: neutral500 (5,5:1 sobre blanco). neutral300 solo para
//   divisores decorativos; los bordes de campos de texto van en neutral500.
// - brandPink solo como relleno con texto neutral900 (7,5:1), nunca como texto.
// - Los colores semánticos (success, warning, error, info) solo se usan para
//   estados. No usarlos como decoración.

import 'package:flutter/material.dart';

abstract final class NinasProColors {
  // Primary · magenta suave (294°)
  static const primary900 = Color(0xFF441849);
  static const primary700 = Color(0xFF8B3295);
  static const primary500 = Color(0xFFC062CB);
  static const primary300 = Color(0xFFDFAFE4);
  static const primary100 = Color(0xFFF0D9F2);

  // Secondary · rosa suave (324°)
  static const secondary900 = Color(0xFF491835);
  static const secondary700 = Color(0xFF95326D);
  static const secondary500 = Color(0xFFCB62A1);
  static const secondary300 = Color(0xFFE4AFCF);
  static const secondary100 = Color(0xFFF2D9E8);

  // Accent · violeta suave (264°)
  static const accent900 = Color(0xFF2C1849);
  static const accent700 = Color(0xFF5A3295);
  static const accent500 = Color(0xFF8C62CB);
  static const accent300 = Color(0xFFC4AFE4);
  static const accent100 = Color(0xFFE3D9F2);

  // Success · presente, guardado, listo
  static const success900 = Color(0xFF104229);
  static const success700 = Color(0xFF1D7C4D);
  static const success500 = Color(0xFF27A566);
  static const success300 = Color(0xFF8BE4B8);
  static const success100 = Color(0xFFDEF7EB);

  // Warning · pendiente (evidencia, autorización, envío sin conexión)
  static const warning900 = Color(0xFF553607);
  static const warning700 = Color(0xFF975F0C);
  static const warning500 = Color(0xFFE28F12);
  static const warning300 = Color(0xFFF4C071);
  static const warning100 = Color(0xFFFCECD5);

  // Error · ausente, error, alerta de inasistencia
  static const error900 = Color(0xFF561015);
  static const error700 = Color(0xFFAB212A);
  static const error500 = Color(0xFFDA3E49);
  static const error300 = Color(0xFFEDA1A6);
  static const error100 = Color(0xFFF9E1E3);

  // Info · justificada, avisos informativos
  static const info900 = Color(0xFF0E2C4E);
  static const info700 = Color(0xFF1D5CA5);
  static const info500 = Color(0xFF2F7FDA);
  static const info300 = Color(0xFF97BFED);
  static const info100 = Color(0xFFDCEAF9);

  // Neutros teñidos (275°)
  static const neutral900 = Color(0xFF1A161D);
  static const neutral700 = Color(0xFF443A4A);
  static const neutral500 = Color(0xFF72637E);
  static const neutral300 = Color(0xFFAFA4B7);
  static const neutral100 = Color(0xFFE1DDE4);
  static const neutral50 = Color(0xFFF8F4FA); // fondo de la app

  // Superficies para modo oscuro
  static const dark900 = Color(0xFF1A161D);
  static const dark800 = Color(0xFF221D26);
  static const dark700 = Color(0xFF2A2430);
  static const dark600 = Color(0xFF332C3A);

  // Colores del sitio ninaspro.cl (acentos de identidad, usar con moderación)
  static const brandPink = Color(0xFFFF78CF);
  static const brandViolet = Color(0xFF3E1F8A);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Colors.transparent;

  // Aliases de conveniencia
  static const primary = primary700;
  static const secondary = secondary700;
  static const accent = accent700;
  static const success = success700;
  static const warning = warning700;
  static const error = error700;
  static const info = info700;
  static const background = neutral50;
  static const surface = white;
}
