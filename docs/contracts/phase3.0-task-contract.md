# Phase 3.0 Task Contract: Editor Shell Architecture & Presentation Foundation

> **版本**：v1.1（草案，待 Human Owner 审批）
> **起草日期**：2026-07-20
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Proposed
> **前置阶段**：Phase 2.9 UI Architecture Prototype（PR 待合并，Prototype 已通过验证）
> **后继阶段**：Phase 3.1 WYSIWYG Mode Migration（Phase 3.0 完成后才启动）
>
> **v1.1 修订**（2026-07-20 Human Owner 反馈）：
> 1. **命名调整**：`UI Skeleton & Runtime Foundation` → `Editor Shell Architecture & Presentation Foundation`（"Skeleton"略显简单，实际是建立 Presentation Layer）
> 2. **目录调整**：新增 `chrome/` 目录（AppBar / StatusBar / Toolbar 既不是 panel 也不是 editor，IDE 架构惯例单独分离）
> 3. **退出标准新增 3 项守门测试**：依赖方向（blocks 不 import editor/panels/chrome）+ BlockRenderer 必须 exhaustive switch
> 4. **ADR**：不新增 ADR（确认 ADR-0009 已覆盖设计，Task Contract 覆盖实施）

---

## 0. 任务缘起

Phase 2.9 已用 **5 份设计文档 + 4 个 Prototype Demo** 验证了"用户体验 → UI Interaction Model → BlockEditor API → Transaction → AST"五层映射的可行性，并冻结了核心接口（BlockEditor API / Transaction / BlockRenderer）。

**但**：Phase 2.9 的产出位于 `lib/presentation/prototype/`，**未接入生产路径**。如果直接进入 Phase 3.1 实现"移除 previewModeProvider / 沉浸式全屏编辑"等具体功能，会面临三个风险：

1. **架构落地风险**：Widget 直接操作 `DocumentElement`（绕过 Transaction），导致"UI → AST"反向依赖
2. **God Object 风险**：为快速实现功能，把 focus / history / theme / file 都塞进一个"大万能 Controller"
3. **补架构风险**：3.7 大纲 / 3.8 文件树 / 3.9 主题等任务后补架构，侧栏、主题、快捷键全部重新改

**Phase 3.0 的核心定位**：不是"做 UI"，而是**建立 Editor Shell Architecture & Presentation Foundation**——把 Phase 2.9 验证过的"用户行为 → EditorCommand → CommandHandler → Transaction → BlockViewState → Widget Tree"运行时通路落地到 production 路径，让 Phase 3.1+ 的所有功能有稳定挂载位置。

**类比 VS Code**：VS Code 不是先做插件，而是先建立 Window（Activity Bar / Side Bar / Editor Group / Status Bar / Command System），插件只是挂进去。FormulaFix 也应类似——Phase 3.0 建立 `EditorShell`（TopBar / Workspace / LeftPanel / EditorViewport / BlockRenderer / StatusBar），后面的 TOC / 文件树 / 主题 / 字号 / 焦点模式全部只是插槽扩展。

**演进类比**：Phase 2.0 的 `BlockEditor` 抽象决定了 Phase 2.1-2.8 的 17 个内核特性能否稳定演进；Phase 3.0 的 Editor Shell Architecture 决定了 Phase 3.1-3.17 的 17 个 UI 特性能否稳定演进。

---

## 1. 目标与范围

### 1.1 核心目标

回答一个问题：**production UI 层的承载结构是什么？用户事件如何接入内核？**

如果这个结构建立正确，Phase 3.1+ 的 UI 功能开发会变成"挂载到既有插槽"的工程实现；如果结构没有建立清楚，Phase 3.1+ 会变成"边开发边决定架构"，每个功能都重新设计一遍侧栏/主题/状态管理。

### 1.2 Phase 3.0 在五层映射中的位置

```
          用户体验层
              │
              ↓
       UI Interaction Model       ← Phase 2.9 已设计
              │
              ↓
       EditorCommand             ← Phase 2.9 已实现（Prototype）
              │
              ↓
       CommandHandler             ← Phase 2.9 已实现（Prototype）
              │
              ↓
       Transaction                ← Phase 2.6 已稳定
              │
              ↓
       BlockViewState             ← Phase 2.9 已实现（Prototype）
              │
              ↓
       Widget Tree                ← Phase 3.0 新增（production 路径）
```

