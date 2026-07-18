import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/document.dart';
import 'file_service.dart' show decodeBytesAuto;
import 'front_matter_parser.dart';

/// 文档元数据（不含正文），用于列表 / 元数据查询 / 搜索 / 监听。
///
/// 与 [Document] 的区别在于不携带 `content`，避免大文件全量加载。
class DocMetadata {
  final String id;
  final String path;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocMetadata({
    required this.id,
    required this.path,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// 文档存储的单一入口（见 ADR-0003 §边界约束 1/2/6）。
///
/// 所有文档 I/O 必须经过本 Repository；业务层禁止直写 [File]。
/// 内部统一使用 [atomicWrite]（tmp → 删除旧目标 → rename）保证原子性。
final fileRepositoryProvider = Provider<FileRepository>((ref) => FileRepository());

/// 原子写：先写 `<path>.tmp`，落盘后（删除旧目标）rename 到最终路径。
///
/// 避免进程崩溃 / 写入中断时留下半截 `.md`。Windows 上 `rename`
/// 不能直接覆盖已存在文件，故先删除旧目标再 rename。
Future<void> atomicWrite(File file, String content) async {
  final dir = file.parent;
  await dir.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  try {
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  } catch (e) {
    try {
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {}
    rethrow;
  }
}

class FileRepository {
  Future<String> _docsDirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}documents';
  }

  /// 由文档 id（= .md 文件名 stem）推导规范化路径。
  Future<String> documentPathFor(String id) async =>
      '${await _docsDirPath()}${Platform.pathSeparator}$id.md';

  ({Document doc, String path}) _parseEntry(
    String path,
    String raw,
    DateTime fallbackModified,
  ) {
    final parsed = FrontMatterParser.parse(raw);
    final meta = parsed.meta;
    final body = parsed.body;
    final id =
        (meta?['id']?.isNotEmpty == true) ? meta!['id']! : _stem(path);
    final createdAt = _parseDate(meta?['createdAt']) ?? fallbackModified;
    final updatedAt = _parseDate(meta?['updatedAt']) ?? fallbackModified;
    final title = _extractTitle(body) ?? '未命名文档';
    final doc = Document(
      id: id,
      title: title,
      content: body,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    return (doc: doc, path: path);
  }

  Future<List<({Document doc, String path})>> _readAll() async {
    final docsDir = Directory(await _docsDirPath());
    if (!await docsDir.exists()) return [];
    final files = docsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    final entries = <({Document doc, String path})>[];
    for (final f in files) {
      final raw = decodeBytesAuto(await f.readAsBytes());
      final stat = await f.stat();
      entries.add(_parseEntry(f.path, raw, stat.modified));
    }
    entries.sort((a, b) => b.doc.updatedAt.compareTo(a.doc.updatedAt));
    return entries;
  }

  DocMetadata _toMeta(({Document doc, String path}) e) => DocMetadata(
        id: e.doc.id,
        path: e.path,
        title: e.doc.title,
        createdAt: e.doc.createdAt,
        updatedAt: e.doc.updatedAt,
      );

  // ---- CRUD ----

  Future<List<Document>> listDocuments() async =>
      (await _readAll()).map((e) => e.doc).toList();

  Future<Document> readDocument(String path) async {
    final file = File(path);
    final raw = decodeBytesAuto(await file.readAsBytes());
    final stat = await file.stat();
    return _parseEntry(path, raw, stat.modified).doc;
  }

  /// 新建文档：生成 uuid 文件名，写入带 front matter 的 .md，返回路径。
  Future<String> createDocument(String title, String content) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final path = await documentPathFor(id);
    final md = FrontMatterParser.build(
      id: id,
      createdAt: now,
      updatedAt: now,
      title: title,
      content: content,
    );
    await atomicWrite(File(path), md);
    return path;
  }

  /// 写入（upsert）：保留已有 id / createdAt，刷新 updatedAt。
  /// 正文原样透传（含用户写入的 `# H1`），不重复注入标题。
  Future<void> writeDocument(
    String path, {
    required String title,
    required String content,
  }) async {
    final file = File(path);
    String id;
    DateTime createdAt;
    if (await file.exists()) {
      final raw = decodeBytesAuto(await file.readAsBytes());
      final meta = FrontMatterParser.parse(raw).meta;
      id = (meta?['id']?.isNotEmpty == true) ? meta!['id']! : _stem(path);
      createdAt = _parseDate(meta?['createdAt']) ?? DateTime.now();
    } else {
      id = const Uuid().v4();
      createdAt = DateTime.now();
    }
    final updatedAt = DateTime.now();
    final md = FrontMatterParser.build(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      title: title,
      content: content,
    );
    await atomicWrite(File(path), md);
  }

  Future<void> deleteDocument(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// 重命名：仅替换正文首个 `# H1`，路径（uuid）不变。
  Future<void> renameDocument(String path, String newTitle) async {
    final file = File(path);
    final raw = decodeBytesAuto(await file.readAsBytes());
    final body = FrontMatterParser.parse(raw).body;
    final newBody = _replaceFirstH1(body, newTitle);
    await writeDocument(path, title: newTitle, content: newBody);
  }

  // ---- 扩展 API（ADR-0003 §边界约束 6） ----

  Future<DocMetadata> getMetadata(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Document not found', path);
    }
    final raw = decodeBytesAuto(await file.readAsBytes());
    final stat = await file.stat();
    return _toMeta((doc: _parseEntry(path, raw, stat.modified).doc, path: path));
  }

  Stream<List<DocMetadata>> watchDocuments() async* {
    final dir = Directory(await _docsDirPath());
    if (!await dir.exists()) {
      yield const [];
      await dir.create(recursive: true);
    }
    await for (final _ in dir.watch(
      events: FileSystemEvent.create |
          FileSystemEvent.delete |
          FileSystemEvent.modify |
          FileSystemEvent.move,
    )) {
      yield await _listMetadata();
    }
  }

  Future<List<DocMetadata>> searchDocuments(String query) async {
    final q = query.toLowerCase();
    final entries = await _readAll();
    if (q.isEmpty) return entries.map(_toMeta).toList();
    return entries
        .where((e) =>
            e.doc.title.toLowerCase().contains(q) ||
            e.doc.content.toLowerCase().contains(q))
        .map(_toMeta)
        .toList();
  }

  Future<bool> exists(String path) async => File(path).exists();

  // ---- 内部工具 ----

  Future<List<DocMetadata>> _listMetadata() async =>
      (await _readAll()).map(_toMeta).toList();

  String _stem(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    return name.endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
  }

  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } on FormatException {
      return null;
    }
  }

  String? _extractTitle(String body) {
    for (final line in body.split('\n')) {
      final t = line.trim();
      if (t.startsWith('# ')) return t.substring(2).trim();
    }
    return null;
  }

  String _replaceFirstH1(String body, String newTitle) {
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('# ')) {
        lines[i] = '# $newTitle';
        return lines.join('\n');
      }
    }
    return '# $newTitle\n\n$body';
  }
}
