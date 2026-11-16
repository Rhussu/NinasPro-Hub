import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/ninaspro_colors.dart';
import '../../config/ninaspro_theme.dart';

/// Piezas visuales compartidas por las vistas de escritorio de la Directiva y sus Ajustes.
///
/// - [DirectorioEncabezado]: título de la sección con sus acciones a la derecha.
/// - [DirectorioPanel]: tarjeta con borde suave, opcionalmente con título.
/// - [DirectorioChip]: etiqueta de estado con los colores semánticos.
/// - [DirectorioTabla]: [DataTable] con scroll horizontal y mensaje cuando está vacía.
/// - [DirectorioMenuLateral]: barra lateral de navegación (escritorio y Ajustes).
/// - [FiltroDesplegable] y [CampoFormulario]: controles de filtros y formularios.

/// Fecha corta en formato chileno: 25/04/2026
String formatearFecha(DateTime? fecha) {
  if (fecha == null) return '—';
  final d = '${fecha.day}'.padLeft(2, '0');
  final m = '${fecha.month}'.padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

/// Fecha y hora: 25/04/2026 09:05
String formatearFechaHora(DateTime fecha) {
  final h = '${fecha.hour}'.padLeft(2, '0');
  final min = '${fecha.minute}'.padLeft(2, '0');
  return '${formatearFecha(fecha)} $h:$min';
}

const nombresDiaSemana = {
  DateTime.monday: 'Lunes',
  DateTime.tuesday: 'Martes',
  DateTime.wednesday: 'Miércoles',
  DateTime.thursday: 'Jueves',
  DateTime.friday: 'Viernes',
  DateTime.saturday: 'Sábado',
  DateTime.sunday: 'Domingo',
};

/// Aviso breve en la parte inferior. [error] lo muestra en rojo.
void mostrarAviso(BuildContext context, String mensaje, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: error ? NinasProColors.error700 : NinasProColors.primary700,
      content: Text(mensaje),
    ),
  );
}

/// Abre un selector de fecha con los textos en español.
Future<DateTime?> elegirFecha(
  BuildContext context, {
  DateTime? inicial,
  DateTime? primera,
  DateTime? ultima,
}) {
  return showDatePicker(
    context: context,
    initialDate: inicial ?? DateTime(2026, 4, 25),
    firstDate: primera ?? DateTime(2020),
    lastDate: ultima ?? DateTime(2030, 12, 31),
    helpText: 'Elegir fecha',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
  );
}

class DirectorioEncabezado extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  const DirectorioEncabezado({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: isDark ? NinasProColors.white : NinasProColors.primary900,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
                  ),
                ),
              ],
            ],
          ),
          if (acciones.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: acciones),
        ],
      ),
    );
  }
}

class DirectorioPanel extends StatelessWidget {
  final String? titulo;
  final Widget? accion;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DirectorioPanel({
    super.key,
    this.titulo,
    this.accion,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isDark ? NinasProColors.dark800 : NinasProColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo!,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    ),
                  ),
                  ?accion,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Tono semántico de un [DirectorioChip]
enum TonoChip { exito, advertencia, error, info, neutro }

class DirectorioChip extends StatelessWidget {
  final String texto;
  final TonoChip tono;
  final IconData? icono;

  const DirectorioChip(this.texto, {super.key, this.tono = TonoChip.neutro, this.icono});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = context.statusColors;
    final StatusTone tone = switch (tono) {
      TonoChip.exito => status.success,
      TonoChip.advertencia => status.warning,
      TonoChip.error => status.error,
      TonoChip.info => status.info,
      TonoChip.neutro => isDark
          ? const StatusTone(foreground: NinasProColors.primary100, background: NinasProColors.primary900)
          : const StatusTone(foreground: NinasProColors.primary900, background: NinasProColors.primary100),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: tone.decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: tone.foreground),
            const SizedBox(width: 4),
          ],
          Text(texto, style: tone.textStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Tono del chip según el estado de una alumna o voluntaria
TonoChip tonoEstado(String estado) => switch (estado) {
      'activa' => TonoChip.exito,
      'preinscrita' => TonoChip.info,
      'retirada' => TonoChip.error,
      'inactiva' => TonoChip.advertencia,
      _ => TonoChip.neutro,
    };

/// 'preinscrita' -> 'Preinscrita'
String etiquetaEstado(String estado) =>
    estado.isEmpty ? estado : '${estado[0].toUpperCase()}${estado.substring(1)}';

class DirectorioTabla extends StatelessWidget {
  final List<String> columnas;
  final List<DataRow> filas;
  final String mensajeVacio;

  const DirectorioTabla({
    super.key,
    required this.columnas,
    required this.filas,
    this.mensajeVacio = 'No hay registros con estos filtros.',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (filas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            mensajeVacio,
            style: TextStyle(color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 40,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 60,
            horizontalMargin: 12,
            columnSpacing: 20,
            headingTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
            ),
            dataTextStyle: TextStyle(
              fontSize: 13,
              color: isDark ? NinasProColors.neutral100 : NinasProColors.neutral900,
            ),
            columns: [for (final c in columnas) DataColumn(label: Text(c))],
            rows: filas,
          ),
        ),
      ),
    );
  }
}

