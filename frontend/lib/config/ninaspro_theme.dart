// Niñas Pro Hub · Tema de Material 3 (claro y oscuro)
//
// Uso en main.dart:
//   MaterialApp(
//     theme: NinasProTheme.light,
//     darkTheme: NinasProTheme.dark,
//     themeMode: ThemeMode.system, // o ThemeMode.light / ThemeMode.dark
//     ...
//   );
//
// Colores de estado en un widget:
//   final tono = context.statusColors.asistencia(EstadoAsistencia.ausente);
//   // o mediante Theme.of(context).extension<StatusColors>()!.asistencia(...)
//   Container(
//     decoration: tono.decoration,
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(EstadoAsistencia.ausente.icon, size: 16, color: tono.foreground),
//         const SizedBox(width: 6),
//         Text(EstadoAsistencia.ausente.label, style: tono.textStyle()),
//       ],
//     ),
//   );
//
// Regla de accesibilidad (WCAG 2.1 / RNF-U-1):
// - Acompañar siempre el color con ícono y texto para no depender solo del color.
// - Botones y elementos interactivos táctiles con área táctil accesible (≥ 48 px de alto).

import 'package:flutter/material.dart';

import 'ninaspro_colors.dart';

typedef C = NinasProColors;

/// Estados del pase de asistencia escolar en Niñas Pro Hub.
enum EstadoAsistencia {
  presente,
  ausente,
  justificada,
  pendiente;

  String get label => switch (this) {
        EstadoAsistencia.presente => 'Presente',
        EstadoAsistencia.ausente => 'Ausente',
        EstadoAsistencia.justificada => 'Justificada',
        EstadoAsistencia.pendiente => 'Pendiente',
      };

  IconData get icon => switch (this) {
        EstadoAsistencia.presente => Icons.check_circle_outline_rounded,
        EstadoAsistencia.ausente => Icons.cancel_outlined,
        EstadoAsistencia.justificada => Icons.info_outline_rounded,
        EstadoAsistencia.pendiente => Icons.schedule_rounded,
      };
}

/// Par de colores para un estado: texto/ícono (foreground) y relleno (background).
@immutable
class StatusTone {
  const StatusTone({required this.foreground, required this.background});

  final Color foreground;
  final Color background;

  /// Decoración rápida para contenedores y chips de estado
  BoxDecoration get decoration => BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      );

  /// Estilo de texto con el color de contraste garantizado
  TextStyle textStyle({
    FontWeight fontWeight = FontWeight.w600,
    double fontSize = 13,
  }) =>
      TextStyle(
        color: foreground,
        fontWeight: fontWeight,
        fontSize: fontSize,
      );

  static StatusTone lerp(StatusTone a, StatusTone b, double t) => StatusTone(
        foreground: Color.lerp(a.foreground, b.foreground, t)!,
        background: Color.lerp(a.background, b.background, t)!,
      );
}

/// Colores semánticos que Material 3 no trae de forma nativa (éxito, advertencia, info).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  final StatusTone success;
  final StatusTone warning;
  final StatusTone error;
  final StatusTone info;

  StatusTone asistencia(EstadoAsistencia estado) => switch (estado) {
        EstadoAsistencia.presente => success,
        EstadoAsistencia.ausente => error,
        EstadoAsistencia.justificada => info,
        EstadoAsistencia.pendiente => warning,
      };

  static const light = StatusColors(
    success: StatusTone(foreground: C.success900, background: C.success100),
    warning: StatusTone(foreground: C.warning900, background: C.warning100),
    error: StatusTone(foreground: C.error900, background: C.error100),
    info: StatusTone(foreground: C.info900, background: C.info100),
  );

  static const dark = StatusColors(
    success: StatusTone(foreground: C.success300, background: C.success900),
    warning: StatusTone(foreground: C.warning300, background: C.warning900),
    error: StatusTone(foreground: C.error300, background: C.error900),
    info: StatusTone(foreground: C.info300, background: C.info900),
  );

  @override
  StatusColors copyWith({
    StatusTone? success,
    StatusTone? warning,
    StatusTone? error,
    StatusTone? info,
  }) =>
      StatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        info: info ?? this.info,
      );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: StatusTone.lerp(success, other.success, t),
      warning: StatusTone.lerp(warning, other.warning, t),
      error: StatusTone.lerp(error, other.error, t),
      info: StatusTone.lerp(info, other.info, t),
    );
  }
}

