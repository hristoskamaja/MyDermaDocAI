import 'package:flutter/material.dart';

import '../../l10n/locale_context.dart';
import '../../models/tracking.dart';
import '../../services/api_client.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/locale_reload.dart';
import '../../widgets/track/track_common.dart';

/// "Your skincare shelf": Morning / Evening summaries and every product, with
/// add / edit (bottom sheet) and delete (confirm dialog).
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> with LocaleReloadMixin {
  final _service = TrackingService();
  late Future<List<SkincareProduct>> _future = _service.getProducts();

  @override
  void reloadForLocale() => _future = _service.getProducts();

  void _refresh() => setState(() => _future = _service.getProducts());

  Future<void> _openSheet([SkincareProduct? product]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductSheet(product: product),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(SkincareProduct product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('track.routine.confirmDelete')),
        content: Text(product.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('track.common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('track.common.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteProduct(product.id);
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('track.error'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TrackScaffold(
      title: context.tr('track.routine.title'),
      actions: [
        IconButton(
          tooltip: context.tr('track.routine.addProduct'),
          onPressed: () => _openSheet(),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: FutureBuilder<List<SkincareProduct>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          if (snapshot.hasError) return TrackLoadError(onRetry: _refresh);
          final products = snapshot.data!;
          final today = isoDate(DateTime.now());
          final active = products.where((p) => p.isActiveOn(today)).toList();
          List<SkincareProduct> forTimes(List<String> times) => active.where((p) => times.contains(p.timeOfDay)).toList()
            ..sort((a, b) => kStepTypes.indexOf(a.stepType).compareTo(kStepTypes.indexOf(b.stepType)));

          return ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              Text(context.tr('track.routine.subtitle'), style: TextStyle(color: c.textMuted, height: 1.5)),
              const SizedBox(height: AppSpace.lg),
              if (products.isEmpty)
                TrackCard(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Column(
                    children: [
                      Text(context.tr('track.routine.emptyTitle'), style: AppTheme.display(c, size: 20)),
                      const SizedBox(height: AppSpace.sm),
                      Text(context.tr('track.routine.emptyText'),
                          textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, height: 1.5)),
                      const SizedBox(height: AppSpace.lg),
                      ElevatedButton(onPressed: () => _openSheet(), child: Text(context.tr('track.routine.addProduct'))),
                    ],
                  ),
                )
              else ...[
                _SummaryCard(
                  icon: Icons.wb_sunny_outlined,
                  title: context.tr('track.routine.morning'),
                  products: forTimes(['AM', 'BOTH']),
                ),
                const SizedBox(height: AppSpace.md),
                _SummaryCard(
                  icon: Icons.nightlight_outlined,
                  title: context.tr('track.routine.evening'),
                  products: forTimes(['PM', 'BOTH']),
                ),
                const SizedBox(height: AppSpace.xl),
                for (final p in products) ...[
                  _ProductCard(product: p, onEdit: () => _openSheet(p), onDelete: () => _delete(p)),
                  const SizedBox(height: AppSpace.md),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<SkincareProduct> products;
  const _SummaryCard({required this.icon, required this.title, required this.products});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: c.primary),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(title, style: AppTheme.display(c, size: 18))),
              Text(context.trp('track.routine.steps', {'n': products.length}),
                  style: TextStyle(color: c.textMuted, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          for (var i = 0; i < products.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(
                children: [
                  Text('${i + 1}.', style: TextStyle(color: c.textLight, fontWeight: FontWeight.w700)),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(products[i].name)),
                  Text(context.tr('track.steps.${products[i].stepType}'),
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final SkincareProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ProductCard({required this.product, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stopped = product.stoppedOn != null && !product.isActiveOn(isoDate(DateTime.now()));
    return Opacity(
      opacity: stopped ? 0.6 : 1,
      child: TrackCard(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      context.tr('track.steps.${product.stepType}'),
                      context.tr('track.timeOfDay.${product.timeOfDay}'),
                      if (product.frequency.isNotEmpty) product.frequency,
                      if (stopped) '${context.tr('track.routine.stopped')} ${product.stoppedOn}',
                    ].join(' · '),
                    style: TextStyle(color: c.textMuted, fontSize: 12.5),
                  ),
                  if (product.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.xs + 2,
                      runSpacing: AppSpace.xs + 2,
                      children: [
                        for (final t in product.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.surface2,
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            ),
                            child: Text(t, style: TextStyle(fontSize: 11.5, color: c.textMuted, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20), tooltip: context.tr('track.common.edit')),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 20), tooltip: context.tr('track.common.delete')),
          ],
        ),
      ),
    );
  }
}

class _ProductSheet extends StatefulWidget {
  final SkincareProduct? product;
  const _ProductSheet({this.product});

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  final _service = TrackingService();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _frequency = TextEditingController(text: widget.product?.frequency ?? '');
  late final _tags = TextEditingController(text: widget.product?.tags.join(', ') ?? '');
  late String _step = widget.product?.stepType ?? 'cleanse';
  late String _when = widget.product?.timeOfDay ?? 'BOTH';
  late String? _started = widget.product?.startedOn;
  late String? _stopped = widget.product?.stoppedOn;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _frequency.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool started) async {
    final now = DateTime.now();
    final current = (started ? _started : _stopped);
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null ? parseIso(current) : now,
      firstDate: DateTime(now.year - 5),
      lastDate: started ? now : DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => started ? _started = isoDate(picked) : _stopped = isoDate(picked));
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'step_type': _step,
      'time_of_day': _when,
      'frequency': _frequency.text.trim(),
      'tags': _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'started_on': _started,
      'stopped_on': _stopped,
    };
    try {
      if (widget.product == null) {
        await _service.createProduct(body);
      } else {
        await _service.updateProduct(widget.product!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : context.tr('track.routine.saveError');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product == null ? context.tr('track.routine.addProduct') : context.tr('track.routine.editProduct'),
                style: AppTheme.display(c, size: 22),
              ),
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: _name,
                maxLength: 100,
                decoration: InputDecoration(labelText: context.tr('track.routine.name'), hintText: context.tr('track.routine.nameHint')),
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _step,
                      decoration: InputDecoration(labelText: context.tr('track.routine.step')),
                      items: [for (final s in kStepTypes) DropdownMenuItem(value: s, child: Text(context.tr('track.steps.$s')))],
                      onChanged: (v) => setState(() => _step = v ?? _step),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _when,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: context.tr('track.routine.when')),
                      items: [for (final s in kTimesOfDay) DropdownMenuItem(value: s, child: Text(context.tr('track.timeOfDay.$s'), overflow: TextOverflow.ellipsis))],
                      onChanged: (v) => setState(() => _when = v ?? _when),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _frequency,
                maxLength: 40,
                decoration: InputDecoration(labelText: context.tr('track.routine.frequency'), hintText: context.tr('track.routine.frequencyHint')),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _tags,
                decoration: InputDecoration(labelText: context.tr('track.routine.tags'), hintText: context.tr('track.routine.tagsHint')),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(child: _DateField(label: context.tr('track.routine.startedOn'), value: _started, onTap: () => _pickDate(true), onClear: () => setState(() => _started = null))),
                  const SizedBox(width: AppSpace.md),
                  Expanded(child: _DateField(label: context.tr('track.routine.stoppedOn'), value: _stopped, onTap: () => _pickDate(false), onClear: () => setState(() => _stopped = null))),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(_error!, style: TextStyle(color: c.high)),
              ],
              const SizedBox(height: AppSpace.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(context.tr('track.common.save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateField({required this.label, required this.value, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null ? null : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear),
        ),
        child: Text(value ?? context.tr('track.routine.notSet'), style: TextStyle(color: value == null ? c.textLight : c.text)),
      ),
    );
  }
}
