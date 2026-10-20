import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';

/// Esqueleto de carga de una pantalla de inicio: bloques grises que pulsan
/// mientras se recargan los datos (al abrir la pantalla o al deslizar para recargar).
///
/// [filas] describe la forma de la pantalla: cada fila es la lista de alturas de sus
/// tarjetas (una tarjeta ocupa todo el ancho; dos se reparten la fila).
class NinasProSkeletonInicio extends StatefulWidget {
  final List<List<double>> filas;

  /// Forma de la pantalla de inicio de Tutora y Gestión
  static const filasTutora = [
    [190.0],
    [130.0, 130.0],
    [78.0],
    [120.0],
    [90.0],
  ];

  /// Forma del portal de la alumna
  static const filasAlumna = [
    [230.0],
    [120.0],
    [160.0],
    [120.0, 120.0],
  ];

  const NinasProSkeletonInicio({super.key, this.filas = filasTutora});

  @override
  State<NinasProSkeletonInicio> createState() => _NinasProSkeletonInicioState();
}

class _NinasProSkeletonInicioState extends State<NinasProSkeletonInicio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final claro = isDark ? NinasProColors.dark800 : NinasProColors.neutral100;
    final oscuro = isDark ? NinasProColors.dark700 : NinasProColors.neutral300.withValues(alpha: 0.5);

    return Semantics(
      label: 'Cargando',
      // Desplazable para que el RefreshIndicator siga funcionando mientras carga
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          for (final fila in widget.filas)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  for (var i = 0; i < fila.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _pulso,
                        builder: (context, _) => Container(
                          height: fila[i],
                          decoration: BoxDecoration(
                            color: Color.lerp(claro, oscuro, _pulso.value),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
