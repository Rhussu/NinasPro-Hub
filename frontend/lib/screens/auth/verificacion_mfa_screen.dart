import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/ninaspro_colors.dart';
import '../../services/auth_service.dart';
import 'acceso_screen.dart';
import 'codigo_recuperacion_screen.dart';

/// Segundo factor de la Directiva (RNF-S-1): la primera vez inscribe su
/// autenticador escaneando un código QR; después, ingresa el código de 6
/// dígitos en cada inicio de sesión. Sin esto la base no le entrega datos.
class VerificacionMfaScreen extends StatefulWidget {
  final AuthService authService;
  final String? correo;

  /// Ya tiene un autenticador inscrito; si no, se muestra el QR para inscribirlo
  final bool inscrita;

  const VerificacionMfaScreen({super.key, required this.authService, this.correo, this.inscrita = false});

  @override
  State<VerificacionMfaScreen> createState() => _VerificacionMfaScreenState();
}

class _VerificacionMfaScreenState extends State<VerificacionMfaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  InscripcionMfa? _inscripcion;
  bool _preparando = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.inscrita) _prepararInscripcion();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _prepararInscripcion() async {
    setState(() {
      _preparando = true;
      _error = null;
    });
    try {
      final inscripcion = await widget.authService.iniciarInscripcionMfa();
      if (!mounted) return;
      setState(() {
        _inscripcion = inscripcion;
        _preparando = false;
      });
    } on ErrorAuth catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _preparando = false;
      });
    }
  }

  Future<void> _verificar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final r = await widget.authService.verificarMfa(codigo: _codigo.text);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (!r.ok) {
        _error = r.mensaje;
        _codigo.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorSecundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;
    final inscribiendo = !widget.inscrita;
    final listoParaCodigo = widget.inscrita || _inscripcion != null;

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
                    const EncabezadoAcceso(tamanoMascota: 72),
                    Text(
                      inscribiendo ? 'Protege tu cuenta de Directiva' : 'Verificación en dos pasos',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      inscribiendo
                          ? 'La Directiva accede a datos de todas las sedes, por eso usa un segundo factor. '
                              'Escanea el código con una app autenticadora (Google Authenticator, Microsoft '
                              'Authenticator o similar) e ingresa el código de $largoCodigo dígitos que te muestre.'
                          : 'Ingresa el código de $largoCodigo dígitos de tu app autenticadora'
                              '${widget.correo == null ? '' : ' para ${widget.correo}'}.',
                      style: TextStyle(fontSize: 14, height: 1.4, color: colorSecundario),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) AvisoAcceso(texto: _error!, esError: true),
                    if (inscribiendo) ..._buildInscripcion(colorSecundario),
                    if (listoParaCodigo) ...[
                      CampoCodigo(controller: _codigo, enabled: !_enviando, onSubmitted: _verificar),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _enviando ? null : _verificar,
                          child: _enviando
                              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Text('Verificar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: _enviando ? null : widget.authService.cerrarSesion,
                      child: const Text('Cerrar sesión'),
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

  List<Widget> _buildInscripcion(Color colorSecundario) {
    final inscripcion = _inscripcion;
    if (_preparando) {
      return const [Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))];
    }
    if (inscripcion == null) {
      return [
        OutlinedButton(onPressed: _prepararInscripcion, child: const Text('Reintentar')),
      ];
    }
    return [
      Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          // El QR necesita fondo blanco para que la cámara lo lea también en modo oscuro
          child: QrImageView(data: inscripcion.uri, size: 200, backgroundColor: Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      Text('¿No puedes escanearlo? Ingresa esta clave en la app:', style: TextStyle(fontSize: 13, color: colorSecundario)),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: SelectableText(
              inscripcion.secreto,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
          ),
          IconButton(
            tooltip: 'Copiar clave',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => Clipboard.setData(ClipboardData(text: inscripcion.secreto)),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }
}
