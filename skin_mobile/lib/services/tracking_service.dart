import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/tracking.dart';
import 'api_client.dart';

/// Client for the `/tracking/` endpoints (own data only). Throws
/// [ApiException] on failures, like the other services.
class TrackingService {
  // ── Daily logs ────────────────────────────────────────────────────────────

  /// Returns null when there is no check-in for [day] yet (404).
  Future<DailyLog?> getLog(String day) async {
    try {
      final data = await ApiClient.get('/tracking/logs/$day/');
      return DailyLog.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Upserts the check-in for [day]. [fields] uses the API's snake_case
  /// names. A multipart request is only used when a [photo] is attached.
  Future<void> saveLog(
    String day,
    Map<String, dynamic> fields, {
    File? photo,
    bool removePhoto = false,
  }) async {
    if (photo != null) {
      final text = <String, String>{};
      fields.forEach((key, value) {
        if (value is List) {
          text[key] = jsonEncode(value);
        } else {
          text[key] = value == null ? '' : value.toString();
        }
      });
      await ApiClient.sendMultipart('PUT', '/tracking/logs/$day/', fields: text, file: photo);
      return;
    }
    await ApiClient.put('/tracking/logs/$day/', {
      ...fields,
      if (removePhoto) 'remove_photo': true,
    });
  }

  /// Private photo, fetched with the Bearer token and returned as bytes.
  Future<Uint8List> getPhoto(String day) => ApiClient.getBytes('/tracking/logs/$day/photo/');

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<SkincareProduct>> getProducts() async {
    final data = await ApiClient.get('/tracking/products/');
    return (data as List).map((e) => SkincareProduct.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createProduct(Map<String, dynamic> body) =>
      ApiClient.post('/tracking/products/', body);

  Future<void> updateProduct(int id, Map<String, dynamic> body) =>
      ApiClient.patch('/tracking/products/$id/', body);

  Future<void> deleteProduct(int id) => ApiClient.delete('/tracking/products/$id/');

  // ── Status, week, timeline ────────────────────────────────────────────────

  Future<TodayStatus> getToday() async =>
      TodayStatus.fromJson(await ApiClient.get('/tracking/today/') as Map<String, dynamic>);

  Future<List<WeekDay>> getWeek() async {
    final data = await ApiClient.get('/tracking/week/') as Map<String, dynamic>;
    return (data['days'] as List).map((e) => WeekDay.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TimelineData> getTimeline({required String from, required String to}) async =>
      TimelineData.fromJson(
        await ApiClient.get('/tracking/timeline/?from=$from&to=$to') as Map<String, dynamic>,
      );

  // ── Insights, correlation, report, Ask AI ─────────────────────────────────

  Future<InsightsResult> getInsights() async =>
      InsightsResult.fromJson(await ApiClient.get('/tracking/insights/') as Map<String, dynamic>);

  Future<Correlation> getCorrelation(String x, String y) async => Correlation.fromJson(
        await ApiClient.get('/tracking/correlation/?x=$x&y=$y') as Map<String, dynamic>,
      );

  Future<WeeklyReport> getWeeklyReport() async => WeeklyReport.fromJson(
        await ApiClient.get('/tracking/weekly-report/') as Map<String, dynamic>,
      );

  Future<AskAnswer> ask(String question, {String? chip}) async => AskAnswer.fromJson(
        await ApiClient.post('/tracking/ask/', {
          'question': question,
          if (chip != null) 'chip': chip,
        }) as Map<String, dynamic>,
      );

  Future<List<SuggestedQuestion>> getSuggestions() async {
    final data = await ApiClient.get('/tracking/ask/suggestions/');
    return (data as List)
        .map((e) => SuggestedQuestion((e as Map)['chip'] as String, e['text'] as String))
        .toList();
  }

  // ── Reminders, saved scans, delete all ────────────────────────────────────

  Future<ReminderSettings> getReminders() async => ReminderSettings.fromJson(
        await ApiClient.get('/tracking/reminders/') as Map<String, dynamic>,
      );

  Future<ReminderSettings> updateReminders(Map<String, dynamic> patch) async =>
      ReminderSettings.fromJson(
        await ApiClient.patch('/tracking/reminders/', patch) as Map<String, dynamic>,
      );

  Future<void> saveScan(int analysisId, {String? bodyArea}) => ApiClient.post(
        '/tracking/scans/$analysisId/save/',
        {if (bodyArea != null && bodyArea.isNotEmpty) 'body_area': bodyArea},
      );

  Future<void> deleteAll() => ApiClient.delete('/tracking/data/?confirm=true');
}
