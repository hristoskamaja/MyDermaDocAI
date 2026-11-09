import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../models/recommendation.dart';
import '../../theme/app_theme.dart';
import '../../widgets/severity_pill.dart';

/// One text section (Overview / Symptoms / Treatment) shown either as a
/// segmented tab (when more than one is available) or as a plain labeled
/// block (when only one is available).
class _InfoTab {
  final String label;
  final String content;
  const _InfoTab(this.label, this.content);
}

/// Shared "result" layout used both for a freshly confident scan result
/// and for the History detail screen (reusing the same visual layout,
/// per spec).
///
/// Layout: photo -> compact hero card (severity + name + confidence +
/// disclaimer) -> Overview/Symptoms/Treatment as tabs instead of one long
/// stacked wall of text -> a prominent "Ask about this result" shortcut
/// that jumps straight to the chat section -> compact recommendation
/// cards -> primary action button -> the full chat section (trailing).
class ScanResultView extends StatefulWidget {
  final ImageProvider? image;
  final String conditionName;
  final String severity;
  final double confidence;
  final String? description;
  final String? symptoms;
  final String? treatmentOverview;
  final List<Recommendation> recommendations;
  final bool isLowConfidence;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final Widget? trailing;

  const ScanResultView({
    super.key,
    this.image,
    required this.conditionName,
    required this.severity,
    required this.confidence,
    this.description,
    this.symptoms,
    this.treatmentOverview,
    this.recommendations = const [],
    this.isLowConfidence = false,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.trailing,
  });

  @override
  State<ScanResultView> createState() => _ScanResultViewState();
}

class _ScanResultViewState extends State<ScanResultView> {
  int _tabIndex = 0;
  final GlobalKey _chatKey = GlobalKey();

  void _scrollToChat() {
    final chatContext = _chatKey.currentContext;
    if (chatContext == null) return;
    Scrollable.ensureVisible(
      chatContext,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (widget.confidence * 100).clamp(0, 100);

    final medical = widget.recommendations
        .where((r) => r.type == RecommendationType.medicalConsult)
        .toList();
    final selfCare = widget.recommendations
        .where((r) => r.type == RecommendationType.selfCare)
        .toList();
    final lifestyle = widget.recommendations
        .where((r) => r.type == RecommendationType.lifestyle)
        .toList();

    final tabs = <_InfoTab>[
      if ((widget.description ?? '').trim().isNotEmpty)
        _InfoTab(context.tr('result.overview'), widget.description!.trim()),
      if ((widget.symptoms ?? '').trim().isNotEmpty)
        _InfoTab(context.tr('result.symptoms'), widget.symptoms!.trim()),
      if ((widget.treatmentOverview ?? '').trim().isNotEmpty)
        _InfoTab(context.tr('result.treatment'), widget.treatmentOverview!.trim()),
    ];
    final activeTab = tabs.isEmpty ? null : tabs[_tabIndex.clamp(0, tabs.length - 1)];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: widget.image != null
                  ? Image(image: widget.image!, fit: BoxFit.cover)
                  : Container(
                      color: c.surface2,
                      child: Icon(Icons.image_rounded, color: c.textLight, size: 48),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Hero card: name, severity, confidence and the AI disclaimer
          // together in one compact block instead of spread across the page.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.conditionName,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SeverityPill(severity: widget.severity, isUncertain: widget.isLowConfidence),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 15, color: c.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      '${pct.toStringAsFixed(0)}% ${context.tr('result.confidenceSuffix')}',
                      style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('result.disclaimer'),
                  style: TextStyle(color: c.textLight, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),

          // Overview / Symptoms / Treatment: tabs when there's more than
          // one, otherwise a single plain labeled block.
          if (tabs.length > 1) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _tabButton(c, tabs[i].label, i == _tabIndex, () {
                    setState(() => _tabIndex = i);
                  })),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _tabContentCard(c, activeTab!.content),
          ] else if (tabs.length == 1) ...[
            const SizedBox(height: 18),
            Text(
              tabs.first.label.toUpperCase(),
              style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            _tabContentCard(c, tabs.first.content),
          ],

          if (widget.recommendations.isNotEmpty) ...[
            const SizedBox(height: 22),
            if (medical.isNotEmpty)
              _recGroup(c, context.tr('result.seeADoctor'), Icons.medical_services_rounded, c.high, c.highSoft, medical),
            if (selfCare.isNotEmpty)
              _recGroup(c, context.tr('result.selfCare'), Icons.spa_rounded, c.low, c.lowSoft, selfCare),
            if (lifestyle.isNotEmpty)
              _recGroup(c, context.tr('result.lifestyle'), Icons.favorite_rounded, c.primary, c.primarySoft, lifestyle),
          ],

          if (widget.trailing != null) ...[
            const SizedBox(height: 18),
            Material(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                onTap: _scrollToChat,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.forum_rounded, color: c.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('result.askAboutResult'),
                              style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('result.askAboutResultSub'),
                              style: TextStyle(color: c.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (widget.primaryActionLabel != null && widget.onPrimaryAction != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onPrimaryAction,
                child: Text(widget.primaryActionLabel!),
              ),
            ),
          ],

          if (widget.trailing != null) ...[
            const SizedBox(height: 28),
            Divider(color: c.border),
            const SizedBox(height: 20),
            KeyedSubtree(key: _chatKey, child: widget.trailing!),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(AppColors c, String label, bool active, VoidCallback onTap) {
    return Material(
      color: active ? c.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: active ? c.primary : c.border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? c.primary : c.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabContentCard(AppColors c, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: c.border),
      ),
      child: Text(
        content,
        style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.55),
      ),
    );
  }

  Widget _recGroup(
    AppColors c,
    String title,
    IconData icon,
    Color color,
    Color soft,
    List<Recommendation> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6),
          ),
          const SizedBox(height: 10),
          ...items.map((r) => _recItem(c, icon, color, soft, r)),
        ],
      ),
    );
  }

  Widget _recItem(AppColors c, IconData icon, Color color, Color soft, Recommendation r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                _recPart(c, context.tr('result.whatToDo'), r.description),
                _recPart(c, context.tr('result.whatToAvoid'), r.whatToAvoid),
                _recPart(c, context.tr('result.whenToSeeDoctor'), r.whenToSeeDoctor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One labeled paragraph of a recommendation; hidden when empty (older
  /// recommendations only have "what to do").
  Widget _recPart(AppColors c, String label, String? text) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.textLight,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text.trim(),
            style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
