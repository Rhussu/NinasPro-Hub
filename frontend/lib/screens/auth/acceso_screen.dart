import 'package:flutter/material.dart';

import '../../config/ninaspro_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/ninaspro_mascot.dart';

enum ModoAcceso { iniciarSesion, crearCuenta, recuperar }

/// Acceso a NiñasPro Hub: iniciar sesión, crear la cuenta de un correo
/// autorizado (US-04, US-05) o pedir el enlace para recuperar la contraseña.
///
/// Cada modo arma su propio formulario (campos, validaciones y errores nuevos):
/// cambiar de modo nunca arrastra el estado del anterior.
class AccesoScreen extends StatefulWidget {
  final AuthService authService;

  /// Aviso que dejó la sesión anterior (ej. cuenta bloqueada o enlace vencido)
  final String? aviso;

  const AccesoScreen({super.key, required this.authService, this.aviso});

  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  // El correo escrito se conserva al cambiar de modo; las contraseñas no
  final _correo = TextEditingController();
  ModoAcceso _modo = ModoAcceso.iniciarSesion;
  bool _avisoVisible = true;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  void _cambiarModo(ModoAcceso modo) {
    FocusScope.of(context).unfocus();
    setState(() {
      _modo = modo;
      _avisoVisible = false;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EncabezadoAcceso(),
                  _FormularioAcceso(
                    key: ValueKey(_modo),
                    modo: _modo,
                    correo: _correo,
                    authService: widget.authService,
                    avisoInicial: _avisoVisible ? widget.aviso : null,
                    onCambiarModo: _cambiarModo,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mascota y nombre de la app, compartidos por las pantallas de acceso.
class EncabezadoAcceso extends StatelessWidget {
  final double tamanoMascota;

  const EncabezadoAcceso({super.key, this.tamanoMascota = 96});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NinasProMascot(size: tamanoMascota),
        const SizedBox(height: 12),
        const Text(
          'NiñasPro Hub',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FormularioAcceso extends StatefulWidget {
  final ModoAcceso modo;
  final TextEditingController correo;
  final AuthService authService;
  final String? avisoInicial;
  final ValueChanged<ModoAcceso> onCambiarModo;

  const _FormularioAcceso({
    super.key,
    required this.modo,
    required this.correo,
    required this.authService,
    required this.avisoInicial,
    required this.onCambiarModo,
  });

  @override
  State<_FormularioAcceso> createState() => _FormularioAccesoState();
}

class _FormularioAccesoState extends State<_FormularioAcceso> {
  final _formKey = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  bool _enviando = false;
  String? _error;
  String? _exito;

  ModoAcceso get _modo => widget.modo;

  @override
  void initState() {
    super.initState();
    _error = widget.avisoInicial;
  }

  @override
  void dispose() {
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
      _exito = null;
    });

    final auth = widget.authService;
    final correo = widget.correo.text;
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
    final colorSecundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;
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

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitulo, style: TextStyle(fontSize: 14, color: colorSecundario)),
            const SizedBox(height: 20),
            if (_error != null) AvisoAcceso(texto: _error!, esError: true),
            if (_exito != null) AvisoAcceso(texto: _exito!, esError: false),
            TextFormField(
              controller: widget.correo,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: _modo == ModoAcceso.recuperar ? TextInputAction.done : TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.alternate_email_rounded)),
              validator: (v) => validarCorreo(v ?? ''),
              onFieldSubmitted: _modo == ModoAcceso.recuperar ? (_) => _enviar() : null,
            ),
            if (_modo == ModoAcceso.iniciarSesion) ...[
              const SizedBox(height: 14),
              CampoContrasena(
                controller: _contrasena,
                etiqueta: 'Contraseña',
                autofillHint: AutofillHints.password,
                validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña.' : null,
                onSubmitted: _enviar,
              ),
            ],
            if (_modo == ModoAcceso.crearCuenta) ...[
              const SizedBox(height: 14),
              CampoContrasena(
                controller: _contrasena,
                etiqueta: 'Contraseña',
                autofillHint: AutofillHints.newPassword,
                textInputAction: TextInputAction.next,
                validator: (v) => validarContrasena(v ?? ''),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Text(
                  'Mínimo 10 caracteres, con mayúsculas, minúsculas y números.',
                  style: TextStyle(fontSize: 12, color: colorSecundario),
                ),
              ),
              const SizedBox(height: 14),
              CampoContrasena(
                controller: _confirmacion,
                etiqueta: 'Repite la contraseña',
                autofillHint: AutofillHints.newPassword,
                validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden.' : null,
                onSubmitted: _enviar,
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
    );
  }

  List<Widget> _enlaces() {
    Widget enlace(String texto, ModoAcceso modo) => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _enviando ? null : () => widget.onCambiarModo(modo),
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

/// Campo de contraseña con botón para mostrarla u ocultarla.
///
/// Los hints de autocompletado son fijos y la decoración no cambia de forma al
/// mostrar la contraseña: en la web, cambiar ambas cosas a la vez sobre el mismo
/// campo podía dejar el `<input>` del navegador sin recibir teclas.
class CampoContrasena extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final String autofillHint;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  const CampoContrasena({
    super.key,
    required this.controller,
    required this.etiqueta,
    required this.autofillHint,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      // Un campo nuevo al alternar la visibilidad: el navegador recibe un <input>
      // limpio en vez de mutar el tipo del que tiene el foco
      key: ValueKey('${widget.etiqueta}-$_visible'),
      controller: widget.controller,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: [widget.autofillHint],
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
          icon: Icon(_visible ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
    );
  }
}

/// Mensaje de error o de éxito en las pantallas de acceso.
class AvisoAcceso extends StatelessWidget {
  final String texto;
  final bool esError;

  const AvisoAcceso({super.key, required this.texto, required this.esError});

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
