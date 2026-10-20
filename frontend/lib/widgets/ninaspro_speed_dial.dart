import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';

/// Sub-botón del Speed Dial de acciones rápidas.
class AccionRapida {
  final IconData icon;
  final String tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const AccionRapida({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });
}

/// FAB tipo Speed Dial: el rayito despliega hacia arriba los sub-botones (solo íconos).
class NinasProSpeedDial extends StatefulWidget {
  final List<AccionRapida> acciones;

  const NinasProSpeedDial({super.key, required this.acciones});

  @override
  State<NinasProSpeedDial> createState() => _NinasProSpeedDialState();
}

class _NinasProSpeedDialState extends State<NinasProSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _abierto = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _alternar() {
    setState(() => _abierto = !_abierto);
    _abierto ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.acciones.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Sub-botones: aparecen escalonados de abajo hacia arriba
        for (var i = 0; i < total; i++)
          Builder(builder: (context) {
            final accion = widget.acciones[i];
            final orden = total - 1 - i;
            final animacion = CurvedAnimation(
              parent: _controller,
              curve: Interval(orden * 0.15, 1.0, curve: Curves.easeOutBack),
            );
            return IgnorePointer(
              ignoring: !_abierto,
              child: FadeTransition(
                opacity: _controller,
                child: ScaleTransition(
                  scale: animacion,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FloatingActionButton.small(
                      heroTag: null,
                      tooltip: accion.tooltip,
                      backgroundColor: accion.backgroundColor,
                      foregroundColor: accion.foregroundColor,
                      onPressed: () {
                        _alternar();
                        accion.onTap();
                      },
                      child: Icon(accion.icon),
                    ),
                  ),
                ),
              ),
            );
          }),
        FloatingActionButton(
          heroTag: null,
          tooltip: _abierto ? 'Cerrar acciones rápidas' : 'Acciones rápidas',
          backgroundColor: NinasProColors.brandPink,
          foregroundColor: NinasProColors.neutral900,
          onPressed: _alternar,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              _abierto ? Icons.close_rounded : Icons.bolt_rounded,
              key: ValueKey(_abierto),
            ),
          ),
        ),
      ],
    );
  }
}
