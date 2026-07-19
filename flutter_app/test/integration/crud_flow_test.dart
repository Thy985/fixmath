/// TC-1.8.1: CRUD 完整往返
///
/// 对应 docs/PHASE1_TEST_PLAN.md §9 集成测试。
///
/// 验证 FileRepository 完整 CRUD 往返：
///   Create → Read → Update → Rename → List → Delete → Verify Gone
///
/// 这是 Phase 1 退出门槛之一（Critical 类别）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:formula_fix/core/services/file_repository.dart';

/// 用临时目录模拟 `getApplicationDocumentsDirectory()`，
/// 使 FileRepository 可在单测中运行而不污染真实 App 数据。
class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.root);
  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;
}

late Directory _tmp;

void main() {
  setUp(() async {
    _tmp = await Directory.systemTemp.createTemp('formulafix_crud_test_');
    PathProviderPlatform.instance = _MockPathProvider(_tmp.path);
  });

  tearDown(() async {
    if (await _tmp.exists()) {
      await _tmp.delete(recursive: true);
    }
  });

  group('TC-1.8.1 CRUD 完整往返', () {
    test('Create → Read → Update → Rename → List → Delete → Verify Gone',
        () async {
      final repo = FileRepository();

      // 1. Create
      final path = await repo.createDocument('初始标题', '初始内容');
      expect(await repo.exists(path), isTrue, reason: '创建后应存在');
      expect(File(path).existsSync(), isTrue, reason: '磁盘上应有 .md 文件');

      // 验证不生成 JSON（ADR-0003：单一真相源）
      final jsonFile = File('${_tmp.path}/formula_fix_documents.json');
      expect(jsonFile.existsSync(), isFalse, reason: 'ADR-0003：禁止 JSON 存储');

      // 2. Read
      final created = await repo.readDocument(path);
      expect(created.title, '初始标题');
      expect(created.content, contains('初始内容'));
      expect(created.content, startsWith('# 初始标题'),
          reason: 'ADR-0003：.md 首行应为 # H1 标题');
      expect(created.id, isNotEmpty);
      expect(created.createdAt, isNotNull);
      expect(created.updatedAt, isNotNull);

      // 3. Update（写新内容，保留 createdAt）
      final originalCreatedAt = created.createdAt;
      await Future.delayed(const Duration(milliseconds: 10));
      await repo.writeDocument(path, title: '初始标题', content: '更新后的内容');
      final updated = await repo.readDocument(path);
      expect(updated.content, contains('更新后的内容'));
      expect(updated.content, isNot(contains('初始内容')),
          reason: '旧内容应被替换');
      expect(updated.createdAt, originalCreatedAt,
          reason: '更新不应改变 createdAt');
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue,
          reason: 'updatedAt 应刷新');

      // 4. Rename
      await repo.renameDocument(path, '新标题');
      final renamed = await repo.readDocument(path);
      expect(renamed.title, '新标题', reason: 'rename 后标题应更新');
      expect(renamed.content, startsWith('# 新标题'),
          reason: 'H1 应同步更新为新标题');

      // 5. List
      final list = await repo.listDocuments();
      expect(list.any((d) => d.id == renamed.id), isTrue,
          reason: 'listDocuments 应包含已重命名的文档');

      // 6. Delete
      await repo.deleteDocument(path);
      expect(await repo.exists(path), isFalse, reason: '删除后应不存在');
      expect(File(path).existsSync(), isFalse,
          reason: '磁盘上的 .md 文件应被物理移除');

      // 7. Verify Gone
      final listAfterDelete = await repo.listDocuments();
      expect(listAfterDelete.any((d) => d.id == renamed.id), isFalse,
          reason: '删除后 listDocuments 不应再含此文档');
    });

    test('多次 CRUD 循环不残留 .tmp', () async {
      final repo = FileRepository();
      for (var i = 0; i < 10; i++) {
        final p = await repo.createDocument('Doc $i', 'content $i');
        await repo.writeDocument(p, title: 'Doc $i', content: 'updated $i');
        await repo.deleteDocument(p);
      }
      final docsDir = Directory('${_tmp.path}/documents');
      if (docsDir.existsSync()) {
        final tmpFiles = docsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.tmp'))
            .toList();
        expect(tmpFiles, isEmpty,
            reason: 'TC-1.2.8: 10 次 CRUD 循环后无 .tmp 残留');
      }
    });

    test('创建不生成第四套存储', () async {
      // ADR-0003：禁止新增第四套存储（已有三套是历史遗留）
      final repo = FileRepository();
      await repo.createDocument('test', 'test');

      // 不应生成新存储
      expect(File('${_tmp.path}/formula_fix_documents.json').existsSync(), isFalse,
          reason: '不应生成 formula_fix_documents.json');
      // SharedPreferences 由 Flutter SDK 管理，不应被 FileRepository 写入文档数据
      // （这里只能间接验证：listDocuments 返回值与 .md 文件一致）
      final list = await repo.listDocuments();
      final docsDir = Directory('${_tmp.path}/documents');
      final mdFiles = docsDir.existsSync()
          ? docsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList()
          : <File>[];
      expect(list.length, mdFiles.length,
          reason: 'listDocuments 应与磁盘 .md 文件数一致（无 JSON 兜底）');
    });

    test('搜索功能可定位已创建文档', () async {
      final repo = FileRepository();
      final p = await repo.createDocument('可搜索文档', '包含独特关键词 formulafix_unique_token_2026');

      final results = await repo.searchDocuments('formulafix_unique_token_2026');
      expect(results.any((m) => m.path == p), isTrue,
          reason: 'searchDocuments 应能定位含关键词的文档');

      // 清理
      await repo.deleteDocument(p);
    });
  });

  group('TC-1.8.x 集成 - 跨模块一致性', () {
    test('FileRepository 与磁盘文件状态一致', () async {
      final repo = FileRepository();
      final p = await repo.createDocument('一致', '内容');

      // repo.exists() 与 File.existsSync() 一致
      expect(await repo.exists(p), File(p).existsSync());

      // repo.deleteDocument 后两者一致
      await repo.deleteDocument(p);
      expect(await repo.exists(p), File(p).existsSync());
    });

    test('多次写同一文档不产生孤儿文件', () async {
      final repo = FileRepository();
      final p = await repo.createDocument('孤儿', 'v1');

      for (var i = 0; i < 5; i++) {
        await repo.writeDocument(p, title: '孤儿', content: 'v$i');
      }

      // documents 目录下应只有 1 个 .md 文件（最后写入的版本）
      final docsDir = Directory('${_tmp.path}/documents');
      final mdFiles = docsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(mdFiles.length, 1, reason: '5 次写同一文档不应产生 5 个文件');

      await repo.deleteDocument(p);
    });
  });
}
