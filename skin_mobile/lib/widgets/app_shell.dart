import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/scan/scan_flow_screen.dart';
import '../screens/track/track_screen.dart';
import 'bottom_nav.dart';

/// Wraps Home / Track / History / Profile with the persistent bottom nav and
/// handles nav state. The "Scan" nav item does not switch tabs - it pushes
/// the scan capture flow directly, per spec.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;

  // Nav order: 0 Home, 1 Scan (push, no page), 2 Track, 3 History, 4 Profile.
  // _pages skips Scan, so nav index n > 1 maps to page n - 1.
  final _pages = const [
    HomeScreen(),
    TrackScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  void _onNavTap(int navIndex) {
    if (navIndex == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ScanFlowScreen()),
      );
      return;
    }
    final pageIndex = navIndex < 1 ? navIndex : navIndex - 1;
    setState(() => _tabIndex = pageIndex);
  }

  int get _navIndex => _tabIndex < 1 ? _tabIndex : _tabIndex + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _navIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
