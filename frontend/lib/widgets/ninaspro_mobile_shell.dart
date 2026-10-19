import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';

/// Contenedor responsivo que asegura una experiencia **100% Mobile-First**.
///
/// Si la pantalla es de teléfono (< 600 px), ocupa todo el ancho de forma fluida.
/// Si se visualiza desde un navegador de escritorio (>= 600 px), enmarca la vista
/// en un smartphone estilizado con bordes redondeados y sombra para que los stakeholders
/// experimenten exactamente cómo funciona en un celular de 390 px de ancho.
class NinasProMobileShell extends StatefulWidget {
  final Widget child;

  const NinasProMobileShell({
    super.key,
    required this.child,
  });

  @override
  State<NinasProMobileShell> createState() => _NinasProMobileShellState();
}

class _NinasProMobileShellState extends State<NinasProMobileShell> {
  bool _forceMobileFrame = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        if (!isDesktop || !_forceMobileFrame) {
          return widget.child;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? NinasProColors.dark900 : NinasProColors.neutral100,
          body: Stack(
            children: [
              // Fondo de ambientación en desktop con gradientes sutiles
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        NinasProColors.primary700.withValues(alpha: isDark ? 0.20 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Dispositivo móvil centrado
              Center(
                child: Container(
                  width: 420,
                  height: constraints.maxHeight * 0.96,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: isDark ? NinasProColors.dark700 : NinasProColors.neutral300,
                      width: 8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        // Dynamic Island / Bocina superior decorativa
                        Container(
                          width: double.infinity,
                          height: 24,
                          color: Theme.of(context).appBarTheme.backgroundColor ??
                              (isDark ? NinasProColors.dark800 : NinasProColors.white),
                          alignment: Alignment.center,
                          child: Container(
                            width: 70,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // Contenido de la app móvil
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                ),
              ),

              // Botón flotante para alternar vista móvil / pantalla completa en desktop
              Positioned(
                top: 16,
                right: 16,
                child: Tooltip(
                  message: 'Alternar vista completa / teléfono',
                  child: FloatingActionButton.small(
                    heroTag: 'toggle_desktop_frame',
                    backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
                    foregroundColor: isDark ? NinasProColors.neutral100 : NinasProColors.neutral900,
                    onPressed: () {
                      setState(() {
                        _forceMobileFrame = !_forceMobileFrame;
                      });
                    },
                    child: Icon(
                      _forceMobileFrame ? Icons.fullscreen_rounded : Icons.phone_android_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
