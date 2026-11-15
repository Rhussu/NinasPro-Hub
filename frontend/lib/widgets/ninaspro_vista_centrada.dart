import 'package:flutter/material.dart';

/// Centra el contenido de las vistas de Gestión, Tutora y Alumna: a pantalla
/// completa en el celular y con un ancho máximo legible en pantallas anchas.
class NinasProVistaCentrada extends StatelessWidget {
  static const anchoMaximo = 720.0;

  final Widget child;

  const NinasProVistaCentrada({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximo),
        child: child,
      ),
    );
  }
}
