import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../screens/track/timeline_screen.dart';
import '../../services/api_client.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import 'track_common.dart';

/// "Save to tracking" on a scan result: optionally attaches a body area (so
/// the same spot can be compared over time) and adds the scan to the timeline.
class SaveToTrackingCard extends StatefulWidget {
  final int analysisId;
  const SaveToTrackingCard({super.key, required this.analysisId});

  @override
  State<SaveToTrackingCard> createState() => _SaveToTrackingCardState();
}

class _SaveToTrackingCardState extends State<SaveToTrackingCard> {
  final _service = TrackingService();
  String _area = '';
  bool _saving = false;
  bool _saved = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveScan(widget.analysisId, bodyArea: _area);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : context.tr('track.saveScan.error'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_saved) {
      return TrackCard(
        color: c.lowSoft,
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: c.low),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(context.tr('track.saveScan.saved'), style: TextStyle(color: c.low, fontWeight: FontWeight.w700))),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimelineScreen())),
              child: Text(context.tr('track.saveScan.viewTimeline')),
            ),
          ],
        ),
      );
    }

    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _area,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('track.saveScan.area')),
            items: [
              DropdownMenuItem(value: '', child: Text(context.tr('track.saveScan.areaNone'))),
              for (final a in kScanAreas) DropdownMenuItem(value: a, child: Text(context.tr('track.areas.$a'))),
            ],
            onChanged: (v) => setState(() => _area = v ?? ''),
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.eco_outlined, size: 18),
              label: Text(_saving ? '…' : context.tr('track.saveScan.button')),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(_error!, style: TextStyle(color: c.high, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
