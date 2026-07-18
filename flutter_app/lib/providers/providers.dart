import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/document.dart';
import '../../core/services/file_repository.dart';

// ============ SharedPreferences ============

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

// ============ Dark Mode ============

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return DarkModeNotifier(prefsAsync.valueOrNull);
});

class DarkModeNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;
  static const _key = 'pref_dark_mode';

  DarkModeNotifier(this._prefs) : super(_prefs?.getBool(_key) ?? false);

  void toggle() {
    state = !state;
    _prefs?.setBool(_key, state);
  }
}

// ============ Documents List ============

final documentsProvider = StateNotifierProvider<DocumentsNotifier, AsyncValue<List<Document>>>((ref) {
  final repo = ref.watch(fileRepositoryProvider);
  return DocumentsNotifier(repo);
});

class DocumentsNotifier extends StateNotifier<AsyncValue<List<Document>>> {
  final FileRepository _repo;

  DocumentsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    state = const AsyncValue.loading();
    try {
      final docs = await _repo.listDocuments();
      state = AsyncValue.data(docs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Document> createDocument(String title, String content) async {
    final path = await _repo.createDocument(title, content);
    final doc = await _repo.readDocument(path);
    state.whenData((docs) {
      state = AsyncValue.data([doc, ...docs]);
    });
    return doc;
  }

  Future<void> deleteDocument(String id) async {
    final path = await _repo.documentPathFor(id);
    await _repo.deleteDocument(path);
    state.whenData((docs) {
      state = AsyncValue.data(docs.where((d) => d.id != id).toList());
    });
  }
}

// ============ Current Document ============

final currentDocumentProvider = StateNotifierProvider<CurrentDocumentNotifier, Document?>((ref) {
  return CurrentDocumentNotifier();
});

class CurrentDocumentNotifier extends StateNotifier<Document?> {
  CurrentDocumentNotifier() : super(null);

  void setDocument(Document doc) {
    state = doc;
  }

  void updateContent(String content) {
    if (state != null) {
      state = state!.copyWith(content: content, updatedAt: DateTime.now());
    }
  }

  void updateTitle(String title) {
    if (state != null) {
      state = state!.copyWith(title: title, updatedAt: DateTime.now());
    }
  }

  void clear() {
    state = null;
  }
}

// ============ Editor Content + History ============

final previewModeProvider = StateProvider<bool>((ref) => false);
final isExportingProvider = StateProvider<bool>((ref) => false);
final searchQueryProvider = StateProvider<String>((ref) => '');

final editorContentProvider = StateNotifierProvider<EditorContentNotifier, String>((ref) {
  return EditorContentNotifier();
});

class EditorContentNotifier extends StateNotifier<String> {
  EditorContentNotifier() : super('');

  void setContent(String content) {
    state = content;
  }

  void clear() {
    state = '';
  }
}

// ============ Search ============

final filteredDocumentsProvider = Provider<List<Document>>((ref) {
  final docsAsync = ref.watch(documentsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  return docsAsync.when(
    data: (docs) {
      if (query.isEmpty) return docs;
      return docs.where((d) =>
        d.title.toLowerCase().contains(query) ||
        d.content.toLowerCase().contains(query)
      ).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});