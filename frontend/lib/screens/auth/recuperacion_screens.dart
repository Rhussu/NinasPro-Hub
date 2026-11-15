import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../services/auth_service.dart';
import 'acceso_screen.dart';

/// Estructura común de las pantallas de recuperación de contraseña.
class _PantallaRecuperacion extends StatelessWidget {
  final String titulo;
  final String texto;
  final List<Widget> children;
  final bool cargando;

  const _PantallaRecuperacion({
    required this.titulo,
    required this.texto,
    this.children = const [],
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EncabezadoAcceso(tamanoMascota: 80),
                  Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    texto,
                    style: TextStyle(fontSize: 14, height: 1.4, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                  ),
                  if (cargando) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _botonCancelar(AuthService auth, {String texto = 'Cancelar y volver al inicio'}) => TextButton(
      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: auth.cancelarRecuperacion,
      child: Text(texto),
    );

/// Pestaña donde se pidió el correo: queda esperando que se abra el enlace.
class CorreoEnviadoScreen extends StatelessWidget {
  final AuthService authService;
  final String? correo;

  const CorreoEnviadoScreen({super.key, required this.authService, this.correo});

  @override
  Widget build(BuildContext context) {
    return _PantallaRecuperacion(
      titulo: 'Revisa tu correo',
      texto: 'Si ${correo ?? 'el correo'} tiene una cuenta, le enviamos un enlace para crear una contraseña nueva. '
          'Ábrelo y elige si quieres cambiarla en esa pestaña o volver a esta.',
      cargando: true,
      children: [_botonCancelar(authService, texto: 'Volver al inicio')],
    );
  }
}

/// Pestaña abierta desde el enlace del correo: elige dónde cambiar la contraseña.
class EnlaceRecuperacionScreen extends StatefulWidget {
  final AuthService authService;
  final String? correo;
  final bool otraPestanaDisponible;

  const EnlaceRecuperacionScreen({
    super.key,
    required this.authService,
    this.correo,
    this.otraPestanaDisponible = false,
  });

  @override
  State<EnlaceRecuperacionScreen> createState() => _EnlaceRecuperacionScreenState();
}

class _EnlaceRecuperacionScreenState extends State<EnlaceRecuperacionScreen> {
  bool _enviando = false;
  String? _error;

  Future<void> _enOtraPestana() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    final r = await widget.authService.cambiarContrasenaEnOtraPestana();
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (!r.ok) _error = r.mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaRecuperacion(
      titulo: 'Crea tu contraseña nueva',
      texto: widget.otraPestanaDisponible
          ? 'Puedes cambiarla aquí o en la pestaña donde pediste el correo.'
          : 'Vamos a cambiar la contraseña${widget.correo == null ? '' : ' de ${widget.correo}'} en esta pestaña.',
      children: [
        if (_error != null) AvisoAcceso(texto: _error!, esError: true),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _enviando ? null : widget.authService.cambiarContrasenaAqui,
            child: const Text('Cambiarla aquí', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        if (widget.otraPestanaDisponible) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _enviando ? null : _enOtraPestana,
              child: const Text('Cambiarla en la pestaña donde la pedí'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _botonCancelar(widget.authService),
      ],
    );
  }
}

/// Otra pestaña está cambiando la contraseña; esta espera y entra sola al terminar.
class EsperandoOtraPestanaScreen extends StatelessWidget {
  final AuthService authService;

  /// Esta es la pestaña del enlace (la otra es donde se pidió el correo)
  final bool soyPestanaDelEnlace;

  const EsperandoOtraPestanaScreen({super.key, required this.authService, this.soyPestanaDelEnlace = false});

  @override
  Widget build(BuildContext context) {
    if (soyPestanaDelEnlace) {
      return _PantallaRecuperacion(
        titulo: 'Continúa en la otra pestaña',
        texto: 'Cambia la contraseña en la pestaña donde pediste el correo. Puedes cerrar esta pestaña.',
        cargando: true,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: authService.cambiarContrasenaAqui,
            child: const Text('Prefiero cambiarla aquí'),
          ),
          const SizedBox(height: 12),
          _botonCancelar(authService),
        ],
      );
    }
    return _PantallaRecuperacion(
      titulo: 'Esperando mientras cambias la contraseña…',
      texto: 'Abriste el enlace en otra pestaña. Cuando guardes la contraseña nueva, esta pantalla entrará sola.',
      cargando: true,
      children: [_botonCancelar(authService)],
    );
  }
}
