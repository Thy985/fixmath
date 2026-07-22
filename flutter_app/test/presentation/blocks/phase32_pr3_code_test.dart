/// Phase 3.2 PR #3 CodeBlock 语法高亮测试。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.11（任务 3.2.10）：
/// - TC-BLOCK-CODE-1：Dart 代码高亮（HighlightView 接入）
/// - TC-BLOCK-CODE-2：未知 language fallback 到 plaintext（不崩溃）
/// - TC-BLOCK-CODE-3：language 别名归一化（js → javascript 等）
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-BLOCK-CODE-1 HighlightView 接入 ============

  group('TC-BLOCK-CODE-1 CodeBlock 语法高亮接入', () {
    test('CodeBlock import flutter_highlight', () {
      final file = File('lib/presentation/blocks/code/code_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains("import 'package:flutter_highlight/flutter_highlight.dart'"),
        isTrue,
        reason: 'CodeBlock 必须 import flutter_highlight（Phase 3.2 §3.11 选项 A）',
      );
      expect(
        content.contains("import 'package:flutter_highlight/themes/github.dart'"),
        isTrue,
        reason: 'CodeBlock 必须 import githubTheme（light 主题,Phase 3.9+ 改为 Theme 驱动）',
      );
    });

    test('CodeBlock render 态使用 HighlightView（替换 Text）', () {
      final file = File('lib/presentation/blocks/code/code_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('HighlightView('),
        isTrue,
        reason: 'CodeBlock render 态必须使用 HighlightView 显示语法高亮',
      );
      expect(
        content.contains('githubTheme'),
        isTrue,
        reason: 'CodeBlock 必须使用 githubTheme 作为高亮主题',
      );
    });

    test('CodeBlock 使用 EditorTokens（不硬编码颜色 / 字号）', () {
      final file = File('lib/presentation/blocks/code/code_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('EditorTokens.codeBackground'),
        isTrue,
        reason: 'CodeBlock 背景必须使用 EditorTokens.codeBackground',
      );
      expect(
        content.contains('EditorTokens.codeFontSize'),
        isTrue,
        reason: 'CodeBlock 字号必须使用 EditorTokens.codeFontSize',
      );
      expect(
        content.contains('EditorTokens.codeLanguageChip'),
        isTrue,
        reason: 'CodeBlock language chip 必须使用 EditorTokens.codeLanguageChip',
      );
      // 不应硬编码 Colors.grey.shade100 / .shade300
      expect(
        content.contains('Colors.grey.shade100'),
        isFalse,
        reason: 'CodeBlock 不应硬编码 Colors.grey.shade100',
      );
      expect(
        content.contains('Colors.grey.shade300'),
        isFalse,
        reason: 'CodeBlock 不应硬编码 Colors.grey.shade300',
      );
    });
  });

  // ============ TC-BLOCK-CODE-2 未知 language fallback ============

  group('TC-BLOCK-CODE-2 未知 language fallback', () {
    test('CodeBlock 有 _normalizeLanguage 方法（处理未知 language）', () {
      final file = File('lib/presentation/blocks/code/code_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('_normalizeLanguage'),
        isTrue,
        reason: 'CodeBlock 必须有 _normalizeLanguage 方法处理未知 language',
      );
      expect(
        content.contains("return 'plaintext'"),
        isTrue,
        reason: 'CodeBlock 未知 language 必须 fallback 到 plaintext（不崩溃）',
      );
    });

    test('CodeBlock _normalizeLanguage 处理 null / empty', () {
      final file = File('lib/presentation/blocks/code/code_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('language == null') || content.contains('language == null'),
        isTrue,
        reason: 'CodeBlock _normalizeLanguage 必须处理 null language',
      );
      expect(
        content.contains('language.isEmpty'),
        isTrue,
        reason: 'CodeBlock _normalizeLanguage 必须处理空 language',
      );
    });
  });

  // ============ TC-BLOCK-CODE-3 language 别名归一化 ============

  group('TC-BLOCK-CODE-3 language 别名归一化', () {
    test('CodeBlock _normalizeLanguage 包含常见别名映射', () {
      final file = File('lib/presentation/blocks/code/code_block.dart');
      final content = file.readAsStringSync();

      // 必须有别名映射表（至少包含 js / ts / py / sh 等常见别名）
      expect(
        content.contains("'js': 'javascript'"),
        isTrue,
        reason: 'CodeBlock _normalizeLanguage 必须映射 js → javascript',
      );
      expect(
        content.contains("'ts': 'typescript'"),
        isTrue,
        reason: 'CodeBlock _normalizeLanguage 必须映射 ts → typescript',
      );
      expect(
        content.contains("'py': 'python'"),
        isTrue,
        reason: 'CodeBlock _normalizeLanguage 必须映射 py → python',
      );
      expect(
        content.contains("'sh': 'bash'") || content.contains("'shell': 'bash'"),
        isTrue,
        reason: 'CodeBlock _normalizeLanguage 必须映射 sh/shell → bash',
      );
    });

    test('CodeBlock _normalizeLanguage 大小写归一化（toLowerCase）', () {
      final file = File('lib/presentation/blocks/code/code_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('toLowerCase()'),
        isTrue,
        reason: 'CodeBlock _normalizeLanguage 必须调用 toLowerCase() 归一化大小写',
      );
    });
  });
}
