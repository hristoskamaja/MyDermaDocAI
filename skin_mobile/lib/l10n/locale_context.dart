import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';

/// `context.tr('home.recentScans')` - shorthand for
/// `context.watch<LocaleProvider>().t(...)`, mirroring the `context.colors`
/// extension in theme/app_theme.dart. Uses `watch` (not `read`) so widgets
/// rebuild immediately when the language is switched in Profile.
extension AppLocaleContext on BuildContext {
  String tr(String key) => watch<LocaleProvider>().t(key);
}

/// Replaces `{name}` placeholders in a translated string, e.g.
/// `context.trp('track.hub.hoursShort', {'n': 7})`.
extension AppLocaleParams on BuildContext {
  String trp(String key, Map<String, Object> vars) {
    var text = tr(key);
    vars.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
    return text;
  }
}
