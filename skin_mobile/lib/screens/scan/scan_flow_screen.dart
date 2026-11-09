import '../../widgets/track/save_to_tracking_card.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/locale_context.dart';
import '../../models/analysis.dart';
import '../../models/recommendation.dart';
import '../../services/analysis_service.dart';
import '../../services/api_client.dart';
import '../../services/condition_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analysis_chat_section.dart';
import '../dermatologist_list_screen.dart';
import 'scan_result_view.dart';
import 'scan_uncertain_view.dart';

enum _ScanStage { capture, analyzing, result, uncertain, error }

/// Single screen holding the full scan flow as internal state:
/// capture -> analyzing -> result (confident) | uncertain | error.
class ScanFlowScreen extends StatefulWidget {
  const ScanFlowScreen({super.key});

  @override
  State<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends State<ScanFlowScreen> {
  final _picker = ImagePicker();
  final _analysisService = AnalysisService();
  final _conditionService = ConditionService();

  _ScanStage _stage = _ScanStage.capture;
  File? _imageFile;
  ScanResponse? _scanResponse;
  List<Recommendation> _recommendations = [];
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _imageFile = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('scan.cameraError')} $e')),
      );
    }
  }

  Future<void> _submitScan() async {
    if (_imageFile == null) return;
    setState(() {
      _stage = _ScanStage.analyzing;
      _errorMessage = null;
    });
    try {
      final response = await _analysisService.scanSkin(_imageFile!);
      List<Recommendation> recs = [];
      if (!response.prediction.isLowConfidence) {
        try {
          recs = await _conditionService.getRecommendations(
            response.analysis.condition.id,
          );
        } catch (_) {
          // Non-fatal: show the result even if recommendations fail to load.
        }
      }
      if (!mounted) return;
      setState(() {
        _scanResponse = response;
        _recommendations = recs;
        _stage = response.prediction.isLowConfidence
            ? _ScanStage.uncertain
            : _ScanStage.result;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _stage = _ScanStage.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('scan.genericError');
        _stage = _ScanStage.error;
      });
    }
  }

  void _reset() {
    setState(() {
      _stage = _ScanStage.capture;
      _imageFile = null;
      _scanResponse = null;
      _recommendations = [];
      _errorMessage = null;
    });
  }

  void _retry() {
    if (_imageFile != null) {
      _submitScan();
    } else {
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(context.tr('nav.scan')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(child: _buildStage(c)),
    );
  }

  Widget _buildStage(AppColors c) {
    switch (_stage) {
      case _ScanStage.capture:
        return _buildCapture(c);
      case _ScanStage.analyzing:
        return _buildAnalyzing(c);
      case _ScanStage.result:
        final analysis = _scanResponse!.analysis;
        return ScanResultView(
          image: FileImage(_imageFile!),
          conditionName: analysis.condition.name,
          severity: analysis.condition.severity,
          confidence: analysis.confidence,
          description: analysis.condition.description,
          symptoms: analysis.condition.symptoms,
          treatmentOverview: analysis.condition.treatmentOverview,
          recommendations: _recommendations,
          primaryActionLabel: context.tr('scan.scanAgain'),
          onPrimaryAction: _reset,
          trailing: Column(children: [
            SaveToTrackingCard(analysisId: analysis.id),
            const SizedBox(height: AppSpace.lg),
            AnalysisChatSection(analysisId: analysis.id),
          ]),
        );
      case _ScanStage.uncertain:
        final prediction = _scanResponse!.prediction;
        return ScanUncertainView(
          image: FileImage(_imageFile!),
          bestGuessName: prediction.conditionName,
          confidence: prediction.confidence,
          onRescan: _reset,
          onFindDermatologist: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DermatologistListScreen()),
            );
          },
        );
      case _ScanStage.error:
        return _buildError(c);
    }
  }

  Widget _buildCapture(AppColors c) {
    final hasImage = _imageFile != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.surface2,
                  border: Border.all(color: c.border),
                ),
                child: hasImage
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_rounded, size: 56, color: c.textLight),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('scan.noPhoto'),
                            style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('scan.captureHint'),
                            style: TextStyle(color: c.textLight, fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (hasImage) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitScan,
                icon: const Icon(Icons.check_rounded),
                label: Text(context.tr('scan.usePhoto')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.replay_rounded),
                label: Text(context.tr('scan.retake')),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(context.tr('scan.capture')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(context.tr('scan.gallery')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyzing(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: c.primary),
          const SizedBox(height: 20),
          Text(
            context.tr('scan.analyzing'),
            style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppColors c) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: c.highSoft, shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, color: c.high, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('scan.errorTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? context.tr('scan.errorDefault'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _retry,
              child: Text(context.tr('common.retry')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _reset,
              child: Text(context.tr('scan.chooseDifferent')),
            ),
          ),
        ],
      ),
    );
  }
}
