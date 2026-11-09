import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/locale_context.dart';
import '../models/analysis.dart';
import '../services/analysis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/locale_reload.dart';
import '../widgets/page_hero_header.dart';
import '../widgets/severity_pill.dart';
import 'analysis_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with LocaleReloadMixin {
  final _analysisService = AnalysisService();
  late Future<List<AnalysisListItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AnalysisListItem>> _load() async {
    final all = await _analysisService.getMyAnalyses();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  void reloadForLocale() {
    _future = _load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, y • h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: PageHeroHeader(
        title: context.tr('history.title'),
        subtitle: context.tr('history.subtitle'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AnalysisListItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline_rounded, color: c.high, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          '${context.tr('history.loadError')}\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded, color: c.textLight, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('history.empty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final a = items[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnalysisDetailScreen(analysisId: a.id),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
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
                              const SizedBox(height: 4),
                              Text(_formatDate(a.createdAt), style: TextStyle(color: c.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (a.isLowConfidence)
                          const SeverityPill(severity: '', isUncertain: true)
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SeverityPill(severity: a.severity),
                              const SizedBox(height: 4),
                              Text(
                                '${(a.confidence * 100).toStringAsFixed(0)}%',
                                style: TextStyle(color: c.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, color: c.textLight),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
