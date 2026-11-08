import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../services/api_client.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/locale_reload.dart';
import '../../widgets/track/scatter_chart.dart';
import '../../widgets/track/track_common.dart';
import '../../widgets/track/track_empty_states.dart';

const _ranges = <String, ({double min, double max})>{
  'sleep': (min: 0, max: 12),
  'stress': (min: 1, max: 10),
  'acne': (min: 0, max: 3),
};

/// AI insights: computed patterns (phrased by the backend), the correlation
/// explorer and "Ask AI about my patterns".
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with LocaleReloadMixin {
  final _service = TrackingService();
  late Future<InsightsResult> _future = _service.getInsights();

  @override
  void reloadForLocale() => _future = _service.getInsights();

  void _reload() => setState(() => _future = _service.getInsights());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TrackScaffold(
      title: context.tr('track.insights.title'),
      body: FutureBuilder<InsightsResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          if (snapshot.hasError) return TrackLoadError(onRetry: _reload);
          final data = snapshot.data!;

          // Backend answers enough_data: false until enough days are logged.
          if (!data.enoughData) {
            return ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                data.loggedDays == 0
                    ? const StartEmptyState()
                    : NotEnoughDataState(logged: data.loggedDays, needed: data.minDays),
              ],
            );
          }

          final others = data.findings.where((f) => f.id != data.featured?.id).toList();
          return RefreshIndicator(
            color: c.primary,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: c.primary),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(data.disclaimer, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                if (data.featured != null) ...[
                  Text(context.tr('track.insights.featured'), style: AppTheme.display(c, size: 20)),
                  const SizedBox(height: AppSpace.md),
                  _InsightCard(insight: data.featured!, featured: true),
                  for (final f in others) ...[
                    const SizedBox(height: AppSpace.md),
                    _InsightCard(insight: f),
                  ],
                ] else
                  TrackCard(child: Text(context.tr('track.insights.none'), style: TextStyle(color: c.textMuted, height: 1.5))),
                const SizedBox(height: AppSpace.xl),
                const _CorrelationExplorer(),
                const SizedBox(height: AppSpace.xl),
                const _AskPanel(),
                const SizedBox(height: AppSpace.lg),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  final bool featured;
  const _InsightCard({required this.insight, this.featured = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final early = insight.strength == 'early_signal';
    return TrackCard(
      color: featured ? c.primarySoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.sm,
            children: [
              _Tag(insight.categoryLabel, c.surface2, c.textMuted),
              _Tag(insight.strengthLabel, early ? c.medSoft : c.primarySoft, early ? c.med : c.primary),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(insight.text, style: const TextStyle(fontSize: 15, height: 1.55)),
          const SizedBox(height: AppSpace.md),
          // A heuristic score (sample size + effect size), never a probability.
          Tooltip(
            message: context.tr('track.insights.confidenceTip'),
            triggerMode: TooltipTriggerMode.tap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('track.insights.confidence'), style: TextStyle(color: c.textMuted, fontSize: 12.5)),
                    Text('${insight.confidence}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (insight.confidence / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: c.primary,
                    backgroundColor: featured ? c.surface : c.surface2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _CorrelationExplorer extends StatefulWidget {
  const _CorrelationExplorer();

  @override
  State<_CorrelationExplorer> createState() => _CorrelationExplorerState();
}

class _CorrelationExplorerState extends State<_CorrelationExplorer> {
  final _service = TrackingService();
  String _x = 'sleep';
  String _y = 'acne';
  Future<Correlation>? _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getCorrelation(_x, _y);
  }

  void _change({String? x, String? y}) {
    setState(() {
      _x = x ?? _x;
      _y = y ?? _y;
      _future = _x == _y ? null : _service.getCorrelation(_x, _y);
    });
  }

  Widget _picker(BuildContext context, String label, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      items: [for (final m in kMetrics) DropdownMenuItem(value: m, child: Text(context.tr('track.insights.$m')))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('track.insights.correlation'), style: AppTheme.display(c, size: 20)),
          const SizedBox(height: AppSpace.xs),
          Text(context.tr('track.insights.correlationSub'), style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5)),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(child: _picker(context, context.tr('track.insights.xAxis'), _x, (v) => _change(x: v))),
              const SizedBox(width: AppSpace.md),
              Expanded(child: _picker(context, context.tr('track.insights.yAxis'), _y, (v) => _change(y: v))),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          if (_x == _y)
            Text(context.tr('track.insights.sameMetric'), style: TextStyle(color: c.med))
          else
            FutureBuilder<Correlation>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Text(context.tr('track.error'), style: TextStyle(color: c.high));
                }
                final result = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScatterChart(points: result.points, xRange: _ranges[_x]!, yRange: _ranges[_y]!),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      '${context.trp('track.insights.pairs', {'n': result.n})} · '
                      '${context.tr('track.insights.relation')}: '
                      '${result.r?.toString() ?? context.tr('track.insights.relationNone')}',
                      style: TextStyle(color: c.textLight, fontSize: 12.5),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AskPanel extends StatefulWidget {
  const _AskPanel();

  @override
  State<_AskPanel> createState() => _AskPanelState();
}

class _AskPanelState extends State<_AskPanel> with LocaleReloadMixin {
  final _service = TrackingService();
  final _controller = TextEditingController();
  List<SuggestedQuestion> _chips = [];
  AskAnswer? _answer;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadChips();
  }

  @override
  void reloadForLocale() => _loadChips();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadChips() async {
    try {
      final chips = await _service.getSuggestions();
      if (mounted) setState(() => _chips = chips);
    } catch (_) {
      if (mounted) setState(() => _chips = []);
    }
  }

  Future<void> _ask(String text, {String? chip}) async {
    final question = text.trim();
    if (question.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
      _controller.text = question;
    });
    try {
      final answer = await _service.ask(question, chip: chip);
      if (mounted) setState(() => _answer = answer);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : context.tr('track.insights.askError'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('track.insights.askTitle'), style: AppTheme.display(c, size: 20)),
          const SizedBox(height: AppSpace.xs),
          Text(context.tr('track.insights.askSub'), style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5)),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final chip in _chips)
                TrackChip(label: chip.text, selected: false, onTap: _busy ? null : () => _ask(chip.text, chip: chip.chip)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _controller,
            maxLength: 300,
            textInputAction: TextInputAction.send,
            onSubmitted: (v) => _ask(v),
            decoration: InputDecoration(
              hintText: context.tr('track.insights.askHint'),
              counterText: '',
              suffixIcon: IconButton(
                onPressed: _busy ? null : () => _ask(_controller.text),
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.send_rounded, color: c.primary),
                tooltip: context.tr('track.insights.ask'),
              ),
            ),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(context.tr('track.insights.thinking'), style: TextStyle(color: c.textMuted)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md),
              child: Text(_error!, style: TextStyle(color: c.high)),
            ),
          if (_answer != null)
            Container(
              margin: const EdgeInsets.only(top: AppSpace.md),
              padding: const EdgeInsets.only(left: AppSpace.md),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: c.primary, width: 3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_answer!.answer, style: const TextStyle(height: 1.55)),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    [
                      _answer!.source == 'ai'
                          ? context.tr('track.insights.answerAi')
                          : context.tr('track.insights.answerTemplate'),
                      if (_answer!.disclaimer.isNotEmpty) _answer!.disclaimer,
                    ].join(' · '),
                    style: TextStyle(color: c.textLight, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
