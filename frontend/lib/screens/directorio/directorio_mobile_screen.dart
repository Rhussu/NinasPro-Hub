import 'package:flutter/material.dart';
import '../../repositories/hub_repository.dart';
import '../gestion/gestion_mobile_screen.dart';

/// Wrapper de compatibilidad histórica para DirectorioMobileScreen.
///
/// Según la arquitectura de roles acordada en el plan v2:
/// - La vista de Directiva Nacional es Desktop-first: [DirectorioDesktopScreen].
/// - La vista de coordinación y gestión de sede móvil reside en [GestionMobileScreen].
class DirectorioMobileScreen extends StatelessWidget {
  final HubRepository repository;

  const DirectorioMobileScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return GestionMobileScreen(repository: repository);
  }
}
