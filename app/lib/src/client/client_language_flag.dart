import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints small, dependency-free flag marks used by the language switcher.
class BrazilFlagPainter extends CustomPainter {
  const BrazilFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 70, size.height / 50);
    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 70, 50),
      paint..color = const Color(0xff009b3a),
    );
    final diamond = Path()
      ..moveTo(35, 5)
      ..lineTo(65, 25)
      ..lineTo(35, 45)
      ..lineTo(5, 25)
      ..close();
    canvas.drawPath(diamond, paint..color = const Color(0xffffdf00));
    canvas.drawCircle(
      const Offset(35, 25),
      11,
      paint..color = const Color(0xff002776),
    );
    final band = Path()
      ..moveTo(24.5, 22.4)
      ..cubicTo(31, 20.8, 39, 22, 45.3, 27.4)
      ..lineTo(44.2, 29)
      ..cubicTo(38, 24, 31, 23.1, 25, 24.2)
      ..close();
    canvas.drawPath(band, paint..color = Colors.white);
    paint.color = Colors.white;
    for (final point in const [
      Offset(29, 28),
      Offset(32, 31),
      Offset(36, 29),
      Offset(39, 32),
      Offset(35, 34),
      Offset(39, 19),
    ]) {
      canvas.drawCircle(point, .85, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BrazilFlagPainter oldDelegate) => false;
}

class UnitedStatesFlagPainter extends CustomPainter {
  const UnitedStatesFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 60, size.height / 40);
    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 60, 40),
      paint..color = Colors.white,
    );
    paint.color = const Color(0xffb22234);
    for (var stripe = 0; stripe < 7; stripe++) {
      canvas.drawRect(
        Rect.fromLTWH(0, stripe * (40 / 13) * 2, 60, 40 / 13),
        paint,
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 24, 21.54),
      paint..color = const Color(0xff3c3b6e),
    );
    paint.color = Colors.white;
    for (var row = 0; row < 9; row++) {
      final count = row.isEven ? 6 : 5;
      for (var column = 0; column < count; column++) {
        final x = row.isEven ? 2 + column * 4 : 4 + column * 4;
        final y = 1.7 + row * 2.25;
        _drawStar(canvas, Offset(x.toDouble(), y), 1.08, paint);
      }
    }
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final angle = -math.pi / 2 + point * math.pi / 5;
      final r = point.isEven ? radius : radius * .42;
      final offset = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (point == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant UnitedStatesFlagPainter oldDelegate) => false;
}
