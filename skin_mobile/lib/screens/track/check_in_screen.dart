import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_client.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/track/face_map.dart';
import '../../widgets/track/track_common.dart';
import '../../widgets/track/tracking_photo.dart';
import 'routine_screen.dart';

const _faceIcons = [
  Icons.sentiment_very_dissatisfied_outlined,
  Icons.sentiment_dissatisfied_outlined,
  Icons.sentiment_neutral_outlined,
  Icons.sentiment_satisfied_outlined,
  Icons.sentiment_very_satisfied_outlined,
];

List<T> _toggle<T>(List<T> list, T value) =>
    list.contains(value) ? list.where((v) => v != value).toList() : [...list, value];

/// Daily check-in: one scroll of numbered cards with a sticky Save bar.
/// Pops with `true` when a check-in was saved so the Hub can refresh.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _service = TrackingService();
  final _picker = ImagePicker();
  final _notes = TextEditingController();
  late final String _day = isoDate(DateTime.now());

  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String? _saveError;

  List<SkincareProduct> _products = [];
  bool _cycleEnabled = false;

  int? _rating;
  int? _acne;
  List<String> _areas = [];
  List<String> _food = [];
  double? _sleepHours;
  String? _sleepQuality;
  int? _stress;
  String? _cycle;
  List<int> _am = [];
  List<int> _pm = [];

  bool _hasSavedPhoto = false;
  bool _removePhoto = false;
  File? _newPhoto;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait([_service.getProducts(), _service.getReminders(), _service.getLog(_day)]);
      final log = results[2] as DailyLog?;
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<SkincareProduct>;
        _cycleEnabled = (results[1] as ReminderSettings).cycleTrackingEnabled;
        if (log != null) {
          _rating = log.skinRating;
          _acne = log.acneSeverity;
          _areas = [...log.affectedAreas];
          _food = [...log.foodTags];
          _sleepHours = log.sleepHours;
          _sleepQuality = log.sleepQuality;
          _stress = log.stress;
          _cycle = log.cyclePhase;
          _am = [...log.routineAm];
          _pm = [...log.routinePm];
          _notes.text = log.notes;
          _hasSavedPhoto = log.hasPhoto;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.tr('track.checkin.photoCamera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.tr('track.checkin.photoGallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() {
          _newPhoto = File(picked.path);
          _removePhoto = false;
        });
      }
    } catch (_) {
      // Permission denied or picker cancelled: nothing to do.
    }
  }

  void _clearPhoto() => setState(() {
        _newPhoto = null;
        if (_hasSavedPhoto) _removePhoto = true;
      });

  Future<void> _save() async {
    if (_rating == null || _acne == null || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _service.saveLog(
        _day,
        {
          'skin_rating': _rating,
          'acne_severity': _acne,
          'affected_areas': _areas,
          'food_tags': _food,
          'sleep_hours': _sleepHours,
          'sleep_quality': _sleepQuality,
          'stress': _stress,
          'cycle_phase': _cycleEnabled ? _cycle : null,
          'routine_am': _am,
          'routine_pm': _pm,
          'notes': _notes.text.trim(),
        },
        photo: _newPhoto,
        removePhoto: _removePhoto,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('track.checkin.saved'))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e is ApiException ? e.message : context.tr('track.checkin.saveError');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = context.watch<LocaleProvider>().lang;
    final canSave = _rating != null && _acne != null && !_saving;

    return TrackScaffold(
      title: context.tr('track.checkin.title'),
      bottomBar: _loading || _loadFailed
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_rating == null || _acne == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: Text(context.tr('track.checkin.required'),
                            style: TextStyle(color: c.textMuted, fontSize: 12.5)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSave ? _save : null,
                        child: Text(_saving ? context.tr('track.checkin.saving') : context.tr('track.checkin.save')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _loadFailed
              ? TrackLoadError(onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  children: [
                    Text(
                      context.trp('track.checkin.forDate', {'date': shortDate(_day, lang)}),
                      style: TextStyle(color: c.textMuted),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    _skinCard(context),
                    const SizedBox(height: AppSpace.lg),
                    _areasCard(context),
                    const SizedBox(height: AppSpace.lg),
                    _foodCard(context),
                    const SizedBox(height: AppSpace.lg),
                    _sleepCard(context),
                    const SizedBox(height: AppSpace.lg),
                    _stressCard(context),
                    const SizedBox(height: AppSpace.lg),
                    _cycleCard(context),
                    const SizedBox(height: AppSpace.lg),
                    _routineCard(context),
                    const SizedBox(height: AppSpace.lg),
                    TrackCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StepTitle(context.tr('track.checkin.notesTitle')),
                          const SizedBox(height: AppSpace.md),
                          TextField(
                            controller: _notes,
                            maxLines: 3,
                            maxLength: 2000,
                            decoration: InputDecoration(hintText: context.tr('track.checkin.notesHint')),
                          ),
                        ],
                      ),
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: AppSpace.lg),
                      Text(_saveError!, style: TextStyle(color: c.high)),
                    ],
                    const SizedBox(height: AppSpace.lg),
                  ],
                ),
    );
  }

  Widget _skinCard(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(context.tr('track.checkin.skinTitle'), number: 1),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: _rating == i + 1,
                    label: context.tr('track.checkin.face${i + 1}'),
                    child: GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Container(
                        margin: EdgeInsets.only(right: i == 4 ? 0 : AppSpace.xs + 2),
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                        decoration: BoxDecoration(
                          color: _rating == i + 1 ? c.primarySoft : c.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: _rating == i + 1 ? c.primary : c.border),
                        ),
                        child: Column(
                          children: [
                            Icon(_faceIcons[i], size: 28, color: _rating == i + 1 ? c.primary : c.textMuted),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('track.checkin.face${i + 1}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _rating == i + 1 ? c.primary : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text(context.tr('track.checkin.acneTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: AppSpace.sm),
          TrackSegmented<int>(
            values: const [0, 1, 2, 3],
            selected: _acne,
            labelOf: (v) => context.tr('track.severity.${kSeverityKeys[v]}'),
            onChanged: (v) => setState(() => _acne = v),
          ),
        ],
      ),
    );
  }

  Widget _areasCard(BuildContext context) {
    final c = context.colors;
    final previewing = _newPhoto != null || (_hasSavedPhoto && !_removePhoto);
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(context.tr('track.checkin.areasTitle'), number: 2),
          const SizedBox(height: AppSpace.xs),
          Text(context.tr('track.checkin.areasHint'), style: TextStyle(color: c.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpace.lg),
          Center(
            child: FaceMap(
              selected: _areas,
              onToggle: (key) => setState(() => _areas = _toggle(_areas, key)),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(context.tr('track.checkin.photoTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: AppSpace.sm),
          if (previewing) ...[
            SizedBox(
              width: 180,
              child: _newPhoto != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: AspectRatio(aspectRatio: 4 / 5, child: Image.file(_newPhoto!, fit: BoxFit.cover)),
                    )
                  : TrackingPhoto(day: _day),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          Wrap(
            spacing: AppSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(previewing ? context.tr('track.checkin.photoChange') : context.tr('track.checkin.photoAdd')),
              ),
              if (previewing)
                TextButton(onPressed: _clearPhoto, child: Text(context.tr('track.checkin.photoRemove'))),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(context.tr('track.checkin.photoPrivate'), style: TextStyle(color: c.textLight, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _foodCard(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(context.tr('track.checkin.foodTitle'), number: 3),
          const SizedBox(height: AppSpace.xs),
          Text(context.tr('track.checkin.foodHint'), style: TextStyle(color: c.textMuted, fontSize: 13)),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final tag in kFoodTags)
                TrackChip(
                  label: context.tr('track.food.$tag'),
                  selected: _food.contains(tag),
                  onTap: () => setState(() => _food = _toggle(_food, tag)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sleepCard(BuildContext context) {
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(context.tr('track.checkin.sleepTitle'), number: 4),
          const SizedBox(height: AppSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('track.checkin.sleepHours'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(
                _sleepHours == null ? '–' : context.trp('track.hub.hoursShort', {'n': _sleepHours!}),
                style: AppTheme.display(context.colors, size: 18),
              ),
            ],
          ),
          Slider(
            value: _sleepHours ?? 7,
            min: 0,
            max: 12,
            divisions: 24,
            onChanged: (v) => setState(() => _sleepHours = v),
          ),
          Text(context.tr('track.checkin.sleepQuality'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: AppSpace.sm),
          TrackSegmented<String>(
            values: kSleepQualities,
            selected: _sleepQuality,
            labelOf: (v) => context.tr('track.sleepQuality.$v'),
            // Tapping the selected quality clears it again.
            onChanged: (v) => setState(() => _sleepQuality = _sleepQuality == v ? null : v),
          ),
        ],
      ),
    );
  }

  Widget _stressCard(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(context.tr('track.checkin.stressTitle'), number: 5),
          const SizedBox(height: AppSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('track.hub.stress'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(
                _stress == null ? '–' : context.trp('track.hub.stressOf', {'n': _stress!}),
                style: AppTheme.display(c, size: 18),
              ),
            ],
          ),
          Slider(
            value: (_stress ?? 5).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => setState(() => _stress = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('track.checkin.stressLow'), style: TextStyle(color: c.textLight, fontSize: 12)),
              Text(context.tr('track.checkin.stressHigh'), style: TextStyle(color: c.textLight, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cycleCard(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(context.tr('track.checkin.cycleTitle'), number: 6),
          const SizedBox(height: AppSpace.sm),
          if (_cycleEnabled) ...[
            Text(context.tr('track.checkin.cycleHint'), style: TextStyle(color: c.textMuted, fontSize: 13)),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final phase in kCyclePhases)
                  TrackChip(
                    label: context.tr('track.phases.$phase'),
                    selected: _cycle == phase,
                    onTap: () => setState(() => _cycle = phase),
                  ),
                TrackChip(
                  label: context.tr('track.checkin.cycleSkip'),
                  selected: _cycle == null,
                  onTap: () => setState(() => _cycle = null),
                ),
              ],
            ),
          ] else
            Text(context.tr('track.checkin.cycleOff'), style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _routineCard(BuildContext context) {
    final c = context.colors;
    final active = _products.where((p) => p.isActiveOn(_day)).toList();
    final amList = active.where((p) => p.timeOfDay == 'AM' || p.timeOfDay == 'BOTH').toList();
    final pmList = active.where((p) => p.timeOfDay == 'PM' || p.timeOfDay == 'BOTH').toList();

    Widget group(String titleKey, List<SkincareProduct> list, List<int> value, void Function(List<int>) set) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(titleKey), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(context.tr('track.checkin.routineEmpty'), style: TextStyle(color: c.textLight, fontSize: 12.5)),
            ),
          for (final p in list)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: c.primary,
              value: value.contains(p.id),
              onChanged: (_) => setState(() => set(_toggle(value, p.id))),
              title: Text(p.name),
              subtitle: Text(context.tr('track.steps.${p.stepType}'),
                  style: TextStyle(color: c.textLight, fontSize: 12)),
            ),
        ],
      );
    }

    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(context.tr('track.checkin.routineTitle'), number: 7),
          const SizedBox(height: AppSpace.md),
          if (active.isEmpty) ...[
            Text(context.tr('track.checkin.routineEmpty'), style: TextStyle(color: c.textMuted)),
            TextButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoutineScreen()));
                // Only refresh the shelf; keep what was already entered.
                final products = await _service.getProducts();
                if (mounted) setState(() => _products = products);
              },
              child: Text(context.tr('track.checkin.addProducts')),
            ),
          ] else ...[
            group('track.checkin.routineMorning', amList, _am, (v) => _am = v),
            const SizedBox(height: AppSpace.md),
            group('track.checkin.routineEvening', pmList, _pm, (v) => _pm = v),
          ],
        ],
      ),
    );
  }
}
