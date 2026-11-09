import 'dart:io';

import '../models/analysis.dart';
import '../models/chat_message.dart';
import 'api_client.dart';

/// Handles skin scan upload + analysis history retrieval against the
/// `/analyses/` endpoints.
class AnalysisService {
  /// Uploads [imageFile] as multipart/form-data under the `image` field
  /// to `POST /analyses/scan-skin/`. May throw [ApiException] — callers
  /// should handle this to show a friendly error state (e.g. on a 502
  /// "AI prediction failed" response).
  Future<ScanResponse> scanSkin(File imageFile) async {
    final data = await ApiClient.postMultipart(
      '/analyses/scan-skin/',
      fieldName: 'image',
      file: imageFile,
    );
    return ScanResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AnalysisListItem>> getMyAnalyses() async {
    final data = await ApiClient.get('/analyses/my-analyses/');
    return (data as List)
        .map((e) => AnalysisListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AnalysisDetail> getAnalysisById(int id) async {
    final data = await ApiClient.get('/analyses/$id/');
    return AnalysisDetail.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches the Q&A history for a given analysis.
  Future<List<ChatMessage>> getChatHistory(int analysisId) async {
    final data = await ApiClient.get('/analyses/$analysisId/chat/');
    return (data as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Asks a follow-up question about the detected condition on this
  /// analysis. Returns both the saved user message and the generated
  /// assistant answer.
  Future<ChatExchange> askQuestion(int analysisId, String question) async {
    final data = await ApiClient.post(
      '/analyses/$analysisId/chat/',
      {'question': question},
      // The backend may take up to ~50s to answer; stay above that.
      timeout: const Duration(seconds: 65),
    );
    return ChatExchange.fromJson(data as Map<String, dynamic>);
  }
}