/// Definición central del tema Material 3 para Niñas Pro Hub.
abstract final class NinasProTheme {
  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: C.primary700,
    onPrimary: C.white,
    primaryContainer: C.primary100,
    onPrimaryContainer: C.primary900,
    secondary: C.secondary700,
    onSecondary: C.white,
    secondaryContainer: C.secondary100,
    onSecondaryContainer: C.secondary900,
    tertiary: C.accent700,
    onTertiary: C.white,
    tertiaryContainer: C.accent100,
    onTertiaryContainer: C.accent900,
    error: C.error700,
    onError: C.white,
    errorContainer: C.error100,
    onErrorContainer: C.error900,
    surface: C.white,
    onSurface: C.neutral900,
    onSurfaceVariant: C.neutral700,
    surfaceContainerLowest: C.white,
    surfaceContainerLow: C.neutral50,
    surfaceContainer: C.neutral50,
    surfaceContainerHigh: C.neutral100,
    surfaceContainerHighest: C.neutral100,
    outline: C.neutral500,
    outlineVariant: C.neutral100,
    inverseSurface: C.neutral900,
    onInverseSurface: C.neutral50,
    inversePrimary: C.primary300,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: C.primary300,
    onPrimary: C.primary900,
    primaryContainer: C.primary700,
    onPrimaryContainer: C.primary100,
    secondary: C.secondary300,
    onSecondary: C.secondary900,
    secondaryContainer: C.secondary700,
    onSecondaryContainer: C.secondary100,
    tertiary: C.accent300,
    onTertiary: C.accent900,
    tertiaryContainer: C.accent700,
    onTertiaryContainer: C.accent100,
    error: C.error300,
    onError: C.error900,
    errorContainer: C.error700,
    onErrorContainer: C.error100,
    surface: C.dark900,
    onSurface: C.neutral100,
    onSurfaceVariant: C.neutral300,
    surfaceContainerLowest: C.dark900,
    surfaceContainerLow: C.dark800,
    surfaceContainer: C.dark800,
    surfaceContainerHigh: C.dark700,
    surfaceContainerHighest: C.dark600,
    outline: C.neutral300,
    outlineVariant: C.neutral700,
    inverseSurface: C.neutral100,
    onInverseSurface: C.neutral900,
    inversePrimary: C.primary700,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static ThemeData get light => _build(lightScheme, StatusColors.light, C.neutral50);

  static ThemeData get dark => _build(darkScheme, StatusColors.dark, C.dark900);

  static ThemeData _build(ColorScheme scheme, StatusColors status, Color background) {
    final isLight = scheme.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      extensions: [status],

      // Barra superior estándar de la app
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? C.white : C.dark800,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      // Tarjetas adaptadas al diseño
      cardTheme: CardThemeData(
        color: isLight ? C.white : C.dark800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isLight ? C.neutral100 : C.dark700,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Botones con área táctil accesible RNF-U-1 (≥ 48 px de alto)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Campos de formulario y entrada de datos
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? C.white : C.dark800,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        hintStyle: TextStyle(
          color: isLight ? C.neutral500 : C.neutral300,
          fontSize: 14,
        ),
      ),

      // Chips y etiquetas
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),

      // Divisores sutiles
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Mensajes flotantes (SnackBar)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Botón de acción flotante (FAB)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Botón de identidad (rosa del sitio con texto oscuro, como "Donar" en ninaspro.cl).
  /// Usar solo para la acción principal de una pantalla, por ejemplo "Guardar asistencia".
  static ButtonStyle brandButton = FilledButton.styleFrom(
    backgroundColor: C.brandPink,
    foregroundColor: C.neutral900,
    minimumSize: const Size(64, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
  );
}

/// Extensiones de conveniencia sobre [BuildContext] para acceso rápido y tipado.
extension NinasProThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ?? StatusColors.light;
}

/// Extensión de conveniencia sobre [ThemeData] para acceder a los colores de estado.
extension NinasProThemeData on ThemeData {
  StatusColors get statusColors =>
      extension<StatusColors>() ?? StatusColors.light;
}
