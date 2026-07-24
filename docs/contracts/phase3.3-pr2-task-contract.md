# Phase 3.3 PR #2 Task Contract: Markdown Toolbar + Template Menu

> **版本**：v2.0（拆分版,落地 Human Owner 评审 P0 修改 + P1 PR 拆分建议）
> **起草日期**：2026-07-24
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Proposed（待 Human Owner 审批后实施）
> **关联文档**：
> - [Phase 3.3 Task Contract v1.4](./phase3.3-task-contract.md) §3.3.7 + §3.3.10 + §9.3 + §9.5
> - [ADR-0011](../ADR/0011-phase3.3-architecture-decisions.md) §3 + §5
> - [ADR-0008](../ADR/0008-editor-transaction-model.md) sealed class 约束
> - [PR #1 chrome 接线](https://github.com/Thy985/fixmath/tree/feat/phase3.3-chrome-wiring)（依赖基础：dirty tracking + wordCount）

---

## 0. v2.0 修订记录（vs v1.0）

| # | 修订点 | 来源 | 章节 |
|---|--------|------|------|
| 1 | 明确 InsertTemplateCommand 长期演进方向（字符串 → enum + TemplateRegistry） | Human P0-1 | §2.5 |
| 2 | 修正 CodeBlock 工具栏行为：从"仅 CodeBlock + `+` 启用"改为"全部禁用" | Human P0-2 | §2.8 |
| 3 | 降低 selection sync 频率：仅 focused 时同步 + 帧内节流 | Human P0-3 | §2.7 |
| 4 | PR 拆分为 4 个子 PR：PR #1.5（E2E 框架）+ PR #2A/B/C | Human P1-4 | §1.2 |
| 5 | 新增 integration_test 端到端验证 | Human P1-5 | §3 + §7.2 |

---

## 1. 目标与范围

### 1.1 总目标

落地 Phase 3.3 Task Contract §3.3.7（Markdown 工具栏核心）+ §3.3.10（模板插入菜单）。

**核心价值**：释放 Phase 3.2 TableBlock / MermaidBlock / CodeBlock 成果。用户不用背 Markdown 语法也能写出含表格 / Mermaid 图 / 代码块的复杂文档。

### 1.2 PR 拆分结构（v2.0 修订）

| PR | 标题 | 范围 | 依赖 | 风险 |
|----|------|------|------|------|
| **#1.5** | integration_test 框架 | 建立 `integration_test/` 目录 + helper + 基础 E2E 用例（app 启动 + SeedDocuments 显示） | PR #1 | Low |
| **#2A** | Command Infrastructure | 3 个 Command 子类 + dispatch + re-export + 单元测试（无 UI） | PR #1.5 | Low |
| **#2B** | Toolbar UI + Selection sync | CoordinatorState 便捷方法 + EditorCoordinator 透传 + BaseBlockState selection 同步 + markdown_toolbar.dart（11 按钮）+ EditorShell 接入 | PR #2A | Medium |
| **#2C** | Template Menu | `+` 模板菜单（8 模板）+ InsertTemplateCommand 实际使用 + 测试 | PR #2B | Medium |

**拆分理由**（AGENTS.md §6.3"禁止大规模重构与功能改动混在同一 PR"）：
- PR #2A 是纯逻辑层,无 UI 风险,可独立验证 Command dispatch 正确性
- PR #2B 是 UI 接入 + selection 数据流,失败回滚不影响 Command 层
- PR #2C 是新产品能力（模板菜单）,独立验证用户价值转换

### 1.3 不在范围（Out of Scope）

- ❌ §3.3.6 自动配对（PR #3）
- ❌ §3.3.8 自动续列表（PR #3）
- ❌ §3.3.2 字号缩放（PR #4 P1）
- ❌ §3.3.3 焦点模式（PR #4 P1）
- ❌ §3.3.9 选区格式化菜单 Overlay（延期 Phase 3.4）
- ❌ `PairInsertCommand` / `InsertNewLineWithPrefixCommand`（PR #3）

### 1.4 前置依赖

- ✅ PR #1 chrome 接线（`feat/phase3.3-chrome-wiring` 分支,已推送待合并）
- ✅ ADR-0011 Accepted（5 条架构决策已审批）
- ✅ Phase 3.2 Block Runtime（6 种 BlockType + inline rendering）

---

## 2. 架构决策（落地 ADR-0011 §3 + §5）

### 2.1 Toolbar 位置：A+B 混合（ADR-0011 §3）

- **位置 A**：底部固定栏（Scaffold body 内,Workspace 与 StatusBar 之间）
- **内部布局 B**：横向滚动（`SingleChildScrollView(scrollDirection: Axis.horizontal)`）

```
┌────────────────────────────────────────────┐
│ EditorViewport（Block 列表）              │
├────────────────────────────────────────────┤
│ [B][I][H1][H2][H3][Code][Link][Quote]... [+] │ ← 横向滚动
├────────────────────────────────────────────┤
│ StatusBar（块数 / 字数 / Undo 状态）       │
└────────────────────────────────────────────┘
```

### 2.2 Toolbar 状态来源：只读 CoordinatorState（ADR-0011 §5）

**允许**：
```dart
coordinator.focusedBlockType  // 只读便捷 getter
coordinator.focusedSelection  // 只读便捷 getter
coordinator.hasSelection      // bool 便捷 getter
```

**禁止**（Hard Rule）：
```dart
Toolbar → TextEditingController  // ❌ 违反依赖方向 chrome → editor
```

### 2.3 Command Layer 强制（Hard Rule 2.3）

所有文本修改必须经：
```
Toolbar 按钮 onTap
  ↓
构造 InsertTextCommand / WrapSelectionCommand / InsertTemplateCommand
  ↓
coordinator.handle(command)
  ↓
CommandHandler._dispatch → _handleInsertText / _handleWrapSelection / _handleInsertTemplate
  ↓
BlockOperations.updateSource（复用现有方法）
  ↓
TransactionBuilder.commit → history.push
  ↓
notifyListeners → UI 重建
```

### 2.4 新 Command 子类定义（ADR-0011 §5）

| Command 类 | 字段 | 行为 |
|-----------|------|------|
| `InsertTextCommand` | `blockId` / `text` / `cursorOffset` / `selection` | 在光标位置插入 `text`,光标移到 `cursorOffset`（相对插入文本末尾） |
| `WrapSelectionCommand` | `blockId` / `prefix` / `suffix` / `selection` | 选区包裹为 `prefix + selection + suffix`,光标移到末尾 |
| `InsertTemplateCommand` | `blockId` / `template` / `mode` | `mode=insert`：在光标插入模板文本;`mode=newBlock`：在当前块后插入新 Block |

**selection 传递方案 A**：Command 字段携带 `TextSelection? selection`（由 Toolbar 构造时从 `coordinator.focusedSelection` 传入）。CommandHandler 保持纯逻辑层,不反向依赖 CoordinatorState。

### 2.5 InsertTemplateCommand 长期演进方向（P0-1 修订）

**当前方案（Phase 3.3,过渡）**：字符串 `template` + `TemplateInsertMode` enum
```dart
InsertTemplateCommand(blockId: id, template: '| A | B |\n|---|---|', mode: newBlock)
```

**长期方向（Phase 3.4+）**：`enum MarkdownTemplate` + domain 层 `TemplateRegistry` 生成内容
```dart
enum MarkdownTemplate { table, mermaid, codeBlock, taskList, quote, hr, image, link }

InsertTemplateCommand(blockId: id, template: MarkdownTemplate.table, mode: newBlock)
// → TemplateRegistry.generate(MarkdownTemplate.table) 返回结构化内容
```

**演进动机**：
- 字符串方案导致 `Template → ParagraphElement → Parser → Block` 路径过长
- 未来 Mermaid 模板需直接生成 `MermaidBlock` 而非走 Parser 转换
- `enum` + Registry 便于扩展（用户自定义模板）与本地化

**技术债务记录**：PR #2C 的 commit message 须注明"当前字符串方案为过渡,Phase 3.4 演进到 enum + TemplateRegistry",并在 [ADR-0011](../ADR/0011-phase3.3-architecture-decisions.md) §5 补充演进路径。

### 2.6 CoordinatorState 扩展（便捷 getter,不改结构）

在 `CoordinatorState` 添加便捷方法（`EditorCoordinator` 仅透传,避免超 200 行守门）：

```dart
BlockType? focusedBlockType(DocumentEditor editor) {
  final id = focusedId;
  if (id == null) return null;
  final element = editor.getBlock(id);
  return element == null ? null : BlockType.fromElement(element);
}

TextSelection? get focusedSelection {
  final id = focusedId;
  if (id == null) return null;
  return viewStateOf(id)?.selection;
}

bool get hasSelection {
  final sel = focusedSelection;
  return sel != null && !sel.isCollapsed;
}
```

`EditorCoordinator` 透传（+3 行）：
```dart
BlockType? get focusedBlockType => _state.focusedBlockType(editor);
TextSelection? get focusedSelection => _state.focusedSelection;
bool get hasSelection => _state.hasSelection;
```

### 2.7 BaseBlockState selection 同步（P0-3 修订：节流策略）

**问题**：selection 变化频繁（用户拖动选择时每帧触发）,直接 `notifyListeners` 会导致 Toolbar 频繁 rebuild,造成光标卡顿。

**节流策略**：
1. **仅 focused 时同步**：非聚焦块的 selection 变化不进入全局状态
2. **帧内节流**：同一帧内多次 selection 变化只同步一次,通过 `WidgetsBinding.instance.addPostFrameCallback` 合并

```dart
bool _selectionSyncScheduled = false;

void _onSelectionChanged() {
  if (!mounted || !isFocused) return;  // 仅 focused 时同步
  if (_selectionSyncScheduled) return;  // 帧内已调度,跳过
  _selectionSyncScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _selectionSyncScheduled = false;
    if (!mounted) return;
    final sel = textController.selection;
    final current = _coordinator.viewStateOf(_blockId)?.selection;
    if (sel != current) {
      final state = _coordinator.viewStateOf(_blockId) ?? BlockViewState(id: _blockId);
      _coordinator.updateViewState(_blockId, state.copyWith(selection: sel));
    }
  });
}
```

**Phase 3.4 演进方向**：建立独立的 `EditorInteractionState`（Notifer）专门保存 selection / cursor / composing region,不污染 `CoordinatorState`。Toolbar 订阅 `EditorInteractionState` 而非 `CoordinatorState`。触发条件：实测 selection 同步导致光标卡顿（< 60fps）。

### 2.8 CodeBlock 工具栏行为（P0-2 修订）

**v1.0 方案（已废弃）**：CodeBlock 内仅 CodeBlock + `+` 启用。

**v2.0 方案**：CodeBlock 聚焦时,**所有工具栏按钮 + `+` 模板菜单全部禁用**。

**理由**：
- 代码块内插入 Markdown 语法（`**bold**` / `# heading` / 表格 / Mermaid）语义混乱
- 代码内容不应被 Markdown 解析,工具栏按钮无意义
- 用户想在 CodeBlock **后**插入新内容：需先聚焦到下一个 Block,或通过回车自动续列表（PR #3）创建新 ParagraphBlock

**视觉提示**：
- CodeBlock 聚焦时工具栏整体变灰（`opacity: 0.38`）
- 显示提示文字"代码块内工具栏不可用"（替代工具栏,或在工具栏上方 1 行 hint）

**实现**：`MarkdownToolbar` 根据 `coordinator.focusedBlockType == BlockType.code` 切换为禁用态。

---

## 3. PR #1.5: integration_test 框架

### 3.1 目标

建立 Phase 3.3+ 端到端验证基础设施,覆盖用户操作链（创建文档 → Toolbar 插入 → Template 插入 → Undo/Redo → Save/Load）。

### 3.2 范围

| # | 任务 | 文件 |
|---|------|------|
| 1 | 建立 `integration_test/` 目录 | `flutter_app/integration_test/` |
| 2 | 添加 `integration_test` dev_dependency | `flutter_app/pubspec.yaml` |
| 3 | 建立 helper：启动 app + 创建文档 + 查找 widget | `integration_test/helpers/test_app.dart` |
| 4 | 基础 E2E 用例：app 启动 + SeedDocuments 显示 | `integration_test/app_startup_test.dart` |
| 5 | 基础 E2E 用例：EditorShell 布局验证（AppBar + Viewport + StatusBar） | `integration_test/editor_shell_layout_test.dart` |

### 3.3 实施详细

**pubspec.yaml**：
```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

**helper/test_app.dart**：
```dart
Future<Widget> pumpTestApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: FormulaFixApp()));
  await tester.pumpAndSettle();
  return tester.widget(find.byType(FormulaFixApp));
}
```

**app_startup_test.dart**：
```dart
testWidgets('app 启动后显示 SeedDocuments', (tester) async {
  await pumpTestApp(tester);
  expect(find.text('FormulaFix Demo'), findsOneWidget);
  expect(find.byType(EditorShell), findsOneWidget);
});
```

### 3.4 验证

- `flutter test integration_test/` 通过
- `flutter analyze` 0 error
- 不影响现有 unit test

---

## 4. PR #2A: Command Infrastructure

### 4.1 目标

建立 3 个新 Command 子类 + dispatch 路径,纯逻辑层,无 UI。

### 4.2 范围

| # | 任务 | 文件 |
|---|------|------|
| 1 | 新增 `InsertTextCommand` / `WrapSelectionCommand` / `InsertTemplateCommand` + `TemplateInsertMode` enum | `lib/presentation/commands/editor_command.dart` |
| 2 | `CommandHandler` 添加 3 个 dispatch 分支 + 3 个 `_handle*` 方法 | `lib/presentation/commands/command_handler.dart` |
| 3 | `commands.dart` re-export 3 个新 Command | `lib/presentation/commands/commands.dart` |
| 4 | 单元测试：3 个新 Command 的 dispatch 行为 | `test/presentation/commands/command_handler_dispatch_test.dart`（扩展） |

### 4.3 实施详细

#### 4.3.1 Command 子类定义（§2.4）

`lib/presentation/commands/editor_command.dart` 新增：

```dart
/// 在光标位置插入文本（Markdown 工具栏按钮）。
@immutable
final class InsertTextCommand extends EditorCommand {
  final BlockId blockId;
  final String text;
  /// 相对插入文本末尾的偏移（0 = 末尾,负数 = 从末尾前移）。
  /// 例如插入 `**|**` 时光标应在中间,cursorOffset = -2。
  final int cursorOffset;
  /// 当前选区（null = 单光标点）。
  /// 由 Toolbar 构造时从 coordinator.focusedSelection 传入。
  final TextSelection? selection;

