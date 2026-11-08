// Models for the skin tracker (`/api/tracking/...`). Mirrors the JSON the
// Django `tracking` app returns; see skin_web/src/pages/Track for the
// matching web screens.

const kAreas = ['forehead', 'nose', 'left_cheek', 'right_cheek', 'chin', 'jawline'];
const kScanAreas = [...kAreas, 'neck', 'chest', 'back', 'arms', 'other'];
const kFoodTags = ['dairy', 'sugar', 'fried', 'alcohol', 'caffeine', 'water'];
const kSleepQualities = ['poor', 'okay', 'great'];
const kCyclePhases = ['menstrual', 'follicular', 'ovulation', 'luteal'];
const kStepTypes = ['cleanse', 'treat', 'hydrate', 'protect'];
const kTimesOfDay = ['AM', 'PM', 'BOTH'];
const kSeverityKeys = ['clear', 'mild', 'moderate', 'severe'];
const kMetrics = ['sleep', 'stress', 'acne'];

List<T> _list<T>(dynamic value, T Function(dynamic) map) =>
    (value as List? ?? const []).map(map).toList();

double? _d(dynamic v) => (v as num?)?.toDouble();

class DailyLog {
  final String date;
  final int skinRating;
  final int acneSeverity;
  final List<String> affectedAreas;
  final bool hasPhoto;
  final String notes;
  final double? sleepHours;
  final String? sleepQuality;
  final int? stress;
  final List<String> foodTags;
  final String? cyclePhase;
  final List<int> routineAm;
  final List<int> routinePm;

  DailyLog({
    required this.date,
    required this.skinRating,
    required this.acneSeverity,
    this.affectedAreas = const [],
    this.hasPhoto = false,
    this.notes = '',
    this.sleepHours,
    this.sleepQuality,
    this.stress,
    this.foodTags = const [],
    this.cyclePhase,
    this.routineAm = const [],
    this.routinePm = const [],
  });

  factory DailyLog.fromJson(Map<String, dynamic> j) => DailyLog(
        date: j['date'] as String,
        skinRating: j['skin_rating'] as int,
        acneSeverity: j['acne_severity'] as int,
        affectedAreas: _list(j['affected_areas'], (e) => e as String),
        hasPhoto: j['has_photo'] as bool? ?? false,
        notes: j['notes'] as String? ?? '',
        sleepHours: _d(j['sleep_hours']),
        sleepQuality: j['sleep_quality'] as String?,
        stress: j['stress'] as int?,
        foodTags: _list(j['food_tags'], (e) => e as String),
        cyclePhase: j['cycle_phase'] as String?,
        routineAm: _list(j['routine_am'], (e) => e as int),
        routinePm: _list(j['routine_pm'], (e) => e as int),
      );
}

class TodayStatus {
  final String date;
  final bool loggedToday;
  final DailyLog? todayLog;
  final int currentStreak;
  final int bestStreak;
  final int totalCheckIns;

  TodayStatus({
    required this.date,
    required this.loggedToday,
    required this.todayLog,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCheckIns,
  });

  factory TodayStatus.fromJson(Map<String, dynamic> j) {
    final streak = j['streak'] as Map<String, dynamic>? ?? const {};
    return TodayStatus(
      date: j['date'] as String,
      loggedToday: j['logged_today'] as bool? ?? false,
      todayLog: j['today_log'] == null
          ? null
          : DailyLog.fromJson(j['today_log'] as Map<String, dynamic>),
      currentStreak: streak['current'] as int? ?? 0,
      bestStreak: streak['best'] as int? ?? 0,
      totalCheckIns: j['total_check_ins'] as int? ?? 0,
    );
  }
}

class WeekDay {
  final String date;
  final int weekday; // 0 = Monday
  final bool isToday;
  final bool isFuture;
  final bool logged;
  final String level; // none | clear | mild | moderate | severe

  WeekDay({
    required this.date,
    required this.weekday,
    required this.isToday,
    required this.isFuture,
    required this.logged,
    required this.level,
  });

  factory WeekDay.fromJson(Map<String, dynamic> j) => WeekDay(
        date: j['date'] as String,
        weekday: j['weekday'] as int,
        isToday: j['is_today'] as bool? ?? false,
        isFuture: j['is_future'] as bool? ?? false,
        logged: j['logged'] as bool? ?? false,
        level: j['level'] as String? ?? 'none',
      );
}

