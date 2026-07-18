import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'file_repository.dart' show atomicWrite;
import 'file_service.dart' show decodeBytesAuto;
import 'front_matter_parser.dart';

/// 一次性迁移：将遗留的 `formula_fix_documents.json` 文档库转为 .md 文件。
///
/// 阶段（见 ADR-0003 §边界约束 7）：
/// Backup → Parse → Generate（`<uuid>.md` + front matter）
/// → Validate count → Validate hash → Mark completed
/// （`documents/.storage_version` marker 作幂等守卫）。
///
/// 任一验证阶段失败：保留 `.bak`、不标记完成、不删除源数据、可安全重跑。
class StorageMigration {
  static const String _jsonName = 'formula_fix_documents.json';
  static const String _markerRel = 'documents/.storage_version';
  static const String _expectedVersion = '1';

  /// 返回 `true` 表示已迁移（或无需迁移）。
  static Future<bool> migrateIfNeeded() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final jsonFile = File('${dir.path}/$_jsonName');
      final marker = File('${dir.path}/$_markerRel');

      // 1. 已完成（marker 命中）或无需迁移（无 JSON）→ 跳过（幂等）
      if (await marker.exists()) {
        final v = (await marker.readAsString()).trim();
        if (v == _expectedVersion) return true;
      }
      if (!await jsonFile.exists()) {
        await _writeMarker(marker, _expectedVersion);
        return true;
      }

      // 2. Backup：保留 .json.bak，全程不删源
      final backup = await jsonFile.copy('${jsonFile.path}.bak');
      debugPrint('[StorageMigration] backup: ${backup.path}');

      // 3. Parse JSON
      final docs = _readJson(jsonFile);

      // 4. Generate：每个 doc 写成 <uuid>.md，并注入最小 front matter
      final docsDir =
          Directory('${dir.path}${Platform.pathSeparator}documents');
      await docsDir.create(recursive: true);

      final written = <String, String>{};
      for (final d in docs) {
        final id = (d['id'] as String?)?.isNotEmpty == true
            ? d['id'] as String
            : const Uuid().v4();
        final createdAt = _parseDate(d['createdAt']) ?? DateTime.now();
        final updatedAt = _parseDate(d['updatedAt']) ?? DateTime.now();
        final title = (d['title'] as String?)?.isNotEmpty == true
            ? d['title'] as String
            : '未命名文档';
        final content = (d['content'] as String?) ?? '';
        final md = FrontMatterParser.build(
          id: id,
          createdAt: createdAt,
          updatedAt: updatedAt,
          title: title,
          content: content,
        );
        final file =
            File('${docsDir.path}${Platform.pathSeparator}$id.md');
        await atomicWrite(file, md);
        written[id] = md;
      }

      // 5. Validate count
      if (written.length != docs.length) {
        debugPrint('[StorageMigration] validation failed: count mismatch '
            '(${written.length} != ${docs.length})');
        return false;
      }

      // 6. Validate content：重新读回每个 .md，与写入内容逐字节比对
      for (final e in written.entries) {
        final re = await File(
          '${docsDir.path}${Platform.pathSeparator}${e.key}.md',
        ).readAsString();
        if (re != e.value) {
          debugPrint('[StorageMigration] validation failed: '
              'content mismatch ${e.key}');
          return false;
        }
      }

      // 7. Mark completed
      await _writeMarker(marker, _expectedVersion);
      debugPrint('[StorageMigration] migrated ${docs.length} documents to .md');
      return true;
    } catch (e) {
      debugPrint('[StorageMigration] error: $e');
      return false;
    }
  }

  static List<Map<String, dynamic>> _readJson(File jsonFile) {
    final bytes = jsonFile.readAsBytesSync();
    final text = decodeBytesAuto(bytes);
    if (text.isEmpty) return [];
    final decoded = json.decode(text);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  static Future<void> _writeMarker(File marker, String version) async {
    await marker.parent.create(recursive: true);
    await marker.writeAsString(version);
  }

  static DateTime? _parseDate(dynamic s) {
    if (s == null) return null;
    try {
      return DateTime.parse(s as String);
    } on FormatException {
      return null;
    }
  }
}
