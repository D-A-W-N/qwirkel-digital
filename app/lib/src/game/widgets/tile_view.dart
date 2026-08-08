import 'package:flutter/material.dart';
import 'package:qwirkle_core/qwirkle_core.dart';
import 'dart:math' as math;

Color colorForTileColor(TileColor color) {
  switch (color) {
    case TileColor.red:
      return const Color(0xFFE53935);
    case TileColor.orange:
      return const Color(0xFFFB8C00);
    case TileColor.yellow:
      return const Color(0xFFFDD835);
    case TileColor.green:
      return const Color(0xFF43A047);
    case TileColor.blue:
      return const Color(0xFF1E88E5);
    case TileColor.purple:
      return const Color(0xFF8E24AA);
  }
}

/// Zeichnet einen Qwirkle-Stein: dunkler Hintergrund mit dem Symbol in seiner Farbe.
class TileView extends StatelessWidget {
  final Tile tile;
  final double size;
  final bool highlighted;
  final Color highlightColor;

  const TileView({
    super.key,
    required this.tile,
    this.size = 40,
    this.highlighted = false,
    this.highlightColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(size * 0.15),
        border: highlighted
            ? Border.all(color: highlightColor, width: 3)
            : Border.all(color: Colors.black54, width: 1),
        // Ein zusätzlicher Glow macht die Hervorhebung auch bei kleiner
        // Kachelgröße/auf dem Handy klar erkennbar, statt sich nur auf die
        // (dort kaum wahrnehmbare) Randfarbe zu verlassen - Nutzer-Feedback:
        // die Farbe für gegnerische Züge muss "markanter und auffälliger"
        // sein.
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.75),
                  blurRadius: 10,
                  spreadRadius: 1.5,
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: CustomPaint(
        painter: _ShapePainter(colorForTileColor(tile.color), tile.shape),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  final Color color;
  final TileShape shape;

  _ShapePainter(this.color, this.shape);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    switch (shape) {
      case TileShape.circle:
        canvas.drawCircle(center, size.shortestSide / 2, paint);
        break;
      case TileShape.square:
        canvas.drawRect(Offset.zero & size, paint);
        break;
      case TileShape.diamond:
        final path = Path()
          ..moveTo(center.dx, 0)
          ..lineTo(size.width, center.dy)
          ..lineTo(center.dx, size.height)
          ..lineTo(0, center.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case TileShape.cross:
        final thickness = size.width * 0.34;
        final path = Path()
          ..addRect(
            Rect.fromCenter(
              center: center,
              width: size.width,
              height: thickness,
            ),
          )
          ..addRect(
            Rect.fromCenter(
              center: center,
              width: thickness,
              height: size.height,
            ),
          );
        canvas.drawPath(path, paint);
        break;
      case TileShape.star:
        canvas.drawPath(_starPath(center, size.shortestSide / 2), paint);
        break;
      case TileShape.clover:
        final r = size.shortestSide * 0.28;
        final offset = size.shortestSide * 0.24;
        canvas.drawCircle(center.translate(0, -offset), r, paint);
        canvas.drawCircle(center.translate(0, offset), r, paint);
        canvas.drawCircle(center.translate(-offset, 0), r, paint);
        canvas.drawCircle(center.translate(offset, 0), r, paint);
        canvas.drawCircle(center, r * 0.9, paint);
        break;
    }
  }

  Path _starPath(Offset center, double outerRadius) {
    const points = 5;
    final innerRadius = outerRadius * 0.42;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi / points) - math.pi / 2;
      final offset = center.translate(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape;
}
