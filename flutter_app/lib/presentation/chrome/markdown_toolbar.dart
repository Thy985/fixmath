/// MarkdownToolbar：Markdown 格式工具栏（chrome 组件）。
///
/// 落地 Phase 3.3 PR #2 Task Contract v2.1：
/// - §2.1 位置 A+B 混合（底部固定栏 + 横向滚动）
/// - §2.2 状态来源：只读 CoordinatorState
/// - §2.3 Command Layer 强制（所有修改通过 EditorCommand）
/// - §2.7.1 selection 强一致读取（onPressed 中重新读取）
/// - §2.8 CodeBlock 工具栏行为（全部禁用 + 提示）
/// - §6.3 `+` 模板菜单按钮（8 模板：表格/Mermaid/代码块/任务列表/引用/分隔线/图片/链接）
///
/// **依赖方向**（Hard Rule 8）：chrome/ 通过 [EditorCoordinator] 接收数据,
/// 不 import blocks/ / panels/。
library;

import 'package:flutter/material.dart';

import '../commands/commands.dart';
import '../editor/editor_coordinator.dart';
import 'editor_strings.dart';
import 'templates.dart';

/// 模板菜单项标识（UI 菜单分发用,非业务字符串判断,§2.5.1 Hard Rule）。
enum _TemplateMenuItem {
  table,
  mermaid,
  codeBlock,
  taskList,
  quote,
  horizontalRule,
  image,
  link,
}

/// 模板配置（label + template + mode + cursorOffset 聚合,消除冗余 switch）。
typedef _TemplateConfig = ({
  _TemplateMenuItem item,
  String label,
  String template,
  TemplateInsertMode mode,
  int cursorOffset,
});

/// 8 种模板的配置清单（§6.3）。
const List<_TemplateConfig> _kTemplateConfigs = [
  (item: _TemplateMenuItem.table, label: EditorStrings.templateMenuTable, template: Templates.tableDefault, mode: TemplateInsertMode.newBlock, cursorOffset: 0),
  (item: _TemplateMenuItem.mermaid, label: EditorStrings.templateMenuMermaid, template: Templates.mermaidDefault, mode: TemplateInsertMode.newBlock, cursorOffset: 0),
  (item: _TemplateMenuItem.codeBlock, label: EditorStrings.templateMenuCodeBlock, template: Templates.codeBlockDefault, mode: TemplateInsertMode.insert, cursorOffset: -4),
  (item: _TemplateMenuItem.taskList, label: EditorStrings.templateMenuTaskList, template: Templates.taskListDefault, mode: TemplateInsertMode.newBlock, cursorOffset: 0),
  (item: _TemplateMenuItem.quote, label: EditorStrings.templateMenuQuote, template: Templates.quoteDefault, mode: TemplateInsertMode.insert, cursorOffset: 0),
  (item: _TemplateMenuItem.horizontalRule, label: EditorStrings.templateMenuHorizontalRule, template: Templates.horizontalRuleDefault, mode: TemplateInsertMode.insert, cursorOffset: 0),
  (item: _TemplateMenuItem.image, label: EditorStrings.templateMenuImage, template: Templates.imageDefault, mode: TemplateInsertMode.insert, cursorOffset: -4),
  (item: _TemplateMenuItem.link, label: EditorStrings.templateMenuLink, template: Templates.linkDefault, mode: TemplateInsertMode.insert, cursorOffset: -4),
];

/// Markdown 格式工具栏（chrome 组件）。
///
/// **状态来源**（§2.2 只读 CoordinatorState）：
/// - `coordinator.focusedId` - 当前聚焦块 ID（null = 无聚焦）
/// - `coordinator.focusedBlockType` - 聚焦块类型（CodeBlock 时禁用工具栏）
/// - `coordinator.focusedSelection` - 聚焦块选区（§2.7.1 强一致读取）
/// - `coordinator.hasSelection` - 是否有非空选区
class MarkdownToolbar extends StatelessWidget {
  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const MarkdownToolbar({
    super.key,
    required this.coordinator,
  });

