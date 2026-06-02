import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/document.dart';
import '../../core/services/document_service.dart';

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});

final documentsProvider = StateNotifierProvider<DocumentsNotifier, AsyncValue<List<Document>>>((ref) {
  final service = ref.watch(documentServiceProvider);
  return DocumentsNotifier(service);
});

final currentDocumentProvider = StateNotifierProvider<CurrentDocumentNotifier, Document?>((ref) {
  return CurrentDocumentNotifier();
});

class DocumentsNotifier extends StateNotifier<AsyncValue<List<Document>>> {
  final DocumentService _service;

  DocumentsNotifier(this._service) : super(const AsyncValue.loading()) {
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    state = const AsyncValue.loading();
    try {
      final docs = await _service.getAllDocuments();
      state = AsyncValue.data(docs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDocument(String title, String content) async {
    try {
      final doc = await _service.createDocument(title, content);
      state.whenData((docs) {
        state = AsyncValue.data([doc, ...docs]);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _service.deleteDocument(id);
      state.whenData((docs) {
        state = AsyncValue.data(docs.where((d) => d.id != id).toList());
      });
    } catch (e) {
      rethrow;
    }
  }
}

class CurrentDocumentNotifier extends StateNotifier<Document?> {
  CurrentDocumentNotifier() : super(null);

  void setDocument(Document? doc) {
    state = doc;
  }

  void updateContent(String content) {
    if (state != null) {
      state = state!.copyWith(
        content: content,
        updatedAt: DateTime.now(),
      );
    }
  }

  void updateTitle(String title) {
    if (state != null) {
      state = state!.copyWith(
        title: title,
        updatedAt: DateTime.now(),
      );
    }
  }

  void clear() {
    state = null;
  }
}
