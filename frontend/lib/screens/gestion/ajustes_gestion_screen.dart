import 'package:flutter/material.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/clase_repository.dart';
import '../../repositories/voluntariado_repository.dart';
import '../ajustes/accesos_rol.dart';
import '../tutora/ajustes_tutora_screen.dart';

/// Ajustes del Equipo de Gestión: los mismos de la Tutora, con la etiqueta de
/// Gestión. Sus [accesos] los registra [GestionMobileScreen]: la clase de hoy,
/// la gestión de la sede (justificativos, alertas, evidencias, tutoras, roles,
/// calendario y voluntariado) y su trabajo como tutora. Los accesos, los datos
/// de las alumnas, la exportación y la auditoría son de la Directiva.
class AjustesGestionScreen extends StatelessWidget {
  final SesionUsuario sesion;
  final VoluntariadoRepository? voluntariado;
  final ClaseRepository? clase;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;
  final RegistroAccesos? accesos;

  const AjustesGestionScreen({
    super.key,
    required this.sesion,
    this.voluntariado,
    this.clase,
    this.themeNotifier,
    this.onCerrarSesion,
    this.accesos,
  });

  @override
  Widget build(BuildContext context) {
    return AjustesTutoraScreen(
      sesion: sesion,
      voluntariado: voluntariado,
      clase: clase,
      themeNotifier: themeNotifier,
      onCerrarSesion: onCerrarSesion,
      rolEtiqueta: 'Gestión',
      rolEmoji: '📋',
      accesos: accesos,
    );
  }
}
