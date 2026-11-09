import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../providers/locale_provider.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/locale_reload.dart';
import '../../widgets/track/track_common.dart';
import '../../widgets/track/track_empty_states.dart';

/// Weekly report: this week vs last week, with Share (text) and Save image
/// (a PNG drawn in-app and handed to the system share sheet).
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> with LocaleReloadMixin {
  final _service = TrackingService();
  late Future<WeeklyReport> _future = _service.getWeeklyReport();
  bool _busy = false;

  @override
  void reloadForLocale() => _future = _service.getWeeklyReport();

  void _reload() => setState(() => _future = _service.getWeeklyReport());

  String _shareText(WeeklyReport r) => context.trp('track.weekly.shareText', {
        'trend': r.trendLabel ?? context.tr('track.weekly.none'),
        'n': r.checkIns,
      });

  Future<void> _share(WeeklyReport r) async {
    try {
      await Share.share(_shareText(r), subject: context.tr('track.weekly.title'));
    } catch (_) {
      _showError();
    }
  }

  Future<void> _saveImage(WeeklyReport r, String lang) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final labels = _ReportLabels(
        none: context.tr('track.weekly.none'),
        trend: context.tr('track.weekly.trend'),
        avgSeverity: context.tr('track.weekly.avgSeverity'),
        sleep: context.tr('track.weekly.sleep'),
        stress: context.tr('track.weekly.stress'),
        checkins: context.tr('track.weekly.checkins'),
        topPattern: context.tr('track.weekly.topPattern'),
      );
      final bytes = await _renderPng(r, labels, lang, context.colors);
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: ['skin-report-${r.periodEnd}.png'],
        text: _shareText(r),
      );
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('track.weekly.shareError'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.watch<LocaleProvider>().lang;
    return TrackScaffold(
      title: context.tr('track.weekly.title'),
      body: FutureBuilder<WeeklyReport>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          if (snapshot.hasError) return TrackLoadError(onRetry: _reload);
          final r = snapshot.data!;
          if (r.checkIns == 0 && r.avgSeverityLastWeek == null) {
            return ListView(padding: const EdgeInsets.all(AppSpace.lg), children: const [StartEmptyState()]);
          }

          final none = context.tr('track.weekly.none');
          final stats = [
            (context.tr('track.weekly.avgSeverity'), r.avgSeverity?.toString() ?? none,
                r.avgSeverityLastWeek != null
                    ? context.trp('track.weekly.lastWeek', {'value': r.avgSeverityLastWeek!})
                    : context.tr('track.weekly.scale')),
            (context.tr('track.weekly.sleep'), r.avgSleep != null ? context.trp('track.hub.hoursShort', {'n': r.avgSleep!}) : none, null),
            (context.tr('track.weekly.stress'), r.avgStress != null ? context.trp('track.hub.stressOf', {'n': r.avgStress!}) : none, null),
            (context.tr('track.weekly.checkins'), '${r.checkIns} / ${r.checkInsOf}', null),
          ];
          final trendColor = r.trend == 'calmer' ? c.low : r.trend == 'more_active' ? c.high : c.text;

          return ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              Text(context.tr('track.weekly.subtitle'), style: TextStyle(color: c.textMuted)),
              const SizedBox(height: AppSpace.lg),
              TrackCard(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${shortDate(r.periodStart, lang)} – ${shortDate(r.periodEnd, lang)}'.toUpperCase(),
                      style: TextStyle(color: c.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(context.tr('track.weekly.trend'), style: TextStyle(color: c.textMuted)),
                    Text(r.trendLabel ?? none, style: AppTheme.display(c, size: 38).copyWith(color: trendColor)),
                    const SizedBox(height: AppSpace.lg),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpace.md,
                      crossAxisSpacing: AppSpace.md,
                      childAspectRatio: 1.35,
                      children: [
                        for (final s in stats)
                          Container(
                            padding: const EdgeInsets.all(AppSpace.md),
                            decoration: BoxDecoration(
                              color: c.primarySoft,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(s.$1, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
                                const SizedBox(height: 2),
                                Text(s.$2, style: AppTheme.display(c, size: 22)),
                                if (s.$3 != null)
                                  Text(s.$3!, style: TextStyle(color: c.textLight, fontSize: 11.5)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (r.topPatternText != null) ...[
                      const SizedBox(height: AppSpace.lg),
                      Text(
                        context.tr('track.weekly.topPattern').toUpperCase(),
                        style: TextStyle(color: c.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(r.topPatternText!, style: const TextStyle(height: 1.55)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _share(r),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(context.tr('track.weekly.share')),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _saveImage(r, lang),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(context.tr('track.weekly.saveImage')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportLabels {
  final String none, trend, avgSeverity, sleep, stress, checkins, topPattern;
  const _ReportLabels({
    required this.none,
    required this.trend,
    required this.avgSeverity,
    required this.sleep,
    required this.stress,
    required this.checkins,
    required this.topPattern,
  });
}

/// Draws the report card as a 1080 x 1080 PNG with dart:ui (no extra package).
Future<Uint8List> _renderPng(WeeklyReport r, _ReportLabels l, String lang, AppColors c) async {
  const size = 1080.0;
  const pad = 80.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = c.surface);
  canvas.drawRect(
    const Rect.fromLTWH(2, 2, size - 4, size - 4),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = c.border,
  );

  void text(String value, double x, double y, double fontSize, Color color,
      {FontWeight weight = FontWeight.w500, double maxWidth = size - pad * 2, int maxLines = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight, height: 1.3)),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(x, y));
  }

  text('DERMASCAN AI', pad, 90, 28, c.primary, weight: FontWeight.w700);
  text('${shortDate(r.periodStart, lang)} – ${shortDate(r.periodEnd, lang)}', pad, 136, 28, c.textMuted);
  text(r.trendLabel ?? l.none, pad, 210, 96, c.text, weight: FontWeight.w700);
  text(l.trend, pad, 330, 30, c.textMuted);

  final stats = [
    (l.avgSeverity, r.avgSeverity?.toString() ?? l.none),
    (l.sleep, r.avgSleep != null ? '${r.avgSleep} h' : l.none),
    (l.stress, r.avgStress != null ? '${r.avgStress} / 10' : l.none),
    (l.checkins, '${r.checkIns} / ${r.checkInsOf}'),
  ];
  const boxW = (size - pad * 2 - 30) / 2;
  for (var i = 0; i < stats.length; i++) {
    final x = pad + (i % 2) * (boxW + 30);
    final y = 400.0 + (i ~/ 2) * 190;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, boxW, 160), const Radius.circular(28)),
      Paint()..color = c.primarySoft,
    );
    text(stats[i].$1, x + 28, y + 24, 26, c.textMuted, weight: FontWeight.w600, maxWidth: boxW - 56);
    text(stats[i].$2, x + 28, y + 80, 56, c.text, weight: FontWeight.w700, maxWidth: boxW - 56);
  }

  if (r.topPatternText != null) {
    text(l.topPattern.toUpperCase(), pad, 800, 24, c.primary, weight: FontWeight.w700);
    text(r.topPatternText!, pad, 840, 32, c.text, maxLines: 5);
  }

  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
