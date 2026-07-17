import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 把任意来源的字节流尝试解析为字符串。优先级：
///   1. UTF-8 BOM / 严格 UTF-8
///   2. UTF-8 容错模式（用 U+FFFD 替换非法序列）— 在中国用户的 .md 文件里
///      GBK / GB18030 字节序列混入 UTF-8 流中很常见，严格模式会抛
///      "Unexpected extension byte"，容错模式可以挽救大部分内容。
///   3. GBK（覆盖 GB2312 / GB18030 的子集）— 中文 Windows 记事本默认编码
///   4. Latin-1（兜底，1:1 字节到字符映射，永不失败）
String decodeBytesAuto(List<int> bytes) {
  if (bytes.isEmpty) return '';
  // BOM 探测
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  // 严格 UTF-8 试一次
  try {
    return utf8.decode(bytes);
  } on FormatException {
    // 继续尝试更宽松的解码器
  }
  // 容错 UTF-8：保证不抛错，对 GBK 字节也基本能恢复出可读文本
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } on FormatException {
    // 极小概率走到这
  }
  // GBK / GB18030：覆盖中文 Windows 记事本默认编码。某些 Flutter SDK
  // 不在 dart:convert 顶层直接导出 `gb18030`，但可以通过
  // `Encoding.getByName('gb18030')` 拿到。拿不到时退到 latin1 兜底。
  try {
    final gbk = Encoding.getByName('gb18030') ?? Encoding.getByName('gbk');
    if (gbk != null) return gbk.decode(bytes);
  } on FormatException {
    // 最后兜底
  }
  return latin1.decode(bytes);
}

class FileService {
  static Future<String> importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt', 'tex'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      return decodeBytesAuto(bytes);
    }

    throw FileImportException('No file selected or file is invalid');
  }

  static Future<String> loadFromPath(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      return decodeBytesAuto(bytes);
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
