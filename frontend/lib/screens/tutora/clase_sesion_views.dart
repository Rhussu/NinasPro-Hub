import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';
import '../../models/hub_models.dart';
import '../../repositories/clase_repository.dart';
import 'clase_sesion_controller.dart';

/// Vistas de la clase en curso, compartidas entre Tutora y Equipo de Gestión.
///
/// - [AsistenciaClaseView]: US-13, pase de lista táctil Presente ↔ Ausente, con historial por semana.
/// - [EjerciciosClaseView]: US-28, ejercicios resueltos y participación activa.
/// - [FotosClaseView]: US-18 y US-19, evidencia fotográfica y consentimientos de imagen.
/// - [mostrarModalRegistroKahoot]: US-29, podio Kahoot de la clase.

/// Muestra el resultado de un guardado de la clase: en la nube, pendiente de envío o rechazado
void mostrarResultadoGuardado(ScaffoldMessengerState messenger, ResultadoGuardado resultado, {required String exito}) {
  final (color, texto) = switch (resultado.estado) {
    EstadoGuardado.guardado => (
      NinasProColors.success700,
      resultado.mensaje == null ? exito : '$exito ${resultado.mensaje}',
    ),
    EstadoGuardado.pendiente => (
      NinasProColors.warning900,
      '📴 Pendiente de envío por falta de conexión: quedó guardado en este dispositivo y se enviará solo al volver internet.',
    ),
    EstadoGuardado.rechazado => (NinasProColors.error700, '⚠️ ${resultado.mensaje ?? 'No se pudo guardar.'}'),
  };
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: Duration(seconds: resultado.guardado && resultado.mensaje == null ? 3 : 6),
        content: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
}

