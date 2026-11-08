import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../theme/app_theme.dart';
import 'track_common.dart';

// Schematic face drawn in a 200 x 230 box; same zones as the web FaceMap.
const _w = 200.0;
const _h = 230.0;

const _ellipses = <String, Rect>{
  'forehead': Rect.fromLTRB(48, 38, 152, 78),
  'nose': Rect.fromLTRB(88, 86, 112, 138),
  'left_cheek': Rect.fromLTRB(38, 104, 82, 152),
  'right_cheek': Rect.fromLTRB(118, 104, 162, 152),
  'chin': Rect.fromLTRB(76, 164, 124, 192),
};

Path _jawPath() => Path()
  ..moveTo(42, 150)
  ..quadraticBezierTo(52, 190, 86, 202)
  ..moveTo(158, 150)
  ..quadraticBezierTo(148, 190, 114, 202);

/// Tap-to-toggle face map. The chips below the drawing do the same, so the
/// painting is never the only way to pick an area.
class FaceMap extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const FaceMap({super.key, required this.selected, required this.onToggle});

  String? _hit(Offset p) {
    for (final key in ['nose', 'chin', 'left_cheek', 'right_cheek', 'forehead']) {
      final r = _ellipses[key]!;
      final dx = (p.dx - r.center.dx) / (r.width / 2);
      final dy = (p.dy - r.center.dy) / (r.height / 2);
      if (dx * dx + dy * dy <= 1.2) return key;
    }
    for (final metric in _jawPath().computeMetrics()) {
      for (double d = 0; d <= metric.length; d += 4) {
        final point = metric.getTangentForOffset(d)!.position;
        if ((point - p).distance < 16) return 'jawline';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        SizedBox(
          width: 200,
          child: AspectRatio(
            aspectRatio: _w / _h,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                onTapUp: (details) {
                  final scale = _w / box.maxWidth;
                  final key = _hit(details.localPosition * scale);
                  if (key != null) onToggle(key);
                },
                child: CustomPaint(
                  painter: _FacePainter(colors: c, selected: selected),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final key in kAreas)
              TrackChip(
                label: context.tr('track.areas.$key'),
                selected: selected.contains(key),
                onTap: () => onToggle(key),
              ),
          ],
        ),
      ],
    );
  }
}

class _FacePainter extends CustomPainter {
  final AppColors colors;
  final List<String> selected;
  _FacePainter({required this.colors, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);

    canvas.drawOval(
      const Rect.fromLTRB(32, 24, 168, 216),
      Paint()..color = colors.surface2,
    );
    canvas.drawOval(
      const Rect.fromLTRB(32, 24, 168, 216),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.border,
    );

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colors.textLight;
    final fill = Paint()..color = colors.high.withValues(alpha: 0.45);

    _ellipses.forEach((key, rect) {
      if (selected.contains(key)) {
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, outline..color = colors.high);
      } else {
        _dashedOval(canvas, rect, outline..color = colors.textLight);
      }
    });

    final jaw = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = selected.contains('jawline')
          ? colors.high.withValues(alpha: 0.7)
          : colors.border;
    canvas.drawPath(_jawPath(), jaw);
  }

  // Dashed outline for unselected zones.
  void _dashedOval(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addOval(rect);
    for (final ui.PathMetric metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.selected.length != selected.length ||
      !old.selected.every(selected.contains) ||
      old.colors != colors;
}
