import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';
import '../models/hub_models.dart';
import '../repositories/hub_repository.dart';

/// Nubecita del AppBar: indica si hay conexión y todo está guardado en la nube,
/// si se están subiendo cambios o si no hay conexión y quedan cambios pendientes.
///
/// Los cambios se suben solos al instante (o al volver internet), así que la nube no se
/// "aprieta para sincronizar": al tocarla se ve el detalle del estado. Cuando se cae la
/// conexión o se terminan de subir los pendientes, se avisa con un mensaje.
class NinasProIndicadorSync extends StatefulWidget {
  final HubRepository repository;

  const NinasProIndicadorSync({super.key, required this.repository});

  static String _cambios(int n) => n == 1 ? '1 cambio pendiente' : '$n cambios pendientes';

  @override
  State<NinasProIndicadorSync> createState() => _NinasProIndicadorSyncState();
}

class _NinasProIndicadorSyncState extends State<NinasProIndicadorSync> {
  late EstadoSincronizacion _estadoAnterior;

  /// Pendientes que había al empezar a subir, para el aviso al terminar
  int _subiendo = 0;

  HubRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _estadoAnterior = repository.estadoSincronizacion.value;
    repository.estadoSincronizacion.addListener(_alCambiarEstado);
  }

  @override
  void didUpdateWidget(NinasProIndicadorSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.estadoSincronizacion.removeListener(_alCambiarEstado);
      _estadoAnterior = repository.estadoSincronizacion.value;
      repository.estadoSincronizacion.addListener(_alCambiarEstado);
    }
  }

  @override
  void dispose() {
    repository.estadoSincronizacion.removeListener(_alCambiarEstado);
    super.dispose();
  }

  void _alCambiarEstado() {
    final estado = repository.estadoSincronizacion.value;
    final anterior = _estadoAnterior;
    _estadoAnterior = estado;
    if (!mounted || estado == anterior) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (estado) {
      case EstadoSincronizacion.sinConexion:
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('📴 Sin conexión: los cambios quedarán guardados en este dispositivo.')),
          );
      case EstadoSincronizacion.sincronizando:
        _subiendo = repository.cambiosPendientes.value;
      case EstadoSincronizacion.sincronizado:
        if (_subiendo > 0) {
          final subidos = NinasProIndicadorSync._cambios(_subiendo).replaceFirst('pendiente', 'subido');
          messenger
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('☁️ Volvió la conexión: $subidos a la nube.')));
        }
        _subiendo = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoSincronizacion>(
      valueListenable: repository.estadoSincronizacion,
      builder: (context, estado, _) => ValueListenableBuilder<int>(
        valueListenable: repository.cambiosPendientes,
        builder: (context, pendientes, _) {
          final (icono, color, tooltip, detalle) = switch (estado) {
            EstadoSincronizacion.sincronizado => (
              Icons.cloud_done_rounded,
              NinasProColors.success500,
              'Conectado · todo guardado en la nube',
              'Tus cambios se suben a la nube al instante.',
            ),
            EstadoSincronizacion.sincronizando => (
              Icons.cloud_sync_rounded,
              NinasProColors.primary500,
              'Subiendo ${NinasProIndicadorSync._cambios(pendientes)}…',
              'Volvió la conexión: se están subiendo los cambios guardados en este dispositivo.',
            ),
            EstadoSincronizacion.sinConexion => (
              Icons.cloud_off_rounded,
              NinasProColors.warning500,
              pendientes == 0 ? 'Sin conexión' : 'Sin conexión · ${NinasProIndicadorSync._cambios(pendientes)}',
              pendientes == 0
                  ? 'Puedes seguir trabajando: lo que hagas se guardará en este dispositivo.'
                  : 'Por ahora solo se ven en este dispositivo. Se subirán solos cuando vuelva internet.',
            ),
          };
          return PopupMenuButton<void>(
            tooltip: tooltip,
            icon: Icon(icono, size: 19, color: color),
            style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                enabled: false,
                child: SizedBox(
                  width: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icono, size: 18, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tooltip,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(detalle, style: const TextStyle(fontSize: 12, color: NinasProColors.neutral500)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