Phase 3.0 的任务是把 Phase 2.9 Prototype 验证过的通路从 `lib/presentation/prototype/` **迁移并升级**到 `lib/presentation/`（production 路径），同时建立 EditorShell / BlockRenderer / SidePanelHost 等承载结构。

### 1.3 范围（5 个任务）

| # | 任务 | 产出 | 类型 |
|---|------|------|------|
| 3.0.1 | Presentation Layer 目录结构 | `lib/presentation/{editor,blocks,panels,themes}/` | 代码骨架 |
| 3.0.2 | Editor Shell（EditorPage + EditorShell + 4 占位插槽） | `lib/presentation/editor/editor_page.dart` 等 | 代码骨架 |
| 3.0.3 | BlockRenderer（3 类型：paragraph / heading / code） | `lib/presentation/blocks/block_renderer.dart` 等 | 代码骨架 |
| 3.0.4 | 数据源接入（InMemoryDocumentEditor + 种子数据） | `lib/presentation/editor/editor_coordinator.dart` | 代码骨架 |
| 3.0.5 | UI Design Reference | `docs/design/ui-spec.md` | 设计规范 |

### 1.4 不在 Phase 3.0 范围内（明确边界）

- ❌ 移除 `previewModeProvider`（Phase 3.1）
- ❌ 实现 9 种 BlockType（Phase 3.0 只 3 种：paragraph / heading / code）
- ❌ 接入真实 `.md` 文件（Phase 3.0 用 `InMemoryDocumentEditor` + 种子数据）
- ❌ 实现快捷键 / 主题切换 / TOC / 文件树 / 焦点模式（Phase 3.2+）
- ❌ 修改 `lib/core/editing/` 内核代码（Phase 3.0 不动内核）
- ❌ 删除 `lib/presentation/screens/` 旧代码（Phase 3.0 与旧 UI 并存，旧 UI 作 fallback）

---

## 2. 关键架构约束（Hard Rules）

### 2.1 AST 零污染（沿用 Phase 2.9）

**禁止**在 `DocumentElement` / `document.dart` 新增 UI 状态字段。

UI 状态通过 `BlockViewState`（Phase 2.9 已落地于 `lib/presentation/states/`）建模，通过 `BlockId` 关联到 AST。

### 2.2 Command Layer 强制（沿用 Phase 2.9）

**所有 UI 事件必须经** `EditorCommand` → `CommandHandler` → `TransactionBuilder` → `BlockOperation` 路径。

**禁止** UI 层直接调用 `BlockOperations` 或修改 AST。

Phase 3.0 落地的 Widget 必须通过 `EditorCoordinator.handler.handle(command)` 处理用户事件。

### 2.3 BlockRenderer 抽象（沿用 Phase 2.9）

新增 Block 类型只增加 renderer，不改 BlockEditor 核心。

Phase 3.0 的 `BlockRenderer` 使用 `exhaustive switch` 渲染 3 种 BlockType（paragraph / heading / code），为 Phase 3.2+ 新增类型留好扩展点。

### 2.4 避免 God Object（Phase 3.0 新增）

**禁止**把 focus / history / theme / file 都塞进一个"大万能 Controller"。

**正确做法**：拆分为多个职责单一的组件：

```
EditorShell
     │
     ↓
EditorCoordinator（只负责协调，不持有业务状态）
     │
     ├── CommandHandler         ← 处理用户事件（Phase 2.9 已落地）
     ├── BlockViewModelProvider ← 管理 Map<BlockId, BlockViewState>
     ├── FocusManager           ← 管理块间焦点切换
     └── ThemeProvider          ← Riverpod Provider，Phase 3.0 仅占位
```

**EditorCoordinator 职责**：协调上述 4 个组件的生命周期，**不直接持有业务状态**。

### 2.5 旧 UI 并存（Phase 3.0 新增）

Phase 3.0 期间，旧 `lib/presentation/screens/editor_screen.dart` **保留为 fallback**，新 `lib/presentation/editor/editor_page.dart` 通过 feature flag 切换。

**理由**：避免 Phase 3.0 期间 UI 完全不可用；为 Phase 3.1 移除 `previewModeProvider` 提供过渡期。

### 2.6 复用 Phase 2.9 产出（Phase 3.0 新增）

Phase 3.0 **不重写** Phase 2.9 已落地的代码：

