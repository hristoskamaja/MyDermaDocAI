import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../theme/app_theme.dart';

/// Visually distinct "low confidence" result state. Uses the `uncertain`
/// / `uncertainSoft` colors (not the severity colors) so it never reads
/// as a specific severity level.
class ScanUncertainView extends StatelessWidget {
  final ImageProvider? image;
  final String bestGuessName;
  final double confidence;
  final VoidCallback onRescan;
  final VoidCallback onFindDermatologist;

  const ScanUncertainView({
    super.key,
    this.image,
    required this.bestGuessName,
    required this.confidence,
    required this.onRescan,
    required this.onFindDermatologist,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (confidence * 100).clamp(0, 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: image != null
                  ? Image(image: image!, fit: BoxFit.cover)
                  : Container(
                      color: c.surface2,
                      child: Icon(Icons.image_rounded, color: c.textLight, size: 48),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.uncertainSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.uncertain.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline_rounded, color: c.uncertain, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('uncertain.title'),
                        style: TextStyle(
                          color: c.uncertain,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('uncertain.body'),
                  style: TextStyle(color: c.text, fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('uncertain.bestGuess'),
                              style: TextStyle(color: c.textMuted, fontSize: 11.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bestGuessName,
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: c.uncertain,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRescan,
              child: Text(context.tr('uncertain.rescan')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onFindDermatologist,
              child: Text(context.tr('findDermatologist.title')),
            ),
          ),
        ],
      ),
    );
  }
}
