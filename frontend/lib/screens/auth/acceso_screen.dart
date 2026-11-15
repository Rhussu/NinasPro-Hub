import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/ninaspro_mascot.dart';

enum ModoAcceso { iniciarSesion, crearCuenta, recuperar }

/// Acceso a NiñasPro Hub: iniciar sesión, crear la cuenta de un correo
/// autorizado (US-04, US-05) o pedir el enlace para recuperar la contraseña.
class AccesoScreen extends StatefulWidget {
  final AuthService authService;

  /// Aviso que dejó la sesión anterior (ej. cuenta sin perfil activo)
  final String? aviso;

  const AccesoScreen({super.key, required this.authService, this.aviso});

  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  ModoAcceso _modo = ModoAcceso.iniciarSesion;
  bool _enviando = false;
  bool _verContrasena = false;
  String? _error;
  String? _exito;

  @override
  void initState() {
    super.initState();
    _error = widget.aviso;
  }

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  void _cambiarModo(ModoAcceso modo) {
    setState(() {
      _modo = modo;
      _error = null;
      _exito = null;
      _contrasena.clear();
      _confirmacion.clear();
    });
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
      _exito = null;
    });

    final auth = widget.authService;
    final correo = _correo.text;
    final resultado = switch (_modo) {
      ModoAcceso.iniciarSesion => await auth.iniciarSesion(correo: correo, contrasena: _contrasena.text),
      ModoAcceso.crearCuenta => await auth.crearCuenta(correo: correo, contrasena: _contrasena.text),
      ModoAcceso.recuperar => await auth.enviarRecuperacion(correo: correo),
    };

    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (resultado.ok) {
        _exito = resultado.mensaje;
      } else {
        _error = resultado.mensaje ?? 'No pudimos completar la operación.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (titulo, subtitulo, boton) = switch (_modo) {
      ModoAcceso.iniciarSesion => ('Te damos la bienvenida', 'Ingresa con tu cuenta de NiñasPro.', 'Ingresar'),
      ModoAcceso.crearCuenta => (
          'Crea tu cuenta',
          'Usa el correo que tu sede autorizó. Si aún no lo hace, pídeselo a tu equipo de gestión.',
          'Crear cuenta',
        ),
      ModoAcceso.recuperar => (
          'Recupera tu contraseña',
          'Te enviaremos un enlace para crear una contraseña nueva. También sirve para desbloquear tu cuenta.',
          'Enviar enlace',
        ),
    };

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
                    const Center(child: NinasProMascot(size: 96)),
                    const SizedBox(height: 12),
                    const Text(
                      'NiñasPro Hub',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 24),
                    Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 14, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) _Aviso(texto: _error!, esError: true),
                    if (_exito != null) _Aviso(texto: _exito!, esError: false),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: _modo == ModoAcceso.recuperar ? TextInputAction.done : TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) => validarCorreo(v ?? ''),
                      onFieldSubmitted: _modo == ModoAcceso.recuperar ? (_) => _enviar() : null,
                    ),
                    if (_modo != ModoAcceso.recuperar) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _contrasena,
                        obscureText: !_verContrasena,
                        autofillHints: [
                          _modo == ModoAcceso.crearCuenta ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                        textInputAction: _modo == ModoAcceso.crearCuenta ? TextInputAction.next : TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          helperText: _modo == ModoAcceso.crearCuenta
                              ? 'Mínimo 10 caracteres, con mayúsculas, minúsculas y números.'
                              : null,
                          suffixIcon: IconButton(
                            tooltip: _verContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña',
                            icon: Icon(_verContrasena ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            onPressed: () => setState(() => _verContrasena = !_verContrasena),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña.';
                          return _modo == ModoAcceso.crearCuenta ? validarContrasena(v) : null;
                        },
                        onFieldSubmitted: _modo == ModoAcceso.iniciarSesion ? (_) => _enviar() : null,
                      ),
                    ],
                    if (_modo == ModoAcceso.crearCuenta) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmacion,
                        obscureText: !_verContrasena,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Repite la contraseña',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden.' : null,
                        onFieldSubmitted: (_) => _enviar(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _enviando ? null : _enviar,
                        child: _enviando
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(boton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._enlaces(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _enlaces() {
    Widget enlace(String texto, ModoAcceso modo) => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _enviando ? null : () => _cambiarModo(modo),
          child: Text(texto),
        );

    return switch (_modo) {
      ModoAcceso.iniciarSesion => [
          enlace('¿Olvidaste tu contraseña?', ModoAcceso.recuperar),
          enlace('Primera vez: crear mi cuenta', ModoAcceso.crearCuenta),
        ],
      _ => [enlace('Volver a iniciar sesión', ModoAcceso.iniciarSesion)],
    };
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  final bool esError;

  const _Aviso({required this.texto, required this.esError});

  @override
  Widget build(BuildContext context) {
    final color = esError ? NinasProColors.error700 : NinasProColors.success700;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(esError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
