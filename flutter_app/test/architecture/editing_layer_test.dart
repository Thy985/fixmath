/// TC-ARCH-11: core/editing/ 分层守门
///
/// 显式守门 `lib/core/editing/` 不反向 import `presentation/` / `domain/` /
/// `providers/`，对应 AGENTS.md §1.1 六层分层架构。
///
/// 已有 [layer_dependency_test.dart] 已覆盖整个 lib/core/，本测试为
/// Phase 2.2 新建的 editing 子目录提供独立守门，便于定位违规。
///
/// Phase 2.3 扩展：sanity check 确保新增的 block_serializer.dart /
/// block_type_detector.dart 被守门覆盖（防止文件被意外跳过）。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final layerPattern = RegExp("import\\s+['\"].*/(presentation|domain|providers)/");

  group('TC-ARCH-11 core/editing/ 分层守门', () {
    test('lib/core/editing/ 不 import presentation/ / domain/ / providers/', () {
      final hits = <String>[];
      final dir = Directory('lib/core/editing');
      if (!dir.existsSync()) {
        fail('lib/core/editing 不存在');
      }
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
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
        reason: 'AGENTS.md §1.1：core/editing/ 不允许反向 import 业务层。\n'
            '新增命中：\n${hits.join("\n")}',
      );
    });

    test('TC-ARCH-11.1 sanity: Phase 2.2 ~ Phase 2.6 新增文件被守门覆盖', () {
      // 确保新增的 editing/ 下文件存在
      // 且能被 Directory.listSync 检测到（防止文件名误写或路径错误）。
      final requiredFiles = <String>[
        'lib/core/editing/block_editor.dart',           // Phase 2.2
        'lib/core/editing/block_editor_state.dart',     // Phase 2.2
        'lib/core/editing/block_types.dart',            // Phase 2.2
        'lib/core/editing/block_serializer.dart',       // Phase 2.3
        'lib/core/editing/block_type_detector.dart',    // Phase 2.3
        'lib/core/editing/composing_state.dart',        // Phase 2.5
        'lib/core/editing/composing_controller.dart',   // Phase 2.5
        'lib/core/editing/document_editor.dart',        // Phase 2.6（Phase 2.2 已创建，2.6 加 preserveId）
        'lib/core/editing/edit_operation.dart',         // Phase 2.6（含 block_operation.dart part file）
        'lib/core/editing/block_operation.dart',        // Phase 2.6（part of edit_operation.dart）
        'lib/core/editing/transaction.dart',            // Phase 2.6
        'lib/core/editing/transaction_builder.dart',    // Phase 2.6
        'lib/core/editing/editor_history.dart',         // Phase 2.6
        'lib/core/editing/block_operations.dart',       // Phase 2.6
      ];
      for (final path in requiredFiles) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path 不存在，但 editing_layer 守门测试要求其存在。',
        );
      }
    });
  });
}