/// Aviso fijo mientras la lista sigue guardada solo en el dispositivo (US-14 escenario 1)
class AvisoPendienteEnvio extends StatelessWidget {
  const AvisoPendienteEnvio({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NinasProColors.warning100,
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: NinasProColors.warning900),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pendiente de envío por falta de conexión. Se enviará solo al volver internet.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NinasProColors.warning900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quién hizo la última edición del pase de lista y a qué hora (US-15)
class LineaUltimaEdicion extends StatelessWidget {
  final String? autora;
  final DateTime? hora;

  const LineaUltimaEdicion({super.key, required this.autora, required this.hora});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = hora;
    final cuando = h == null
        ? ''
        : ' · ${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')} '
              '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 14, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Última edición: ${autora ?? 'sin registro'}$cuando',
              style: TextStyle(fontSize: 11.5, color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Registro editado más recientemente de una lista (para [LineaUltimaEdicion])
RegistroAsistencia? ultimaEdicion(List<RegistroAsistencia> registros) {
  RegistroAsistencia? ultima;
  for (final r in registros) {
    final h = r.horaMarcado;
    if (r.editadoPor == null || h == null) continue;
    if (ultima == null || h.isAfter(ultima.horaMarcado!)) ultima = r;
  }
  return ultima;
}

// Pase de lista táctil rápido (US-13) con historial semana a semana del curso y corrección posterior (US-15)
class AsistenciaClaseView extends StatefulWidget {
  final ClaseSesionController controller;

  const AsistenciaClaseView({super.key, required this.controller});

  @override
  State<AsistenciaClaseView> createState() => _AsistenciaClaseViewState();
}

class _AsistenciaClaseViewState extends State<AsistenciaClaseView> {
  // Clase que se está viendo; null = clase en curso
  String? _sesionVistaId;
  ListaClase _historial = const ListaClase();
  List<RegistroAsistencia> _registrosHistorial = [];
  bool _cargandoHistorial = false;
  String? _errorHistorial;

  // Corrección de una clase anterior (US-15 escenarios 1 y 3)
  bool _corrigiendo = false;
  bool _guardando = false;

  ClaseSesionController get controller => widget.controller;

  bool get _esClaseActual => _sesionVistaId == null || _sesionVistaId == controller.sesionId;

  SesionClase? get _sesionVista {
    final id = _sesionVistaId ?? controller.sesionId;
    return controller.sesiones.where((s) => s.id == id).firstOrNull;
  }

  Future<void> _verSesion(String id) async {
    if (id == controller.sesionId) {
      setState(() {
        _sesionVistaId = null;
        _corrigiendo = false;
      });
      return;
    }
    setState(() {
      _sesionVistaId = id;
      _corrigiendo = false;
      _cargandoHistorial = true;
      _errorHistorial = null;
    });
    try {
      final lista = await controller.listaDeSesion(id);
      if (!mounted || _sesionVistaId != id) return;
      setState(() {
        _historial = lista;
        _registrosHistorial = List.of(lista.registros);
        _cargandoHistorial = false;
      });
    } catch (_) {
      if (!mounted || _sesionVistaId != id) return;
      setState(() {
        _cargandoHistorial = false;
        _errorHistorial = 'No pudimos cargar esta clase. Revisa tu conexión.';
      });
    }
  }

  void _avisarJustificada(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: NinasProColors.warning900,
        content: Text('🔒 Justificada por Equipo de Gestión. Las tutoras solo marcan Presente o Ausente.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _ciclarEstado(BuildContext context, int index) {
    if (_esClaseActual) {
      if (!controller.ciclarEstado(index)) _avisarJustificada(context);
      return;
    }
    final reg = _registrosHistorial[index];
    final nuevo = alternarEstado(reg.estado);
    if (nuevo == null) return _avisarJustificada(context);
    setState(() => _registrosHistorial[index] = reg.copyWith(estado: nuevo));
  }

  // Corregir (o pasar por primera vez) la lista de una clase anterior
  void _empezarCorreccion() {
    setState(() {
      _corrigiendo = true;
      _registrosHistorial = [
        for (final r in _historial.registros)
          r.estado == EstadoAsistencia.pendiente ? r.copyWith(estado: EstadoAsistencia.presente) : r,
      ];
    });
  }

  Future<void> _guardar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final actual = _esClaseActual;
    final claseId = actual ? controller.sesionId : _sesionVistaId!;
    final registros = actual ? controller.registros : _registrosHistorial;
    int contar(EstadoAsistencia e) => registros.where((r) => r.estado == e).length;

    setState(() => _guardando = true);
    final reloj = Stopwatch()..start();
    final resultado = await controller.guardarAsistenciaDe(claseId, registros);
    reloj.stop();
    if (!mounted) return;
    setState(() => _guardando = false);

    mostrarResultadoGuardado(
      messenger,
      resultado,
      exito:
          '✅ Asistencia guardada: ${contar(EstadoAsistencia.presente)} presentes, '
          '${contar(EstadoAsistencia.ausente)} ausentes, ${contar(EstadoAsistencia.justificada)} justificadas '
          '(${reloj.elapsedMilliseconds} ms).',
    );
    if (!actual && !resultado.rechazado) await _verSesion(claseId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.cargando) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return EstadoSinPaseLista(icono: Icons.cloud_off_rounded, titulo: 'Sin datos', mensaje: controller.error!);
        }
        if (controller.sesiones.isEmpty) {
          return const EstadoSinPaseLista(
            titulo: 'Sin clases',
            mensaje: 'Tu curso aún no tiene clases programadas.',
          );
        }

        final actual = _esClaseActual;
        final sesion = _sesionVista;
        final hoy = controller.hoy();
        final registrable = sesion != null && sesionRegistrable(sesion, hoy);
        final registros = actual ? controller.registros : _registrosHistorial;
        final tienePaseLista = actual ? controller.tienePaseLista : _historial.tienePaseLista;
        final editable = registrable && (actual || _corrigiendo);
        int contar(EstadoAsistencia e) => registros.where((r) => r.estado == e).length;
        final ultima = ultimaEdicion(registros);

        final etiqueta = actual
            ? 'Clase actual'
            : sesion != null && !_dia(sesion.fecha).isAfter(_dia(hoy))
            ? (_corrigiendo ? 'Historial · corrigiendo' : 'Historial · solo lectura')
            : 'Próxima clase';

        Widget contenido;
        if (_cargandoHistorial && !actual) {
          contenido = const Center(child: CircularProgressIndicator());
        } else if (_errorHistorial != null && !actual) {
          contenido = EstadoSinPaseLista(icono: Icons.cloud_off_rounded, titulo: 'Sin datos', mensaje: _errorHistorial!);
        } else if (sesion?.suspendida ?? false) {
          contenido = EstadoSinPaseLista(
            icono: Icons.event_busy_rounded,
            titulo: 'Clase suspendida',
            mensaje: sesion?.motivoSuspension ?? 'Esta clase no se realiza.',
          );
        } else if (!registrable) {
          contenido = const EstadoSinPaseLista(
            titulo: 'Clase programada',
            mensaje: 'Esta clase aún no se realiza: el pase de lista se abre el día de la clase.',
          );
        } else if (registros.isEmpty) {
          contenido = const EstadoSinPaseLista(
            icono: Icons.group_off_rounded,
            titulo: 'Sin alumnas activas',
            mensaje: 'El curso no tiene alumnas con la matrícula activa.',
          );
        } else if (!tienePaseLista && !editable) {
          contenido = EstadoSinPaseLista(
            mensaje: 'Esta clase aún no tiene pase de lista registrado.',
            accion: TextButton.icon(
              onPressed: _empezarCorreccion,
              icon: const Icon(Icons.fact_check_rounded, size: 18),
              label: const Text('Pasar lista'),
            ),
          );
        } else {
          contenido = Column(
            children: [
              BarraContadoresAsistencia(
                contadores: [
                  ContadorAsistencia(label: 'Presentes', count: contar(EstadoAsistencia.presente), estado: EstadoAsistencia.presente),
                  ContadorAsistencia(label: 'Ausentes', count: contar(EstadoAsistencia.ausente), estado: EstadoAsistencia.ausente),
                  ContadorAsistencia(label: 'Justificadas', count: contar(EstadoAsistencia.justificada), estado: EstadoAsistencia.justificada),
                ],
              ),
              if (actual && controller.pendienteDeEnvio) const AvisoPendienteEnvio(),
              if (tienePaseLista) LineaUltimaEdicion(autora: ultima?.editadoPor, hora: ultima?.horaMarcado),

              // Lista táctil de alumnas
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: registros.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final reg = registros[index];

                    return TarjetaAsistencia(
                      nombre: reg.alumnaNombre,
                      estado: reg.estado,
                      bloqueada: reg.estado == EstadoAsistencia.justificada,
                      onTap: editable ? () => _ciclarEstado(context, index) : null,
                      detalle: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            reg.alumnaRut,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                            ),
                          ),
                          if (!reg.autorizaImagen)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: NinasProColors.warning100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Sin foto',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: NinasProColors.warning900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              if (editable)
                BarraGuardarAsistencia(
                  label: actual ? 'Guardar Asistencia de la Clase' : 'Guardar Corrección',
                  onGuardar: _guardando ? null : () => _guardar(context),
                )
              else if (registrable && !actual)
                BarraGuardarAsistencia(
                  label: 'Corregir lista',
                  icono: Icons.edit_rounded,
                  onGuardar: _empezarCorreccion,
                ),
            ],
          );
        }

        return Column(
          children: [
            SelectorSemanaClase(
              sesiones: controller.sesiones,
              sesionVistaId: _sesionVistaId ?? controller.sesionId,
              sesionActualId: controller.sesionId,
              etiqueta: etiqueta,
              onCambiar: _verSesion,
            ),
            Expanded(child: contenido),
          ],
        );
      },
    );
  }
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Selector para recorrer semana a semana las clases del curso.
/// La clase en curso es editable; las demás se muestran como historial de solo lectura.
class SelectorSemanaClase extends StatelessWidget {
  final List<SesionClase> sesiones;
  final String sesionVistaId;
  final String sesionActualId;
  final ValueChanged<String> onCambiar;

