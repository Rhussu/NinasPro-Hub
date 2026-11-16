import 'package:flutter/material.dart';
import '../../models/sesion_usuario.dart';
import '../../repositories/accesos_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../accesos/accesos_view.dart';
import '../calendario/calendario_screen.dart';
import '../tutora/ajustes_tutora_screen.dart';

/// Ajustes del Equipo de Gestión: los mismos de la Tutora, con la etiqueta de
/// Gestión, el calendario de clases de su sede (US-03) y "Accesos" para
/// autorizar correos de alumnas (US-04).
class AjustesGestionScreen extends StatelessWidget {
  final HubRepository repository;
  final String tutoraId;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;
  final AccesosRepository? accesosRepository;
  final CatalogoRepository? catalogoRepository;
  final SesionUsuario? sesion;

  const AjustesGestionScreen({
    super.key,
    required this.repository,
    this.tutoraId = 'tutora-1', // Misma tutora por defecto que GestionMobileScreen
    this.themeNotifier,
    this.onCerrarSesion,
    this.accesosRepository,
    this.catalogoRepository,
    this.sesion,
  });

  @override
  Widget build(BuildContext context) {
    final accesos = accesosRepository;
    final catalogo = catalogoRepository;
    final s = sesion;
    return AjustesTutoraScreen(
      repository: repository,
      tutoraId: tutoraId,
      themeNotifier: themeNotifier,
      onCerrarSesion: onCerrarSesion,
      rolEtiqueta: 'Gestión',
      rolEmoji: '📋',
      seccionesExtra: [
        if ((accesos != null && s != null) || catalogo != null)
          AjustesSeccion(
            titulo: 'Administración',
            children: [
              if (catalogo != null)
                AjustesTile(
                  icono: Icons.calendar_month_rounded,
                  titulo: 'Calendario de clases',
                  subtitulo: 'Suspende sesiones o agrega clases de recuperación',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CalendarioScreen(repository: catalogo)),
                  ),
                ),
              if (accesos != null && s != null)
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