| Phase 2.9 产出 | Phase 3.0 复用方式 |
|---|---|
| `lib/presentation/commands/editor_command.dart` | 原位保留 |
| `lib/presentation/commands/commands.dart` | 原位保留 |
| `lib/presentation/commands/command_handler.dart` | 原位保留 |
| `lib/presentation/states/block_view_state.dart` | 原位保留 |
| `lib/presentation/prototype/_shared/in_memory_document_editor.dart` | **迁移**到 `lib/presentation/editor/`（production 路径） |
| `lib/presentation/prototype/_shared/block_editor_facade.dart` | **重命名**为 `editor_coordinator.dart` 并迁移到 `lib/presentation/editor/` |
| `lib/presentation/prototype/demo1_dual_state_block.dart` | 作为 **设计参考**，逻辑提取到 `lib/presentation/blocks/paragraph_block.dart` |
| `lib/presentation/prototype/demo4_complex_blocks.dart` | 作为 **设计参考**，逻辑提取到 `lib/presentation/blocks/block_renderer.dart` |

迁移后 `lib/presentation/prototype/` 目录是否保留由 Human Owner 决定（建议保留作历史参考，Phase 3.0 完成后归档为 `_archive/`）。

---

## 3. 任务详细分解

### 3.1 任务 3.0.1：Presentation Layer 目录结构

**输出**：`lib/presentation/{editor,blocks,panels,themes}/` 目录

**目录结构**（与 ADR-0009 §3 一致，新增 `chrome/`）：

```
lib/presentation/

├── editor/                  ← EditorShell + EditorCoordinator
│   ├── editor_page.dart         ← 顶层页面（Route 入口）
│   ├── editor_shell.dart        ← 布局壳（组合 chrome + workspace + status）
│   ├── editor_coordinator.dart  ← 协调器（从 BlockEditorFacade 重命名迁移）
│   ├── editor_scope.dart         ← InheritedWidget 注入 Coordinator
│   └── seed_documents.dart      ← 种子数据（3 个示例文档）
│
├── blocks/                  ← BlockRenderer + 子组件
│   ├── block_renderer.dart       ← exhaustive switch 分发器
│   ├── paragraph_block.dart     ← 段落块（render + edit 双态）
│   ├── heading_block.dart        ← 标题块
│   └── code_block.dart           ← 代码块
│
├── chrome/                  ← 编辑器外壳组件（非 panel 非 editor，IDE 架构惯例）
│   ├── editor_app_bar.dart       ← AppBar（title + modified indicator 插槽）
│   └── editor_status_bar.dart    ← StatusBar（块数 / 字数 / Undo 状态插槽）
│
├── commands/                ← 已存在（Phase 2.9 落地）
│   ├── editor_command.dart
│   ├── commands.dart
│   └── command_handler.dart
│
├── states/                  ← 已存在（Phase 2.9 落地）
│   └── block_view_state.dart
│
├── panels/                  ← 侧栏占位（Phase 3.0 仅插槽，不实现功能）
│   ├── side_panel_host.dart      ← 侧栏容器（插槽）
│   ├── toc_panel.dart            ← 大纲面板（Phase 3.0 占位，Phase 3.7 实现）
│   └── file_panel.dart           ← 文件树面板（Phase 3.0 占位，Phase 3.8 实现）
│
├── themes/                  ← 主题占位（Phase 3.0 仅 token，不实现切换）
│   └── editor_tokens.dart        ← 主题 token（颜色 / 间距 / 字号）
│
├── widgets/                 ← 旧 widgets（Phase 3.0 保留，Phase 3.1+ 逐步迁移）
├── screens/                 ← 旧 screens（保留为 fallback）
└── prototype/               ← Phase 2.9 Prototype（保留作历史参考）
```

**为什么 `chrome/` 单独分离**（Human Owner 反馈）：
- AppBar / StatusBar / Toolbar 既不是 panel（侧栏功能）也不是 editor（编辑区）
- VS Code / IntelliJ 等 IDE 架构都把 chrome 与 workspace 分离
- 单独分离便于 Phase 3.1+ 独立演进（如 modified indicator 接入业务逻辑、字号缩放控件接入 StatusBar）

### 3.2 任务 3.0.2：Editor Shell

**输出**：`lib/presentation/editor/editor_page.dart` + `editor_shell.dart` + `editor_state.dart`

**布局**：

