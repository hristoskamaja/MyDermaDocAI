// Small, offline tests: shared Track widgets and the EN/MK string tables.
// No network, platform plugins or backend are needed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:skin_mobile/l10n/app_strings.dart';
import 'package:skin_mobile/providers/locale_provider.dart';
import 'package:skin_mobile/services/api_client.dart';
import 'package:skin_mobile/services/locale_storage.dart';
import 'package:skin_mobile/theme/app_theme.dart';
import 'package:skin_mobile/widgets/track/track_common.dart';
import 'package:skin_mobile/widgets/track/track_empty_states.dart';

Widget _wrap(Widget child, {LocaleProvider? locale}) {
  return ChangeNotifierProvider<LocaleProvider>(
    create: (_) => locale ?? LocaleProvider(),
    child: MaterialApp(
      theme: ThemeData(extensions: const [AppColorsExtension(AppColors.light)]),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

/// All dot-notation leaf keys under [prefix] in a nested string table.
Set<String> _keys(Map<String, dynamic> table, String prefix) {
  final out = <String>{};
  void walk(dynamic node, String path) {
    if (node is Map<String, dynamic>) {
      node.forEach((k, v) => walk(v, path.isEmpty ? k : '$path.$k'));
    } else {
      out.add(path);
    }
  }

  walk(table[prefix], prefix);
  return out;
}

void main() {
  // Never try to download fonts during tests.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('every track.* string exists in both English and Macedonian', () {
    final en = _keys(AppStrings.en, 'track');
    final mk = _keys(AppStrings.mk, 'track');
    expect(en, isNotEmpty);
    expect(en.difference(mk), isEmpty, reason: 'missing in MK');
    expect(mk.difference(en), isEmpty, reason: 'missing in EN');
  });

  test('reminder note says notifications are coming soon, in both languages', () {
    expect(AppStrings.t('en', 'track.reminders.note'), contains('coming soon'));
    expect(AppStrings.t('mk', 'track.reminders.note'), contains('наскоро'));
  });

  test('network and chat error messages exist in both languages', () {
    for (final key in ['common.serverUnreachable', 'chat.timeout']) {
      expect(AppStrings.t('en', key), isNot(key));
      expect(AppStrings.t('mk', key), isNot(key));
      expect(AppStrings.t('mk', key), isNot(AppStrings.t('en', key)));
    }
  });

  test('a request timeout becomes a clear localized message, not the raw exception', () async {
    for (final lang in ['en', 'mk']) {
      LocaleStorage.current = lang;
      await expectLater(
        http.runWithClient(
          () => ApiClient.post('/jwt-auth/login/', {}, auth: false),
          () => MockClient((_) async => throw TimeoutException('raw detail')),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.isTimeout, 'isTimeout', true)
            .having((e) => e.message, 'message', AppStrings.t(lang, 'common.serverUnreachable'))
            .having((e) => e.message, 'no raw text', isNot(contains('TimeoutException')))),
      );
    }
    LocaleStorage.current = 'en';
  });

  test('missing keys fall back to English, then to the key itself', () {
    expect(AppStrings.t('mk', 'nav.home'), isNotEmpty);
    expect(AppStrings.t('en', 'does.not.exist'), 'does.not.exist');
  });

  test('shortDate formats in both languages without locale data', () {
    expect(shortDate('2026-11-08', 'en'), 'Nov 8');
    expect(shortDate('2026-11-08', 'mk'), '8 ное');
    expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
  });

  testWidgets('TrackSegmented reports the tapped value', (tester) async {
    int? picked;
    await tester.pumpWidget(_wrap(
      TrackSegmented<int>(
        values: const [0, 1, 2],
        selected: 0,
        labelOf: (v) => 'level $v',
        onChanged: (v) => picked = v,
      ),
    ));

    await tester.tap(find.text('level 2'));
    expect(picked, 2);
  });

  testWidgets('NotEnoughDataState shows progress as days and percent', (tester) async {
    await tester.pumpWidget(_wrap(const NotEnoughDataState(logged: 4, needed: 7)));

    expect(find.text('4 of 7 days'), findsOneWidget);
    expect(find.text('57%'), findsOneWidget);
  });
}
