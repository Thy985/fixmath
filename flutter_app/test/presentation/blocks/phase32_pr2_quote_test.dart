/// Phase 3.2 PR #2 QuoteBlock 测试。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.4：
/// - TC-BLOCK-QUOTE-1：QuoteBlock render 视觉（左侧竖线 + serif + 文本）
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-BLOCK-QUOTE-1 QuoteBlock render 视觉 ============

  group('TC-BLOCK-QUOTE-1 QuoteBlock render 视觉', () {
    test('QuoteBlock 使用 BlockquoteElement.text 渲染纯文本', () {
      final file = File('lib/presentation/blocks/quote/quote_block.dart');
      expect(file.existsSync(), isTrue, reason: 'quote_block.dart 必须存在');
      final content = file.readAsStringSync();

      // 必须访问 widget.element.text（BlockquoteElement 的 text 字段）
      expect(
        content.contains('widget.element.text'),
        isTrue,
        reason: 'QuoteBlock 必须使用 BlockquoteElement.text 渲染文本',
      );
    });

    test('QuoteBlock 左侧竖线使用 EditorTokens.quoteBorderColor', () {
      final file = File('lib/presentation/blocks/quote/quote_block.dart');
      final content = file.readAsStringSync();

      // 必须使用 EditorTokens.quoteBorderColor（不硬编码 Color(0xFFC0C0C0)）
      expect(
        content.contains('EditorTokens.quoteBorderColor'),
        isTrue,
        reason: 'Phase 3.2 PR #2：QuoteBlock 左侧竖线颜色必须使用 '
            'EditorTokens.quoteBorderColor（Token 先行,ui-spec.md §1.1 R1）',
      );
      // 不应硬编码 Color(0xFFC0C0C0)
      expect(
        content.contains('Color(0xFFC0C0C0)'),
        isFalse,
        reason: 'QuoteBlock 不应硬编码 Color(0xFFC0C0C0),应使用 EditorTokens',
      );
    });

    test('QuoteBlock 使用 serif 字体（与 ParagraphBlock sans-serif 区分）', () {
      final file = File('lib/presentation/blocks/quote/quote_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains("fontFamily: 'serif'"),
        isTrue,
        reason: 'QuoteBlock 必须使用 serif 字体（视觉规范,ui-spec.md §2.3）',
      );
    });

    test('QuoteBlock 使用 EditorTokens.paragraphFontSize（fontSize: 16）', () {
      final file = File('lib/presentation/blocks/quote/quote_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('EditorTokens.paragraphFontSize'),
        isTrue,
        reason: 'QuoteBlock 字号必须使用 EditorTokens.paragraphFontSize',
      );
      // 不应硬编码 fontSize: 16
      expect(
        RegExp(r'fontSize:\s*16\b').hasMatch(content),
        isFalse,
        reason: 'QuoteBlock 不应硬编码 fontSize: 16,应使用 EditorTokens',
      );
    });

    test('QuoteBlock extends BaseBlockState（不重写 build）', () {
      final file = File('lib/presentation/blocks/quote/quote_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('extends BaseBlockState<QuoteBlock>'),
        isTrue,
        reason: 'QuoteBlock 必须 extends BaseBlockState<QuoteBlock>',
      );
      // 不应重写 build()（由基类统一调度）
      final lines = content.split('\n');
      var hasBuildOverride = false;
      for (var i = 0; i < lines.length - 1; i++) {
        if (RegExp(r'^\s*@override\s*$').hasMatch(lines[i])) {
          for (var j = i + 1; j < lines.length; j++) {
            final next = lines[j].trim();
            if (next.isEmpty) continue;
            if (RegExp(r'Widget\s+build\(BuildContext\s+context\)').hasMatch(next)) {
              hasBuildOverride = true;
            }
            break;
          }
        }
      }
      expect(
        hasBuildOverride,
        isFalse,
        reason: 'QuoteBlock 不应重写 build(),由 BaseBlockState 统一调度（§3.0 方案 A）',
      );
      expect(
        content.contains('Widget buildRenderContent(BuildContext context)'),
        isTrue,
        reason: 'QuoteBlock 必须实现 buildRenderContent（§3.0 方案 A）',
      );
    });
  });
}
