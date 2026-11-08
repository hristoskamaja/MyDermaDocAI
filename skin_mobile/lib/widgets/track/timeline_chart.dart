import 'package:flutter/material.dart';

import '../../models/tracking.dart';
import '../../theme/app_theme.dart';

/// Acne severity (0-3) as a filled line, with sleep and stress rescaled onto
/// the same 0-3 axis as dashed lines, and shaded cycle phases. Tapping near a
/// day reports its index through [onSelect] so the screen can show real values.
class TimelineChart extends StatelessWidget {
  final List<TimelinePoint> points;
  final List<CycleRange> phases;
  final bool showSleep;
  final bool showStress;
  final bool showCycle;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final String Function(int) yLabel;
  final String Function(String) xLabel;

  const TimelineChart({
    super.key,
    required this.points,
    required this.phases,
    required this.showSleep,
    required this.showStress,
    required this.showCycle,
    required this.selectedIndex,
    required this.onSelect,
    required this.yLabel,
    required this.xLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final painter = _TimelinePainter(
          c: c,
          points: points,
          phases: phases,
          showSleep: showSleep,
          showStress: showStress,
          showCycle: showCycle,
          selectedIndex: selectedIndex,
          yLabel: yLabel,
          xLabel: xLabel,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final index = painter.indexAt(d.localPosition.dx, box.maxWidth);
            if (index != null) onSelect(index);
          },
          child: CustomPaint(size: Size(box.maxWidth, 240), painter: painter),
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final AppColors c;
  final List<TimelinePoint> points;
  final List<CycleRange> phases;
  final bool showSleep;
  final bool showStress;
  final bool showCycle;
  final int? selectedIndex;
  final String Function(int) yLabel;
  final String Function(String) xLabel;

  static const double _left = 64;
  static const double _right = 8;
  static const double _top = 8;
  static const double _bottom = 24;

  _TimelinePainter({
    required this.c,
    required this.points,
    required this.phases,
    required this.showSleep,
    required this.showStress,
    required this.showCycle,
    required this.selectedIndex,
    required this.yLabel,
    required this.xLabel,
  });

  double _x(int i, double width) {
    final inner = width - _left - _right;
    if (points.length <= 1) return _left + inner / 2;
    return _left + inner * i / (points.length - 1);
  }

  double _y(double value, double height) {
    final inner = height - _top - _bottom;
    return _top + inner * (1 - value / 3);
  }

  int? indexAt(double dx, double width) {
    if (points.isEmpty) return null;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (dx - _x(i, width)).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  Color _phaseColor(String phase) {
    switch (phase) {
      case 'menstrual':
        return c.highSoft;
      case 'follicular':
        return c.lowSoft;
      case 'ovulation':
        return c.primarySoft;
      default:
        return c.medSoft;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width;
    final h = size.height;

    final index = {for (var i = 0; i < points.length; i++) points[i].date: i};

    if (showCycle) {
      for (final p in phases) {
        final a = index[p.start];
        final b = index[p.end];
        if (a == null || b == null) continue;
        final step = points.length > 1 ? (w - _left - _right) / (points.length - 1) : 0;
        canvas.drawRect(
          Rect.fromLTRB(_x(a, w) - step / 2, _top, _x(b, w) + step / 2, h - _bottom),
          Paint()..color = _phaseColor(p.phase).withValues(alpha: 0.8),
        );
      }
    }

    final grid = Paint()
      ..color = c.border
      ..strokeWidth = 1;
    for (var level = 0; level <= 3; level++) {
      final y = _y(level.toDouble(), h);
      canvas.drawLine(Offset(_left, y), Offset(w - _right, y), grid);
      _text(canvas, yLabel(level), Offset(0, y - 7), c.textMuted, 10.5, maxWidth: _left - 6);
    }

    // X labels: first, middle, last.
    for (final i in {0, points.length ~/ 2, points.length - 1}) {
      final label = xLabel(points[i].date);
      _text(canvas, label, Offset(_x(i, w) - 20, h - 16), c.textMuted, 10.5, maxWidth: 40, center: true);
    }

    if (showSleep) {
      _line(canvas, w, h, (p) => p.sleepHours == null ? null : p.sleepHours! / 12 * 3, c.primary, dashed: true);
    }
    if (showStress) {
      _line(canvas, w, h, (p) => p.stress == null ? null : p.stress! / 10 * 3, c.med, dashed: true);
    }
    _line(canvas, w, h, (p) => p.acneSeverity?.toDouble(), c.high, width: 3, fill: true, dots: true);

    if (selectedIndex != null && selectedIndex! < points.length) {
      final x = _x(selectedIndex!, w);
      canvas.drawLine(
        Offset(x, _top),
        Offset(x, h - _bottom),
        Paint()
          ..color = c.textLight
          ..strokeWidth = 1,
      );
    }
  }

  void _line(
    Canvas canvas,
    double w,
    double h,
    double? Function(TimelinePoint) value,
    Color color, {
    double width = 2,
    bool dashed = false,
    bool fill = false,
    bool dots = false,
  }) {
    final path = Path();
    final area = Path();
    Offset? first;
    Offset? last;
    final dotPoints = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final v = value(points[i]);
      if (v == null) continue;
      final o = Offset(_x(i, w), _y(v, h));
      if (first == null) {
        path.moveTo(o.dx, o.dy);
        area.moveTo(o.dx, h - _bottom);
        area.lineTo(o.dx, o.dy);
        first = o;
      } else {
        path.lineTo(o.dx, o.dy);
        area.lineTo(o.dx, o.dy);
      }
      last = o;
      dotPoints.add(o);
    }
    if (first == null || last == null) return;

    if (fill) {
      area.lineTo(last.dx, h - _bottom);
      area.close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.08));
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    if (dashed) {
      for (final metric in path.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 9) {
          canvas.drawPath(metric.extractPath(d, d + 5), paint);
        }
      }
    } else {
      canvas.drawPath(path, paint);
    }

    if (dots) {
      for (final o in dotPoints) {
        canvas.drawCircle(o, 3, Paint()..color = color);
      }
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color, double size,
      {double maxWidth = 80, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      textAlign: center ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: maxWidth, minWidth: center ? maxWidth : 0);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => true;
}

/// Small colored swatch + label used in legends.
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: AppSpace.xs + 2),
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Colors for the legend of a cycle phase (mirrors the chart shading).
Color phaseColor(AppColors c, String phase) {
  switch (phase) {
    case 'menstrual':
      return c.highSoft;
    case 'follicular':
      return c.lowSoft;
    case 'ovulation':
      return c.primarySoft;
    default:
      return c.medSoft;
  }
}
