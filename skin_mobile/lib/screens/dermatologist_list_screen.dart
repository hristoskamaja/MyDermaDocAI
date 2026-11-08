import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/locale_context.dart';
import '../models/dermatologist.dart';
import '../services/dermatologist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/locale_reload.dart';
import '../widgets/page_hero_header.dart';

/// Read-only list of dermatologists. Rows can come from the admin typing
/// them in by hand through the React admin panel, or from
/// scrape_dermatologists.py on the backend - either way an empty list is
/// an expected, normal state (not an error) and must say so clearly.
///
/// Sorted by real distance whenever we can get a GPS fix (see
/// _tryGetLocation) - native location permissions work regardless of
/// HTTPS, unlike browser geolocation on the web app. A manual city picker
/// (see _filterBar) is always visible too, both for parity with the web
/// app's city picker (FindDermatologist.jsx) and as a fallback: if GPS is
/// denied/unavailable, we don't just silently show the plain alphabetical
/// list with no explanation - the picker lets the user get distance
/// sorting anyway, and a small hint explains why it's there.
class DermatologistListScreen extends StatefulWidget {
  const DermatologistListScreen({super.key});

  @override
  State<DermatologistListScreen> createState() =>
      _DermatologistListScreenState();
}

class _DermatologistListScreenState extends State<DermatologistListScreen> with LocaleReloadMixin {
  final _dermatologistService = DermatologistService();
  late Future<List<Dermatologist>> _future;
  bool _usingLocation = false;
  bool _gpsFailed = false;
  String? _selectedCity;

