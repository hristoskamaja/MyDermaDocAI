import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';

/// Shows a private check-in photo. The bytes are fetched with the Bearer
/// token ([TrackingService.getPhoto]) and rendered with [Image.memory] - the
/// protected URL is never handed to Image.network.
class TrackingPhoto extends StatefulWidget {
  final String day;
  final double? width;
  final double? height;
  final double aspectRatio;

  const TrackingPhoto({
    super.key,
    required this.day,
    this.width,
    this.height,
    this.aspectRatio = 4 / 5,
  });

  @override
  State<TrackingPhoto> createState() => _TrackingPhotoState();
}

class _TrackingPhotoState extends State<TrackingPhoto> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = TrackingService().getPhoto(widget.day);
  }

  @override
  void didUpdateWidget(TrackingPhoto old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) _future = TrackingService().getPhoto(widget.day);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Container(
            color: c.surface2,
            child: FutureBuilder<Uint8List>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover, gaplessPlayback: true);
                }
                if (snapshot.hasError) {
                  return Icon(Icons.image_not_supported_outlined, color: c.textLight);
                }
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
