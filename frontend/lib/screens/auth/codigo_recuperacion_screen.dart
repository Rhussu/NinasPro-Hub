import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/ninaspro_colors.dart';
import '../../services/auth_service.dart';
import 'acceso_screen.dart';

/// Se pidió recuperar la contraseña: se ingresa aquí el código que llegó al
/// correo, en la misma pantalla donde se pidió (US-05, US-06).
class CodigoRecuperacionScreen extends StatefulWidget {
  final AuthService authService;
  final String? correo;

  const CodigoRecuperacionScreen({super.key, required this.authService, this.correo});

  @override
  State<CodigoRecuperacionScreen> createState() => _CodigoRecuperacionScreenState();
}

class _CodigoRecuperacionScreenState extends State<CodigoRecuperacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  bool _enviando = false;
  String? _error;
  String? _exito;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
      _exito = null;
    });
    final r = await widget.authService.verificarCodigo(codigo: _codigo.text);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (!r.ok) _error = r.mensaje;
    });
  }

  Future<void> _reenviar() async {
    final correo = widget.correo;
    if (_enviando || correo == null) return;
    setState(() {
      _enviando = true;
      _error = null;
      _exito = null;
    });
    final r = await widget.authService.enviarRecuperacion(correo: correo);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (r.ok) {
        _codigo.clear();
        _exito = 'Te enviamos un código nuevo. El anterior ya no sirve.';
      } else {
        _error = r.mensaje;
      }
    });
  }

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
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const EncabezadoAcceso(tamanoMascota: 80),
                      const Text('Revisa tu correo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        'Si ${widget.correo ?? 'el correo'} tiene una cuenta, le enviamos un código de $largoCodigo números. '
                        'Ingrésalo aquí para crear tu contraseña nueva.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) AvisoAcceso(texto: _error!, esError: true),
                      if (_exito != null) AvisoAcceso(texto: _exito!, esError: false),
                      TextFormField(
                        controller: _codigo,
                        autofocus: true,
                        enabled: !_enviando,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        // Se admiten espacios para pegar el código tal como viene en el correo
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                          LengthLimitingTextInputFormatter(largoCodigo + 2),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
                        decoration: const InputDecoration(labelText: 'Código'),
                        validator: (v) => validarCodigo(v ?? ''),
                        onFieldSubmitted: (_) => _verificar(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _enviando ? null : _verificar,
                          child: _enviando
                              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Text('Verificar código', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _enviando || widget.correo == null ? null : _reenviar,
                        child: const Text('Enviarme otro código'),
                      ),
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
