import 'package:flutter/material.dart';

import '../l10n/locale_context.dart';
import '../theme/app_theme.dart';
import '../widgets/page_hero_header.dart';

/// Placeholder tab until the skin tracker (check-ins, routine, timeline)
/// ships. Mirrors skin_web/src/pages/Track/Track.jsx.
class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: PageHeroHeader(
        title: context.tr('track.title'),
        subtitle: context.tr('track.subtitle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.xl),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.eco_outlined, color: c.primary),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(context.tr('track.soonTitle'), style: AppTheme.display(c, size: 22)),
                const SizedBox(height: AppSpace.sm),
                Text(
                  context.tr('track.soonText'),
                  style: TextStyle(color: c.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
