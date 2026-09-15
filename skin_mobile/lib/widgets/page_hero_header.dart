import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'hero_wave.dart';

/// Full-bleed wavy header for secondary tabs/screens (History, Profile,
/// Find a dermatologist) - the same "mini hero" motif as the web app's
/// page-hero-band (skin_web page CSS files) and the mobile Home screen's own
/// hero. Deliberately not used on the Scan flow, which has its own step UI.
class PageHeroHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final List<Widget>? actions;

  const PageHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.actions,
  });

  static const double height = 196;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipPath(
      clipper: const HeroWaveClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.fromLTRB(12, 18, 20, 46),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.primary, c.primaryDeep],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: HeroDotsPainter()),
            ),
            SafeArea(
              bottom: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showBackButton)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    )
                  else
                    const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