```
┌──────────────────────────────────────┐
│ AppBar（title + modified indicator） │
├────────────┬─────────────────────────┤
│            │                         │
│ SidePanel  │     BlockEditorView     │
│ （占位）   │     （3 种 Block 渲染） │
│            │                         │
├────────────┴─────────────────────────┤
│ StatusBar（块数 / 字数 / Undo 状态）  │
└──────────────────────────────────────┘
```

**代码结构**：

```dart
EditorPage                              ← Route 入口
    │
    └── EditorShell                     ← 布局壳（组合 chrome + workspace + status）
            │
            ├── EditorAppBar            ← chrome/ — AppBar 插槽
            │
            ├── Workspace              ← 编辑区 + 侧栏组合
            │     ├── SidePanelHost    ← panels/ — 侧栏插槽（占位）
            │     │     ├── TocPanel    ← Phase 3.7 实现
            │     │     └── FilePanel  ← Phase 3.8 实现
            │     │
            │     └── EditorViewport   ← 编辑视口
            │           └── BlockRenderer  ← blocks/ — 渲染分发
            │                 ├── ParagraphBlock
            │                 ├── HeadingBlock
            │                 └── CodeBlock
            │
            └── EditorStatusBar        ← chrome/ — 状态栏插槽
```

**功能**：仅显示 + 占位。

**不实现**：TOC / 文件树 / 主题切换 / 快捷键 / 修改状态指示（仅占位，不接业务逻辑）。

### 3.3 任务 3.0.3：BlockRenderer

**输出**：`lib/presentation/blocks/block_renderer.dart` + 3 个子组件

**支持类型**（第一批 3 种）：

| BlockType | Renderer | 双态切换 | 备注 |
|---|---|---|---|
| `paragraph` | `ParagraphBlock` | ✅ | 复用 Phase 2.9 Demo 1 双态逻辑 |
| `heading` | `HeadingBlock` | ✅ | level 1-6 渲染样式 |
| `code` | `CodeBlock` | ✅ | 显示 language 标签 + monospace |

**不支持类型**（Phase 3.2+ 实现）：

- ❌ `formula`（依赖公式渲染基础设施）
- ❌ `mermaid`（依赖 WebView 预热）
- ❌ `table`（依赖表格可视化编辑）
- ❌ `listItem` / `taskListItem`（依赖列表快捷输入）
- ❌ `blockquote` / `horizontalRule`（简单，但不在 Phase 3.0 第一批）

**Renderer 接口**（**强制 exhaustive switch**，不允许 fallback 到 GenericBlock）：

```dart
class BlockRenderer extends StatelessWidget {
  final BlockViewState state;
  final DocumentElement element;
  final EditorCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    // Phase 3.0：exhaustive switch 只支持 3 种类型
    // 新增 Block 类型必须显式增加 case 分支（不允许 _ fallback）
    return switch (element) {
      ParagraphElement() => ParagraphBlock(
          state: state, element: element, coordinator: coordinator),
      HeadingElement() => HeadingBlock(
          state: state, element: element, coordinator: coordinator),
      CodeElement() => CodeBlock(
          state: state, element: element, coordinator: coordinator),
      // Phase 3.0 期间：其他 6 种类型显式抛 UnimplementedError
      // 让 Phase 3.2+ 实现新类型时立即发现（而不是默默 fallback）
      _ => throw UnimplementedError(
          'BlockType ${element.runtimeType} not supported in Phase 3.0'),
    };
  }
}
```

**为什么不允许 GenericBlock fallback**（Human Owner 反馈）：
- 若有 fallback，新增 Block 类型时不会立刻暴露未实现，可能默默退化显示
- 显式抛错让 Phase 3.2+ 实现新类型时立即被测试发现
- 与 Phase 2.4 的 `BlockType.fromElement` exhaustive 设计一致

### 3.4 任务 3.0.4：数据源接入

**输出**：`lib/presentation/editor/editor_coordinator.dart` + `seed_documents.dart`

**关键决策**：不使用 Fake Model，使用 `InMemoryDocumentEditor`（Phase 2.9 已实现 `DocumentEditor` 接口）。

**理由**：
- `InMemoryDocumentEditor` 实现了真实 `DocumentEditor` 接口
- 保证 Phase 3 UI 测试的是 **真实 Core Interface**，不是 Fake
- Phase 3.1+ 接入真实 `.md` 文件时，只需替换数据源（Editor 的实现从 InMemory 切换到基于 .md 的实现），UI 层不变

**EditorCoordinator 设计**（避免 God Object）：

