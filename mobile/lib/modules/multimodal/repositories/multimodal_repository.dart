import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';

class MultimodalRepository {
  final ApiClient apiClient;

  MultimodalRepository({required this.apiClient});

  Future<Map<String, dynamic>> uploadAndExtract({
    required String imageBase64,
    String mimeType = 'image/jpeg',
    String? imageKindHint,
  }) async {
    final body = <String, dynamic>{
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    };
    if (imageKindHint != null) {
      body['imageKindHint'] = imageKindHint;
    }
    final resp = await apiClient.post('/api/v1/multimodal/upload-and-extract', body: body);
    return resp as Map<String, dynamic>;
  }

  /// GET /api/v1/multimodal/drafts — list the user's drafts (optionally
  /// filtered by status, e.g. 'draft' for pending review).
  Future<List<Map<String, dynamic>>> listDrafts({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final resp = await apiClient.get('/api/v1/multimodal/drafts$query');
    if (resp is Map && resp['drafts'] is List) {
      return (resp['drafts'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getDraft(String draftId) async {
    final resp = await apiClient.get('/api/v1/multimodal/drafts/$draftId');
    return resp as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateDraftField({
    required String draftId,
    required int fieldIndex,
    double? userEditedValue,
    String? userEditedUnit,
    bool? isApproved,
  }) async {
    final body = <String, dynamic>{
      'fieldIndex': fieldIndex,
    };
    if (userEditedValue != null) body['userEditedValue'] = userEditedValue;
    if (userEditedUnit != null) body['userEditedUnit'] = userEditedUnit;
    if (isApproved != null) body['isApproved'] = isApproved;

    final resp = await apiClient.put('/api/v1/multimodal/drafts/$draftId/fields', body: body);
    return resp as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> commitDraft({
    required String draftId,
    bool deleteSourceImage = true,
    String? observedAt,
  }) async {
    final body = <String, dynamic>{
      'deleteSourceImage': deleteSourceImage,
    };
    if (observedAt != null) body['observedAt'] = observedAt;

    final resp = await apiClient.post('/api/v1/multimodal/drafts/$draftId/commit', body: body);
    return resp as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> discardDraft(String draftId) async {
    final resp = await apiClient.delete('/api/v1/multimodal/drafts/$draftId');
    return resp as Map<String, dynamic>;
  }
}

final multimodalRepositoryProvider = Provider<MultimodalRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MultimodalRepository(apiClient: apiClient);
});

/// Drafts awaiting user review/commit (status = 'draft').
final pendingDraftsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(multimodalRepositoryProvider).listDrafts(status: 'draft');
});
