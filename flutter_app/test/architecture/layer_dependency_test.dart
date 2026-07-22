/// TC-ARCH-3: 分层依赖方向守门
///
/// 对应 AGENTS.md §1.1 六层分层架构（严格自上而下依赖）。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 注意：raw string 内不能含未转义的 `"`，故改用普通字符串 + 转义。
  // 匹配 import 语句中的 presentation/ domain/ providers/ 路径
  final layerPattern = RegExp("import\\s+['\"].*/(presentation|domain|providers)/");
  final servicesPattern = RegExp("import\\s+['\"].*core/services/");
  final allowedInPresentation = RegExp("core/(router|constants|utils)/");

  // 已知历史违法（待 Phase 2/3 重构时清理）：
  //   - app_router.dart 在 core/router/ 但需引用 presentation/screens/ 构建 GoRoute。
  //     正确做法：把 router 配置移到顶层或注入 builder，需 Phase 3 路由层重构。
  //   - formula_pdf_renderer.dart 在 core/services/ 但复用了 domain/services/export_service.dart
  //     的 safeClip 工具函数。正确做法：把 safeClip 下沉到 core/utils/。
  // 与 AGENTS.md §10 一致：历史问题先记账，新增代码不得延续。
  const knownCoreLayerOffenders = <String>[
    'lib/core/router/app_router.dart',
    'lib/core/services/formula_pdf_renderer.dart',
  ];

  // 已知历史违法（待 Phase 2/3 重构时清理）：
  //   presentation/ 直接 import core/services/ 在多处违反 AGENTS.md §4.2。
  //   正确做法：经 providers/ 中间层注入服务，但需先抽出 Provider。
  //   Phase 1 仅清理存储 / Provider 重复；服务注入下沉推到 Phase 2-3。
  // 与 AGENTS.md §10 一致：历史问题先记账，新增代码不得延续。
  //
  // Phase 3.2 PR #3 新增登记（Task Contract v1.2 §3.2.8 已批准）：
  //   - mermaid_block.dart：MermaidBlock 通过 MermaidService 共享 WebView 实例
  //     （复用现有 LRU 缓存 + 并发控制），与 widgets/mermaid_host.dart 同源。
  //     Phase 3.9+ 主题切换时统一改为 MermaidServiceProvider 注入。
  const knownPresentationServiceOffenders = <String>[
    'lib/presentation/screens/document_list_screen.dart',
    'lib/presentation/screens/editor_screen.dart',
    'lib/presentation/screens/file_manager_screen.dart',
    'lib/presentation/widgets/mermaid_host.dart',
    'lib/presentation/widgets/preview_content.dart',
    'lib/presentation/blocks/mermaid/mermaid_block.dart',
  ];

  group('TC-ARCH-3 分层依赖方向', () {
    test('lib/core/ 不 import presentation/ / domain/ / providers/', () {
      final hits = <String>[];
      final dir = Directory('lib/core');
      if (!dir.existsSync()) {
        fail('lib/core 不存在');
      }
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (knownCoreLayerOffenders.any((o) => path.endsWith(o))) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (layerPattern.hasMatch(line)) {
            hits.add('$path:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'AGENTS.md §1.1：core 不允许反向 import 业务层。\n'
            '已知历史违法规避见 knownCoreLayerOffenders（待 Phase 2/3 重构清理）。\n'
            '新增命中：\n${hits.join("\n")}',
      );
    });

    test('lib/data/ 不 import presentation/ / domain/ / providers/', () {
      final hits = <String>[];
      final dir = Directory('lib/data');
      if (!dir.existsSync()) {
        fail('lib/data 不存在');
      }
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (layerPattern.hasMatch(line)) {
            hits.add('${entity.path.replaceAll("\\", "/")}:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'AGENTS.md §1.1：data 不允许 import 业务层。\n'
            '命中：\n${hits.join("\n")}',
      );
    });

    test('lib/presentation/ 不直接 import core/services/*Service', () {
      final hits = <String>[];
      final dir = Directory('lib/presentation');
      if (!dir.existsSync()) {
        fail('lib/presentation 不存在');
      }
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (knownPresentationServiceOffenders.any((o) => path.endsWith(o))) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (servicesPattern.hasMatch(line) &&
              !allowedInPresentation.hasMatch(line)) {
            hits.add('$path:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'AGENTS.md §4.2：presentation 不直接调用 core/services，'
            '必须经 providers/。\n'
            '已知历史违法规避见 knownPresentationServiceOffenders（待 Phase 2/3 重构清理）。\n'
            '新增命中：\n${hits.join("\n")}',
      );
    });

    // 守门测试：禁止 knownOffenders 列表增长。
    // 如果新增了违法规避，必须先在此登记并说明理由，避免悄悄积累。
    test('known historical offender count frozen', () {
      expect(
        knownCoreLayerOffenders.length,
        lessThanOrEqualTo(2),
        reason: 'core 层历史违法规避数量不应继续增长。'
            '若必须新增，请同步更新 AGENTS.md §10 并说明 Phase。',
      );
      expect(
        knownPresentationServiceOffenders.length,
        lessThanOrEqualTo(6),
        reason: 'presentation 层历史违法规避数量不应继续增长。'
            '若必须新增，请同步更新 AGENTS.md §10 并说明 Phase。',
      );
    });
  });
}
