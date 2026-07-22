/// Phase 3.2 PR #2 架构守门测试（BlockRenderer case 分发 + EditorTokens）。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.4 / §3.5 / §3.7：
/// - TC-BLOCK-CASE-DISPATCH：BlockRenderer 的 Quote / Table case 分发
/// - EditorTokens 扩展验证（5 个新 token）
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-BLOCK-CASE-DISPATCH BlockRenderer case 分发 ============

  group('TC-BLOCK-CASE-DISPATCH BlockRenderer Quote / Table case 分发', () {
    test('BlockRenderer 包含 BlockquoteElement be => QuoteBlock 分支', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('BlockquoteElement be => QuoteBlock'),
        isTrue,
        reason: 'BlockRenderer 必须有 BlockquoteElement → QuoteBlock 的 case 分发',
      );
    });

    test('BlockRenderer 包含 TableElement te => TableBlock 分支', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('TableElement te => TableBlock'),
        isTrue,
        reason: 'BlockRenderer 必须有 TableElement → TableBlock 的 case 分发',
      );
    });

    test('BlockRenderer import quote_block.dart 和 table_block.dart', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains("import 'quote/quote_block.dart'"),
        isTrue,
        reason: 'BlockRenderer 必须 import quote/quote_block.dart',
      );
      expect(
        content.contains("import 'table/table_block.dart'"),
        isTrue,
        reason: 'BlockRenderer 必须 import table/table_block.dart',
      );
    });
  });

  // ============ EditorTokens 扩展验证 ============

  group('EditorTokens Phase 3.2 PR #2 扩展', () {
    test('EditorTokens 新增 5 个 token（quote/table/link）', () {
      final file = File('lib/presentation/themes/editor_tokens.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('quoteBorderColor'),
        isTrue,
        reason: 'EditorTokens 必须有 quoteBorderColor',
      );
      expect(
        content.contains('tableBorderColor'),
        isTrue,
        reason: 'EditorTokens 必须有 tableBorderColor',
      );
      expect(
        content.contains('tableHeaderBackground'),
        isTrue,
        reason: 'EditorTokens 必须有 tableHeaderBackground',
      );
      expect(
        content.contains('tableCellFontSize'),
        isTrue,
        reason: 'EditorTokens 必须有 tableCellFontSize',
      );
      expect(
        content.contains('linkColor'),
        isTrue,
        reason: 'EditorTokens 必须有 linkColor',
      );
    });
  });
}
