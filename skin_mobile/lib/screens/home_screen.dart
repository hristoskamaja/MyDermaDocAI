import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/locale_context.dart';
import '../models/analysis.dart';
import '../providers/auth_provider.dart';
import '../services/analysis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/locale_reload.dart';
import '../widgets/severity_pill.dart';
import 'dermatologist_list_screen.dart';
import 'scan/scan_flow_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with LocaleReloadMixin {
  final _analysisService = AnalysisService();
  late Future<List<AnalysisListItem>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _recentFuture = _load();
  }

  @override
  void reloadForLocale() {
    _recentFuture = _load();
  }

  Future<List<AnalysisListItem>> _load() async {
    final all = await _analysisService.getMyAnalyses();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(3).toList();
  }

  Future<void> _refresh() async {
    setState(() => _recentFuture = _load());
    await _recentFuture;
  }

  void _startScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanFlowScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = context.watch<AuthProvider>().currentUser;
    final greetName = user?.firstName ?? 'there';

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${context.tr('home.greeting')} $greetName', style: AppTheme.display(c, size: 30)),
                const SizedBox(height: AppSpace.sm),
                Text(
                  context.tr('home.subtitle'),
                  style: TextStyle(fontSize: 15, color: c.textMuted),
                ),
                const SizedBox(height: AppSpace.xl),
                _buildScanCard(c),
                const SizedBox(height: AppSpace.xxl),
                _buildRecentScans(c),
                const SizedBox(height: AppSpace.xl),
                _buildFindDermatologist(c),
                const SizedBox(height: AppSpace.xxl),
                _buildTips(c),
                const SizedBox(height: AppSpace.xl),
                Center(
                  child: Text(
                    'AI-generated estimates are not a medical diagnosis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: c.textLight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Solid accent card (no gradient) that opens the scan flow.
  Widget _buildScanCard(AppColors c) {
    return Material(
      color: c.primary,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg + 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg + 4),
        onTap: _startScan,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home.scanCardTitle'),
                      style: AppTheme.display(c, size: 24).copyWith(color: c.onPrimary),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      context.tr('home.scanCardSub'),
                      style: TextStyle(fontSize: 14, color: c.onPrimary.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.onPrimary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.center_focus_strong_rounded, color: c.onPrimary, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScans(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('home.recentScans'), style: AppTheme.display(c, size: 20)),
        const SizedBox(height: AppSpace.md),
        FutureBuilder<List<AnalysisListItem>>(
          future: _recentFuture,
          builder: (context, snapshot) {
            // Keep showing the previous list while a language reload runs.
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _infoBox(c, '${context.tr('home.recentError')}\n${snapshot.error}');
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return _infoBox(c, context.tr('home.recentEmpty'));
            }
            return Column(
              children: items.map((a) => _scanRow(c, a)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _infoBox(AppColors c, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(text, style: TextStyle(color: c.textMuted)),
    );
  }

  Widget _scanRow(AppColors c, AnalysisListItem a) {
    final date = _formatDate(a.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.conditionName,
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.text, fontSize: 15),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(date, style: TextStyle(color: c.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (a.isLowConfidence)
            const SeverityPill(severity: '', isUncertain: true)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SeverityPill(severity: a.severity),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${(a.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFindDermatologist(AppColors c) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DermatologistListScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
                child: Icon(Icons.person_search_rounded, color: c.primary, size: 22),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home.findDermatologistTitle'),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('home.findDermatologistSub'),
                      style: TextStyle(fontSize: 12.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: c.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, y').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Widget _buildTips(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('home.tipsTitle'), style: AppTheme.display(c, size: 20)),
        const SizedBox(height: AppSpace.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _tipCard(c, Icons.wb_sunny_outlined, context.tr('home.tipLightingTitle'),
                  context.tr('home.tipLightingBody')),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: _tipCard(c, Icons.crop_free_rounded, context.tr('home.tipFrameTitle'),
                  context.tr('home.tipFrameBody')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tipCard(AppColors c, IconData icon, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.primary),
          const SizedBox(height: AppSpace.md),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: c.text, fontSize: 13.5)),
          const SizedBox(height: AppSpace.xs),
          Text(body, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}