  const InsertTextCommand({
    required this.blockId,
    required this.text,
    this.cursorOffset = 0,
    this.selection,
    super.origin = CommandOrigin.menu,
  }) : super(displayName: '插入文本');
}

/// 选区包裹（选中文字 → `**selection**`）。
@immutable
final class WrapSelectionCommand extends EditorCommand {
  final BlockId blockId;
  final String prefix;
  final String suffix;
  final TextSelection selection;

  const WrapSelectionCommand({
    required this.blockId,
    required this.prefix,
    required this.suffix,
    required this.selection,
    super.origin = CommandOrigin.menu,
  }) : super(displayName: '包裹选区');
}

/// 插入模板（表格 / Mermaid / 代码块等）。
///
/// **过渡方案（Phase 3.3）**：字符串 `template` + `mode`。
/// **长期方向（Phase 3.4+）**：演进为 `enum MarkdownTemplate` +
/// domain 层 `TemplateRegistry` 生成结构化内容（见 ADR-0011 §5 演进路径）。
@immutable
final class InsertTemplateCommand extends EditorCommand {
  final BlockId blockId;
  final String template;
  final TemplateInsertMode mode;
  final TextSelection? selection;

  const InsertTemplateCommand({
    required this.blockId,
    required this.template,
    this.mode = TemplateInsertMode.insert,
    this.selection,
    super.origin = CommandOrigin.menu,
  }) : super(displayName: '插入模板');
}

