import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../screens/track/check_in_screen.dart';
import '../../theme/app_theme.dart';
import 'track_common.dart';

/// "Start tracking your skin" - no check-ins at all yet.
class StartEmptyState extends StatelessWidget {
  const StartEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        children: [
          const _IconBubble(icon: Icons.eco_outlined),
          const SizedBox(height: AppSpace.lg),
          Text(context.tr('track.empty.startTitle'),
              textAlign: TextAlign.center, style: AppTheme.display(c, size: 22)),
          const SizedBox(height: AppSpace.sm),
          Text(context.tr('track.empty.startText'),
              textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, height: 1.5)),
          const SizedBox(height: AppSpace.lg),
          ElevatedButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CheckInScreen())),
            child: Text(context.tr('track.empty.firstCheckin')),
          ),
        ],
      ),
    );
  }
}

/// "Not enough data yet" with segments for logged days out of the minimum.
class NotEnoughDataState extends StatelessWidget {
  final int logged;
  final int needed;
  const NotEnoughDataState({super.key, required this.logged, required this.needed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = logged.clamp(0, needed);
    final pct = needed == 0 ? 0 : (done / needed * 100).round();
    return TrackCard(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        children: [
          const _IconBubble(icon: Icons.hourglass_empty_rounded),
          const SizedBox(height: AppSpace.lg),
          Text(context.tr('track.empty.notEnoughTitle'),
              textAlign: TextAlign.center, style: AppTheme.display(c, size: 22)),
          const SizedBox(height: AppSpace.sm),
          Text(context.trp('track.empty.notEnoughText', {'n': needed}),
              textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, height: 1.5)),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.trp('track.empty.daysOf', {'a': done, 'b': needed}),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('$pct%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              for (var i = 0; i < needed; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: i == needed - 1 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i < done ? c.primary : c.surface2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  const _IconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
      child: Icon(icon, color: c.primary, size: 26),
    );
  }
}