  /// Texto bajo el tema (por defecto: clase actual o historial de solo lectura)
  final String? etiqueta;

  const SelectorSemanaClase({
    super.key,
    required this.sesiones,
    required this.sesionVistaId,
    required this.sesionActualId,
    required this.onCambiar,
    this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx = sesiones.indexWhere((s) => s.id == sesionVistaId);
    final sesion = idx != -1 ? sesiones[idx] : null;
    final esActual = sesionVistaId == sesionActualId;

    final f = sesion?.fecha;
    final fechaStr = f == null ? '' : '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
    final etiqueta = this.etiqueta ?? (esActual ? 'Clase actual' : 'Historial · solo lectura');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark800 : NinasProColors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: idx > 0 ? () => onCambiar(sesiones[idx - 1].id) : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  sesion != null ? 'Semana ${sesion.numeroSesion} · $fechaStr' : 'Semana',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                if (sesion != null)
                  Text(
                    sesion.tema,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                    ),
                  ),
                Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: esActual
                        ? NinasProColors.brandPink
                        : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
                  ),
                ),
              ],
            ),
          ),
          if (!esActual)
            IconButton(
              tooltip: 'Volver a la clase actual',
              icon: const Icon(Icons.today_rounded, color: NinasProColors.brandPink),
              onPressed: () => onCambiar(sesionActualId),
            ),
          IconButton(
            tooltip: 'Semana siguiente',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: idx != -1 && idx < sesiones.length - 1 ? () => onCambiar(sesiones[idx + 1].id) : null,
          ),
        ],
      ),
    );
  }
}