class TimelinePoint {
  final String date;
  final int? acneSeverity;
  final double? sleepHours;
  final int? stress;
  final String? cyclePhase;
  final bool hasPhoto;

  TimelinePoint({
    required this.date,
    this.acneSeverity,
    this.sleepHours,
    this.stress,
    this.cyclePhase,
    this.hasPhoto = false,
  });

  factory TimelinePoint.fromJson(Map<String, dynamic> j) => TimelinePoint(
        date: j['date'] as String,
        acneSeverity: j['acne_severity'] as int?,
        sleepHours: _d(j['sleep_hours']),
        stress: j['stress'] as int?,
        cyclePhase: j['cycle_phase'] as String?,
        hasPhoto: j['has_photo'] as bool? ?? false,
      );
}

class CycleRange {
  final String phase;
  final String start;
  final String end;
  CycleRange(this.phase, this.start, this.end);

  factory CycleRange.fromJson(Map<String, dynamic> j) =>
      CycleRange(j['phase'] as String, j['start'] as String, j['end'] as String);
}

class TrackedScan {
  final int id;
  final String? conditionName;
  final String? image;
  final String bodyArea;
  final String date;

  TrackedScan({
    required this.id,
    this.conditionName,
    this.image,
    required this.bodyArea,
    required this.date,
  });

  factory TrackedScan.fromJson(Map<String, dynamic> j) => TrackedScan(
        id: j['id'] as int,
        conditionName: j['condition_name'] as String?,
        image: j['image'] as String?,
        bodyArea: j['body_area'] as String? ?? '',
        date: j['date'] as String,
      );
}

class TimelineData {
  final List<TimelinePoint> points;
  final List<CycleRange> cyclePhases;
  final List<TrackedScan> scans;

  TimelineData(this.points, this.cyclePhases, this.scans);

  factory TimelineData.fromJson(Map<String, dynamic> j) => TimelineData(
        _list(j['points'], (e) => TimelinePoint.fromJson(e as Map<String, dynamic>)),
        _list(j['cycle_phases'], (e) => CycleRange.fromJson(e as Map<String, dynamic>)),
        _list(j['scans'], (e) => TrackedScan.fromJson(e as Map<String, dynamic>)),
      );
}

class Insight {
  final String id;
  final String categoryLabel;
  final String strength; // pattern | early_signal
  final String strengthLabel;
  final int confidence;
  final String text;

  Insight({
    required this.id,
    required this.categoryLabel,
    required this.strength,
    required this.strengthLabel,
    required this.confidence,
    required this.text,
  });

  factory Insight.fromJson(Map<String, dynamic> j) => Insight(
        id: j['id'] as String,
        categoryLabel: j['category_label'] as String? ?? '',
        strength: j['strength'] as String? ?? 'early_signal',
        strengthLabel: j['strength_label'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.round() ?? 0,
        text: j['text'] as String? ?? '',
      );
}

class InsightsResult {
  final bool enoughData;
  final int loggedDays;
  final int minDays;
  final List<Insight> findings;
  final Insight? featured;
  final String disclaimer;

  InsightsResult({
    required this.enoughData,
    required this.loggedDays,
    required this.minDays,
    required this.findings,
    required this.featured,
    required this.disclaimer,
  });

  factory InsightsResult.fromJson(Map<String, dynamic> j) => InsightsResult(
        enoughData: j['enough_data'] as bool? ?? false,
        loggedDays: j['logged_days'] as int? ?? 0,
        minDays: j['min_days'] as int? ?? 7,
        findings: _list(j['findings'], (e) => Insight.fromJson(e as Map<String, dynamic>)),
        featured: j['featured'] == null
            ? null
            : Insight.fromJson(j['featured'] as Map<String, dynamic>),
        disclaimer: j['disclaimer'] as String? ?? '',
      );
}

class CorrelationPoint {
  final double x;
  final double y;
  CorrelationPoint(this.x, this.y);
}

class Correlation {
  final List<CorrelationPoint> points;
  final int n;
  final double? r;

  Correlation(this.points, this.n, this.r);

