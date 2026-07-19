/// TC-ARCH-11: core/editing/ 分层守门
///
/// 显式守门 `lib/core/editing/` 不反向 import `presentation/` / `domain/` /
/// `providers/`，对应 AGENTS.md §1.1 六层分层架构。
///
/// 已有 [layer_dependency_test.dart] 已覆盖整个 lib/core/，本测试为
/// Phase 2.2 新建的 editing 子目录提供独立守门，便于定位违规。
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
  });
}
