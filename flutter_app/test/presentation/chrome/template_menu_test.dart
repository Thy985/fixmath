/// TemplateMenu Widget 测试：Phase 3.3 PR #2C。
///
/// 落地 Phase 3.3 PR #2 Task Contract v2.1：
/// - §6.3 `+` 模板菜单按钮（8 模板）
/// - §2.5.1 Hard Rule：禁止业务逻辑用字符串判断模板类型
/// - §2.7.1 selection 强一致读取（验证 baseOffset + extentOffset）
/// - §5.4.1 + §6.4.1：测试必须验证 selection offset
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/editor_history.dart';
import 'package:formula_fix/presentation/chrome/editor_strings.dart';
import 'package:formula_fix/presentation/chrome/markdown_toolbar.dart';
import 'package:formula_fix/presentation/chrome/templates.dart';
import 'package:formula_fix/presentation/editor/editor_coordinator.dart';
import 'package:formula_fix/presentation/editor/in_memory_document_editor.dart';
import 'package:formula_fix/presentation/states/block_view_state.dart';

void main() {
  late InMemoryDocumentEditor editor;
  late EditorHistory history;
  late EditorCoordinator coordinator;

  setUp(() {
    editor = InMemoryDocumentEditor();
    history = EditorHistory();
    coordinator = EditorCoordinator(editor: editor, history: history);
  });

  /// 构造测试 widget：AnimatedBuilder 监听 coordinator,触发 MarkdownToolbar 重建。
  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: coordinator,
          builder: (context, _) => MarkdownToolbar(coordinator: coordinator),
        ),
      ),
    );
  }

  group('Phase 3.3 PR #2C §6.3 模板菜单渲染', () {
    testWidgets('`+` 按钮渲染（tooltip = templateMenuTooltip）', (tester) async {
      final id = editor.addParagraph('hello');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byTooltip(EditorStrings.templateMenuTooltip), findsOneWidget);
    });

    testWidgets('PopupMenu 展开后显示 8 个模板项', (tester) async {
      final id = editor.addParagraph('hello');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 点击 `+` 按钮展开 PopupMenu
      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();

      // 验证 8 个模板标签均出现
      const labels = [
        EditorStrings.templateMenuTable,
        EditorStrings.templateMenuMermaid,
        EditorStrings.templateMenuCodeBlock,
        EditorStrings.templateMenuTaskList,
        EditorStrings.templateMenuQuote,
        EditorStrings.templateMenuHorizontalRule,
        EditorStrings.templateMenuImage,
        EditorStrings.templateMenuLink,
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: '应显示模板: $label');
      }
    });

    test('8 个模板标签字符串均非空', () {
      const labels = [
        EditorStrings.templateMenuTable,
        EditorStrings.templateMenuMermaid,
        EditorStrings.templateMenuCodeBlock,
        EditorStrings.templateMenuTaskList,
        EditorStrings.templateMenuQuote,
        EditorStrings.templateMenuHorizontalRule,
        EditorStrings.templateMenuImage,
        EditorStrings.templateMenuLink,
      ];
      for (final label in labels) {
        expect(label, isNotEmpty, reason: '模板标签不应为空');
      }
    });
  });

  group('Phase 3.3 PR #2C §2.5.1 Templates 常量', () {
    test('8 个模板常量均非空 + 内容结构正确', () {
      expect(Templates.tableDefault, isNotEmpty);
      expect(Templates.tableDefault, contains('|---|---|'));
      expect(Templates.mermaidDefault, startsWith('```mermaid'));
      expect(Templates.codeBlockDefault, startsWith('```dart'));
      expect(Templates.taskListDefault, isNotEmpty);
      expect(Templates.quoteDefault, isNotEmpty);
      expect(Templates.horizontalRuleDefault, isNotEmpty);
      expect(Templates.imageDefault, isNotEmpty);
      expect(Templates.linkDefault, isNotEmpty);
    });
  });

  group('Phase 3.3 PR #2C newBlock 模式（表格 / Mermaid / 任务列表）', () {
    testWidgets('选择「表格」→ 创建新 Block + 焦点转移到新块', (tester) async {
      final id = editor.addParagraph('hello');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuTable));
      await tester.pumpAndSettle();

      // 验证：创建了新 Block（blockCount 从 1 → 2）
      expect(coordinator.blockCount, equals(2));

      // 验证：焦点转移到新块
      final focusedId = coordinator.focusedId;
      expect(focusedId, isNotNull);
      expect(focusedId, isNot(equals(id)),
          reason: 'newBlock 模式焦点应转移到新块');

      // 验证：新块 source 包含表格模板内容
      expect(coordinator.sourceOf(focusedId!), contains('列1'));
    });

    testWidgets('选择「Mermaid」→ 创建新 Block 包含 mermaid 内容', (tester) async {
      final id = editor.addParagraph('text');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuMermaid));
      await tester.pumpAndSettle();

      expect(coordinator.blockCount, equals(2));
      final focusedId = coordinator.focusedId;
      expect(focusedId, isNot(equals(id)));
      expect(coordinator.sourceOf(focusedId!), contains('graph TD'));
    });

    testWidgets('选择「任务列表」→ 创建新 Block 包含任务列表内容', (tester) async {
      final id = editor.addParagraph('text');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuTaskList));
      await tester.pumpAndSettle();

      expect(coordinator.blockCount, equals(2));
      expect(coordinator.sourceOf(coordinator.focusedId!), contains('- [ ]'));
    });

    testWidgets('newBlock 模式 selection 验证：光标在新块 offset 0（§5.4.1）',
        (tester) async {
      final id = editor.addParagraph('hello');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuTable));
      await tester.pumpAndSettle();

      // §5.4.1：验证 selection.baseOffset + extentOffset
      final focusedId = coordinator.focusedId;
      final sel = coordinator.viewStateOf(focusedId!)?.selection;
      expect(sel, isNotNull, reason: '新块应有 selection');
      expect(sel!.baseOffset, equals(0), reason: '新块光标应在 offset 0');
      expect(sel.extentOffset, equals(0), reason: '新块光标应在 offset 0（collapsed）');
    });
  });

  group('Phase 3.3 PR #2C insert 模式（代码块 / 引用 / 分隔线 / 图片 / 链接）', () {
    testWidgets('选择「代码块」→ 当前块插入 codeBlock 模板', (tester) async {
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuCodeBlock));
      await tester.pumpAndSettle();

      // 验证：仍在同一块（未创建新块）
      expect(coordinator.blockCount, equals(1));
      // 验证：source 包含代码块模板
      expect(coordinator.sourceOf(id), contains('```dart'));
    });

    testWidgets('选择「引用块」→ 当前块插入 quote 模板', (tester) async {
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuQuote));
      await tester.pumpAndSettle();

      expect(coordinator.blockCount, equals(1));
      expect(coordinator.sourceOf(id), contains('> '));
    });

    testWidgets('选择「分隔线」→ 当前块插入 hr 模板', (tester) async {
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuHorizontalRule));
      await tester.pumpAndSettle();

      expect(coordinator.blockCount, equals(1));
      expect(coordinator.sourceOf(id), contains('---'));
    });

    testWidgets('选择「图片」→ 当前块插入 image 模板', (tester) async {
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuImage));
      await tester.pumpAndSettle();

      expect(coordinator.blockCount, equals(1));
      expect(coordinator.sourceOf(id), contains('![alt](url)'));
    });

    testWidgets('选择「链接」→ 当前块插入 link 模板', (tester) async {
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuLink));
      await tester.pumpAndSettle();

      expect(coordinator.blockCount, equals(1));
      expect(coordinator.sourceOf(id), contains('[文本](url)'));
    });
  });

  group('Phase 3.3 PR #2C §5.4.1 + §6.4.1 selection offset 验证', () {
    testWidgets('insert 模式：无选区时光标定位到插入文本末尾 + cursorOffset', (tester) async {
      // 代码块模板：cursorOffset = -4
      // template = '```dart\n\n```' (length 12)
      // 无选区 → insertOffset = 0（空块 source.length = 0）
      // 光标位置 = 0 + 12 + (-4) = 8
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuCodeBlock));
      await tester.pumpAndSettle();

      // §5.4.1：验证 selection.baseOffset + extentOffset
      final sel = coordinator.viewStateOf(id)?.selection;
      expect(sel, isNotNull, reason: 'insert 后应有 selection');
      expect(sel!.isCollapsed, isTrue, reason: '应为 collapsed 光标');
      expect(sel.baseOffset, equals(8),
          reason: '光标应在 offset 8（代码区空行）');
      expect(sel.extentOffset, equals(8));
    });

    testWidgets('insert 模式：有选区时光标基于 selection.baseOffset 计算', (tester) async {
      // 图片模板：cursorOffset = -4
      // template = '![alt](url)' (length 11)
      // 选区 baseOffset = 3 → insertOffset = 3
      // 光标位置 = 3 + 11 + (-4) = 10
      final id = editor.addParagraph('hello');
      coordinator.setFocus(id);
      // 设置选区 [3, 3)（collapsed,baseOffset = 3）
      final state = coordinator.viewStateOf(id) ?? BlockViewState(id: id);
      coordinator.updateViewState(
        id,
        state.copyWith(
          selection: const TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuImage));
      await tester.pumpAndSettle();

      // §6.4.1：验证 selection offset 基于 baseOffset 计算
      final sel = coordinator.viewStateOf(id)?.selection;
      expect(sel, isNotNull);
      expect(sel!.baseOffset, equals(3 + 11 + (-4)),
          reason: '光标 = insertOffset(3) + template.length(11) + cursorOffset(-4) = 10');
      expect(sel.extentOffset, equals(10));
    });

    testWidgets('insert 模式：链接模板 cursorOffset 定位到 url 位置', (tester) async {
      // 链接模板：cursorOffset = -4
      // template = '[文本](url)' (length 9)
      // 空块 → insertOffset = 0
      // 光标位置 = 0 + 9 + (-4) = 5（url 的 'u' 位置）
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuLink));
      await tester.pumpAndSettle();

      final sel = coordinator.viewStateOf(id)?.selection;
      expect(sel, isNotNull);
      expect(sel!.baseOffset, equals(5), reason: '光标应定位到 url 位置（offset 5）');
      expect(sel.extentOffset, equals(5));
    });

    testWidgets('insert 模式：引用模板 cursorOffset=0 光标在末尾', (tester) async {
      // 引用模板：cursorOffset = 0, template = '> 引用内容' (length 6)
      // 空块 → insertOffset = 0, 光标位置 = 0 + 6 + 0 = 6
      final id = editor.addParagraph('');
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      await tester.tap(find.byTooltip(EditorStrings.templateMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EditorStrings.templateMenuQuote));
      await tester.pumpAndSettle();

      final sel = coordinator.viewStateOf(id)?.selection;
      expect(sel, isNotNull);
      expect(sel!.baseOffset, equals(6), reason: '光标应在插入文本末尾（offset 6）');
    });
  });

  group('Phase 3.3 PR #2C §2.8 CodeBlock 禁用 + 无聚焦禁用', () {
    testWidgets('CodeBlock 聚焦时 `+` 按钮不显示（整体工具栏禁用,§2.8）',
        (tester) async {
      final id = editor.addBlock('print("hello")', BlockType.code);
      coordinator.setFocus(id);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // CodeBlock 聚焦时显示禁用提示,不显示工具栏按钮（含 `+`）
      expect(find.text(EditorStrings.codeBlockToolbarDisabled), findsOneWidget);
      expect(find.byTooltip(EditorStrings.templateMenuTooltip), findsNothing);
    });

    testWidgets('无聚焦块时 `+` 按钮禁用（onPressed = null）', (tester) async {
      editor.addParagraph('hello');
      // 不 setFocus
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // `+` 按钮（Icons.add）应存在但禁用
      expect(find.byIcon(Icons.add), findsOneWidget);
      final iconButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(IconButton),
        ),
      );
      expect(iconButton.onPressed, isNull, reason: '无聚焦块时 `+` 应禁用');
    });
  });
}
