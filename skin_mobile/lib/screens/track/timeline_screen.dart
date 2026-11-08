import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_config.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/locale_reload.dart';
import '../../widgets/track/timeline_chart.dart';
import '../../widgets/track/track_common.dart';
import '../../widgets/track/track_empty_states.dart';
import '../../widgets/track/tracking_photo.dart';

/// Skin timeline: acne severity with sleep / stress / cycle overlays, a
/// before/after photo compare, and the scans the user saved to tracking.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with LocaleReloadMixin {
  final _service = TrackingService();
  int _range = 30;
  late Future<TimelineData> _future = _load();

  bool _sleep = true;
  bool _stress = true;
  bool _cycle = true;
  int? _selected;
  String? _beforeDay;
  String? _afterDay;

  Future<TimelineData> _load() {
    final now = DateTime.now();
    return _service.getTimeline(
      from: isoDate(now.subtract(Duration(days: _range - 1))),
      to: isoDate(now),
    );
  }

  @override
  void reloadForLocale() => _future = _load();

  void _reload() => setState(() {
        _selected = null;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.watch<LocaleProvider>().lang;

    return TrackScaffold(
      title: context.tr('track.timeline.title'),
      body: FutureBuilder<TimelineData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          if (snapshot.hasError) return TrackLoadError(onRetry: _reload);
          final data = snapshot.data!;
          if (data.points.isEmpty) {
            return ListView(padding: const EdgeInsets.all(AppSpace.lg), children: const [StartEmptyState()]);
          }

          final photoDays = data.points.where((p) => p.hasPhoto).map((p) => p.date).toList();
          final before = photoDays.contains(_beforeDay) ? _beforeDay : (photoDays.length >= 2 ? photoDays.first : null);
          final after = photoDays.contains(_afterDay) ? _afterDay : (photoDays.length >= 2 ? photoDays.last : null);
          final selected = _selected != null && _selected! < data.points.length ? data.points[_selected!] : null;
          final phases = data.cyclePhases.map((p) => p.phase).toSet();

          return RefreshIndicator(
            color: c.primary,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                TrackSegmented<int>(
                  values: const [30, 90],
                  selected: _range,
                  labelOf: (v) => context.tr('track.timeline.range$v'),
                  onChanged: (v) {
                    _range = v;
                    _reload();
                  },
                ),
                const SizedBox(height: AppSpace.lg),
                TrackCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LegendDot(color: c.high, label: context.tr('track.timeline.acne')),
                          TrackChip(label: context.tr('track.timeline.sleep'), selected: _sleep, onTap: () => setState(() => _sleep = !_sleep)),
                          TrackChip(label: context.tr('track.timeline.stress'), selected: _stress, onTap: () => setState(() => _stress = !_stress)),
                          TrackChip(label: context.tr('track.timeline.cycle'), selected: _cycle, onTap: () => setState(() => _cycle = !_cycle)),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TimelineChart(
                        points: data.points,
                        phases: data.cyclePhases,
                        showSleep: _sleep,
                        showStress: _stress,
                        showCycle: _cycle,
                        selectedIndex: _selected,
                        onSelect: (i) => setState(() => _selected = i),
                        yLabel: (v) => context.tr('track.severity.${kSeverityKeys[v]}'),
                        xLabel: (d) => shortDate(d, lang),
                      ),
                      if (_cycle && phases.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.sm),
                        Wrap(
                          spacing: AppSpace.md,
                          children: [
                            for (final phase in phases)
                              LegendDot(color: phaseColor(c, phase), label: context.tr('track.phases.$phase')),
                          ],
                        ),
                      ],
                      if (selected != null) ...[
                        const Divider(height: AppSpace.xl),
                        _Readout(point: selected, lang: lang),
                      ],
                      const SizedBox(height: AppSpace.sm),
                      Text(context.tr('track.timeline.chartHint'), style: TextStyle(color: c.textLight, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(context.tr('track.timeline.beforeAfter'), style: AppTheme.display(c, size: 20)),
                const SizedBox(height: AppSpace.md),
                TrackCard(
                  child: photoDays.length < 2
                      ? Text(context.tr('track.timeline.needTwoPhotos'), style: TextStyle(color: c.textMuted, height: 1.5))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PhotoPick(
                                label: context.tr('track.timeline.before'),
                                days: photoDays,
                                value: before!,
                                lang: lang,
                                onChanged: (v) => setState(() => _beforeDay = v),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: _PhotoPick(
                                label: context.tr('track.timeline.after'),
                                days: photoDays,
                                value: after!,
                                lang: lang,
                                onChanged: (v) => setState(() => _afterDay = v),
                              ),
                            ),
                          ],
                        ),
                ),
                if (data.scans.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xl),
                  Text(context.tr('track.timeline.savedScans'), style: AppTheme.display(c, size: 20)),
                  const SizedBox(height: AppSpace.md),
                  for (final scan in data.scans) ...[
                    _ScanRow(scan: scan, lang: lang),
                    const SizedBox(height: AppSpace.sm),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  final TimelinePoint point;
  final String lang;
  const _Readout({required this.point, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parts = <String>[
      if (point.acneSeverity != null)
        '${context.tr('track.timeline.acne')}: ${context.tr('track.severity.${kSeverityKeys[point.acneSeverity!]}')}',
      if (point.sleepHours != null) '${context.tr('track.timeline.sleep')}: ${context.trp('track.hub.hoursShort', {'n': point.sleepHours!})}',
      if (point.stress != null) '${context.tr('track.timeline.stress')}: ${context.trp('track.hub.stressOf', {'n': point.stress!})}',
      if (point.cyclePhase != null) '${context.tr('track.timeline.cycle')}: ${context.tr('track.phases.${point.cyclePhase}')}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(shortDate(point.date, lang), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        for (final p in parts) Text(p, style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5)),
      ],
    );
  }
}

class _PhotoPick extends StatelessWidget {
  final String label;
  final List<String> days;
  final String value;
  final String lang;
  final ValueChanged<String> onChanged;
  const _PhotoPick({required this.label, required this.days, required this.value, required this.lang, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          items: [for (final d in days) DropdownMenuItem(value: d, child: Text(shortDate(d, lang)))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        const SizedBox(height: AppSpace.sm),
        TrackingPhoto(day: value),
      ],
    );
  }
}

class _ScanRow extends StatelessWidget {
  final TrackedScan scan;
  final String lang;
  const _ScanRow({required this.scan, required this.lang});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final area = scan.bodyArea.isEmpty ? null : context.tr('track.areas.${scan.bodyArea}');
    return TrackCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: SizedBox(
              width: 52,
              height: 52,
              child: scan.image == null
                  ? Container(color: c.surface2)
                  : Image.network(resolveMediaUrl(scan.image!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: c.surface2)),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.conditionName ?? '–', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  [shortDate(scan.date, lang), if (area != null) area].join(' · '),
                  style: TextStyle(color: c.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