/// Estado vacío de una clase: sin pase de lista, programada, suspendida o sin datos.
class EstadoSinPaseLista extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  const EstadoSinPaseLista({
    super.key,
    this.icono = Icons.event_available_rounded,
    this.titulo = 'Clase programada',
    this.mensaje = 'Esta clase aún no tiene pase de lista registrado.',
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: NinasProColors.brandPink),
            const SizedBox(height: 10),
            Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
            if (accion != null) ...[const SizedBox(height: 10), accion!],
          ],
        ),
      ),
    );
  }
}

/// Datos de un contador de la barra resumen de asistencia.
class ContadorAsistencia {
  final String label;
  final int count;
  final EstadoAsistencia estado;

  const ContadorAsistencia({required this.label, required this.count, required this.estado});
}

/// Barra resumen sticky con contadores por estado de asistencia.
class BarraContadoresAsistencia extends StatelessWidget {
  final List<ContadorAsistencia> contadores;

  const BarraContadoresAsistencia({super.key, required this.contadores});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark800 : NinasProColors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < contadores.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _CounterChip(
                label: contadores[i].label,
                count: contadores[i].count,
                estado: contadores[i].estado,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de pase de lista: avatar, nombre, [detalle] y botón táctil de estado.
/// Si [onTap] es null la tarjeta es de solo lectura (historial).
class TarjetaAsistencia extends StatelessWidget {
  final String nombre;
  final EstadoAsistencia estado;
  final Widget detalle;
  final Widget? etiqueta;
  final bool bloqueada;
  final VoidCallback? onTap;

  const TarjetaAsistencia({
    super.key,
    required this.nombre,
    required this.estado,
    required this.detalle,
    this.etiqueta,
    this.bloqueada = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tono = context.statusColors.asistencia(estado);
    final esAusente = estado == EstadoAsistencia.ausente;

    final botonEstado = Container(
      constraints: const BoxConstraints(minWidth: 105, minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: tono.decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            bloqueada ? Icons.lock_outline_rounded : estado.icon,
            size: 16,
            color: tono.foreground,
          ),
          const SizedBox(width: 6),
          Text(estado.label, style: tono.textStyle(fontSize: 12)),
        ],
      ),
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: esAusente
              ? NinasProColors.error700.withValues(alpha: 0.5)
              : (isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
          width: esAusente ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Avatar o iniciales
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? NinasProColors.dark700 : NinasProColors.primary100,
              child: Text(
                nombre.isNotEmpty ? nombre[0] : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? NinasProColors.primary300 : NinasProColors.primary900,
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nombre,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (etiqueta != null) ...[
                        const SizedBox(width: 6),
                        etiqueta!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  detalle,
                ],
              ),
            ),

            // Botón táctil grande (área táctil >= 48px) para alternar estado P/A
            if (onTap != null)
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: botonEstado,
              )
            else
              botonEstado,
          ],
        ),
      ),
    );
  }
}

/// Barra inferior fija con el botón de guardar asistencia.
class BarraGuardarAsistencia extends StatelessWidget {
  final String label;

  /// null mientras se guarda (botón deshabilitado)
  final VoidCallback? onGuardar;
  final IconData icono;

