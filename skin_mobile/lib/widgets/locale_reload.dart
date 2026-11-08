import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';

/// Mixin for screens that load language-dependent backend data (condition
/// text, recommendations, dermatologists, history item names).
///
/// `ApiClient` attaches `?lang=` from `LocaleStorage.current`, so the data
/// already comes back localized - but only at fetch time. Without this a
/// future created in `initState` keeps the old language until the screen is
/// rebuilt from scratch. When the language changes, [reloadForLocale] is
/// called (once per change, never for the first build); assign a fresh
/// future in it. FutureBuilder keeps showing the previous snapshot data while
/// the new future is pending, so the screen does not flicker - just make sure
/// the spinner is only shown when there is no data yet.
mixin LocaleReloadMixin<T extends StatefulWidget> on State<T> {
  String? _loadedLang;

  /// Start a new load. Do not wrap in setState; the in-progress rebuild
  /// already picks up the new future.
  void reloadForLocale();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Provider.of<LocaleProvider>(context).lang;
    if (_loadedLang != null && _loadedLang != lang) {
      reloadForLocale();
    }
    _loadedLang = lang;
  }
}
