import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/ninaspro_mascot.dart';

/// Se muestra al abrir el enlace de recuperación: define la contraseña nueva
/// y, si la cuenta estaba bloqueada por intentos fallidos, la desbloquea (US-05, US-06).
class NuevaContrasenaScreen extends StatefulWidget {
  final AuthService authService;

  const NuevaContrasenaScreen({super.key, required this.authService});

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
    if (!_formKey.currentState!.validate()) return;
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: NinasProMascot(size: 80)),
                    const SizedBox(height: 16),
                    const Text('Crea tu contraseña nueva', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('Mínimo 10 caracteres, con mayúsculas, minúsculas y números.'),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    TextFormField(
                      controller: _contrasena,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(labelText: 'Contraseña nueva', prefixIcon: Icon(Icons.lock_rounded)),
                      validator: (v) => validarContrasena(v ?? ''),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmacion,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Repite la contraseña',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden.' : null,
                      onFieldSubmitted: (_) => _guardar(),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
