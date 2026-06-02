import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  static Future<String> importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt', 'tex'],
    );
    
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    
    throw FileImportException('No file selected or file is invalid');
  }

  static Future<String> loadFromPath(String path) async {
    try {
      final file = File(path);
      return await file.readAsString();
    } catch (e) {
      throw FileLoadException('Failed to load file: $path');
    }
  }

  static Future<String> saveToFile(String content, {String? filename}) async {
    if (content.isEmpty) {
      throw FileSaveException('Cannot save empty content');
    }
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = filename ?? 'formulafix_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${dir.path}/$name');
      await file.writeAsString(content);
      return file.path;
    } catch (e) {
      throw FileSaveException('Failed to save file: $e');
    }
  }

  static Future<List<FileSystemEntity>> listDocuments() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync()
          .where((f) => f.path.endsWith('.md') || f.path.endsWith('.txt'))
          .toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (e) {
      throw FileListException('Failed to list files: $e');
    }
  }

  static Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw FileDeleteException('Failed to delete file: $e');
    }
  }
}

class FileImportException implements Exception {
  final String message;
  FileImportException(this.message);
  @override
  String toString() => message;
}

class FileLoadException implements Exception {
  final String message;
  FileLoadException(this.message);
  @override
  String toString() => message;
}

class FileSaveException implements Exception {
  final String message;
  FileSaveException(this.message);
  @override
  String toString() => message;
}

class FileListException implements Exception {
  final String message;
  FileListException(this.message);
  @override
  String toString() => message;
}

class FileDeleteException implements Exception {
  final String message;
  FileDeleteException(this.message);
  @override
  String toString() => message;
}
