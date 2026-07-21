/// TC-ARCH-UI-8: Phase 3.0 exhaustive switch 守门测试。
///
/// 落地 Phase 3.0 Task Contract §3.3（BlockRenderer 抽象）+ §6（Exit Gate）+
/// ADR-0009 Hard Rule 3（BlockRenderer 抽象）。
///
/// 守门内容：
/// - `BlockRenderer` 必须使用 `switch (element)` exhaustive 语法
/// - `BlockRenderer` 不允许 `_ =>` fallback 分支
/// - `BlockRenderer` 必须显式支持 3 种 BlockType（paragraph / heading / code）
/// - 未实现的 6 种类型必须显式 throw UnimplementedError（不默默退化显示）
///
/// 为什么不允许 GenericBlock fallback（Human Owner 反馈）：
/// - 若有 fallback，新增 Block 类型时不会立刻暴露未实现，可能默默退化显示
/// - 显式抛错让 Phase 3.2+ 实现新类型时立即被测试发现
/// - 与 Phase 2.4 的 BlockType.fromElement exhaustive 设计一致
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-ARCH-UI-8 exhaustive switch 守门 ============

  group('TC-ARCH-UI-8 exhaustive switch 守门：BlockRenderer 不允许 _ => fallback', () {
    test('block_renderer.dart 包含 switch (element) 语法', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      expect(file.existsSync(), isTrue,
          reason: 'block_renderer.dart 必须存在');
      final content = file.readAsStringSync();
      expect(
        content.contains('switch (element)'),
        isTrue,
        reason: 'Phase 3.0 Task Contract §3.3：BlockRenderer 必须使用 '
            'switch (element) exhaustive 语法。',
      );
    });

    test('block_renderer.dart 不含 _ => fallback 分支', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final lines = file.readAsLinesSync();
      final hits = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        // 匹配 _ => 或 _ =>（允许空格）的 fallback 分支
        if (RegExp(r'^_\s*=>').hasMatch(trimmed) ||
            RegExp(r'\|\|\s*_\s*=>').hasMatch(trimmed)) {
          hits.add('${i + 1}: ${line.trim()}');
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'Phase 3.0 Task Contract §3.3：BlockRenderer 必须使用 exhaustive '
            'switch，不允许 _ => fallback 到 GenericBlock。\n'
            '命中：\n${hits.join('\n')}',
      );
    });

    test('block_renderer.dart 显式支持 3 种 BlockType', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final content = file.readAsStringSync();
      // 必须显式 case ParagraphElement / HeadingElement / CodeElement
      expect(
        content.contains('ParagraphElement'),
        isTrue,
        reason: 'BlockRenderer 必须支持 ParagraphElement',
      );
      expect(
        content.contains('HeadingElement'),
        isTrue,
        reason: 'BlockRenderer 必须支持 HeadingElement',
      );
      expect(
        content.contains('CodeElement'),
        isTrue,
        reason: 'BlockRenderer 必须支持 CodeElement',
      );
      // 其他 6 种类型必须显式 throw UnimplementedError（不默默 fallback）
      expect(
        content.contains('UnimplementedError'),
        isTrue,
        reason: 'Phase 3.0：未实现的 6 种类型必须显式 throw UnimplementedError，'
            '不允许默默退化显示。',
      );
    });
  });
}