  @override
  Widget build(BuildContext context) {
    // §2.8：CodeBlock 聚焦时显示禁用提示替代工具栏按钮
    // ADR-0011 §3：Toolbar 不 import core/editing/，通过 coordinator 便捷属性查询
    final isCodeBlock = coordinator.isFocusedOnCodeBlock;
    final hasFocused = coordinator.focusedId != null;

    if (isCodeBlock) {
      return const _DisabledBar(hint: EditorStrings.codeBlockToolbarDisabled);
    }

    // 无聚焦块：工具栏整体禁用（按钮 onPressed = null,Flutter 自动应用 disabled 样式）
    return _ToolbarButtons(
      coordinator: coordinator,
      enabled: hasFocused,
    );
  }
}

/// 工具栏按钮组（11 按钮 + 横向滚动布局）。
class _ToolbarButtons extends StatelessWidget {
  final EditorCoordinator coordinator;
  final bool enabled;

  const _ToolbarButtons({
    required this.coordinator,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _buildButtons(context),
        ),
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    return [
      _FormatButton(
        label: 'B',
        tooltip: EditorStrings.boldTooltip,
        onPressed: enabled
            ? () => _handleWrapOrInsert(
                  prefix: '**',
                  suffix: '**',
                  noSelectionText: '****',
                  noSelectionCursorOffset: -2,
                )
            : null,
      ),
      _FormatButton(
        label: 'I',
        tooltip: EditorStrings.italicTooltip,
        onPressed: enabled
            ? () => _handleWrapOrInsert(
                  prefix: '*',
                  suffix: '*',
                  noSelectionText: '**',
                  noSelectionCursorOffset: -1,
                )
            : null,
      ),
      _FormatButton(
        label: 'H1',
        tooltip: EditorStrings.h1Tooltip,
        onPressed: enabled ? () => _handleInsert('# ') : null,
      ),
      _FormatButton(
        label: 'H2',
        tooltip: EditorStrings.h2Tooltip,
        onPressed: enabled ? () => _handleInsert('## ') : null,
      ),
      _FormatButton(
        label: 'H3',
        tooltip: EditorStrings.h3Tooltip,
        onPressed: enabled ? () => _handleInsert('### ') : null,
      ),
      _FormatButton(
        label: 'Code',
        tooltip: EditorStrings.codeTooltip,
        onPressed: enabled
            ? () => _handleWrapOrInsert(
                  prefix: '`',
                  suffix: '`',
                  noSelectionText: '``',
                  noSelectionCursorOffset: -1,
                )
            : null,
      ),
      _FormatButton(
        label: 'Link',
        tooltip: EditorStrings.linkTooltip,
        onPressed: enabled
            ? () => _handleWrapOrInsert(
                  prefix: '[',
                  suffix: ']()',
                  noSelectionText: '[]()',
                  noSelectionCursorOffset: -3,
                )
            : null,
      ),
      _FormatButton(
        label: 'Quote',
        tooltip: EditorStrings.quoteTooltip,
        onPressed: enabled ? () => _handleInsert('> ') : null,
      ),
      _FormatButton(
        label: 'OL',
        tooltip: EditorStrings.orderedListTooltip,
        onPressed: enabled ? () => _handleInsert('1. ') : null,
      ),
      _FormatButton(
        label: 'UL',
        tooltip: EditorStrings.unorderedListTooltip,
        onPressed: enabled ? () => _handleInsert('- ') : null,
      ),
      _FormatButton(
        label: 'Task',
        tooltip: EditorStrings.taskListTooltip,
        onPressed: enabled ? () => _handleInsert('- [ ] ') : null,
      ),
      // §6.3：`+` 模板菜单按钮（PopupMenu,8 模板）
      _TemplateMenuButton(
        enabled: enabled,
        onSelected: enabled ? _handleTemplateSelect : null,
      ),
    ];
  }