```dart
class EditorCoordinator {
  final InMemoryDocumentEditor editor;
  final EditorHistory history;
  late final CommandHandler handler;
  final Map<BlockId, BlockViewState> _viewStates = {};
  BlockId? _focusedId;

  EditorCoordinator({required this.editor, required this.history}) {
    handler = CommandHandler(_Facade(this));
  }

  // 协调接口（不持有业务状态，只转发）
  BlockViewState? viewStateOf(BlockId id) => _viewStates[id];
  void updateViewState(BlockId id, BlockViewState state) { ... }
  void setFocus(BlockId id) { ... }
  void clearFocus(BlockId id) { ... }

  // 查询接口（转发到 editor）
  int get blockCount => editor.blockCount;
  List<BlockId> get allIds => editor.allIds;
  DocumentElement? getBlock(BlockId id) => editor.getBlock(id);
  String sourceOf(BlockId id) => editor.sourceOf(id);

  // Undo / Redo（转发到 history）
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;
  Transaction? undo() { ... }
  Transaction? redo() { ... }
}
```

**种子数据**（3 个示例文档）：

```dart
class SeedDocuments {
  /// 演示文档 1：基础块组合
  static Document demo1() => Document(children: [
    HeadingElement(level: 1, text: 'FormulaFix Demo'),
    ParagraphElement(children: [TextElement('Hello, Block Editor!')]),
    CodeElement(code: 'void main() { print("hi"); }', language: 'dart'),
  ]);

  /// 演示文档 2：标题层级
  static Document demo2() => Document(children: [
    HeadingElement(level: 1, text: '标题一'),
    HeadingElement(level: 2, text: '标题二'),
    HeadingElement(level: 3, text: '标题三'),
    ParagraphElement(children: [TextElement('正文内容')]),
  ]);

  /// 演示文档 3：代码示例
  static Document demo3() => Document(children: [
    ParagraphElement(children: [TextElement('代码示例：')]),
    CodeElement(code: 'def greet():\n    return "hi"', language: 'python'),
  ]);
}
```

### 3.5 任务 3.0.5：UI Design Reference

**输出**：`docs/design/ui-spec.md`

**目的**：把前面 HTML Demo 的"视觉探索"沉淀为"设计规范"。

**至少记录**：

| 维度 | 示例 |
|---|---|
| 内容宽度 | 720px（mobile）/ 960px（tablet） |
| 块间距 | 16px |
| 字号 scale | h1=32px / h2=24px / h3=20px / body=16px / code=14px |
| 工具栏高度 | 48px |
| 侧栏宽度 | 280px |
| 侧栏行为 | swipe-in / 侧栏按钮触发 |
| 主题 token | light/dark 颜色 token |
| Block 边框 | focused=2px blue / unfocused=1px grey |
| 状态栏高度 | 24px |

**不直接照搬 HTML Demo**——沉淀规范，不照搬代码。

---

## 4. 产出物清单

### 4.1 AI 可 commit 的产出物（非架构决策类）

| 文件 | 类型 | AI 权限 |
|------|------|---------|
| `docs/contracts/phase3.0-task-contract.md` | Task Contract | ✅ 可起草 + commit |
| `lib/presentation/editor/*.dart` | 代码骨架 | ✅ 可起草 + commit |
| `lib/presentation/blocks/*.dart` | 代码骨架 | ✅ 可起草 + commit |
| `lib/presentation/panels/*.dart` | 代码骨架 | ✅ 可起草 + commit |
| `lib/presentation/themes/*.dart` | 代码骨架 | ✅ 可起草 + commit |
| `test/presentation/editor/*_test.dart` | 单元测试 | ✅ 可起草 + commit |
| `test/architecture/ui_layer_isolation_test.dart` | 架构守门测试 | ✅ 可起草 + commit |
| `docs/releases/phase3.0-verification-report.md` | Verification Report | ✅ 可起草 + commit |

### 4.2 AI 仅起草不 commit 的产出物（架构决策类）

| 文件 | 类型 | AI 权限 |
|------|------|---------|
| `docs/design/ui-spec.md` | 设计规范 | 起草不 commit（属设计决策类，建议 Human Owner 审批后 commit） |
| `docs/ROADMAP.md`（新增 Phase 3.0 节） | 顶层架构文档 | 起草不 commit |

### 4.3 不产出的文件

