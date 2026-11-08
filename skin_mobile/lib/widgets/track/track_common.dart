import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../theme/app_theme.dart';

/// Local calendar date as YYYY-MM-DD (not UTC).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseIso(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsMk = ['јан', 'фев', 'мар', 'апр', 'мај', 'јун', 'јул', 'авг', 'сеп', 'окт', 'ное', 'дек'];

/// "2026-11-08" -> "Nov 8" / "8 ное". Hand-rolled so no intl locale data
/// has to be initialised for Macedonian.
String shortDate(String iso, String lang) {
  if (iso.isEmpty) return '';
  final d = parseIso(iso);
  return lang == 'mk' ? '${d.day} ${_monthsMk[d.month - 1]}' : '${_monthsEn[d.month - 1]} ${d.day}';
}

/// (foreground, background) for a breakout level from the API.
({Color fg, Color bg}) levelColors(AppColors c, String level) {
  switch (level) {
    case 'clear':
      return (fg: c.low, bg: c.lowSoft);
    case 'mild':
      return (fg: c.med, bg: c.medSoft);
    case 'moderate':
    case 'severe':
      return (fg: c.high, bg: c.highSoft);
    default:
      return (fg: c.textMuted, bg: Colors.transparent);
  }
}

/// Flat bordered card, the building block of every Track screen.
class TrackCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TrackCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

/// Numbered section heading used by the check-in cards.
class StepTitle extends StatelessWidget {
  final String title;
  final int? number;
  const StepTitle(this.title, {super.key, this.number});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        if (number != null) ...[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: TextStyle(color: c.primary, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpace.md),
        ],
        Expanded(child: Text(title, style: AppTheme.display(c, size: 18))),
      ],
    );
  }
}

/// Selectable pill (food tags, areas, phases, filters).
class TrackChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dashed;

  const TrackChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.primary : c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: selected ? c.primary : c.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.onPrimary : c.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped segmented control (severity, sleep quality, ranges).
class TrackSegmented<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const TrackSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? c.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    labelOf(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: v == selected ? c.onPrimary : c.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Error placeholder with a retry button.
class TrackLoadError extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const TrackLoadError({super.key, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: c.high, size: 40),
            const SizedBox(height: AppSpace.md),
            Text(
              message ?? context.tr('track.error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted),
            ),
            const SizedBox(height: AppSpace.lg),
            ElevatedButton(onPressed: onRetry, child: Text(context.tr('common.retry'))),
          ],
        ),
      ),
    );
  }
}

/// Scaffold used by every pushed Track sub-screen: back arrow, serif title.
class TrackScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final List<Widget>? actions;

  const TrackScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomBar,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(top: false, bottom: bottomBar == null, child: body),
      bottomNavigationBar: bottomBar,
    );
  }
}
