import 'package:flutter/material.dart';

import '../l10n/locale_context.dart';
import '../theme/app_theme.dart';

/// Persistent bottom navigation bar (Home / Scan / Track / History /
/// Profile) using Material 3's NavigationBar with a soft pill indicator.
/// The "Scan" item does not represent a tab body - selecting it should push
/// straight into the scan capture flow (handled by the parent).
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: context.tr('nav.home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.center_focus_strong_outlined),
              selectedIcon: const Icon(Icons.center_focus_strong_rounded),
              label: context.tr('nav.scan'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.show_chart_rounded),
              selectedIcon: const Icon(Icons.show_chart_rounded),
              label: context.tr('nav.track'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_rounded),
              selectedIcon: const Icon(Icons.history_rounded),
              label: context.tr('nav.history'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: context.tr('nav.profile'),
            ),
          ],
        ),
      ),
    );
  }
}
