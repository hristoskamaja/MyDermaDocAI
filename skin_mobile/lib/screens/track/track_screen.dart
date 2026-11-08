import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../providers/locale_provider.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/locale_reload.dart';
import '../../widgets/page_hero_header.dart';
import '../../widgets/track/track_common.dart';
import '../../widgets/track/track_empty_states.dart';
import 'check_in_screen.dart';
import 'insights_screen.dart';
import 'reminders_screen.dart';
import 'routine_screen.dart';
import 'timeline_screen.dart';
import 'weekly_report_screen.dart';

class _HubData {
  final TodayStatus today;
  final List<WeekDay> week;
  final ReminderSettings reminders;
  final Insight? topInsight;
  _HubData(this.today, this.week, this.reminders, this.topInsight);
}

/// Track tab (Hub): today's check-in call to action, streak, this week, the
/// five category tiles, the top insight, and entries to the other sections.
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> with LocaleReloadMixin {
  final _service = TrackingService();
  late Future<_HubData> _future = _load();

  Future<_HubData> _load() async {
    final results = await Future.wait([_service.getToday(), _service.getWeek(), _service.getReminders()]);
    // The banner is a nice-to-have: a failure here must not break the hub.
    Insight? top;
    try {
      final insights = await _service.getInsights();
      top = insights.enoughData ? insights.featured : null;
    } catch (_) {
      top = null;
    }
    return _HubData(results[0] as TodayStatus, results[1] as List<WeekDay>, results[2] as ReminderSettings, top);
  }

  @override
  void reloadForLocale() => _future = _load();

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.watch<LocaleProvider>().lang;
    return Scaffold(
      backgroundColor: c.background,
      appBar: PageHeroHeader(
        title: context.tr('track.title'),
        subtitle: context.tr('track.subtitle'),
      ),
      body: FutureBuilder<_HubData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          if (snapshot.hasError) return TrackLoadError(onRetry: _reload);
          final data = snapshot.data!;

          return RefreshIndicator(
            color: c.primary,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
              children: data.today.totalCheckIns == 0
                  ? [const StartEmptyState(), const SizedBox(height: AppSpace.xl), _explore(context)]
                  : [
                      _cta(context, data.today, lang),
                      const SizedBox(height: AppSpace.md),
                      _streak(context, data.today),
                      const SizedBox(height: AppSpace.lg),
                      _week(context, data.week),
                      const SizedBox(height: AppSpace.lg),
                      _tiles(context, data),
                      if (data.topInsight != null) ...[
                        const SizedBox(height: AppSpace.lg),
                        _banner(context, data.topInsight!),
                      ],
                      const SizedBox(height: AppSpace.xl),
                      _explore(context),
                    ],
            ),
          );
        },
      ),
    );
  }

  Widget _cta(BuildContext context, TodayStatus today, String lang) {
    final c = context.colors;
    final logged = today.loggedToday;
    return TrackCard(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr('track.hub.today')} · ${shortDate(today.date, lang)}'.toUpperCase(),
            style: TextStyle(color: c.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(logged ? context.tr('track.hub.done') : context.tr('track.hub.notYet'),
              style: AppTheme.display(c, size: 24)),
          const SizedBox(height: AppSpace.xs),
          Text(logged ? context.tr('track.hub.doneSub') : context.tr('track.hub.notYetSub'),
              style: TextStyle(color: c.textMuted)),
          const SizedBox(height: AppSpace.lg),
          ElevatedButton.icon(
            onPressed: () => _open(const CheckInScreen()),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            iconAlignment: IconAlignment.end,
            label: Text(logged ? context.tr('track.hub.edit') : context.tr('track.hub.start')),
          ),
        ],
      ),
    );
  }

  Widget _streak(BuildContext context, TodayStatus today) {
    final c = context.colors;
    return TrackCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
            child: Icon(Icons.local_fire_department_outlined, color: c.primary),
          ),
          const SizedBox(width: AppSpace.lg),
          Text('${today.currentStreak}', style: AppTheme.display(c, size: 40)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              '${context.tr('track.hub.streak')} · ${context.tr('track.hub.best')} ${today.bestStreak}',
              style: TextStyle(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _week(BuildContext context, List<WeekDay> week) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('track.hub.thisWeek'), style: AppTheme.display(c, size: 18)),
              GestureDetector(
                onTap: () => _open(const TimelineScreen()),
                child: Text(context.tr('track.tabs.timeline'),
                    style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: Column(
                    children: [
                      Text(context.tr('track.weekday.${day.weekday}'),
                          style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpace.sm),
                      _dayDot(c, day),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayDot(AppColors c, WeekDay day) {
    final colors = levelColors(c, day.level);
    return Opacity(
      opacity: day.isFuture ? 0.5 : 1,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: day.logged ? colors.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
          border: day.isToday
              ? Border.all(color: c.primary, width: 2)
              : day.logged
                  ? null
                  : Border.all(color: c.border),
        ),
        child: day.logged
            ? Icon(Icons.check_rounded, size: 18, color: colors.fg)
            : Text(
                day.date.substring(8),
                style: TextStyle(
                  color: day.isToday ? c.primary : c.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _tiles(BuildContext context, _HubData data) {
    final log = data.today.todayLog;
    final notLogged = context.tr('track.hub.notLogged');
    final food = log != null && log.foodTags.isNotEmpty
        ? log.foodTags.take(2).map((k) => context.tr('track.food.$k')).join(', ')
        : notLogged;
    final sleep = log?.sleepHours != null ? context.trp('track.hub.hoursShort', {'n': log!.sleepHours!}) : notLogged;
    final stress = log?.stress != null ? context.trp('track.hub.stressOf', {'n': log!.stress!}) : notLogged;
    final cycle = !data.reminders.cycleTrackingEnabled
        ? context.tr('track.hub.cycleOff')
        : log?.cyclePhase != null
            ? context.tr('track.phases.${log!.cyclePhase}')
            : notLogged;
    final skincare = log != null
        ? '${context.tr('track.hub.morningShort')} ${log.routineAm.length} · ${context.tr('track.hub.eveningShort')} ${log.routinePm.length}'
        : notLogged;

    final tiles = [
      (Icons.restaurant_outlined, context.tr('track.hub.food'), food, () => _open(const CheckInScreen())),
      (Icons.bedtime_outlined, context.tr('track.hub.sleep'), sleep, () => _open(const CheckInScreen())),
      (Icons.psychology_outlined, context.tr('track.hub.stress'), stress, () => _open(const CheckInScreen())),
      (Icons.event_available_outlined, context.tr('track.hub.cycle'), cycle,
          () => _open(data.reminders.cycleTrackingEnabled ? const CheckInScreen() : const RemindersScreen())),
      (Icons.water_drop_outlined, context.tr('track.hub.skincare'), skincare, () => _open(const RoutineScreen())),
    ];

    final c = context.colors;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpace.md,
      crossAxisSpacing: AppSpace.md,
      childAspectRatio: 1.7,
      children: [
        for (final t in tiles)
          TrackCard(
            onTap: t.$4,
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.$1, size: 20, color: c.primary),
                const SizedBox(height: AppSpace.xs + 2),
                Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _banner(BuildContext context, Insight insight) {
    final c = context.colors;
    return Material(
      color: c.primarySoft,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => _open(const InsightsScreen()),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: c.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(insight.text,
                    maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _explore(BuildContext context) {
    final c = context.colors;
    final items = [
      (Icons.show_chart_rounded, 'track.tabs.timeline', const TimelineScreen()),
      (Icons.auto_awesome_outlined, 'track.tabs.insights', const InsightsScreen()),
      (Icons.spa_outlined, 'track.tabs.routine', const RoutineScreen()),
      (Icons.summarize_outlined, 'track.tabs.weekly', const WeeklyReportScreen()),
      (Icons.notifications_none_rounded, 'track.tabs.reminders', const RemindersScreen()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('track.explore'), style: AppTheme.display(c, size: 18)),
        const SizedBox(height: AppSpace.md),
        TrackCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                ListTile(
                  leading: Icon(items[i].$1, color: c.primary),
                  title: Text(context.tr(items[i].$2), style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right_rounded, color: c.textLight),
                  onTap: () => _open(items[i].$3),
                ),
                if (i < items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