  // Same 11 cities core/services/geo.py's MK_CITY_COORDS knows about (and
  // scrape_dermatologists.py has listings for) - kept in sync by hand with
  // FindDermatologist.jsx's MK_CITIES, same reasoning as there: no endpoint
  // just for "which cities do you support".
  static const List<String> _mkCities = [
    'Скопје', 'Битола', 'Штип', 'Куманово', 'Прилеп',
    'Охрид', 'Струмица', 'Гевгелија', 'Кочани', 'Неготино', 'Радовиш',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void reloadForLocale() {
    _future = _load();
  }

  Future<Position?> _tryGetLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // geolocator 12.0.0 (pinned in pubspec.yaml) still takes these as
      // direct named params - the newer locationSettings: object form
      // only exists from a later major version, so passing it here fails
      // to compile against 12.0.0.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      // GPS off, permission dialog dismissed, timed out, emulator with no
      // fused location provider, etc. - none of these should block the
      // screen, just skip distance-sorting for this load.
      return null;
    }
  }

  Future<List<Dermatologist>> _load() async {
    // Manual city picks always win over GPS - it's an explicit choice, and
    // also the fallback for whenever GPS silently fails (emulator with no
    // location configured, permission denied, etc.) so the screen never
    // ends up with no location control at all, just an alphabetical list
    // and no way to tell why.
    if (_selectedCity != null) {
      if (mounted) setState(() { _usingLocation = false; _gpsFailed = false; });
      return _dermatologistService.getAll(nearCity: _selectedCity);
    }

    final position = await _tryGetLocation();
    if (mounted) {
      setState(() {
        _usingLocation = position != null;
        _gpsFailed = position == null;
      });
    }
    return _dermatologistService.getAll(
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }

  void _onCityChanged(String? city) {
    setState(() => _selectedCity = city);
    _refresh();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await _launch(uri);
  }

  Future<void> _openWebsite(String website) async {
    var url = website.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await _launch(uri);
  }

  Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('findDermatologist.linkError'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('findDermatologist.linkError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: PageHeroHeader(
        title: context.tr('findDermatologist.title'),
        subtitle: context.tr('findDermatologist.subtitle'),
        showBackButton: true,
      ),
      body: Column(
        children: [
          _filterBar(c),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Dermatologist>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _messageState(
                      c,
                      icon: Icons.error_outline_rounded,
                      iconColor: c.high,
                      text: '${context.tr('findDermatologist.loadError')}\n'
                          '${snapshot.error}',
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return _messageState(
                      c,
                      icon: Icons.person_search_rounded,
                      iconColor: c.textLight,
                      text: context.tr('findDermatologist.empty'),
                    );
                  }
                  final showBanner = _usingLocation || _selectedCity != null;
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length + (showBanner ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (showBanner) {
                        if (index == 0) return _locationBanner(c);
                        return _dermatologistCard(context, c, items[index - 1]);
                      }
                      return _dermatologistCard(context, c, items[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Manual city picker - always visible (not just when GPS fails), same
  /// reasoning as the web app's fd-city-picker: it doubles as an explicit
  /// override and a discoverable fallback, instead of the location feature
  /// being invisible whenever GPS silently doesn't work.
  ///
  /// A tappable row that opens a custom bottom sheet, instead of
  /// DropdownButton - the stock dropdown route/menu (even with
  /// borderRadius/dropdownColor set) still rendered as a plain sharp
  /// white box on-device and Maja reported taps inside it as
  /// unresponsive. A bottom sheet is a plain, well-behaved route with
  /// full control over its look, so it sidesteps both problems.
  Widget _filterBar(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openCityPicker(c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, color: c.textMuted, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('findDermatologist.yourCity'),
                      style: TextStyle(color: c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedCity ?? context.tr('findDermatologist.anyCity'),
                        style: TextStyle(color: c.text, fontSize: 13.5, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_gpsFailed && _selectedCity == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: c.textLight, size: 13),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    context.tr('findDermatologist.gpsUnavailable'),
                    style: TextStyle(color: c.textLight, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openCityPicker(AppColors c) {
    // isScrollControlled + a fixed heightFactor gives the sheet one
    // definite height up front; the list inside is Expanded (not
    // separately height-constrained) so IT scrolls internally instead
    // of the outer Column ever being asked to be taller than the sheet
    // - that mismatch is what caused the yellow/black "overflowed by N
    // pixels" render strip Maja saw at the bottom before.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final cities = <String?>[null, ..._mkCities];
        return FractionallySizedBox(
          heightFactor: 0.62,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                  child: Row(
                    children: [
                      Text(
                        context.tr('findDermatologist.yourCity'),
                        style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: cities.length,
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      final selected = city == _selectedCity;
                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _onCityChanged(city);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  city ?? context.tr('findDermatologist.anyCity'),
                                  style: TextStyle(
                                    color: selected ? c.primary : c.text,
                                    fontSize: 14.5,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check_rounded, color: c.primary, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _locationBanner(AppColors c) {
    final label = _selectedCity != null
        ? '${context.tr('findDermatologist.sortedByDistanceCity')} $_selectedCity'
        : context.tr('findDermatologist.sortedByDistance');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.near_me_rounded, color: c.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _messageState(
    AppColors c, {
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 36),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dermatologistCard(BuildContext context, AppColors c, Dermatologist d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  d.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    fontSize: 16,
                  ),
                ),
              ),
              if (d.distanceKm != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${d.distanceKm!.toStringAsFixed(1)} км',
                    style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (d.clinicName != null && d.clinicName!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              d.clinicName!,
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ],
          if ((d.city != null && d.city!.trim().isNotEmpty) ||
              (d.address != null && d.address!.trim().isNotEmpty)) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, color: c.textLight, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [d.city, d.address]
                        .where((s) => s != null && s.trim().isNotEmpty)
                        .join(' · '),
                    style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          if (d.notes != null && d.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_rounded, color: c.textLight, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    d.notes!,
                    style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          if ((d.phone != null && d.phone!.trim().isNotEmpty) ||
              (d.website != null && d.website!.trim().isNotEmpty)) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (d.phone != null && d.phone!.trim().isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(d.phone!),
                      icon: const Icon(Icons.call_rounded, size: 17),
                      label: Text(context.tr('findDermatologist.call')),
                    ),
                  ),
                if (d.phone != null &&
                    d.phone!.trim().isNotEmpty &&
                    d.website != null &&
                    d.website!.trim().isNotEmpty)
                  const SizedBox(width: 10),
                if (d.website != null && d.website!.trim().isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openWebsite(d.website!),
                      icon: const Icon(Icons.link_rounded, size: 17),
                      label: Text(context.tr('findDermatologist.website')),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
