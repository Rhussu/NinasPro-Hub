import 'package:flutter/material.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/hub_repository.dart';
import '../../widgets/ninaspro_ajustes.dart';
import '../calendario/calendario_screen.dart';
import '../tutora/ajustes_tutora_screen.dart';

/// Ajustes del Equipo de Gestión: los mismos de la Tutora, con la etiqueta de
/// Gestión y el calendario de clases de su sede (US-03). Gestión opera el
/// semana a semana; los accesos y los datos de las alumnas son de la Directiva.
class AjustesGestionScreen extends StatelessWidget {
  final HubRepository repository;
  final String tutoraId;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;
  final CatalogoRepository? catalogoRepository;

  const AjustesGestionScreen({
    super.key,
    required this.repository,
    this.tutoraId = 'tutora-1', // Misma tutora por defecto que GestionMobileScreen
    this.themeNotifier,
    this.onCerrarSesion,
    this.catalogoRepository,
  });

  @override
  Widget build(BuildContext context) {
    final catalogo = catalogoRepository;
    return AjustesTutoraScreen(
      repository: repository,
      tutoraId: tutoraId,
      themeNotifier: themeNotifier,
      onCerrarSesion: onCerrarSesion,
      rolEtiqueta: 'Gestión',
      rolEmoji: '📋',
      seccionesExtra: [
        if (catalogo != null)
          AjustesSeccion(
            titulo: 'Administración',
            children: [
              AjustesTile(
                icono: Icons.calendar_month_rounded,
                titulo: 'Calendario de clases',
                subtitulo: 'Suspende sesiones o agrega clases de recuperación',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CalendarioScreen(repository: catalogo)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
