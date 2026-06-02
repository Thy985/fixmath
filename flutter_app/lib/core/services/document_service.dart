import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/document.dart';

class DocumentService {
  static const String _fileName = 'formula_fix_documents.json';
  final Uuid _uuid = const Uuid();

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<Document>> getAllDocuments() async {
    try {
      final f = await _file;
      if (!await f.exists()) return [];
      final content = await f.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> list = json.decode(content);
      return list.map((j) => _fromJson(j as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Failed to load documents: $e');
      return [];
    }
  }

  Future<Document> createDocument(String title, String content) async {
    final now = DateTime.now();
    final doc = Document(
      id: _uuid.v4(),
      title: title.isEmpty ? '未命名文档' : title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    final docs = await getAllDocuments();
    docs.insert(0, doc);
    await _saveAll(docs);
    return doc;
  }

  Future<Document> updateDocument(Document doc) async {
    final updated = doc.copyWith(updatedAt: DateTime.now());
    final docs = await getAllDocuments();
    final idx = docs.indexWhere((d) => d.id == doc.id);
    if (idx != -1) {
      docs[idx] = updated;
      await _saveAll(docs);
    }
    return updated;
  }

  Future<void> deleteDocument(String id) async {
    final docs = await getAllDocuments();
    docs.removeWhere((d) => d.id == id);
    await _saveAll(docs);
  }

  Future<void> _saveAll(List<Document> docs) async {
    final f = await _file;
    final list = docs.map(_toJson).toList();
    await f.writeAsString(json.encode(list));
  }

  Map<String, dynamic> _toJson(Document doc) {
    return {
      'id': doc.id,
      'title': doc.title,
      'content': doc.content,
      'createdAt': doc.createdAt.toIso8601String(),
      'updatedAt': doc.updatedAt.toIso8601String(),
    };
  }

  Document _fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // Legacy autosave for import compatibility
  Future<String?> loadAutoSave() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/formula_fix_autosave.md');
      if (await f.exists()) return f.readAsString();
    } catch (e) {
      debugPrint('Failed to load autosave: $e');
    }
    return null;
  }

  Future<void> clearAutoSave() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/formula_fix_autosave.md');
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Failed to clear autosave: $e');
    }
  }
}