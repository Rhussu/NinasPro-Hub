import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';

/// Mascota de NiñasPro: Gatita robot con gafas y laptop espacial,
/// acompañada de estrellas y micro-íconos de ciencia/tecnología.
///
/// Diseñada con [CustomPainter] y los colores oficiales de [NinasProColors].
class NinasProMascot extends StatelessWidget {
  final double size;
  final bool showStars;

  const NinasProMascot({
    super.key,
    this.size = 100,
    this.showStars = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MascotPainter(showStars: showStars),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final bool showStars;

  _MascotPainter({required this.showStars});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.45);

    final pinkPaint = Paint()
      ..color = NinasProColors.brandPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.024).clamp(1.5, 3.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPink = Paint()
      ..color = NinasProColors.brandPink.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = NinasProColors.brandPink.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Halo brillante de fondo
    canvas.drawCircle(center, w * 0.35, glowPaint);

    // Orejas de gatita
    final leftEar = Path()
      ..moveTo(center.dx - w * 0.26, center.dy - h * 0.14)
      ..lineTo(center.dx - w * 0.32, center.dy - h * 0.38)
      ..lineTo(center.dx - w * 0.12, center.dy - h * 0.28)
      ..close();
    canvas.drawPath(leftEar, fillPink);
    canvas.drawPath(leftEar, pinkPaint);

    final rightEar = Path()
      ..moveTo(center.dx + w * 0.26, center.dy - h * 0.14)
      ..lineTo(center.dx + w * 0.32, center.dy - h * 0.38)
      ..lineTo(center.dx + w * 0.12, center.dy - h * 0.28)
      ..close();
    canvas.drawPath(rightEar, fillPink);
    canvas.drawPath(rightEar, pinkPaint);

    // Casco / Cabeza redonda
    final headRect = Rect.fromCircle(center: center, radius: w * 0.30);
    canvas.drawOval(headRect, fillPink);
    canvas.drawOval(headRect, pinkPaint);

    // Antena espacial superior
    canvas.drawLine(
      Offset(center.dx, center.dy - w * 0.30),
      Offset(center.dx, center.dy - w * 0.42),
      pinkPaint,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy - w * 0.44),
      w * 0.04,
      Paint()
        ..color = NinasProColors.brandPink
        ..style = PaintingStyle.fill,
    );

    // Visor / Lentes redondos grandes de gatita
    final leftEyeCenter = Offset(center.dx - w * 0.12, center.dy - h * 0.04);
    final rightEyeCenter = Offset(center.dx + w * 0.12, center.dy - h * 0.04);
    final eyeRadius = w * 0.09;

    canvas.drawCircle(leftEyeCenter, eyeRadius, pinkPaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius, pinkPaint);

    // Puente de los lentes
    canvas.drawLine(
      Offset(leftEyeCenter.dx + eyeRadius, leftEyeCenter.dy),
      Offset(rightEyeCenter.dx - eyeRadius, rightEyeCenter.dy),
      pinkPaint,
    );

    // Pupilas sonrientes
    final pupilPaint = Paint()
      ..color = NinasProColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(leftEyeCenter, eyeRadius * 0.45, pupilPaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius * 0.45, pupilPaint);

    // Bigotitos laterales robóticos
    canvas.drawLine(
      Offset(center.dx - w * 0.28, center.dy + h * 0.05),
      Offset(center.dx - w * 0.38, center.dy + h * 0.03),
      pinkPaint,
    );
    canvas.drawLine(
      Offset(center.dx - w * 0.28, center.dy + h * 0.11),
      Offset(center.dx - w * 0.37, center.dy + h * 0.14),
      pinkPaint,
    );
    canvas.drawLine(
      Offset(center.dx + w * 0.28, center.dy + h * 0.05),
      Offset(center.dx + w * 0.38, center.dy + h * 0.03),
      pinkPaint,
    );
    canvas.drawLine(
      Offset(center.dx + w * 0.28, center.dy + h * 0.11),
      Offset(center.dx + w * 0.37, center.dy + h * 0.14),
      pinkPaint,
    );

    // Nariz y boquita tierna
    final mouthPath = Path()
      ..moveTo(center.dx - w * 0.05, center.dy + h * 0.12)
      ..quadraticBezierTo(
        center.dx - w * 0.025,
        center.dy + h * 0.16,
        center.dx,
        center.dy + h * 0.12,
      )
      ..quadraticBezierTo(
        center.dx + w * 0.025,
        center.dy + h * 0.16,
        center.dx + w * 0.05,
        center.dy + h * 0.12,
      );
    canvas.drawPath(mouthPath, pinkPaint);

    // Laptop en el regazo
    final laptopBase = Rect.fromCenter(
      center: Offset(center.dx, h * 0.84),
      width: w * 0.52,
      height: h * 0.08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(laptopBase, const Radius.circular(3)),
      pinkPaint,
    );

    // Pantalla de la laptop abierta
    final screenPath = Path()
      ..moveTo(center.dx - w * 0.22, h * 0.82)
      ..lineTo(center.dx - w * 0.18, h * 0.62)
      ..lineTo(center.dx + w * 0.18, h * 0.62)
      ..lineTo(center.dx + w * 0.22, h * 0.82)
      ..close();
    canvas.drawPath(screenPath, fillPink);
    canvas.drawPath(screenPath, pinkPaint);

    // Logo código `</>` o corazón en la tapa de la laptop
    canvas.drawLine(
      Offset(center.dx - w * 0.06, h * 0.72),
      Offset(center.dx - w * 0.02, h * 0.70),
      pinkPaint,
    );
    canvas.drawLine(
      Offset(center.dx - w * 0.02, h * 0.70),
      Offset(center.dx - w * 0.06, h * 0.68),
      pinkPaint,
    );
    canvas.drawLine(
      Offset(center.dx + w * 0.06, h * 0.72),
      Offset(center.dx + w * 0.02, h * 0.70),
      pinkPaint,
    );
    canvas.drawLine(
      Offset(center.dx + w * 0.02, h * 0.70),
      Offset(center.dx + w * 0.06, h * 0.68),
      pinkPaint,
    );

    // Estrellitas destellantes ✨ alrededor
    if (showStars) {
      _drawSparkle(canvas, Offset(w * 0.15, h * 0.15), w * 0.06, pinkPaint);
      _drawSparkle(canvas, Offset(w * 0.86, h * 0.22), w * 0.08, pinkPaint);
      _drawSparkle(canvas, Offset(w * 0.88, h * 0.72), w * 0.05, pinkPaint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset pt, double radius, Paint paint) {
    final path = Path()
      ..moveTo(pt.dx, pt.dy - radius)
      ..quadraticBezierTo(pt.dx, pt.dy, pt.dx + radius, pt.dy)
      ..quadraticBezierTo(pt.dx, pt.dy, pt.dx, pt.dy + radius)
      ..quadraticBezierTo(pt.dx, pt.dy, pt.dx - radius, pt.dy)
      ..quadraticBezierTo(pt.dx, pt.dy, pt.dx, pt.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.showStars != showStars;
}