- ❌ 不新增 ADR（ADR-0009 v1.1 已覆盖 UI 架构设计，Phase 3.0 是落地实施）
- ❌ 不修改 `docs/ADR/*.md`（除非落地过程中暴露设计缺陷，走 ADR 修订流程）
- ❌ 不修改 `AGENTS.md` / `docs/ARCHITECTURE.md` / `docs/REFACTOR_DESIGN.md` 等顶层文档

---

## 5. 验证计划

### 5.1 自动验证

- `flutter analyze --no-fatal-infos --fatal-warnings` — 0 warning
- `flutter test` — 全部通过，0 regression（Phase 2.9 的 843 tests 仍 PASS）
- 新增架构守门测试（TC-ARCH-UI-*）：

**Command Layer 守门**：
- `TC-ARCH-UI-1`：`lib/presentation/{editor,blocks,panels,chrome}/` 下不直接 import `BlockOperations` / `DocumentEditor`
- `TC-ARCH-UI-2`：`lib/presentation/blocks/` 下不直接 import `lib/core/editing/` 内核包（除 BlockId / BlockType 等纯类型）
- `TC-ARCH-UI-3`：Widget 类不含 `DocumentElement` 字段（必须通过 EditorCoordinator 访问）

**God Object 守门**：
- `TC-ARCH-UI-4`：`lib/presentation/editor/editor_coordinator.dart` 文件 ≤ 200 行 + 不持有 `Theme` / `File` / `Route` 等领域状态

**依赖方向守门**（Human Owner v1.1 反馈新增）：
- `TC-ARCH-UI-5`：`lib/presentation/blocks/` 不 import `lib/presentation/editor/` / `lib/presentation/panels/` / `lib/presentation/chrome/`
- `TC-ARCH-UI-6`：`lib/presentation/editor/` 不 import `lib/presentation/panels/`
- `TC-ARCH-UI-7`：`lib/presentation/chrome/` 不 import `lib/presentation/blocks/` / `lib/presentation/panels/`（chrome 只通过 EditorCoordinator 接收数据）

**exhaustive switch 守门**（Human Owner v1.1 反馈新增）：
- `TC-ARCH-UI-8`：`lib/presentation/blocks/block_renderer.dart` 必须使用 `switch (element)` 语法且不含 `_ =>` fallback 分支（强制 exhaustive，新增类型时编译期暴露）

**依赖方向图**（守门测试保障）：
```
editor/  ─────────────────────────────────┐
   ↓                                     │
chrome/ ── (通过 EditorCoordinator) ──────┤
   ↓                                     │
blocks/ ←── EditorCoordinator 注入 ──────┘
   ↓
core/editing  (内核，UI 不直接访问 mutation)
```

### 5.2 功能验证（手动）

- `flutter run` 启动后看到 EditorShell + 3 种 Block + 侧栏占位 + 状态栏占位
- 点击 paragraph block → 进入 edit 态 → 修改 source → 失焦 → 回到 render 态，内容更新
- 点击 heading block → 同上验证双态切换
- 点击 code block → 同上验证双态切换
- 3 种 block 之间点击切换 focus，旧块自动提交 + 切回 render 态

### 5.3 架构验证

- **AST 零污染**：grep 检查 `lib/presentation/editor/` + `lib/presentation/blocks/` 下不含 `DocumentElement` 字段（必须通过 Coordinator 访问）
- **Command Layer 强制**：grep 检查 `lib/presentation/blocks/` 下不直接 import `BlockOperations` / `TransactionBuilder`
- **避免 God Object**：`EditorCoordinator` 文件 ≤ 200 行，只含协调逻辑，不含业务状态
- **旧 UI 并存**：`lib/presentation/screens/editor_screen.dart` 仍可独立运行

---

## 6. 退出条件（Exit Gate）

Phase 3.0 完成必须满足：

### UI 验证
- [ ] `flutter run` 看到 EditorShell 正常显示
- [ ] 3 种 Block（paragraph / heading / code）渲染正确
- [ ] Block 双态切换（render ↔ edit）Demo 可用
- [ ] SidePanel / StatusBar 插槽存在（占位即可）

### 架构验证
- [ ] Widget 不直接访问 AST（通过 EditorCoordinator）
- [ ] Widget 不直接调用 DocumentEditor mutation（通过 CommandHandler）
- [ ] Command 是唯一用户行为入口
- [ ] EditorCoordinator 不持有业务状态（只协调，文件 ≤ 200 行）
- [ ] AST 零污染（grep 守门通过）
- [ ] **依赖方向守门**（Human Owner v1.1 反馈）：
  - [ ] `blocks/` 不 import `editor/` / `panels/` / `chrome/`
  - [ ] `editor/` 不 import `panels/`
  - [ ] `chrome/` 不 import `blocks/` / `panels/`