  const BarraGuardarAsistencia({
    super.key,
    required this.label,
    required this.onGuardar,
    this.icono = Icons.check_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark900 : NinasProColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            style: NinasProTheme.brandButton,
            onPressed: onGuardar,
            icon: Icon(icono, size: 20),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  final String label;
  final int count;
  final EstadoAsistencia estado;

  const _CounterChip({required this.label, required this.count, required this.estado});

  @override
  Widget build(BuildContext context) {
    final tono = context.statusColors.asistencia(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: tono.decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icon, size: 14, color: tono.foreground),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: tono.textStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// Registro de Ejercicios y Participación Activa (US-28)
class EjerciciosClaseView extends StatefulWidget {
  final ClaseSesionController controller;

  const EjerciciosClaseView({super.key, required this.controller});

  @override
  State<EjerciciosClaseView> createState() => _EjerciciosClaseViewState();
}

class _EjerciciosClaseViewState extends State<EjerciciosClaseView> {
  bool _guardando = false;

  ClaseSesionController get controller => widget.controller;

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    final resultado = await controller.guardarParticipacion();
    if (!mounted) return;
    setState(() => _guardando = false);
    mostrarResultadoGuardado(messenger, resultado, exito: '✅ Ejercicios y participación guardados.');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.cargando) {
          return const Center(child: CircularProgressIndicator());
        }

        final alumnasPresentes = controller.alumnasPresentes;

        if (alumnasPresentes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                controller.tienePaseLista
                    ? 'No hay alumnas marcadas como Presentes en esta sesión.'
                    : 'Guarda primero el pase de lista: los ejercicios se registran solo a las alumnas Presentes.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(child: _buildLista(isDark, alumnasPresentes)),
            BarraGuardarAsistencia(
              label: 'Guardar Ejercicios y Participación',
              onGuardar: _guardando ? null : _guardar,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLista(bool isDark, List<RegistroAsistencia> alumnasPresentes) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NinasProColors.accent700.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: NinasProColors.accent700),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mostrando únicamente a las alumnas Presentes (US-28). '
                  'Las alumnas ausentes tienen bloqueado el registro de ejercicios.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (controller.pendienteDeEnvio) ...[const SizedBox(height: 10), const AvisoPendienteEnvio()],
        const SizedBox(height: 14),
        ...alumnasPresentes.map((reg) {
          final part = controller.participacionDe(reg);

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reg.alumnaNombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text('Ejercicios resueltos en aula:', style: TextStyle(fontSize: 12.5)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () {
                              if (part.ejerciciosResueltos > 0) {
                                controller.actualizarParticipacion(
                                  part.copyWith(ejerciciosResueltos: part.ejerciciosResueltos - 1),
                                );
                              }
                            },
                          ),
                          Text(
                            '${part.ejerciciosResueltos}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () {
                              controller.actualizarParticipacion(
                                part.copyWith(ejerciciosResueltos: part.ejerciciosResueltos + 1),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text('Participación activa en aula:', style: TextStyle(fontSize: 12.5)),
                      Switch(
                        value: part.participacionActiva,
                        activeThumbColor: NinasProColors.brandPink,
                        onChanged: (val) {
                          controller.actualizarParticipacion(part.copyWith(participacionActiva: val));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// Evidencia Fotográfica y Consentimientos de Imagen (US-18, US-19)
class FotosClaseView extends StatelessWidget {
  final ClaseSesionController controller;

  const FotosClaseView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.cargando) {
          return const Center(child: CircularProgressIndicator());
        }

        final alumnasSinFoto = controller.alumnasPresentes.where((r) => !r.autorizaImagen).toList();

        final todasConFoto = alumnasSinFoto.isEmpty;
        final fotoSubida = controller.fotoSubida;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            Card(
              elevation: 0,
              color: isDark ? NinasProColors.dark800 : NinasProColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          todasConFoto ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: todasConFoto ? NinasProColors.success700 : NinasProColors.warning700,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            todasConFoto
                                ? 'Foto 100% Apta para Redes / Sponsors'
                                : 'Atención: Restricción de Imagen',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (todasConFoto)
                      Text(
                        'Todas las alumnas presentes cuentan con autorización de imagen firmada por sus apoderados (US-19).',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                        ),
                      )
                    else ...[
                      Text(
                        'Las siguientes alumnas presentes NO tienen consentimiento de imagen:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...alumnasSinFoto.map((a) => Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Text(
                              '• ${a.alumnaNombre} (${a.alumnaRut})',
                              style: const TextStyle(
                                fontSize: 13,
                                color: NinasProColors.error700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )),
                      const SizedBox(height: 6),
                      const Text(
                        '⚠️ La fotografía de la clase debe tomarse de espaldas o difuminar los rostros.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: NinasProColors.warning900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? NinasProColors.dark800 : NinasProColors.neutral50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? NinasProColors.dark700 : NinasProColors.neutral300,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    fotoSubida ? Icons.photo_library_rounded : Icons.cloud_upload_outlined,
                    size: 48,
                    color: NinasProColors.brandPink,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fotoSubida
                        ? 'Evidencia fotográfica lista y comprimida en cliente'
                        : 'Subir foto de la sesión desde el celular (US-18)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: NinasProTheme.brandButton,
                    onPressed: () {
                      controller.marcarFotoSubida();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: NinasProColors.success700,
                          content: Text('📸 Foto comprimida (< 1.5 MB) y vinculada a la sesión.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: Text(fotoSubida ? 'Reemplazar Foto' : 'Tomar / Seleccionar Foto'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Modal para registrar podio Kahoot de la clase (US-29)
void mostrarModalRegistroKahoot(BuildContext context, ClaseSesionController controller) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final presentes = controller.alumnasPresentes;

  if (presentes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Guarda primero el pase de lista: el podio Kahoot se arma con las alumnas presentes.'),
      ),
    );
    return;
  }

  // Tantos lugares como presentes, hasta 3: con una sola, queda primera
  final cantidad = lugaresPodio(presentes.length);
  final guardado = controller.podioAlumnas;
  final lugares = <String>[];
  final ids = [for (final p in presentes) p.alumnaId];
  for (var i = 0; i < cantidad; i++) {
    // El podio guardado, si su alumna sigue presente; si no, la primera presente libre
    final previa = i < guardado.length ? guardado[i] : null;
    final valida = previa != null && ids.contains(previa) && !lugares.contains(previa);
    lugares.add(valida ? previa : ids.firstWhere((id) => !lugares.contains(id)));
  }
  String? error;
  const etiquetas = [
    '🥇 1° Lugar (Medalla de Oro):',
    '🥈 2° Lugar (Medalla de Plata):',
    '🥉 3° Lugar (Medalla de Bronce):',
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? NinasProColors.dark600 : NinasProColors.neutral300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NinasProColors.warning100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: NinasProColors.warning900, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Registrar Podio Kahoot (US-29)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  cantidad == 1
                      ? 'Hoy hay una sola alumna presente: queda en el 1° lugar. Se actualizará su historial.'
                      : 'Asigna las $cantidad alumnas ganadoras del desafío de hoy. Se actualizará su historial.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
                const SizedBox(height: 16),

                // Un selector por lugar (1°, 2° y 3°, según las presentes)
                for (var i = 0; i < cantidad; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _DropdownKahoot(
                    label: etiquetas[i],
                    selectedValue: lugares[i],
                    presentes: presentes,
                    onChanged: (val) {
                      if (val == null) return;
                      setModalState(() {
                        lugares[i] = val;
                        error = null;
                      });
                    },
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: NinasProColors.error700),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: NinasProTheme.brandButton,
                    onPressed: () async {
                      // US-29 escenario 2: una alumna distinta en cada lugar
                      if (lugares.toSet().length < lugares.length) {
                        setModalState(() => error = 'Elige una alumna distinta para cada lugar del podio.');
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final resultado = await controller.guardarPodioKahoot(lugares);
                      mostrarResultadoGuardado(messenger, resultado, exito: '🏆 Podio Kahoot registrado con éxito.');
                    },
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Guardar Podio de la Sesión'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _DropdownKahoot extends StatelessWidget {
  final String label;
  final String selectedValue;
  final List<RegistroAsistencia> presentes;
  final ValueChanged<String?> onChanged;

  const _DropdownKahoot({
    required this.label,
    required this.selectedValue,
    required this.presentes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedValue,
              dropdownColor: isDark ? NinasProColors.dark800 : NinasProColors.white,
              items: presentes.map((a) {
                return DropdownMenuItem(
                  value: a.alumnaId,
                  child: Text(a.alumnaNombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