  // ============ Command 构造与分发（§2.3 + §2.7.1）============

  /// 处理「包裹选区 / 插入文本」双路径按钮（B / I / Code / Link）。
  ///
  /// **§2.7.1 强一致读取**：Command 构造瞬间通过 [coordinator.focusedSelection]
  /// 重新读取最新 selection（不依赖节流后可能滞后的视觉态）。
  void _handleWrapOrInsert({
    required String prefix,
    required String suffix,
    required String noSelectionText,
    required int noSelectionCursorOffset,
  }) {
    final blockId = coordinator.focusedId;
    if (blockId == null) return;

    // §2.7.1：强一致读取 selection
    final selection = coordinator.focusedSelection;
    final hasSelection =
        selection != null && selection.baseOffset != selection.extentOffset;

    if (hasSelection) {
      // 有选区 → WrapSelectionCommand
      coordinator.handle(WrapSelectionCommand(
        blockId: blockId,
        prefix: prefix,
        suffix: suffix,
        selection: selection,
      ));
    } else {
      // 无选区 → InsertTextCommand（光标定位到插入文本中间或末尾）
      coordinator.handle(InsertTextCommand(
        blockId: blockId,
        text: noSelectionText,
        cursorOffset: noSelectionCursorOffset,
        selection: selection,
      ));
    }
  }

  /// 处理纯插入按钮（H1 / H2 / H3 / Quote / OL / UL / Task）。
  ///
  /// 这些按钮始终走 InsertTextCommand（不依赖选区）。
  void _handleInsert(String text) {
    final blockId = coordinator.focusedId;
    if (blockId == null) return;

    // §2.7.1：强一致读取 selection（用于计算插入位置）
    final selection = coordinator.focusedSelection;

    coordinator.handle(InsertTextCommand(
      blockId: blockId,
      text: text,
      cursorOffset: 0,
      selection: selection,
    ));
  }

  /// 处理模板菜单选择（§6.3 + §2.5.1）。
  ///
  /// 从 [_kTemplateConfigs] 查找配置,构造 [InsertTemplateCommand]。
  /// **§2.5.1 Hard Rule**：不解析模板字符串内容,直接使用常量。
  /// **§2.7.1**：强一致读取 selection（仅 insert 模式使用）。
  void _handleTemplateSelect(_TemplateMenuItem item) {
    final blockId = coordinator.focusedId;
    if (blockId == null) return;
    final config = _kTemplateConfigs.firstWhere((c) => c.item == item);
    // §2.7.1：强一致读取 selection（insert 模式用于计算插入位置）
    final selection = coordinator.focusedSelection;
    coordinator.handle(InsertTemplateCommand(
      blockId: blockId,
      template: config.template,
      mode: config.mode,
      selection: config.mode == TemplateInsertMode.insert ? selection : null,
      cursorOffset: config.cursorOffset,
    ));
  }
}

/// 单个格式按钮（紧凑 TextButton + Tooltip）。
class _FormatButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  const _FormatButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// CodeBlock 聚焦时的禁用栏（显示提示文字替代工具栏按钮,§2.8）。
class _DisabledBar extends StatelessWidget {
  final String hint;

  const _DisabledBar({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        hint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// `+` 模板菜单按钮（PopupMenu,8 模板,§6.3）。
///
/// 使用 [_TemplateMenuItem] enum 作为 PopupMenuItem value,
/// 避免字符串业务判断（§2.5.1 Hard Rule）。
class _TemplateMenuButton extends StatelessWidget {
  final bool enabled;
  final ValueChanged<_TemplateMenuItem>? onSelected;

  const _TemplateMenuButton({
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TemplateMenuItem>(
      icon: const Icon(Icons.add, size: 20),
      tooltip: EditorStrings.templateMenuTooltip,
      enabled: enabled,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final c in _kTemplateConfigs)
          PopupMenuItem(value: c.item, child: Text(c.label)),
      ],
    );
  }
}