- [ ] **BlockRenderer 强制 exhaustive switch**（Human Owner v1.1 反馈）：不允许 `_ =>` fallback 到 GenericBlock

### 工程验证
- [ ] `flutter analyze` 0 warning
- [ ] `flutter test` 0 regression（Phase 2.9 的 843 tests 仍 PASS）
- [ ] 新增架构守门测试全 PASS（TC-ARCH-UI-1 ~ 8）
- [ ] `docs/design/ui-spec.md` 定稿（Human Owner 签字）

### 文档验证
- [ ] `docs/ROADMAP.md` 新增 Phase 3.0 节（Human Owner commit）
- [ ] Phase 3.0 Verification Report 完成

---

## 7. 风险评估

### 7.1 风险 1：迁移过程中暴露 Phase 2.9 设计缺陷

**概率**：中（Phase 2.9 Prototype 已通过 4 Demo 验证，但 production 路径有更严格的约束）

**影响**：需修改 Phase 2.9 已 commit 的代码（commands / states / prototype）

**缓解**：
1. 修改必须保持向后兼容（不破坏 Phase 2.9 的 843 tests）
2. 重大修改走 ADR 修订流程（修订 ADR-0009）
3. 修改必须先更新 Task Contract，由 Human Owner 审批

### 7.2 风险 2：EditorCoordinator 仍然变成 God Object

**概率**：中（"协调器"边界容易模糊，可能逐步累积状态）

**影响**：Phase 3.1+ 重构成本上升

**缓解**：
1. `TC-ARCH-UI-4` 守门测试限制 Coordinator 文件 ≤ 200 行
2. Coordinator 只持有 `editor` + `history` + `handler` + `_viewStates` + `_focusedId` 五个字段
3. Theme / File / Route 等其他状态必须放独立 Provider，不能进 Coordinator

### 7.3 风险 3：UI Design Reference 与实际实现脱节

**概率**：高（规范容易写成"理想"，实施时被简化）

**影响**：Phase 3.1+ 实现时发现规范不实用，重新设计

**缓解**：
1. `docs/design/ui-spec.md` 只记录 Phase 3.0 实际落地的值，不预测未来
2. Phase 3.1+ 实现新功能时，先更新 ui-spec 再实现代码
3. ui-spec 与代码同步更新（PR 必须包含 ui-spec diff）

### 7.4 风险 4：旧 UI 与新 UI 并存导致路由冲突

**概率**：中（两套 UI 都注册路由可能冲突）

**影响**：用户看到两个入口，困惑

**缓解**：
1. Phase 3.0 用 feature flag（如 `kEnableNewEditor` const bool）切换，默认 false
2. Phase 3.1 完成后再把 feature flag 默认设为 true
3. Phase 3.17 完成后再删除旧 UI 代码

---

## 8. 实施顺序

### 8.1 第一步：起草 Task Contract + ROADMAP（本阶段）

- AI 起草 `phase3.0-task-contract.md`（本文件）
- AI 起草 `docs/ROADMAP.md` 修改草案（新增 Phase 3.0 节）
- Human Owner 审批 Task Contract + ROADMAP 修改
- Human Owner commit + push（架构决策类，AI 不 commit）
- **此阶段可与 Phase 2.9 PR 评审并行**

### 8.2 第二步：等 Phase 2.9 PR 合并

- Phase 2.9 PR 由 Human Owner 在 GitHub Web UI 创建并合并
- Phase 2.9 合并后，Phase 2.9 的代码（commands / states / prototype）正式进入 main

### 8.3 第三步：建立目录结构 + Editor Shell

- 从 main 切出新分支 `feat/phase3.0-ui-skeleton`
- 创建 `lib/presentation/{editor,blocks,panels,themes}/` 目录
- 实现 `editor_page.dart` + `editor_shell.dart` + `editor_state.dart`（仅布局骨架）
- 实现 `panels/side_panel_host.dart` + `themes/editor_tokens.dart`（占位）

### 8.4 第四步：迁移 InMemoryDocumentEditor + EditorCoordinator

