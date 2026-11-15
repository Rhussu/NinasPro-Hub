import 'package:flutter/material.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/accesos_repository.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../accesos/accesos_view.dart';
import '../tutora/ajustes_tutora_screen.dart';

/// Ajustes del Equipo de Gestión: los mismos de la Tutora, con la etiqueta de
/// Gestión y el acceso a "Accesos" para autorizar correos de alumnas (US-04).
class AjustesGestionScreen extends StatelessWidget {
  final HubRepository repository;
  final String tutoraId;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;
  final AccesosRepository? accesosRepository;
  final SesionUsuario? sesion;

  const AjustesGestionScreen({
    super.key,
    required this.repository,
    this.tutoraId = 'tutora-1', // Misma tutora por defecto que GestionMobileScreen
    this.themeNotifier,
    this.onCerrarSesion,
    this.accesosRepository,
    this.sesion,
  });

  @override
  Widget build(BuildContext context) {
    final accesos = accesosRepository;
    final s = sesion;
    return AjustesTutoraScreen(
      repository: repository,
      tutoraId: tutoraId,
      themeNotifier: themeNotifier,
      onCerrarSesion: onCerrarSesion,
      rolEtiqueta: 'Gestión',
      rolEmoji: '📋',
      seccionesExtra: [
        if (accesos != null && s != null)
          AjustesSeccion(
            titulo: 'Administración',
            children: [
              AjustesTile(
                icono: Icons.how_to_reg_rounded,
                titulo: 'Accesos',
                subtitulo: 'Autoriza el correo de las alumnas de tu sede',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AccesosScreen(repository: accesos, sesion: s)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