/// Opción de la barra lateral
@immutable
class OpcionMenuLateral {
  final IconData icono;
  final String etiqueta;

  const OpcionMenuLateral(this.icono, this.etiqueta);
}

class DirectorioMenuLateral extends StatelessWidget {
  final List<OpcionMenuLateral> opciones;
  final int seleccionada;
  final ValueChanged<int> onSeleccionar;
  final Widget? encabezado;

  const DirectorioMenuLateral({
    super.key,
    required this.opciones,
    required this.seleccionada,
    required this.onSeleccionar,
    this.encabezado,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: isDark ? NinasProColors.dark800 : NinasProColors.white,
        border: Border(
          right: BorderSide(color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        children: [
          if (encabezado != null) ...[encabezado!, const SizedBox(height: 12)],
          for (var i = 0; i < opciones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _OpcionMenu(
                opcion: opciones[i],
                seleccionada: i == seleccionada,
                onTap: () => onSeleccionar(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpcionMenu extends StatelessWidget {
  final OpcionMenuLateral opcion;
  final bool seleccionada;
  final VoidCallback onTap;

  const _OpcionMenu({required this.opcion, required this.seleccionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorTexto = seleccionada
        ? (isDark ? NinasProColors.white : NinasProColors.primary900)
        : (isDark ? NinasProColors.neutral300 : NinasProColors.neutral700);

    return Material(
      color: seleccionada
          ? (isDark ? NinasProColors.primary900 : NinasProColors.primary100)
          : NinasProColors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                opcion.icono,
                size: 20,
                color: seleccionada
                    ? (isDark ? NinasProColors.brandPink : NinasProColors.primary700)
                    : colorTexto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  opcion.etiqueta,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: seleccionada ? FontWeight.w800 : FontWeight.w600,
                    color: colorTexto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menú desplegable de filtro con la opción "Todas" (valor null)
class FiltroDesplegable<T> extends StatelessWidget {
  final String etiqueta;
  final T? valor;
  final Map<T, String> opciones;
  final ValueChanged<T?> onChanged;
  final double ancho;

  const FiltroDesplegable({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.ancho = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: DropdownButtonFormField<T?>(
        // La key fuerza a redibujar cuando el valor cambia desde afuera (ej. al limpiar filtros)
        key: ValueKey(valor),
        initialValue: opciones.containsKey(valor) ? valor : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder(), isDense: true),
        items: [
          DropdownMenuItem<T?>(
            value: null,
            child: const Text('Todas', style: TextStyle(color: NinasProColors.neutral500)),
          ),
          for (final e in opciones.entries)
            DropdownMenuItem<T?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Campo de texto con borde, usado en los formularios de los diálogos
class CampoFormulario extends StatelessWidget {
  final TextEditingController controller;
  final String etiqueta;
  final String? ayuda;
  final String? Function(String?)? validator;
  final TextInputType? teclado;
  final int maxLineas;
  final List<TextInputFormatter>? formateadores;

  const CampoFormulario({
    super.key,
    required this.controller,
    required this.etiqueta,
    this.ayuda,
    this.validator,
    this.teclado,
    this.maxLineas = 1,
    this.formateadores,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: teclado,
        maxLines: maxLineas,
        validator: validator,
        inputFormatters: formateadores,
        decoration: InputDecoration(
          labelText: etiqueta,
          helperText: ayuda,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Validador de campo obligatorio
String? obligatorio(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? 'Este campo es obligatorio' : null;
