import 'package:flutter/material.dart';

import '../../models/tracking.dart';
import '../../theme/app_theme.dart';

/// Minimal scatter plot for the correlation explorer. Axis ranges are fixed
/// per metric (sleep 0-12 h, stress 1-10, acne 0-3) so charts are comparable.
class ScatterChart extends StatelessWidget {
  final List<CorrelationPoint> points;
  final ({double min, double max}) xRange;
  final ({double min, double max}) yRange;

  const ScatterChart({
    super.key,
    required this.points,
    required this.xRange,
    required this.yRange,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: CustomPaint(
        painter: _ScatterPainter(c: c, points: points, xr: xRange, yr: yRange),
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  final AppColors c;
  final List<CorrelationPoint> points;
  final ({double min, double max}) xr;
  final ({double min, double max}) yr;

  _ScatterPainter({required this.c, required this.points, required this.xr, required this.yr});

  static const double _pad = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(_pad, 8, size.width - _pad - 8, size.height - _pad - 8);

    final grid = Paint()
      ..color = c.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final dx = plot.left + plot.width * i / 4;
      final dy = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(dx, plot.top), Offset(dx, plot.bottom), grid);
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), grid);
    }

    _label(canvas, _fmt(xr.min), Offset(plot.left - 4, plot.bottom + 4));
    _label(canvas, _fmt(xr.max), Offset(plot.right - 8, plot.bottom + 4));
    _label(canvas, _fmt(yr.min), Offset(2, plot.bottom - 12));
    _label(canvas, _fmt(yr.max), Offset(2, plot.top));

    final dot = Paint()..color = c.primary.withValues(alpha: 0.55);
    for (final p in points) {
      final x = plot.left + plot.width * ((p.x - xr.min) / (xr.max - xr.min)).clamp(0.0, 1.0);
      final y = plot.bottom - plot.height * ((p.y - yr.min) / (yr.max - yr.min)).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, y), 5, dot);
    }
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: c.textMuted, fontSize: 10.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ScatterPainter old) => old.points != points || old.c != c;
}
