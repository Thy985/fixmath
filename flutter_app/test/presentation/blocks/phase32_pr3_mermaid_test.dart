/// Phase 3.2 PR #3 MermaidBlock 测试。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.3（任务 3.2.2）：
/// - TC-BLOCK-MERMAID-1：MermaidBlock render 视觉（封装 MermaidElementWidget）
/// - TC-BLOCK-MERMAID-2：WebView 未就绪 fallback 占位
/// - TC-BLOCK-MERMAID-3：MermaidBlock extends BaseBlockState（§3.0 方案 A 守门）
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-BLOCK-MERMAID-1 MermaidBlock render 视觉 ============

  group('TC-BLOCK-MERMAID-1 MermaidBlock render 视觉', () {
    test('MermaidBlock 使用 MermaidElement.code 渲染', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      expect(file.existsSync(), isTrue, reason: 'mermaid_block.dart 必须存在');
      final content = file.readAsStringSync();

      expect(
        content.contains('widget.element.code'),
        isTrue,
        reason: 'MermaidBlock 必须使用 MermaidElement.code 渲染',
      );
    });

    test('MermaidBlock 封装 MermaidElementWidget（复用现有渲染逻辑）', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('MermaidElementWidget'),
        isTrue,
        reason: 'MermaidBlock 必须封装 MermaidElementWidget（复用 core/services/mermaid_renderer.dart）',
      );
    });

    test('MermaidBlock 使用 EditorTokens（不硬编码颜色 / 字号）', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('EditorTokens.codeBackground'),
        isTrue,
        reason: 'MermaidBlock 背景必须使用 EditorTokens.codeBackground',
      );
      expect(
        content.contains('EditorTokens.codeFontSize'),
        isTrue,
        reason: 'MermaidBlock edit 态字号必须使用 EditorTokens.codeFontSize',
      );
      // 不应硬编码 Colors.grey.shade100（与 PR #2 review fix 一致）
      expect(
        content.contains('Colors.grey.shade100'),
        isFalse,
        reason: 'MermaidBlock 不应硬编码 Colors.grey.shade100',
      );
    });

    test('MermaidBlock edit 态 monospace + newline action', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains("fontFamily: 'monospace'"),
        isTrue,
        reason: 'MermaidBlock edit 态必须使用 monospace 字体',
      );
      expect(
        content.contains('TextInputAction.newline'),
        isTrue,
        reason: 'MermaidBlock edit 态必须用 newline action（多行源码）',
      );
    });
  });

  // ============ TC-BLOCK-MERMAID-2 WebView 未就绪 fallback ============

  group('TC-BLOCK-MERMAID-2 WebView 未就绪 fallback', () {
    test('MermaidBlock 检测 MermaidService.isReady', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('MermaidService.isReady'),
        isTrue,
        reason: 'MermaidBlock 必须检测 MermaidService.isReady 状态',
      );
    });

    test('MermaidBlock WebView 未就绪时显示占位（不崩溃）', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      // 必须有 fallback 占位方法
      expect(
        content.contains('WebView 预热中'),
        isTrue,
        reason: 'MermaidBlock WebView 未就绪时必须显示占位文本',
      );
      // 必须显示源码预览（让用户在 edit 态修正）
      expect(
        content.contains('_buildWebViewNotReadyPlaceholder'),
        isTrue,
        reason: 'MermaidBlock 必须有 _buildWebViewNotReadyPlaceholder 方法',
      );
    });
  });

  // ============ TC-BLOCK-MERMAID-3 §3.0 方案 A 守门 ============

  group('TC-BLOCK-MERMAID-3 MermaidBlock §3.0 方案 A 守门', () {
    test('MermaidBlock extends BaseBlockState（不重写 build）', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('extends BaseBlockState<MermaidBlock>'),
        isTrue,
        reason: 'MermaidBlock 必须 extends BaseBlockState<MermaidBlock>',
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
        reason: 'MermaidBlock 不应重写 build(),由 BaseBlockState 统一调度（§3.0 方案 A）',
      );
      expect(
        content.contains('Widget buildRenderContent(BuildContext context)'),
        isTrue,
        reason: 'MermaidBlock 必须实现 buildRenderContent（§3.0 方案 A）',
      );
    });
  });
}