enum TemplateInsertMode {
  /// 在当前块光标位置插入模板文本。
  insert,
  /// 在当前块后插入新 Block（模板作为独立 Block）。
  newBlock,
}
```

#### 4.3.2 CommandHandler dispatch

`lib/presentation/commands/command_handler.dart` 在 `_dispatch` switch 添加：

```dart
return switch (command) {
  // ... 现有 8 个 case ...
  InsertTextCommand c => _handleInsertText(c, operations),
  WrapSelectionCommand c => _handleWrapSelection(c, operations),
  InsertTemplateCommand c => _handleInsertTemplate(c, operations),
};
```

新增 3 个 `_handle*` 方法（实现详见 Task Contract §3.2 v1.0,逻辑不变）。

### 4.4 验证

- `flutter analyze` 0 error
- `flutter test test/presentation/commands/` 通过
- 架构守门：`editor_command.dart` ≤ 400 行（TC-ARCH-7）

---

## 5. PR #2B: Toolbar UI + Selection sync

### 5.1 目标

实现 Markdown 工具栏 11 按钮 + selection 数据流,不含模板菜单（`+` 按钮在 PR #2C 实现）。

### 5.2 范围

| # | 任务 | 文件 |
|---|------|------|
| 1 | `CoordinatorState` 添加 `focusedBlockType` / `focusedSelection` / `hasSelection` | `lib/presentation/states/coordinator_state.dart` |
| 2 | `EditorCoordinator` 透传 3 个 getter | `lib/presentation/editor/editor_coordinator.dart` |
| 3 | `BaseBlockState` 添加 selection 同步（节流策略 §2.7） | `lib/presentation/blocks/base_block_state.dart` |
| 4 | 新建 `chrome/markdown_toolbar.dart`（11 按钮 + CodeBlock 禁用态） | `lib/presentation/chrome/markdown_toolbar.dart` |
| 5 | `EditorShell` 接入 MarkdownToolbar | `lib/presentation/editor/editor_shell.dart` |
| 6 | 测试：按钮插入 + 选区包裹 + CodeBlock 禁用态 + selection 同步 | `test/presentation/chrome/markdown_toolbar_test.dart` + `test/presentation/blocks/selection_sync_test.dart` |

### 5.3 实施详细

#### 5.3.1 按钮清单（11 个,不含 `+`）

| 按钮 | 图标 | 无选区（插入） | 有选区（包裹） | Command |
|------|------|---------------|---------------|---------|
| B | `format_bold` | `**\|**`（cursorOffset=-2） | `**sel**` | WrapSelection |
| I | `format_italic` | `*\|*`（cursorOffset=-1） | `*sel*` | WrapSelection |
| H1 | `title` | `# ` | - | InsertText |
| H2 | `title` | `## ` | - | InsertText |
| H3 | `title` | `### ` | - | InsertText |
| Code | `code` | `` `\|` ``（cursorOffset=-1） | `` `sel` `` | WrapSelection |
| Link | `link` | `[\|](url)`（cursorOffset=-4） | `[sel](url)` | WrapSelection |
| Quote | `format_quote` | `> ` | - | InsertText |
| List | `format_list_bulleted` | `- ` | - | InsertText |
| List | `format_list_numbered` | `1. ` | - | InsertText |
| CodeBlock | `data_object` | ```` ```dart\n\|\n``` ````（cursorOffset=-5） | - | InsertText |

