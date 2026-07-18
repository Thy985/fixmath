import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:formula_fix/core/services/front_matter_parser.dart';
import 'package:formula_fix/core/services/file_repository.dart';
import 'package:formula_fix/core/services/storage_migration.dart';

/// 用临时目录模拟 `getApplicationDocumentsDirectory()`，
/// 使 FileRepository / StorageMigration 可在单测中运行。
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.root);
  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;
}

late Directory _tmp;

/// 用当前平台的路径分隔符拼接，避免 Windows 上 `/` 与 `\` 不一致。
String _p(String base, String part) => '$base${Platform.pathSeparator}$part';

void main() {
  setUp(() async {
    _tmp = await Directory.systemTemp.createTemp('formulafix_store_test_');
    PathProviderPlatform.instance = _MockPathProvider(_tmp.path);
  });

  tearDown(() async {
    if (await _tmp.exists()) {
      await _tmp.delete(recursive: true);
    }
  });

  group('FrontMatterParser', () {
    test('build 后再 parse 还原 meta 与带 H1 的 body', () {
      final md = FrontMatterParser.build(
        id: 'abc',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 2, 2),
        title: 'Hello',
        content: 'body text\nsecond line',
      );
      final parsed = FrontMatterParser.parse(md);
      expect(parsed.meta!['id'], 'abc');
      expect(parsed.meta!['createdAt'], '2026-01-01T00:00:00.000');
      expect(parsed.meta!['updatedAt'], '2026-02-02T00:00:00.000');
      // 标题以 # H1 形式写入正文首行
      expect(parsed.body, startsWith('# Hello'));
      expect(parsed.body, contains('body text\nsecond line'));
    });

    test('仅在正文无前导 H1 时注入 # H1，避免重复', () {
      final md = FrontMatterParser.build(
        id: 'x',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'T',
        content: 'no h1 here',
      );
      expect(md, contains('# T'));

      final md2 = FrontMatterParser.build(
        id: 'x',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'T',
        content: '# Existing\nbody',
      );
      final h1Count =
          md2.split('\n').where((l) => l.trim() == '# Existing').length;
      expect(h1Count, 1);
    });

    test('无 front matter 时 meta 为 null', () {
      final p = FrontMatterParser.parse('plain body\n# Title');
      expect(p.meta, isNull);
      expect(p.body, 'plain body\n# Title');
    });
  });

  group('FileRepository', () {
    late FileRepository repo;
    setUp(() => repo = FileRepository());

    test('createDocument -> readDocument 往返一致（标题存为首行 H1）', () async {
      final path = await repo.createDocument('My Title', 'hello world');
      final doc = await repo.readDocument(path);
      expect(doc.title, 'My Title');
      expect(doc.content, startsWith('# My Title'));
      expect(doc.content, contains('hello world'));
      expect(doc.id, isNotEmpty);
    });

    test('listDocuments 包含已创建文档', () async {
      final p = await repo.createDocument('Doc A', 'a');
      final docs = await repo.listDocuments();
      final id = (await repo.readDocument(p)).id;
      expect(docs.any((d) => d.id == id), isTrue);
    });

    test('writeDocument 保留 createdAt 并刷新 updatedAt', () async {
      final p = await repo.createDocument('T', 'v1');
      final first = await repo.readDocument(p);
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.writeDocument(p, title: 'T', content: 'v2');
      final second = await repo.readDocument(p);
      expect(second.content, contains('v2'));
      expect(second.createdAt, first.createdAt);
      expect(second.updatedAt.isAfter(first.updatedAt), isTrue);
    });

    test('renameDocument 改正文首个 H1 标题', () async {
      final p = await repo.createDocument('Old', 'body');
      await repo.renameDocument(p, 'New');
      final doc = await repo.readDocument(p);
      expect(doc.title, 'New');
    });

    test('deleteDocument 删除文件并反映到 exists', () async {
      final p = await repo.createDocument('X', 'x');
      expect(await repo.exists(p), isTrue);
      await repo.deleteDocument(p);
      expect(await repo.exists(p), isFalse);
    });

    test('getMetadata 与 searchDocuments', () async {
      final p = await repo.createDocument('Searchable', 'unique_token_xyz');
      final meta = await repo.getMetadata(p);
      expect(meta.title, 'Searchable');
      final results = await repo.searchDocuments('unique_token_xyz');
      expect(results.any((m) => m.path == p), isTrue);
    });

    test('原子写不残留 .tmp', () async {
      final dir = await getApplicationDocumentsDirectory();
      final p = _p(dir.path, _p('documents', 'atomic_test.md'));
      await repo.writeDocument(p, title: 'A', content: 'c');
      final tmpFiles = Directory(_p(dir.path, 'documents'))
          .listSync()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(tmpFiles, isEmpty);
      expect(await File(p).exists(), isTrue);
    });
  });

  group('StorageMigration', () {
    test('JSON 文档库迁移为 .md（带 front matter + marker），且幂等', () async {
      final dir = await getApplicationDocumentsDirectory();
      final json = <Map<String, dynamic>>[
        {
          'id': 'id-1',
          'title': 'Doc One',
          'content': 'content one',
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-02T00:00:00.000',
        },
        {
          'id': 'id-2',
          'title': 'Doc Two',
          'content': 'content two',
          'createdAt': '2026-02-01T00:00:00.000',
          'updatedAt': '2026-02-02T00:00:00.000',
        },
      ];
      final jsonFile = File(_p(dir.path, 'formula_fix_documents.json'));
      await jsonFile.writeAsString(jsonEncode(json));

      final ok1 = await StorageMigration.migrateIfNeeded();
      expect(ok1, isTrue);

      final f1 = File(_p(_p(dir.path, 'documents'), 'id-1.md'));
      expect(await f1.exists(), isTrue);
      final meta = FrontMatterParser.parse(await f1.readAsString());
      expect(meta.meta!['id'], 'id-1');

      final marker =
          await File(_p(_p(dir.path, 'documents'), '.storage_version')).readAsString();
      expect(marker.trim(), '1');

      // 篡改一个已迁移文件
      await f1.writeAsString('# tampered');

      // 第二次迁移必须幂等（marker 已存在）→ 不还原
      final ok2 = await StorageMigration.migrateIfNeeded();
      expect(ok2, isTrue);
      final after =
          await File(_p(_p(dir.path, 'documents'), 'id-1.md')).readAsString();
      expect(after, '# tampered');
    });

    test('无 JSON 时 migrateIfNeeded 返回 true 并写入 marker', () async {
      final ok = await StorageMigration.migrateIfNeeded();
      expect(ok, isTrue);
      final dir = await getApplicationDocumentsDirectory();
      final marker = File(_p(_p(dir.path, 'documents'), '.storage_version'));
      expect(await marker.exists(), isTrue);
    });
  });
}
