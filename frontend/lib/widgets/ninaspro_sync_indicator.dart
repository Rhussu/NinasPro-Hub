import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';
import '../models/hub_models.dart';
import '../repositories/hub_repository.dart';
import '../repositories/mock_hub_repository.dart';

/// Nubecita del AppBar: indica si hay conexión y todo está guardado en la nube,
/// si se están subiendo cambios o si no hay conexión y quedan cambios pendientes.
///
/// Los cambios se suben solos al instante (o al volver internet), así que la nube no se
/// "aprieta para sincronizar": al tocarla se ve el detalle del estado. En el mockup, el menú
/// incluye además un interruptor para simular que se cae la conexión.
class NinasProIndicadorSync extends StatelessWidget {
  final HubRepository repository;

  const NinasProIndicadorSync({super.key, required this.repository});

  static String _cambios(int n) => n == 1 ? '1 cambio pendiente' : '$n cambios pendientes';

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
                'Subiendo ${_cambios(pendientes)}…',
                'Volvió la conexión: se están subiendo los cambios guardados en este dispositivo.',
              ),
            EstadoSincronizacion.sinConexion => (
                Icons.cloud_off_rounded,
                NinasProColors.warning500,
                pendientes == 0 ? 'Sin conexión' : 'Sin conexión · ${_cambios(pendientes)}',
                pendientes == 0
                    ? 'Puedes seguir trabajando: lo que hagas se guardará en este dispositivo.'
                    : 'Por ahora solo se ven en este dispositivo. Se subirán solos cuando vuelva internet.',
              ),
          };
          final mock = repository is MockHubRepository ? repository as MockHubRepository : null;

          return PopupMenuButton<bool>(
            tooltip: tooltip,
            icon: Icon(icono, size: 19, color: color),
            style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (conectar) => _simularConexion(context, mock!, conectar),
            itemBuilder: (context) => [
              PopupMenuItem<bool>(
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
              if (mock != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem<bool>(
                  value: !mock.conectado,
                  child: Row(
                    children: [
                      Icon(mock.conectado ? Icons.wifi_off_rounded : Icons.wifi_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(mock.conectado ? 'Simular sin conexión' : 'Recuperar conexión'),
                            const Text(
                              'Solo en el mockup',
                              style: TextStyle(fontSize: 11, color: NinasProColors.neutral500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _simularConexion(BuildContext context, MockHubRepository mock, bool conectar) async {
    final messenger = ScaffoldMessenger.of(context);
    final pendientes = mock.cambiosPendientes.value;
    await mock.simularConexion(conectar);
    if (!conectar) {
      messenger.showSnackBar(
        const SnackBar(content: Text('📴 Sin conexión: los cambios quedarán guardados en este dispositivo.')),
      );
    } else if (pendientes > 0 && mock.conectado) {
      messenger.showSnackBar(
        SnackBar(content: Text('☁️ Volvió la conexión: ${_cambios(pendientes).replaceFirst('pendiente', 'subido')} a la nube.')),
      );
    }
  }
}