#### 5.3.2 选区包裹模式视觉提示

`hasSelection == true` 时工具栏背景色变为 `EditorTokens.codeBackground`。

#### 5.3.3 CodeBlock 禁用态（§2.8）

`coordinator.focusedBlockType == BlockType.code` 时：
- 工具栏整体 `opacity: 0.38`
- 显示 hint："代码块内工具栏不可用"
- 所有按钮 `onPressed: null`

#### 5.3.4 EditorShell 接入

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: EditorAppBar(...),
    body: Column(
      children: [
        Expanded(child: Workspace(coordinator: coordinator)),
        MarkdownToolbar(coordinator: coordinator),  // 新增
      ],
    ),
    bottomNavigationBar: EditorStatusBar(coordinator: coordinator),
  );
}
```

### 5.4 验证

- `flutter analyze` 0 error
- `flutter test` 通过（含新测试文件）
- 架构守门：`markdown_toolbar.dart` ≤ 400 行 + 不 import `core/editing/`
- E2E（PR #1.5 框架）：`integration_test/toolbar_buttons_test.dart` 覆盖 11 按钮插入

---

## 6. PR #2C: Template Menu

### 6.1 目标

实现 `+` 模板菜单,8 种模板插入。释放 Phase 3.2 TableBlock / MermaidBlock / CodeBlock 成果。

### 6.2 范围

| # | 任务 | 文件 |
|---|------|------|
| 1 | `MarkdownToolbar` 添加 `+` 按钮 + PopupMenu（8 模板） | `lib/presentation/chrome/markdown_toolbar.dart` |
| 2 | 测试：8 种模板插入正确 | `test/presentation/chrome/template_menu_test.dart` |
| 3 | E2E：模板插入流程 | `integration_test/template_insert_test.dart` |

### 6.3 实施详细

#### 6.3.1 模板清单（8 种）

| 模板 | 插入内容 | Command | mode |
|------|----------|---------|------|
| 表格 | `\| 列1 \| 列2 \|\n\| --- \| --- \|\n\| 内容 \| 内容 \|` | InsertTemplate | newBlock |
| Mermaid | ```` ```mermaid\ngraph TD\nA-->B\n``` ```` | InsertTemplate | newBlock |
| 代码块 | ```` ```dart\n\|\n``` ```` | InsertTemplate | insert |
| 任务列表 | `- [ ] 任务1\n- [ ] 任务2` | InsertTemplate | newBlock |
| 引用块 | `> 引用内容` | InsertTemplate | insert |
| 分隔线 | `---` | InsertTemplate | insert |
| 图片 | `![alt](url)` | InsertTemplate | insert |
| 链接 | `[文本](url)` | InsertTemplate | insert |

#### 6.3.2 技术债务记录（§2.5）

PR #2C commit message 须注明：
> 当前字符串方案为过渡,Phase 3.4 演进到 enum MarkdownTemplate + TemplateRegistry。详见 ADR-0011 §5 演进路径。

### 6.4 验证

- `flutter analyze` 0 error
- `flutter test` 通过
- E2E：8 模板插入正确

---

## 7. 验证计划（汇总）

### 7.1 自动化验证（unit + architecture）

| 维度 | 测试文件 | PR |
|------|----------|----|
| Command dispatch | `command_handler_dispatch_test.dart` | #2A |
| InsertText + WrapSelection | `markdown_toolbar_test.dart` | #2B |
| CodeBlock 禁用态 | `markdown_toolbar_test.dart` | #2B |
| Selection 同步 | `selection_sync_test.dart` | #2B |
| 8 模板插入 | `template_menu_test.dart` | #2C |
| 架构守门 | `ui_command_layer_test.dart` + `ui_dependency_direction_test.dart` | #2B |

### 7.2 端到端验证（integration_test）

| 用例 | 文件 | PR |
|------|------|----|
| app 启动 + SeedDocuments | `app_startup_test.dart` | #1.5 |
| EditorShell 布局 | `editor_shell_layout_test.dart` | #1.5 |
| Toolbar 11 按钮 | `toolbar_buttons_test.dart` | #2B |
| Template 8 模板 | `template_insert_test.dart` | #2C |
| Undo/Redo 操作链 | `undo_redo_flow_test.dart` | #2C |

### 7.3 架构验证

- [ ] `chrome/markdown_toolbar.dart` 只 import `editor/editor_coordinator.dart` + `commands/commands.dart` + Flutter/Material
- [ ] Toolbar 不直接访问 `TextEditingController`
- [ ] 3 个新 Command 位于 `editor_command.dart`（sealed class 约束）
- [ ] `commands.dart` re-export 完整
- [ ] `EditorCoordinator` ≤ 200 行（TC-ARCH-UI-4）
- [ ] `markdown_toolbar.dart` ≤ 400 行（TC-ARCH-7）

---

## 8. 风险评估

| 风险 | 影响 | 缓解 | PR |
|------|------|------|----|
| `EditorCoordinator` 超 200 行守门 | 高 | getter 逻辑放 `CoordinatorState`,Coordinator 仅透传（+3 行） | #2B |
| `markdown_toolbar.dart` 超 400 行 | 中 | 按钮配置抽为静态 const Map;模板清单在 PR #2C 独立文件 | #2B/#2C |
| selection 同步触发频繁 `notifyListeners` 导致性能问题 | 中 | 帧内节流 + 仅 focused 时同步（§2.7） | #2B |
| CommandHandler 需要 selection 但不应依赖 CoordinatorState | 中 | 方案 A：Command 字段携带 selection（§2.4） | #2A |
| `InsertTemplateCommand` newBlock 模式插入多行模板解析异常 | 中 | 表格模板作为单一 ParagraphElement 插入,由 `tryTransform` 自动转为 TableBlock | #2C |
| Toolbar 与键盘冲突 | 中 | Toolbar 在 `body` 内（非 `bottomNavigationBar`）,`Scaffold.resizeToAvoidBottomInset` 自动调整 | #2B |
| **integration_test 在 CI 环境失败** | 中 | CI 仅跑 unit + architecture,E2E 仅本地 / 手动触发 | #1.5 |

---

## 9. 成功标准（Exit Gate）

### 9.1 PR #1.5
- [ ] `integration_test/` 目录建立 + helper 可用
- [ ] `flutter test integration_test/` 通过
- [ ] 不影响现有 unit test

### 9.2 PR #2A
- [ ] 3 个新 Command 子类 + dispatch + re-export 完成
- [ ] `command_handler_dispatch_test.dart` 扩展通过
- [ ] `editor_command.dart` ≤ 400 行

### 9.3 PR #2B
- [ ] `markdown_toolbar.dart` 11 按钮 + CodeBlock 禁用态
- [ ] `EditorShell` 接入 Toolbar
- [ ] selection 同步节流策略生效
- [ ] `EditorCoordinator` ≤ 200 行
- [ ] `markdown_toolbar.dart` ≤ 400 行
- [ ] 架构守门通过（Toolbar 不 import `core/editing/`）

### 9.4 PR #2C
- [ ] `+` 模板菜单 8 模板
- [ ] `template_menu_test.dart` 通过
- [ ] commit message 注明技术债务（§2.5）

### 9.5 工程验证（每个 PR）
- [ ] `flutter analyze` 0 error
- [ ] `flutter test` 0 regression
- [ ] `flutter build apk --debug` 成功
- [ ] `flutter build web` 成功

---

## 10. 回滚计划

### 10.1 回滚触发条件
- Toolbar 接入导致 EditorShell 布局崩溃（PR #2B）
- selection 同步导致输入卡顿（PR #2B）
- CommandHandler dispatch 分支破坏现有 8 个 Command（PR #2A）
- 模板插入导致 Block 解析异常（PR #2C）

### 10.2 回滚步骤（按 PR 独立）
1. `git revert` 对应 PR 的 commit
2. 验证 `flutter test` 仍全部通过
3. 由于 PR 拆分,回滚单个 PR 不影响其他 PR

---

## 11. Task Contract 四问（AGENTS.md §9.2）

### 11.1 What changes?

见 §1.2 PR 拆分结构 + 各 PR §3/4/5/6.2 范围表。

### 11.2 How to verify?

见 §7 验证计划。关键指标：
- 3 个新 Command dispatch 测试通过（#2A）
- 11 按钮 + 8 模板插入正确（#2B/#2C）
- selection 同步节流生效（#2B）
- E2E 用例通过（#1.5/#2B/#2C）

### 11.3 What feedback signals exist?

**成功信号**：
- `flutter analyze` 0 error
- `flutter test` 0 regression
- E2E 用例通过
- 架构守门通过

**失败信号**：
- `EditorCoordinator` 超 200 行（TC-ARCH-UI-4 失败）
- `markdown_toolbar.dart` 超 400 行（TC-ARCH-7 失败）
- Toolbar 直接 import `core/editing/`（TC-ARCH-UI-1/2 失败）
- selection 同步导致 `flutter test` 性能 regression

### 11.4 What is done?

见 §9 各 PR Exit Gate。

---

## 12. 实施顺序

1. **PR #1.5**：integration_test 框架（§3）
2. **PR #2A**：Command Infrastructure（§4）
3. **PR #2B**：Toolbar UI + Selection sync（§5）
4. **PR #2C**：Template Menu（§6）

每个 PR 独立评审 + 独立合并,失败独立回滚。

---

**本文件由 AI Agent 起草,版本 v2.0（Proposed,待 Human Owner 审批后实施）。**
