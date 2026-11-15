import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'acceso_screen.dart';

/// Formulario de contraseña nueva, después de verificar el código del correo.
/// Al guardarla la cuenta se desbloquea y recién ahí se entra a la app (US-05, US-06).
class NuevaContrasenaScreen extends StatefulWidget {
  final AuthService authService;
  final String? correo;

  const NuevaContrasenaScreen({super.key, required this.authService, this.correo});

  @override
  State<NuevaContrasenaScreen> createState() => _NuevaContrasenaScreenState();
}

class _NuevaContrasenaScreenState extends State<NuevaContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final r = await widget.authService.actualizarContrasena(contrasena: _contrasena.text);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (!r.ok) _error = r.mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const EncabezadoAcceso(tamanoMascota: 80),
                      const Text('Crea tu contraseña nueva', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.correo == null ? '' : 'Cuenta: ${widget.correo}. '}'
                        'Mínimo 10 caracteres, con mayúsculas, minúsculas y números.',
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) AvisoAcceso(texto: _error!, esError: true),
                      CampoContrasena(
                        controller: _contrasena,
                        etiqueta: 'Contraseña nueva',
                        autofillHint: AutofillHints.newPassword,
                        textInputAction: TextInputAction.next,
                        validator: (v) => validarContrasena(v ?? ''),
                      ),
                      const SizedBox(height: 14),
                      CampoContrasena(
                        controller: _confirmacion,
                        etiqueta: 'Repite la contraseña',
                        autofillHint: AutofillHints.newPassword,
                        validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden.' : null,
                        onSubmitted: _guardar,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _enviando ? null : _guardar,
                          child: _enviando
                              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Text('Guardar contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _enviando ? null : widget.authService.cancelarRecuperacion,
                        child: const Text('Cancelar y volver al inicio'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
