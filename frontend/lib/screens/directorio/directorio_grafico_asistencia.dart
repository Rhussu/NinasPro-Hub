import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../models/hub_models.dart';
import 'directorio_widgets.dart';

/// Gráfico de líneas de la asistencia clase a clase: eje X = fecha de la clase,
/// eje Y = % de alumnas presentes ese día.
///
/// - "Nacional": una línea con el promedio de todas las sedes (ponderado por alumnas).
/// - "Por sede": una línea por sede, con leyenda.
/// Al pasar el mouse se muestra una línea guía y el detalle de esa clase.
class GraficoAsistencia extends StatefulWidget {
  final List<SerieAsistencia> series;
  final double meta;

  const GraficoAsistencia({super.key, required this.series, this.meta = 80});

  @override
  State<GraficoAsistencia> createState() => _GraficoAsistenciaState();
}

/// Línea ya preparada para dibujar: nombre, color y % por índice de fecha (null si no hubo clase)
class _Linea {
  final String nombre;
  final Color color;
  final List<double?> valores;

  const _Linea(this.nombre, this.color, this.valores);
}

class _GraficoAsistenciaState extends State<GraficoAsistencia> {
  bool _porSede = false;
  int? _hover;

  // Colores categóricos validados para daltonismo (orden fijo: el color sigue a la sede)
  static const _coloresClaro = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A)];
  static const _coloresOscuro = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70)];

  List<DateTime> get _fechas {
    final fechas = {for (final s in widget.series) ...s.puntos.map((p) => p.fecha)}.toList()..sort();
    return fechas;
  }

  List<_Linea> _lineas(List<DateTime> fechas, bool isDark) {
    if (!_porSede) {
      final valores = [
        for (final f in fechas)
          () {
            final puntos = widget.series.expand((s) => s.puntos).where((p) => p.fecha == f);
            final total = puntos.fold(0, (t, p) => t + p.total);
            return total == 0 ? null : puntos.fold(0, (t, p) => t + p.presentes) * 100 / total;
          }(),
      ];
      return [_Linea('Nacional', isDark ? NinasProColors.primary300 : NinasProColors.primary700, valores)];
    }
    final colores = isDark ? _coloresOscuro : _coloresClaro;
    return [
      for (var i = 0; i < widget.series.length && i < colores.length; i++)
        _Linea(
          widget.series[i].sedeNombre,
          colores[i],
          [
            for (final f in fechas) widget.series[i].puntos.where((p) => p.fecha == f).firstOrNull?.porcentaje,
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fechas = _fechas;
    final lineas = _lineas(fechas, isDark);
    final colorTexto = isDark ? NinasProColors.neutral100 : NinasProColors.neutral900;
    final colorSecundario = isDark ? NinasProColors.neutral300 : NinasProColors.neutral500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controles y leyenda en una fila sobre el gráfico
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Nacional')),
                ButtonSegment(value: true, label: Text('Por sede')),
              ],
              selected: {_porSede},
              onSelectionChanged: (s) => setState(() {
                _porSede = s.first;
                _hover = null;
              }),
            ),
            if (_porSede)
              for (final l in lineas) _Leyenda(color: l.color, texto: l.nombre, colorTexto: colorTexto),
            _Leyenda(color: colorSecundario, texto: 'Meta ${widget.meta.round()}%', colorTexto: colorTexto, delgada: true),
          ],
        ),
        const SizedBox(height: 16),
        if (fechas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Aún no hay clases realizadas.')),
          )
        else
          SizedBox(
            height: 260,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final geometria = _Geometria(constraints.biggest, fechas.length);
                final hover = _hover;
                return MouseRegion(
                  onHover: (e) => setState(() => _hover = geometria.indiceMasCercano(e.localPosition.dx)),
                  onExit: (_) => setState(() => _hover = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => setState(() => _hover = geometria.indiceMasCercano(d.localPosition.dx)),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PintorAsistencia(
                              geometria: geometria,
                              fechas: fechas,
                              lineas: lineas,
                              meta: widget.meta,
                              hover: hover,
                              colorGrilla: isDark ? NinasProColors.dark600 : NinasProColors.neutral100,
                              colorEjes: colorSecundario,
                              colorSuperficie: isDark ? NinasProColors.dark800 : NinasProColors.white,
                            ),
                          ),
                        ),
                        if (hover != null)
                          _Tooltip(
                            geometria: geometria,
                            indice: hover,
                            fecha: fechas[hover],
                            lineas: lineas,
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Área de dibujo y conversión de datos a píxeles
class _Geometria {
  static const izquierda = 44.0;
  static const derecha = 16.0;
  static const arriba = 10.0;
  static const abajo = 28.0;

  final Size tamano;
  final int cantidad;

  const _Geometria(this.tamano, this.cantidad);

  double get ancho => tamano.width - izquierda - derecha;
  double get alto => tamano.height - arriba - abajo;

  double x(int indice) => cantidad == 1 ? izquierda + ancho / 2 : izquierda + ancho * indice / (cantidad - 1);
  double y(double porcentaje) => arriba + alto * (1 - porcentaje / 100);

  int indiceMasCercano(double dx) {
    if (cantidad == 1) return 0;
    final i = ((dx - izquierda) / ancho * (cantidad - 1)).round();
    return i.clamp(0, cantidad - 1);
  }
}

class _PintorAsistencia extends CustomPainter {
  final _Geometria geometria;
  final List<DateTime> fechas;
  final List<_Linea> lineas;
  final double meta;
  final int? hover;
  final Color colorGrilla;
  final Color colorEjes;
  final Color colorSuperficie;

  _PintorAsistencia({
    required this.geometria,
    required this.fechas,
    required this.lineas,
    required this.meta,
    required this.hover,
    required this.colorGrilla,
    required this.colorEjes,
    required this.colorSuperficie,
  });

  void _texto(Canvas canvas, String texto, Offset posicion, {TextAlign alinear = TextAlign.left, Color? color}) {
    final pintor = TextPainter(
      text: TextSpan(text: texto, style: TextStyle(fontSize: 11, color: color ?? colorEjes)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (alinear) {
      TextAlign.right => posicion.dx - pintor.width,
      TextAlign.center => posicion.dx - pintor.width / 2,
      _ => posicion.dx,
    };
    pintor.paint(canvas, Offset(dx, posicion.dy - pintor.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometria;
    final grilla = Paint()
      ..color = colorGrilla
      ..strokeWidth = 1;

    // Grilla horizontal y eje Y (0 a 100 %)
    for (final v in [0, 25, 50, 75, 100]) {
      final y = g.y(v.toDouble());
      canvas.drawLine(Offset(_Geometria.izquierda, y), Offset(size.width - _Geometria.derecha, y), grilla);
      _texto(canvas, '$v%', Offset(_Geometria.izquierda - 8, y), alinear: TextAlign.right);
    }

    // Meta de asistencia como referencia (su etiqueta va en la leyenda para no tapar las líneas)
    final yMeta = g.y(meta);
    canvas.drawLine(
      Offset(_Geometria.izquierda, yMeta),
      Offset(size.width - _Geometria.derecha, yMeta),
      Paint()
        ..color = colorEjes
        ..strokeWidth = 1,
    );

    // Eje X: fechas de las clases (se saltan etiquetas si no caben)
    final paso = math.max(1, (fechas.length * 48 / g.ancho).ceil());
    for (var i = 0; i < fechas.length; i += paso) {
      final f = fechas[i];
      _texto(
        canvas,
        '${'${f.day}'.padLeft(2, '0')}/${'${f.month}'.padLeft(2, '0')}',
        Offset(g.x(i), size.height - _Geometria.abajo / 2),
        alinear: TextAlign.center,
      );
    }

    // Línea guía del hover
    if (hover != null) {
      canvas.drawLine(
        Offset(g.x(hover!), _Geometria.arriba),
        Offset(g.x(hover!), _Geometria.arriba + g.alto),
        Paint()
          ..color = colorEjes
          ..strokeWidth = 1,
      );
    }

    // Líneas de datos: 2 px con uniones redondeadas; se cortan donde no hubo clase
    for (final linea in lineas) {
      final trazo = Paint()
        ..color = linea.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final camino = Path();
      var abierto = false;
      for (var i = 0; i < linea.valores.length; i++) {
        final v = linea.valores[i];
        if (v == null) {
          abierto = false;
          continue;
        }
        final p = Offset(g.x(i), g.y(v));
        abierto ? camino.lineTo(p.dx, p.dy) : camino.moveTo(p.dx, p.dy);
        abierto = true;
      }
      canvas.drawPath(camino, trazo);

      // Puntos de 8 px con anillo del color de la superficie; el del hover, más grande
      for (var i = 0; i < linea.valores.length; i++) {
        final v = linea.valores[i];
        if (v == null) continue;
        final centro = Offset(g.x(i), g.y(v));
        final radio = i == hover ? 6.0 : 4.0;
        canvas.drawCircle(centro, radio + 2, Paint()..color = colorSuperficie);
        canvas.drawCircle(centro, radio, Paint()..color = linea.color);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorAsistencia old) =>
      old.hover != hover || old.lineas != lineas || old.geometria.tamano != geometria.tamano;
}

class _Tooltip extends StatelessWidget {
  final _Geometria geometria;
  final int indice;
  final DateTime fecha;
  final List<_Linea> lineas;
  final bool isDark;

  const _Tooltip({
    required this.geometria,
    required this.indice,
    required this.fecha,
    required this.lineas,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const ancho = 230.0;
    final x = geometria.x(indice);
    // Se da vuelta al lado izquierdo cerca del borde derecho
    final izquierda = x + 12 + ancho > geometria.tamano.width ? x - 12 - ancho : x + 12;
    final colorTexto = isDark ? NinasProColors.neutral100 : NinasProColors.neutral900;

    return Positioned(
      left: izquierda,
      top: _Geometria.arriba,
      width: ancho,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? NinasProColors.dark700 : NinasProColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? NinasProColors.dark600 : NinasProColors.neutral100),
            boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Clase del ${formatearFecha(fecha)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colorTexto),
              ),
              const SizedBox(height: 6),
              for (final l in lineas)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Container(width: 10, height: 3, color: l.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l.nombre, style: TextStyle(fontSize: 12, color: colorTexto)),
                      ),
                      Text(
                        l.valores[indice] == null ? 'sin clase' : '${l.valores[indice]!.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorTexto),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  final Color colorTexto;

  /// Trazo de 1 px, para la línea de referencia de la meta
  final bool delgada;

  const _Leyenda({required this.color, required this.texto, required this.colorTexto, this.delgada = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: delgada ? 1 : 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(fontSize: 12.5, color: colorTexto)),
      ],
    );
  }
}
