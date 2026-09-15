import 'package:flutter/material.dart';

/// Clips a widget's bottom edge into a gentle wave, mirroring the web app's
/// decorative header shape (skin_web/src/components/decor/PageHeroWave.jsx),
/// so the mobile and web hero bands share the same visual motif.
class HeroWaveClipper extends CustomClipper<Path> {
  const HeroWaveClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.571)
      ..cubicTo(
        w * 0.79, h * 0.905,
        w * 0.486, h * 1.0,
        w * 0.25, h * 0.762,
      )
      ..cubicTo(
        w * 0.118, h * 0.619,
        w * 0.0417, h * 0.524,
        0, h * 0.619,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Faint scattered dots over the hero band, echoing the "skin spots being
/// examined" motif used on the web hero/features bands.
class HeroDotsPainter extends CustomPainter {
  const HeroDotsPainter();

  void _dot(Canvas canvas, Size size, double fx, double fy, double r, double opacity) {
    canvas.drawCircle(
      Offset(size.width * fx, size.height * fy),
      r,
      Paint()..color = Colors.white.withOpacity(opacity),
    );
  }

  void _ring(Canvas canvas, Size size, double fx, double fy, double r, double opacity) {
    canvas.drawCircle(
      Offset(size.width * fx, size.height * fy),
      r,
      Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _dot(canvas, size, 0.08, 0.20, 4, 0.30);
    _dot(canvas, size, 0.16, 0.40, 3, 0.20);
    _dot(canvas, size, 0.05, 0.58, 5, 0.16);
    _dot(canvas, size, 0.90, 0.16, 4, 0.28);
    _dot(canvas, size, 0.82, 0.42, 3, 0.20);
    _ring(canvas, size, 0.93, 0.60, 6, 0.24);
    _dot(canvas, size, 0.93, 0.60, 2, 0.26);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
