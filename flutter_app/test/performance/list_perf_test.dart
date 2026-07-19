/// TC-PERF-2: listDocuments(1000 文件)
///
/// 对应 docs/PHASE1_TEST_PLAN.md §14.2 性能基线。
///
/// 测试方法（参考 §14.1）：
///   - 10 次取中位数
///   - 本地开发机指标仅供参考，以 CI 为退出标准
///   - CI: GitHub Actions ubuntu-latest, 4 cores / 16GB RAM
///
/// 测试架构：
///   - 使用 _MockPathProvider 将 getApplicationDocumentsDirectory()
///     重定向到临时目录
///   - 在 documents/ 子目录下预创建 1000 份 .md 文件
///   - 测量 FileRepository.listDocuments() 耗时
///   - 注意：listDocuments 会读所有文件内容解析 front matter，因此
///     1000 文件 ≠ 纯目录扫描，包含 1000 次 file.readAsBytes() + 解析。
///
/// ## Phase 1 Gate 阈值（经 Human Owner 评审 2026-07-19 确认）
///
/// 原始基线 500ms 经实测确认无法在当前实现下达成，经 Human Owner 评审：
/// - 「1000 文件不是高频场景」（FormulaFix 是移动端 Typora 类工具）
/// - 「不要为了 500ms 提前引入复杂系统」
///
/// **调整后阈值**（本地与 CI 统一）：
/// - 3000ms（3s）— 实测波动范围 1700-2300ms，3000ms 给本地约 1000ms
///   缓冲，避免 developer-machine flake 阻塞开发
/// - CI（GitHub Actions ubuntu-latest）通常更稳定，实测远低于 3000ms
///
/// **偏差根因**（与原基线 500ms 的差距来源）：
/// - `FileRepository._readAll` 顺序读 1000 份文件，每份做 `readAsBytes()` +
///   `decodeBytesAuto` + `FrontMatterParser.parse` + `file.stat()`
/// - Phase 0 UI Prototype Freeze 禁止优化 `FileRepository` 业务逻辑
/// - ADR-0003 §边界约束 5 明示「Phase 1 小规模直接扫 documents/，Phase 2+
///   引入 SQLite 索引或全文索引作为可重建派生缓存」
///
/// **Phase 2 优化方向**（不在 Phase 1 范围内）：
/// - 引入 `Directory.watch()` + 增量 mtime 缓存
/// - 引入 SQLite 元数据索引（可重建派生缓存，非真相源）
/// - 不允许引入第二真相源（ADR-0003 §边界约束 5 明示禁止）
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:formula_fix/core/services/file_repository.dart';

class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.root);
  final String root;

  @override
  Future<String> getApplicationDocumentsPath() async => root;
}

late Directory _tmp;

String _p(String base, String part) => '$base${Platform.pathSeparator}$part';

void main() {
  setUp(() async {
    _tmp = await Directory.systemTemp.createTemp('formulafix_perf_test_');
    PathProviderPlatform.instance = _MockPathProvider(_tmp.path);
  });

  tearDown(() async {
    if (await _tmp.exists()) {
      await _tmp.delete(recursive: true);
    }
  });

  test('TC-PERF-2: listDocuments(1000 文件) 中位数 < 3000ms', () async {
    // 准备 1000 份 .md 文件到 documents/ 子目录
    final docsDir = Directory(_p(_tmp.path, 'documents'));
    await docsDir.create(recursive: true);
    for (var i = 0; i < 1000; i++) {
      final file = File(_p(docsDir.path, 'doc_$i.md'));
      await file.writeAsString(
        '---\n'
        'id: id-$i\n'
        'createdAt: 2026-01-01T00:00:00.000\n'
        'updatedAt: 2026-01-01T00:00:00.000\n'
        '---\n'
        '\n'
        '# 文档 $i\n'
        '\n'
        '这是第 $i 份文档的正文内容。\n',
      );
    }
    final actualCount =
        Directory(_p(_tmp.path, 'documents')).listSync().length;
    expect(actualCount, 1000, reason: '应预创建 1000 份 .md 文件');

    final repo = FileRepository();

    // 预热：首次会触发 file_repository 内部缓存 / 系统调用初始化
    await repo.listDocuments();

    const repetitions = 10;
    final elapsed = <int>[];
    for (var i = 0; i < repetitions; i++) {
      final sw = Stopwatch()..start();
      final docs = await repo.listDocuments();
      sw.stop();
      expect(docs.length, 1000,
          reason: 'listDocuments 应返回全部 1000 份文档');
      elapsed.add(sw.elapsedMicroseconds);
    }
    elapsed.sort();
    final medianMicros = elapsed[repetitions ~/ 2];
    final medianMs = medianMicros / 1000.0;

    debugPrint('TC-PERF-2 files: 1000');
    debugPrint('TC-PERF-2 elapsed (ms): '
        '${elapsed.map((e) => (e / 1000.0).toStringAsFixed(2)).join(', ')}');
    debugPrint('TC-PERF-2 median: ${medianMs.toStringAsFixed(2)}ms '
        '(target: <3000ms)');

    // 退出标准（Phase 1 Gate，经 Human Owner 评审 2026-07-19 确认）：
    //   - 统一阈值：3000ms（3s）— 本地与 CI 一致
    //
    // 原 PHASE1_TEST_PLAN.md §14.2 基线为 500ms，但实测确认当前实现
    // （FileRepository._readAll 顺序读 1000 份文件 + FrontMatterParser
    // 解析）无法在 500ms 内完成。Phase 0 UI Prototype Freeze 禁止优化
    // FileRepository 业务逻辑，1000 文件也不是 FormulaFix 当前高频场景
    // （移动端 Typora 类工具）。
    //
    // 按用户评审：「1000 文件不是高频场景」「不要为了 500ms 提前引入
    // 复杂系统」——SQLite 缓存 / FileIndex Cache 留到 Phase 2。
    //
    // 实测波动范围（本地 Windows + 杀软扫描）：1700-2300ms
    // 统一 3000ms 阈值给本地约 1000ms 缓冲，避免 developer-machine flake
    // 阻塞开发；CI（GitHub Actions ubuntu-latest）通常更稳定，实测远低
    // 于 3000ms。
    const threshold = 3000;
    expect(medianMs, lessThan(threshold),
        reason: '阈值 ${threshold}ms。median=${medianMs.toStringAsFixed(2)}ms');
  });
}
