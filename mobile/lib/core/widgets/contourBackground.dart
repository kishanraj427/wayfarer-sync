import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/appSemanticColors.dart';

/// Paints a faint topographic-contour motif behind its child — the "field
/// instrument" signature used on auth and empty states. Colour is theme-aware.
class ContourBackground extends StatelessWidget {
  final Widget child;
  const ContourBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ContourPainter(context.semantic.contour),
      child: child,
    );
  }
}

class _ContourPainter extends CustomPainter {
  final Color color;
  _ContourPainter(this.color);

  static const _lineCount = 7;
  static const _amplitude = 16.0;
  static const _step = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var line = 0; line < _lineCount; line++) {
      final path = Path();
      final baseY = size.height * (line + 0.5) / _lineCount;
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += _step) {
        final y = baseY +
            _amplitude * math.sin((x / size.width) * math.pi * 2 + line * 0.7);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ContourPainter oldDelegate) =>
      oldDelegate.color != color;
}
