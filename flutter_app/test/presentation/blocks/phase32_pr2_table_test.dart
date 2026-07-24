/// Phase 3.2 PR #2 TableBlock 测试。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.5：
/// - TC-BLOCK-TABLE-1：TableBlock render 视觉（headers + rows + 边框）
/// - TC-BLOCK-TABLE-2：TableBlock 空表边缘情况
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(
        content.contains('Widget buildRenderContent(BuildContext context)'),
        isTrue,
        reason: 'TableBlock 必须实现 buildRenderContent（§3.0 方案 A）',
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
}
