import '../widgets/track/save_to_tracking_card.dart';
import 'package:flutter/material.dart';

import '../l10n/locale_context.dart';
import '../models/analysis.dart';
import '../models/recommendation.dart';
import '../services/analysis_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/condition_service.dart';
import '../theme/app_theme.dart';
import '../widgets/analysis_chat_section.dart';
import '../widgets/locale_reload.dart';
import 'scan/scan_result_view.dart';

/// Detail view for a past scan, opened from History. Reuses the same
/// [ScanResultView] layout as a fresh confident scan result, fetched via
/// `GET /analyses/<id>/` (nested condition) + the recommendations
/// endpoint for that condition id.
class AnalysisDetailScreen extends StatefulWidget {
  final int analysisId;

  const AnalysisDetailScreen({super.key, required this.analysisId});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> with LocaleReloadMixin {
  final _analysisService = AnalysisService();
  final _conditionService = ConditionService();

  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void reloadForLocale() {
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final detail = await _analysisService.getAnalysisById(widget.analysisId);
    List<Recommendation> recs = [];
    try {
      recs = await _conditionService.getRecommendations(detail.condition.id);
    } catch (_) {
      // Non-fatal: show the analysis even if recommendations fail to load.
    }
    return _DetailData(detail, recs);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(context.tr('result.scanDetailsTitle'))),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : context.tr('result.loadError');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: c.high, size: 40),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: Text(context.tr('common.retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final detail = data.detail;
          final imageProvider = detail.image != null && detail.image!.isNotEmpty
              ? NetworkImage(resolveMediaUrl(detail.image!))
              : null;
          return ScanResultView(
            image: imageProvider,
            conditionName: detail.condition.name,
            severity: detail.condition.severity,
            confidence: detail.confidence,
            description: detail.condition.description,
            symptoms: detail.condition.symptoms,
            treatmentOverview: detail.condition.treatmentOverview,
            recommendations: data.recommendations,
            isLowConfidence: detail.isLowConfidence,
            trailing: Column(children: [
              SaveToTrackingCard(analysisId: detail.id),
              const SizedBox(height: AppSpace.lg),
              AnalysisChatSection(analysisId: detail.id),
            ]),
          );
        },
      ),
    );
  }
}

class _DetailData {
  final AnalysisDetail detail;
  final List<Recommendation> recommendations;
  _DetailData(this.detail, this.recommendations);
}
