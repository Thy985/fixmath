/// Phase 3.2 PR #2 Inline rendering 测试（Link / Image）。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.6 / §3.7：
/// - TC-BLOCK-LINK-1：LinkElement inline rendering（蓝色 + 下划线,无多余 URL）
/// - TC-BLOCK-IMAGE-1：ImageElement inline rendering（占位 + alt 文本）
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-BLOCK-LINK-1 LinkElement inline rendering ============

  group('TC-BLOCK-LINK-1 LinkElement inline rendering', () {
    test('ParagraphBlock inline renderer 支持 LinkElement', () {
      final file = File('lib/presentation/blocks/paragraph/paragraph_block.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(
        content.contains('LinkElement'),
        isTrue,
        reason: 'ParagraphBlock inline renderer 必须支持 LinkElement',
      );
    });

    test('LinkElement 渲染为蓝色 + 下划线', () {
      final file = File('lib/presentation/blocks/paragraph/paragraph_block.dart');
      final content = file.readAsStringSync();

      // 必须使用 EditorTokens.linkColor（不硬编码 Colors.blue）
      expect(
        content.contains('EditorTokens.linkColor'),
        isTrue,
        reason: 'LinkElement 颜色必须使用 EditorTokens.linkColor'
            '（Token 先行,ui-spec.md §1.1 R1）',
      );
      expect(
        content.contains('Colors.blue'),
        isFalse,
        reason: 'LinkElement 不应硬编码 Colors.blue,应使用 EditorTokens.linkColor',
      );
      // 必须有下划线
      expect(
        content.contains('TextDecoration.underline'),
        isTrue,
        reason: 'LinkElement 必须有下划线（视觉规范,ui-spec.md §3.2）',
      );
    });

    test('LinkElement 不显示多余 URL 后缀', () {
      final file = File('lib/presentation/blocks/paragraph/paragraph_block.dart');
      final content = file.readAsStringSync();

      // 不应有 " ($url)" 后缀（Phase 3.2 §3.7 移除）
      // 使用原始字符串避免 $url 被解释为字符串插值
      expect(
        content.contains(r' ($url)'),
        isFalse,
        reason: 'Phase 3.2 §3.7：LinkElement 不应显示多余 (url) 后缀,'
            '只显示蓝色文本 + 下划线',
      );
    });
  });

  // ============ TC-BLOCK-IMAGE-1 ImageElement inline rendering ============

  group('TC-BLOCK-IMAGE-1 ImageElement inline rendering', () {
    test('ParagraphBlock inline renderer 支持 ImageElement', () {
      final file = File('lib/presentation/blocks/paragraph/paragraph_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('ImageElement'),
        isTrue,
        reason: 'ParagraphBlock inline renderer 必须支持 ImageElement',
      );
    });

    test('ImageElement 渲染为 [图片: alt] 占位 + 次要颜色', () {
      final file = File('lib/presentation/blocks/paragraph/paragraph_block.dart');
      final content = file.readAsStringSync();

      // 必须有 [图片: 占位文本
      expect(
        content.contains('[图片:'),
        isTrue,
        reason: 'ImageElement 必须渲染为 [图片: alt] 占位文本',
      );
      // 必须使用 EditorTokens.textSecondary
      // （注：InlineCodeElement 仍用 Colors.grey.shade200,是 pre-existing,不在本测试范围）
      expect(
        content.contains('EditorTokens.textSecondary'),
        isTrue,
        reason: 'ImageElement 占位颜色必须使用 EditorTokens.textSecondary',
      );
      // 必须有斜体
      expect(
        content.contains('FontStyle.italic'),
        isTrue,
        reason: 'ImageElement 占位文本必须斜体（视觉规范）',
      );
    });
  });
}