- 把 `lib/presentation/prototype/_shared/in_memory_document_editor.dart` 迁移到 `lib/presentation/editor/`
- 把 `lib/presentation/prototype/_shared/block_editor_facade.dart` 重命名为 `editor_coordinator.dart` 并迁移
- 实现 `seed_documents.dart`（3 个示例文档）

### 8.5 第五步：实现 BlockRenderer + 3 个 Block 组件

- 实现 `blocks/block_renderer.dart`（exhaustive switch）
- 实现 `blocks/paragraph_block.dart`（双态切换，复用 Phase 2.9 Demo 1 逻辑）
- 实现 `blocks/heading_block.dart`
- 实现 `blocks/code_block.dart`

### 8.6 第六步：接入 EditorPage 到路由 + feature flag

- 在 `main.dart` 或路由配置中新增 `kEnableNewEditor` feature flag
- flag 为 true 时路由到 `EditorPage`，false 时路由到旧 `EditorScreen`
- 默认 false，保证不影响现有用户

### 8.7 第七步：UI Design Reference

- 起草 `docs/design/ui-spec.md`
- Human Owner 审批 + commit

### 8.8 第八步：架构守门测试 + Phase 3.0 Exit Gate

- 实现 `TC-ARCH-UI-1 ~ 4` 守门测试
- 起草 Phase 3.0 Verification Report
- Human Owner 验收
- 正式关闭 Phase 3.0，启动 Phase 3.1

---

## 9. AI 协作信息

### 9.1 AI 自我审查清单

- [ ] 本 Task Contract 已明确范围与边界（5 个任务，不夹带其他功能）
- [ ] 所有架构决策类文件授权情况已明确（ROADMAP / ui-spec 起草不 commit）
- [ ] Phase 2.9 复用关系已明确（commands / states 原位保留，prototype/_shared 迁移重命名）
- [ ] 避免 God Object 约束已量化（Coordinator ≤ 200 行 + 守门测试）
- [ ] 风险已评估且有缓解措施
- [ ] 验证计划覆盖自动 + 功能 + 架构三层

### 9.2 反馈信号

**成功信号**：
- EditorShell 可运行
- 3 种 Block 双态切换流畅
- Phase 3.1 实现时无架构返工（直接挂载到既有插槽）

**失败信号**：
- EditorCoordinator 文件 > 200 行（God Object 苗头）
- Widget 直接 import `BlockOperations`（Command Layer 被绕过）
- Phase 3.1 实现时发现 BlockRenderer 接口需重大修改

### 9.3 回滚方案

- 若 Phase 3.0 验证失败，回滚到 Phase 2.9 状态（Phase 2.9 已合并 main）
- 若新 UI 影响旧 UI，feature flag 切回 false
- 若迁移过程中 Phase 2.9 代码需重大修改，走 ADR 修订流程

---

## 10. 待决问题（Human Owner 审批时拍板）

### 10.1 问题 1：Phase 2.9 Prototype 目录保留策略

Phase 3.0 完成后，`lib/presentation/prototype/` 目录如何处理？

**倾向**：
- 选项 A：保留作历史参考（建议）
  - 理由：Prototype 是 ADR-0009 落地的设计证据，保留有助于理解"为什么这样设计"
- 选项 B：归档为 `_archive/`
  - 理由：避免新代码混淆，但仍可查
- 选项 C：直接删除
  - 理由：Phase 3.0 已迁移所有有用逻辑到 production 路径，Prototype 完成使命

### 10.2 问题 2：feature flag 默认值

Phase 3.0 期间 `kEnableNewEditor` 默认值是 true 还是 false？

**倾向**：默认 false
- 理由：Phase 3.0 期间新 UI 只有骨架，用户体验不完整；旧 UI 仍作主入口
- Phase 3.1 完成后改为默认 true
- Phase 3.17 完成后删除旧 UI

### 10.3 问题 3：UI Design Reference 文件归属

`docs/design/ui-spec.md` 属于架构决策类还是工程文档？

**倾向**：工程文档（AI 可 commit，但需 Human Owner 审批首版）
- 理由：ui-spec 是"视觉规范"，不是"架构决策"；但首版需 Human Owner 确认设计方向

### 10.4 问题 4：种子文档来源

3 个种子文档的内容来源？

**倾向**：从 Phase 2.9 Prototype Demo 中提取（Demo 1 / 2 / 4 的初始数据）
- 理由：保证 Phase 3.0 与 Phase 2.9 验证场景一致

---

**本 Task Contract 由 AI Agent 起草 v1.0，待 Human Owner 审批。**
