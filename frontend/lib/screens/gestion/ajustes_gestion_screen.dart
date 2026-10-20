import 'package:flutter/material.dart';
import '../../repositories/hub_repository.dart';
import '../tutora/ajustes_tutora_screen.dart';

/// Ajustes del Equipo de Gestión: los mismos de la Tutora, con la etiqueta de Gestión.
class AjustesGestionScreen extends StatelessWidget {
  final HubRepository repository;
  final String tutoraId;
  final ValueNotifier<ThemeMode>? themeNotifier;

  const AjustesGestionScreen({
    super.key,
    required this.repository,
    this.tutoraId = 'tutora-1', // Misma tutora por defecto que GestionMobileScreen
    this.themeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return AjustesTutoraScreen(
      repository: repository,
      tutoraId: tutoraId,
      themeNotifier: themeNotifier,
      rolEtiqueta: 'Gestión',
      rolEmoji: '📋',
    );
  }
}
