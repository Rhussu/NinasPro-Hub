import 'package:flutter/material.dart';

import '../../models/sesion_usuario.dart';
import '../../services/auth_service.dart';
import 'acceso_screen.dart';
import 'nueva_contrasena_screen.dart';
import 'recuperacion_screens.dart';

/// Decide qué mostrar según el estado de autenticación: carga, acceso, los pasos
/// de la recuperación de contraseña o la app de la usuaria.
class AuthGate extends StatefulWidget {
  final AuthService authService;
  final Widget Function(BuildContext context, SesionUsuario sesion) builder;

  const AuthGate({super.key, required this.authService, required this.builder});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  EtapaAuth? _etapaAnterior;

  @override
  void initState() {
    super.initState();
    widget.authService.estado.addListener(_alCambiarEstado);
    widget.authService.iniciar();
  }

  @override
  void dispose() {
    widget.authService.estado.removeListener(_alCambiarEstado);
    super.dispose();
  }

  /// Al cerrar sesión (o expirar) se descartan las pantallas abiertas encima,
  /// como Ajustes, para que nadie siga viendo datos de la cuenta anterior.
  void _alCambiarEstado() {
    final etapa = widget.authService.estado.value.etapa;
    if (etapa != _etapaAnterior && etapa != EtapaAuth.conSesion && mounted) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
    _etapaAnterior = etapa;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoAuth>(
      valueListenable: widget.authService.estado,
      builder: (context, estado, _) {
        final sesion = estado.sesion;
        return switch (estado.etapa) {
          EtapaAuth.iniciando => const Scaffold(body: Center(child: CircularProgressIndicator())),
          EtapaAuth.sinSesion => AccesoScreen(
              // Una pantalla nueva por cada aviso, para mostrarlo aunque ya estuviera abierta
              key: ValueKey(estado.aviso),
              authService: widget.authService,
              aviso: estado.aviso,
            ),
          EtapaAuth.correoEnviado => CorreoEnviadoScreen(authService: widget.authService, correo: estado.correo),
          EtapaAuth.enlaceRecuperacion => EnlaceRecuperacionScreen(
              authService: widget.authService,
              correo: estado.correo,
              otraPestanaDisponible: estado.otraPestanaDisponible,
            ),
          EtapaAuth.recuperandoContrasena => NuevaContrasenaScreen(authService: widget.authService, correo: estado.correo),
          EtapaAuth.esperandoOtraPestana => EsperandoOtraPestanaScreen(
              authService: widget.authService,
              soyPestanaDelEnlace: estado.soyPestanaDelEnlace,
            ),
          EtapaAuth.conSesion when sesion != null => KeyedSubtree(
              // Cambiar de cuenta reinicia por completo la app de la usuaria anterior
              key: ValueKey(sesion.perfilId),
              child: widget.builder(context, sesion),
            ),
          EtapaAuth.conSesion => AccesoScreen(authService: widget.authService),
        };
      },
    );
  }
}
