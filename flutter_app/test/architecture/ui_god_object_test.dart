/// TC-ARCH-UI-4: Phase 3.0 God Object 守门测试。
///
/// 落地 Phase 3.0 Task Contract §2.4（避免 God Object）+ §6（Exit Gate）。
///
/// 守门内容：
/// - `EditorCoordinator` 文件 ≤ 200 行
/// - `EditorCoordinator` 不持有 Theme / File / Route 等领域状态
///
/// 避免 Phase 3.0 把 focus / history / theme / file 都塞进一个"大万能 Controller"。
/// 正确做法：EditorCoordinator 只协调，不持有业务状态。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-ARCH-UI-4 God Object 守门 ============

  group('TC-ARCH-UI-4 God Object 守门：EditorCoordinator 文件 ≤ 200 行 + 字段约束', () {
    test('editor_coordinator.dart 行数 ≤ 200', () {
      final file = File('lib/presentation/editor/editor_coordinator.dart');
      expect(file.existsSync(), isTrue,
          reason: 'editor_coordinator.dart 必须存在');
      final lines = file.readAsLinesSync();
      expect(
        lines.length,
        lessThanOrEqualTo(200),
        reason: 'Phase 3.0 Task Contract §2.4：EditorCoordinator 文件 ≤ 200 行，'
            '避免 God Object。当前 ${lines.length} 行。',
      );
    });

    test('EditorCoordinator 不持有 Theme / File / Route 领域状态', () {
      final file = File('lib/presentation/editor/editor_coordinator.dart');
      final content = file.readAsStringSync();
      // 检测不应出现的字段类型
      final forbiddenFields = <String>[
        'ThemeData',
        'File ',
        'Route ',
        'Navigator',
        ' GoRouter',
      ];
      final hits = <String>[];
      final lines = content.split('\n');
      for (final field in forbiddenFields) {
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
          if (line.contains(field) &&
              (line.contains('final ') ||
                  line.contains('late ') ||
                  line.contains('var '))) {
            hits.add('${i + 1}: ${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'Phase 3.0 Task Contract §2.4：EditorCoordinator 不持有 Theme / File / '
            'Route 等领域状态。这些应放独立 Provider。\n'
            '命中：\n${hits.join('\n')}',
      );
    });
  });
}
