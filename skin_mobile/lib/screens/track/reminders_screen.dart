import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../services/api_client.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/locale_reload.dart';
import '../../widgets/track/track_common.dart';

/// Reminder preferences (saved to the account) and "delete all my tracking
/// data". This version does not schedule local notifications yet.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with LocaleReloadMixin {
  final _service = TrackingService();
  ReminderSettings? _settings;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reloadForLocale() {}

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final s = await _service.getReminders();
      if (mounted) setState(() => _settings = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Saves one change and keeps the server's answer as the truth.
  Future<void> _update(Map<String, dynamic> patch) async {
    final previous = _settings;
    try {
      final saved = await _service.updateReminders(patch);
      if (mounted) setState(() => _settings = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _settings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : context.tr('track.reminders.saveError'))),
      );
    }
  }

  Future<void> _pickTime() async {
    final parts = _settings!.checkinTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    _update({'checkin_time': '$hh:$mm'});
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('track.reminders.dangerTitle')),
        content: Text(ctx.tr('track.reminders.dangerText')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('track.reminders.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.high),
            child: Text(ctx.tr('track.reminders.confirmDelete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteAll();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('track.reminders.deleted'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('track.error'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _settings;
    return TrackScaffold(
      title: context.tr('track.reminders.title'),
      body: _loading && s == null
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _failed || s == null
              ? TrackLoadError(onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  children: [
                    Text(context.tr('track.reminders.subtitle'), style: TextStyle(color: c.textMuted)),
                    const SizedBox(height: AppSpace.lg),
                    TrackCard(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm, horizontal: AppSpace.lg),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.tr('track.reminders.checkin')),
                            value: s.checkinEnabled,
                            onChanged: (v) => _update({'checkin_enabled': v}),
                          ),
                          if (s.checkinEnabled)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(context.tr('track.reminders.checkinTime')),
                              trailing: Text(s.checkinTime, style: AppTheme.display(c, size: 18)),
                              onTap: _pickTime,
                            ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.tr('track.reminders.rescan')),
                            value: s.rescanEnabled,
                            onChanged: (v) => _update({'rescan_enabled': v}),
                          ),
                          if (s.rescanEnabled)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(context.tr('track.reminders.rescanWeeks')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: s.rescanWeeks > 1 ? () => _update({'rescan_weeks': s.rescanWeeks - 1}) : null,
                                    icon: const Icon(Icons.remove_circle_outline_rounded),
                                  ),
                                  Text('${s.rescanWeeks} ${context.tr('track.reminders.weeks')}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  IconButton(
                                    onPressed: s.rescanWeeks < 12 ? () => _update({'rescan_weeks': s.rescanWeeks + 1}) : null,
                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.tr('track.reminders.cycle')),
                            subtitle: Text(context.tr('track.reminders.cycleHint'), style: TextStyle(color: c.textLight, fontSize: 12.5)),
                            value: s.cycleTrackingEnabled,
                            onChanged: (v) => _update({'cycle_tracking_enabled': v}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: c.primary),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(context.tr('track.reminders.note'),
                                style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    TrackCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('track.reminders.dangerTitle'), style: AppTheme.display(c, size: 18)),
                          const SizedBox(height: AppSpace.xs),
                          Text(context.tr('track.reminders.dangerText'), style: TextStyle(color: c.textMuted, height: 1.5)),
                          const SizedBox(height: AppSpace.md),
                          OutlinedButton(
                            onPressed: _deleteAll,
                            style: OutlinedButton.styleFrom(foregroundColor: c.high, side: BorderSide(color: c.high)),
                            child: Text(context.tr('track.reminders.deleteAll')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