  factory Correlation.fromJson(Map<String, dynamic> j) => Correlation(
        _list(
          j['points'],
          (e) => CorrelationPoint(
            ((e as Map)['x'] as num).toDouble(),
            (e['y'] as num).toDouble(),
          ),
        ),
        j['n'] as int? ?? 0,
        _d(j['r']),
      );
}

class WeeklyReport {
  final String periodStart;
  final String periodEnd;
  final double? avgSeverity;
  final double? avgSeverityLastWeek;
  final String? trend; // calmer | similar | more_active
  final String? trendLabel;
  final double? avgSleep;
  final double? avgStress;
  final int checkIns;
  final int checkInsOf;
  final String? topPatternText;

  WeeklyReport({
    required this.periodStart,
    required this.periodEnd,
    this.avgSeverity,
    this.avgSeverityLastWeek,
    this.trend,
    this.trendLabel,
    this.avgSleep,
    this.avgStress,
    required this.checkIns,
    required this.checkInsOf,
    this.topPatternText,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> j) {
    final period = j['period'] as Map<String, dynamic>? ?? const {};
    final top = j['top_pattern'] as Map<String, dynamic>?;
    return WeeklyReport(
      periodStart: period['start'] as String? ?? '',
      periodEnd: period['end'] as String? ?? '',
      avgSeverity: _d(j['avg_severity']),
      avgSeverityLastWeek: _d(j['avg_severity_last_week']),
      trend: j['trend'] as String?,
      trendLabel: j['trend_label'] as String?,
      avgSleep: _d(j['avg_sleep']),
      avgStress: _d(j['avg_stress']),
      checkIns: j['check_ins'] as int? ?? 0,
      checkInsOf: j['check_ins_of'] as int? ?? 7,
      topPatternText: top?['text'] as String?,
    );
  }
}

class SkincareProduct {
  final int id;
  final String name;
  final String stepType;
  final String timeOfDay;
  final String frequency;
  final List<String> tags;
  final String? startedOn;
  final String? stoppedOn;

  SkincareProduct({
    required this.id,
    required this.name,
    required this.stepType,
    required this.timeOfDay,
    this.frequency = '',
    this.tags = const [],
    this.startedOn,
    this.stoppedOn,
  });

  factory SkincareProduct.fromJson(Map<String, dynamic> j) => SkincareProduct(
        id: j['id'] as int,
        name: j['name'] as String,
        stepType: j['step_type'] as String,
        timeOfDay: j['time_of_day'] as String? ?? 'BOTH',
        frequency: j['frequency'] as String? ?? '',
        tags: _list(j['tags'], (e) => e as String),
        startedOn: j['started_on'] as String?,
        stoppedOn: j['stopped_on'] as String?,
      );

  /// A product stopped before [day] (YYYY-MM-DD) is no longer in the routine.
  bool isActiveOn(String day) => stoppedOn == null || stoppedOn!.compareTo(day) >= 0;
}

class ReminderSettings {
  final bool checkinEnabled;
  final String checkinTime; // HH:MM
  final bool rescanEnabled;
  final int rescanWeeks;
  final bool cycleTrackingEnabled;

  ReminderSettings({
    required this.checkinEnabled,
    required this.checkinTime,
    required this.rescanEnabled,
    required this.rescanWeeks,
    required this.cycleTrackingEnabled,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        checkinEnabled: j['checkin_enabled'] as bool? ?? false,
        // The API sends HH:MM:SS.
        checkinTime: ((j['checkin_time'] as String?) ?? '20:00').substring(0, 5),
        rescanEnabled: j['rescan_enabled'] as bool? ?? false,
        rescanWeeks: j['rescan_weeks'] as int? ?? 4,
        cycleTrackingEnabled: j['cycle_tracking_enabled'] as bool? ?? false,
      );
}

class AskAnswer {
  final String answer;
  final String source; // ai | template
  final String disclaimer;
  AskAnswer(this.answer, this.source, this.disclaimer);

  factory AskAnswer.fromJson(Map<String, dynamic> j) => AskAnswer(
        j['answer'] as String? ?? '',
        j['source'] as String? ?? 'template',
        j['disclaimer'] as String? ?? '',
      );
}

class SuggestedQuestion {
  final String chip;
  final String text;
  SuggestedQuestion(this.chip, this.text);
}
