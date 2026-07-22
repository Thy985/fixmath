/// Phase 3.2 PR #2 功能测试：QuoteBlock / TableBlock / Link Inline Rendering。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.4 / §3.5 / §3.7：
/// - TC-BLOCK-QUOTE-1：QuoteBlock render 视觉（左侧竖线 + serif + 文本）
/// - TC-BLOCK-TABLE-1：TableBlock render 视觉（headers + rows + 边框）
/// - TC-BLOCK-TABLE-2：TableBlock 空表边缘情况
/// - TC-BLOCK-LINK-1：LinkElement inline rendering（蓝色 + 下划线,无多余 URL）
/// - TC-BLOCK-IMAGE-1：ImageElement inline rendering（占位 + alt 文本）
/// - TC-BLOCK-CASE-DISPATCH：BlockRenderer 的 Quote / Table case 分发
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
/// 不使用 WidgetTester（避免依赖完整 EditorScope widget 树）
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
  });

  // ============ TC-BLOCK-TABLE-1 TableBlock render 视觉 ============

  group('TC-BLOCK-TABLE-1 TableBlock render 视觉', () {
    test('TableBlock 使用 TableElement.headers 和 TableElement.rows', () {
      final file = File('lib/presentation/blocks/table/table_block.dart');
      expect(file.existsSync(), isTrue, reason: 'table_block.dart 必须存在');
      final content = file.readAsStringSync();

      expect(
        content.contains('widget.element.headers'),
        isTrue,
        reason: 'TableBlock 必须使用 TableElement.headers',
      );
      expect(
        content.contains('widget.element.rows'),
        isTrue,
        reason: 'TableBlock 必须使用 TableElement.rows',
      );
    });

    test('TableBlock 使用 Table widget 渲染（headers + rows + 边框）', () {
      final file = File('lib/presentation/blocks/table/table_block.dart');
      final content = file.readAsStringSync();

      // 必须使用 Table widget
      expect(
        content.contains('Table('),
        isTrue,
        reason: 'TableBlock 必须使用 Table widget 渲染',
      );
      // 必须有表头行（headers）
      expect(
        content.contains('TableRow'),
        isTrue,
        reason: 'TableBlock 必须使用 TableRow 渲染表头和数据行',
      );
      // 必须有边框
      expect(
        content.contains('TableBorder.all'),
        isTrue,
        reason: 'TableBlock 必须有表格边框（TableBorder.all）',
      );
      // 表头必须加粗
      expect(
        content.contains('FontWeight.bold'),
        isTrue,
        reason: 'TableBlock 表头必须加粗（FontWeight.bold）',
      );
    });

    test('TableBlock 使用 EditorTokens（不硬编码颜色 / 字号）', () {
      final file = File('lib/presentation/blocks/table/table_block.dart');
      final content = file.readAsStringSync();

      // 边框颜色
      expect(
        content.contains('EditorTokens.tableBorderColor'),
        isTrue,
        reason: 'TableBlock 边框颜色必须使用 EditorTokens.tableBorderColor',
      );
      expect(
        content.contains('Colors.grey.shade300'),
        isFalse,
        reason: 'TableBlock 不应硬编码 Colors.grey.shade300',
      );
      // 表头背景
      expect(
        content.contains('EditorTokens.tableHeaderBackground'),
        isTrue,
        reason: 'TableBlock 表头背景必须使用 EditorTokens.tableHeaderBackground',
      );
      expect(
        content.contains('Colors.grey.shade100'),
        isFalse,
        reason: 'TableBlock 不应硬编码 Colors.grey.shade100',
      );
      // 单元格字号
      expect(
        content.contains('EditorTokens.tableCellFontSize'),
        isTrue,
        reason: 'TableBlock 单元格字号必须使用 EditorTokens.tableCellFontSize',
      );
    });

    test('TableBlock 无冗余 columnWidths: const {}', () {
      final file = File('lib/presentation/blocks/table/table_block.dart');
      final content = file.readAsStringSync();

      // 不应有冗余 columnWidths: const {}（已由 defaultColumnWidth 处理）
      expect(
        content.contains('columnWidths: const {}'),
        isFalse,
        reason: 'TableBlock 不应有冗余 columnWidths: const {},'
            '已由 defaultColumnWidth: IntrinsicColumnWidth() 处理',
      );
    });

    test('TableBlock 使用 SingleChildScrollView 横向滚动（避免窄屏溢出）', () {
      final file = File('lib/presentation/blocks/table/table_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('SingleChildScrollView'),
        isTrue,
        reason: 'TableBlock 必须使用 SingleChildScrollView 包裹,避免窄屏溢出',
      );
      expect(
        content.contains('Axis.horizontal'),
        isTrue,
        reason: 'TableBlock 滚动方向必须是 Axis.horizontal',
      );
    });
  });

  // ============ TC-BLOCK-TABLE-2 TableBlock 空表边缘情况 ============

  group('TC-BLOCK-TABLE-2 TableBlock 空表边缘情况', () {
    test('TableBlock 处理 headers 和 rows 都为空的情况', () {
      final file = File('lib/presentation/blocks/table/table_block.dart');
      final content = file.readAsStringSync();

      // 必须有空表检测（headers.isEmpty && rows.isEmpty）
      expect(
        content.contains('headers.isEmpty && rows.isEmpty'),
        isTrue,
        reason: 'TableBlock 必须处理 headers 和 rows 都为空的边缘情况',
      );
      // 必须有空表占位文本
      expect(
        content.contains('空表格'),
        isTrue,
        reason: 'TableBlock 空表必须有占位文本（"空表格"）',
      );
    });
  });

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

  // ============ TC-BLOCK-BASE §3.0 方案 A 守门（QuoteBlock / TableBlock） ============

  group('TC-BLOCK-BASE QuoteBlock / TableBlock §3.0 方案 A 守门', () {
    test('QuoteBlock extends BaseBlockState（不重写 build）', () {
      final file = File('lib/presentation/blocks/quote/quote_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('extends BaseBlockState<QuoteBlock>'),
        isTrue,
        reason: 'QuoteBlock 必须 extends BaseBlockState<QuoteBlock>',
      );
      // 不应重写 build()（由基类统一调度）
      // 检测 @override 后跟 Widget build(BuildContext context)
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
    });

    test('TableBlock extends BaseBlockState（不重写 build）', () {
      final file = File('lib/presentation/blocks/table/table_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('extends BaseBlockState<TableBlock>'),
        isTrue,
        reason: 'TableBlock 必须 extends BaseBlockState<TableBlock>',
      );
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
        reason: 'TableBlock 不应重写 build(),由 BaseBlockState 统一调度（§3.0 方案 A）',
      );
    });

    test('QuoteBlock / TableBlock 实现 buildRenderContent', () {
      for (final name in [
        'lib/presentation/blocks/quote/quote_block.dart',
        'lib/presentation/blocks/table/table_block.dart',
      ]) {
        final file = File(name);
        final content = file.readAsStringSync();
        expect(
          content.contains('Widget buildRenderContent(BuildContext context)'),
          isTrue,
          reason: '$name 必须实现 buildRenderContent（§3.0 方案 A）',
        );
      }
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
