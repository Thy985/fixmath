# Phase 3.2 Task Contract: Block Runtime Expansion

> **版本**：v1.2（小型修订,消除 PR 划分依赖矛盾 + AST 类型命名错误）
> **起草日期**：2026-07-21
> **v1.1 修订日期**：2026-07-21（记录 §9 决策事项结果）
> **v1.2 修订日期**：2026-07-22（§3.6 / §3.7 改为 inline rendering；§8.1 PR 划分调整；§6.1 Exit Gate 拆分；ui-spec.md §7 同步）
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Accepted（v1.1 Human Owner 审批通过 2026-07-21；v1.2 为小型修订,无架构决策变化）
> **前置阶段**：Phase 3.1 WYSIWYG Migration（✅ Phase 3.1-A 已完成；Phase 3.1-B/C 为触发制延后项,不阻塞 Phase 3.2）
> **后继阶段**：Phase 3.3 Immersive Experience（体验层沉浸式：焦点模式 / 打字机模式 / 字号缩放等）
>
> **关联文档**：
> - [ROADMAP.md Phase 3.2](../ROADMAP.md)（阶段重新划分说明 2026-07-21）
> - [design/ui-spec.md §7](../design/ui-spec.md)（扩展点表格）
> - [ADR-0009 UI Architecture Design](../ADR/0009-ui-architecture-design.md)
> - [Phase 3.0 Task Contract](./phase3.0-task-contract.md)
> - [Phase 3.1 Task Contract](./phase3.1-task-contract.md)

---

## 0. 任务缘起

Phase 3.0 建立了 EditorShell + BlockRenderer 的 production 路径骨架，但 BlockRenderer 的 exhaustive switch 只覆盖了 3 种 BlockType（paragraph / heading / code），其余 6 种类型显式抛 `UnimplementedError`：

```dart
// block_renderer.dart 第 75-86 行
ListElement() ||
TaskListItemElement() ||
TableElement() ||
BlockquoteElement() ||
MermaidElement() ||
HorizontalRuleElement() =>
  throw UnimplementedError('BlockType ${element.runtimeType} not supported in Phase 3.0'),
```

Phase 3.1-A 已完成 WYSIWYG 架构迁移（EditorPage 默认 + 无 PreviewContent 卡片包裹 + BlockId 迁移通知），但**内容能力仍然是"最小可编辑系统"**——用户在 `/editor` 中打开含表格 / 引用 / Mermaid 的 .md 文档时，仍会触发 `UnimplementedError`。

**Phase 3.2 的核心定位**：从"最小可编辑系统"扩展为"完整 Markdown Block Runtime"。

**演进类比**：Phase 3.0 建立"VS Code Window"，Phase 3.1 让 EditorPage 成为默认入口，Phase 3.2 才真正让用户能编辑完整 Markdown 文档（而不是只有 3 种 BlockType 的小子集）。

---

## 1. 目标与范围

### 1.1 核心目标

回答一个问题：**如何让 BlockRenderer 支持完整 Markdown Block 类型，同时避免 Block 数量增加后的架构退化？**

如果只是"给每种 Block 加个 case 分支"，Phase 3.5+ 会出现：
- Block 间共享逻辑重复（toolbar / selection / drag handle）
- Block 工具栏无处挂载（只能塞进每个 Block 内部）
- 测试覆盖碎片化（每个 Block 各搞一套）
- 目录结构扁平化（6 个新 Block 文件全堆在 `blocks/` 根目录）

所以 Phase 3.2 不只是"加 6 个 Block"，而是**同时建立 `blocks/<type>/` 目录结构 + `blocks/shared/` 共享组件**。

### 1.2 范围（10 个任务）

| # | 任务 | 产出 | 类型 |
|---|------|------|------|
| 3.2.1 | MathBlock（行内 + 块级公式） | `blocks/math/` | 新 Block |
| 3.2.2 | MermaidBlock（流程图 / 时序图） | `blocks/mermaid/` | 新 Block |
| 3.2.3 | QuoteBlock（引用块） | `blocks/quote/` | 新 Block |
| 3.2.4 | TableBlock（含可视化编辑） | `blocks/table/` | 新 Block |
| 3.2.5 | ImageBlock（含 alt 占位） | `blocks/image/` | 新 Block |
| 3.2.6 | LinkBlock（行内链接） | `blocks/link/` | 新 Block |
| 3.2.7 | `blocks/<type>/` 目录结构 + `blocks/shared/` | 目录重组 + 3 个共享组件 | 架构演进 |
| 3.2.8 | WebView 预热机制 | 后台预热通道 | 性能 |
| 3.2.9 | 公式 / Mermaid 渲染缓存 | 缓存层 | 性能 |
| 3.2.10 | 代码块语法高亮 | CodeBlock 内部 | 视觉 |

### 1.3 不在 Phase 3.2 范围内（明确边界）

- ❌ 体验层沉浸式（焦点模式 / 打字机模式 / 字号缩放）（Phase 3.3）
- ❌ TOC / 文件树 / 主题切换（Phase 3.4+）
- ❌ 修改 `lib/core/editing/` 内核代码（Phase 3.2 不动内核）
- ❌ 修改 EditorShell 布局（Phase 3.2 只扩展 BlockRenderer）
- ❌ 解决 `BaseBlockState.buildRenderContent` 死代码问题（Phase 3.2 决策点 §3.0 处理）
- ❌ ListElement / TaskListItemElement / HorizontalRuleElement 的独立 Block（评估后纳入 §3.11 备选）

---

## 2. 关键架构约束（Hard Rules）

### 2.1 AST 零污染（沿用 Phase 3.0）

**禁止**在 `DocumentElement` / `document.dart` 新增 UI 状态字段。UI 状态通过 `BlockViewState` 建模。

### 2.2 Command Layer 强制（沿用 Phase 3.0）

所有 UI 事件必须经 `EditorCommand` → `CommandHandler` → `TransactionBuilder` → `BlockOperation`。

**新增约束**：WebView 预热、渲染缓存等基础设施也不允许绕过 Command 路径修改 AST（缓存只读不写）。

### 2.3 BlockRenderer 抽象 + exhaustive switch（沿用 Phase 3.0 v1.1）

新增 Block 类型只增加 renderer + case 分支，**不允许 `_ =>` fallback**。

**Phase 3.2 目标**：将 `UnimplementedError` 的 6 种类型（list / taskListItem / table / blockquote / mermaid / horizontalRule）大部分实现，剩余显式保留抛错（如果决定不实现）。

### 2.4 依赖方向严格（沿用 Phase 3.0 Hard Rule 8）

- `blocks/<type>/` 不 import `editor/` / `panels/` / `chrome/`
- `blocks/<type>/` 只能 import `blocks/shared/` + `editor/editor_coordinator.dart`（通过 EditorScope 注入）
- `blocks/shared/` 不 import `editor/` 之外的文件
- `editor/` 不 import `panels/`
- `chrome/` 不 import `blocks/` / `panels/`

### 2.5 避免 God Object（Phase 3.2 强化）

**禁止**把 6 种新 Block 的共享逻辑塞进一个"BlockUtils"大杂烩。

**正确做法**：按职责拆分到 `blocks/shared/`：
- `block_toolbar.dart`：Block 工具栏（插入 / 删除 / 移动）
- `block_selection.dart`：Block 选中态
- `block_drag_handle.dart`：Block 拖拽手柄

### 2.6 WebView 复用（Phase 3.2 新增）

MathBlock / MermaidBlock 都需要 WebView 渲染。**禁止**每个 Block 各自管理 WebView 实例。

**正确做法**：通过 `WebViewPool`（Phase 3.2.8）统一管理，Block 只持有 `WebViewHandle` 引用。

### 2.7 旧 UI 不动（Phase 3.2 新增）

`lib/presentation/widgets/` 下的旧 renderer（paragraph_renderer / heading_renderer / code_renderer / blockquote_renderer / table_renderer 等）**保持不动**，仅作为 `/editor-legacy` 的 fallback。

**理由**：避免 Phase 3.2 与 legacy 代码耦合，legacy 的清理归入 Phase 3.4+。

---

## 3. 任务详细分解

### 3.0 决策点：BaseBlockState 死代码处理（Phase 3.2 启动时必做）

**背景**：Phase 3.1-A PR #2 评审 Issue #2 发现 `BaseBlockState.buildRenderContent` 是空壳死代码（3 个子类在 `build()` 中直接分发，未调用此抽象方法）。

**Phase 3.2 启动时必须二选一**（不实施则本接口成为半永久死代码）：

#### 方案 A（推荐）：基类统一调度

让 `BaseBlockState.build()` 统一按 `currentMode` 分发：
- `RenderMode.rendered` → 调用子类 `buildRenderContent(context)`
- `RenderMode.editing` → 调用基类 `buildEditField(style: editStyle)`

子类只实现 `buildRenderContent` + 提供 `editStyle`，不再重写 `build()`。

**优点**：消除 40 行/Block 的重复分发样板，新增 6 个 Block 时只需实现 `buildRenderContent`。
**风险**：需要重构现有 3 个 Block（paragraph / heading / code），与 Phase 3.2 新增 Block 同 PR。

#### 方案 B：移除抽象接口

移除 `BaseBlockState.buildRenderContent` 抽象方法，让 `build()` 成为子类的约定（保持当前结构）。

**优点**：零重构现有代码。
**风险**：6 个新 Block 需要各自重复 40 行分发样板。

**推荐**：方案 A（与 Phase 3.2 的"建立可扩展结构"目标一致）。

**决策权**：Human Owner。

### 3.1 任务 3.2.7：blocks/ 目录重组（优先执行，为 6 个新 Block 铺路）

**目标**：从扁平结构升级为分层结构。

**当前结构**：
```
lib/presentation/blocks/
├── base_block_state.dart
├── block_renderer.dart
├── code_block.dart
├── heading_block.dart
└── paragraph_block.dart
```

**目标结构**：
```
lib/presentation/blocks/
├── block_renderer.dart            ← exhaustive switch 分发器
├── base_block_state.dart          ← 抽象基类（§3.0 方案 A 后）
│
├── paragraph/
│   └── paragraph_block.dart       ← 从根目录迁移
├── heading/
│   └── heading_block.dart        ← 从根目录迁移
├── code/
│   └── code_block.dart           ← 从根目录迁移
│
├── math/                          ← Phase 3.2.1 新增
│   └── math_block.dart
├── mermaid/                       ← Phase 3.2.2 新增
│   └── mermaid_block.dart
├── quote/                         ← Phase 3.2.3 新增
│   └── quote_block.dart
├── table/                         ← Phase 3.2.4 新增
│   └── table_block.dart
├── image/                         ← Phase 3.2.5 新增
│   └── image_block.dart
├── link/                          ← Phase 3.2.6 新增
│   └── link_block.dart
│
└── shared/                        ← Phase 3.2.7 新增
    ├── block_toolbar.dart         ← Block 工具栏（插入/删除/移动）
    ├── block_selection.dart       ← Block 选中态
    └── block_drag_handle.dart     ← Block 拖拽手柄
```

**迁移规则**：
- 3 个现有 Block 文件迁移到 `<type>/` 目录，更新 import 路径
- `block_renderer.dart` 的 import 路径同步更新
- 守门测试 `TC-ARCH-UI-5 ~ 7`（依赖方向）同步更新断言

**测试**：现有 922 tests 必须 0 regression。

### 3.2 任务 3.2.1：MathBlock（行内 + 块级公式）

**AST 类型**：`FormulaElement`（已存在于 [document.dart](../../flutter_app/lib/data/models/document.dart)）

**视觉规范**（见 [ui-spec.md §3.1](../design/ui-spec.md)）：
- render 态：LaTeX 渲染（MathJax / KaTeX via WebView）
- edit 态：`$latex$` / `$$latex$$` source
- Typora 化原则：纯 serif italic，无卡片背景

**实现要点**：
- 行内公式：嵌入 ParagraphBlock 的 inline 渲染（不作为独立 Block）
- 块级公式：独立 MathBlock，经 WebView 渲染

**依赖**：任务 3.2.8（WebView 预热）+ 任务 3.2.9（渲染缓存）

**测试**：
- TC-BLOCK-MATH-1：行内公式 render 视觉正确
- TC-BLOCK-MATH-2：块级公式 render / edit 双态切换
- TC-BLOCK-MATH-3：WebView 预热后冷启动 < 500ms

### 3.3 任务 3.2.2：MermaidBlock

**AST 类型**：`MermaidElement`（已存在）

**视觉规范**：
- render 态：Mermaid.js 渲染（WebView）
- edit 态：`mermaid` source

**实现要点**：
- 复用 `lib/core/services/mermaid_service.dart` 的渲染逻辑
- WebViewPool 共享 MathBlock 的 WebView 实例

**测试**：
- TC-BLOCK-MERMAID-1：流程图 render 视觉正确
- TC-BLOCK-MERMAID-2：时序图 render 视觉正确
- TC-BLOCK-MERMAID-3：edit / render 双态切换

### 3.4 任务 3.2.3：QuoteBlock

**AST 类型**：`BlockquoteElement`（已存在）

**视觉规范**（Typora 化）：
- 左侧 3dp `#C0C0C0` 竖线 + serif 正文
- edit 态：`> text` source

**实现要点**：纯 Flutter Widget，无 WebView 依赖。

**测试**：
- TC-BLOCK-QUOTE-1：单层引用 render 视觉
- TC-BLOCK-QUOTE-2：嵌套引用 render 视觉
- TC-BLOCK-QUOTE-3：双态切换

### 3.5 任务 3.2.4：TableBlock

**AST 类型**：`TableElement`（已存在）

**视觉规范**：
- render 态：原生 Flutter Table 渲染
- edit 态：Markdown table source

**实现要点**：
- Phase 3.2 只实现基本渲染 + 双态切换
- 可视化编辑（点击 cell 直接编辑）归入 Phase 3.3（原 ROADMAP 3.15）
- 支持表格语法对齐（GFM table）

**测试**：
- TC-BLOCK-TABLE-1：基本表格 render
- TC-BLOCK-TABLE-2：双态切换
- TC-BLOCK-TABLE-3：含对齐标记的表格

### 3.6 任务 3.2.5：Image Inline Rendering Enhancement

> **v1.2 修订**：任务名从 "ImageBlock" 改为 "Image Inline Rendering Enhancement"。
> 原命名误导（`ImageBlock` 暗示独立 BlockType），实际 AST 中
> [ImageElement extends InlineElement](../../flutter_app/lib/data/models/document.dart)，
> 不进入 BlockRenderer 的 exhaustive switch。

**AST 类型**：`ImageElement extends InlineElement`（已存在,**行内元素**）

**视觉规范**（见 [ui-spec.md §3.1](../design/ui-spec.md)）：
- render 态：占位 + alt 文本（Phase 3.5+ 接入图片管理）
- edit 态：`![alt](url)` source

**实现要点**：
- 扩展 `paragraph_block.dart` 的 inline 渲染器（已有占位渲染,Phase 3.2 仅微调）
- 不在 BlockRenderer 新增 case（违反 TC-ARCH-UI-8 exhaustive switch 守门）
- 实际图片加载归入 Phase 3.5（原 ROADMAP 3.5）

**测试**：
- TC-BLOCK-IMAGE-1：占位 + alt 文本 render
- TC-BLOCK-IMAGE-2：双态切换

### 3.7 任务 3.2.6：Link Inline Rendering Enhancement

> **v1.2 修订**：任务名从 "LinkBlock" 改为 "Link Inline Rendering Enhancement"。
> 与 §3.6 同理,`LinkElement extends InlineElement`,不进入 BlockRenderer。

**AST 类型**：`LinkElement extends InlineElement`（已存在,**行内元素**）

**设计决策**：Link 作为**行内元素**,不是独立 Block。Phase 3.2 在 ParagraphBlock 的 inline 渲染中实现 LinkElement 的 render 态（蓝色文本 + 下划线,不显示多余 URL）+ edit 态（`[text](url)` source）。

**实现要点**：
- 扩展 `paragraph_block.dart` 的 inline 渲染器（已有占位渲染,Phase 3.2 仅微调：移除多余 ` (url)` 后缀）
- 不创建独立 `blocks/link/` 目录（不进入 BlockRenderer case）
- 不在 BlockRenderer 新增 case（违反 TC-ARCH-UI-8）

**测试**：
- TC-BLOCK-LINK-1：行内链接 render 视觉（蓝色 + 下划线,无多余 URL）
- TC-BLOCK-LINK-2：edit source 显示正确

### 3.8 任务 3.2.7：blocks/shared/ 共享组件

**3 个共享组件**：

#### block_toolbar.dart

**职责**：Block 工具栏（插入 / 删除 / 移动按钮）

**挂载点**：每个 Block 的 render 态右上角（hover / long-press 显示）

**API**：
```dart
class BlockToolbar extends StatelessWidget {
  final BlockId blockId;
  final EditorCoordinator coordinator;
  // ...
}
```

#### block_selection.dart

**职责**：Block 选中态视觉（边框高亮）

**API**：
```dart
class BlockSelection extends StatelessWidget {
  final BlockId blockId;
  final bool isSelected;
  final Widget child;
  // ...
}
```

#### block_drag_handle.dart

**职责**：Block 拖拽手柄（Phase 3.2 只占位，实际拖拽归入 Phase 3.4+）

**API**：
```dart
class BlockDragHandle extends StatelessWidget {
  final BlockId blockId;
  // ...
}
```

**测试**：
- TC-SHARED-TOOLBAR-1：工具栏挂载 + 按钮点击触发 Command
- TC-SHARED-SELECTION-1：选中态视觉正确
- TC-SHARED-DRAG-1：拖拽手柄占位显示

### 3.9 任务 3.2.8：WebView 预热机制

**目标**：App 启动后并行加载 WebView，不阻塞首屏。

**实现要点**：
- 在 `main()` 或 `EditorPage.initState` 中启动 WebView 预热
- 通过 `WebViewPool` 管理 N 个预热实例（N=2 默认）
- MathBlock / MermaidBlock 从 pool 借用，用完归还

**依赖**：`flutter_inappwebview`（已在 `pubspec.yaml`）

**测试**：
- TC-PERF-WEBVIEW-1：预热后冷启动 < 500ms
- TC-PERF-WEBVIEW-2：pool 借还机制正确

### 3.10 任务 3.2.9：公式 / Mermaid 渲染缓存

**目标**：不退出 App 时清空缓存。

**实现要点**：
- 缓存 key：`hash(latex_source)` 或 `hash(mermaid_source)`
- 缓存 value：渲染后的 Widget 树或 HTML 字符串
- LRU 策略，maxsize=50

**测试**：
- TC-PERF-CACHE-1：相同 source 二次渲染命中缓存
- TC-PERF-CACHE-2：LRU 淘汰策略正确

### 3.11 任务 3.2.10：代码块语法高亮

**目标**：CodeBlock 的 render 态支持语法高亮。

**实现要点**：
- 选项 A：`flutter_highlight`（纯 Dart，无 WebView 依赖）
- 选项 B：highlight.js via WebView（与 MathBlock 共享 pool）
- 推荐：选项 A（性能更好，避免 WebView 滥用）

**依赖**：新增 `flutter_highlight` 到 `pubspec.yaml`（需 Human Owner 审批）

**测试**：
- TC-BLOCK-CODE-1：Dart 代码高亮正确
- TC-BLOCK-CODE-2：Python 代码高亮正确
- TC-BLOCK-CODE-3：未知 language 不崩溃

---

## 4. 验证计划

### 4.1 自动化验证

```bash
cd flutter_app
flutter analyze  # 0 error
flutter test     # 0 regression
```

**测试矩阵**：

| 类型 | 测试 ID | 数量 |
|------|---------|------|
| 单元测试 | TC-BLOCK-{MATH,MERMAID,QUOTE,TABLE,IMAGE,LINK,CODE}-* | ~30 |
| 单元测试 | TC-SHARED-{TOOLBAR,SELECTION,DRAG}-* | ~10 |
| 性能测试 | TC-PERF-{WEBVIEW,CACHE}-* | ~6 |
| 架构守门 | TC-ARCH-UI-5 ~ 7（依赖方向，更新断言） | 3 |

### 4.2 功能验证

- [ ] 含表格 / 引用 / Mermaid / 公式的 .md 文档可在 `/editor` 正常打开
- [ ] 每种新 Block 双态切换正常
- [ ] WebView 预热后冷启动 < 500ms
- [ ] 渲染缓存命中二次渲染

### 4.3 架构验证

- [ ] AST 零污染（grep 守门通过）
- [ ] 依赖方向守门通过（`blocks/<type>/` 不 import `editor/` 之外）
- [ ] BlockRenderer exhaustive switch（新增 case 分支，无 `_ =>` fallback）
- [ ] 无 God Object（`blocks/shared/` 3 个文件职责单一）
- [ ] WebView 复用（MathBlock / MermaidBlock 共享 `WebViewPool`）

---

## 5. 风险评估

| 风险 | 等级 | 影响 | 缓解措施 |
|------|------|------|---------|
| §3.0 方案 A 重构现有 3 个 Block 引入 regression | 中 | 现有 922 tests 受影响 | 逐个重构 + 完整测试覆盖 |
| `flutter_highlight` 新依赖与现有 `flutter_inappwebview` 冲突 | 低 | 编译失败 | dependency_overrides 稳定版锁定 |
| WebViewPool 实现复杂度高 | 中 | Phase 3.2 延期 | 简化为单实例 WebView + 预热 |
| 表格可视化编辑范围蔓延 | 中 | 超出 Phase 3.2 边界 | 明确归入 Phase 3.3 |
| LinkBlock 作为行内元素与 Block 概念冲突 | 低 | 设计混乱 | 明确在 §3.7 声明为行内元素 |

---

## 6. 成功标准（Phase 3.2 Exit Gate）

参照 [Phase 3.0 Task Contract §4 退出条件](./phase3.0-task-contract.md) 的四维度结构，Phase 3.2 Exit Gate 也分维度验证。

### 6.1 UI 验证

> **v1.2 修订**：原 "6 种新 Block 双态切换正常" 表述错误。
> 实际 BlockType 新增 4 种（Quote / Table / Math / Mermaid）,
> Image / Link 是 InlineElement（不进入 BlockRenderer case）。
> 验收标准按 AST 事实拆分为两条。

- [ ] 含表格 / 引用 / Mermaid / 公式 / 图片占位 / 行内链接的 .md 文档可在 `/editor` 正常打开（无 `UnimplementedError`）
- [ ] **4 种新增 Block 双态切换正常**（render ↔ edit）：
  - QuoteBlock / TableBlock（PR #2）
  - MathBlock / MermaidBlock（PR #3）
- [ ] **Image / Link Inline Rendering 符合设计规范**：
  - Image：占位 + alt 文本（Phase 3.5+ 接入图片管理）
  - Link：蓝色文本 + 下划线（不显示多余 URL 后缀）
  - 两者均扩展自 ParagraphBlock 的 inline renderer,不进入 BlockRenderer exhaustive switch
- [ ] 行内公式 / 行内链接在 ParagraphBlock inline renderer 中正确渲染
- [ ] BlockToolbar 在每个 Block 上挂载可用（hover / long-press 触发）

### 6.2 架构验证

- [ ] AST 零污染（`grep` 守门通过：`DocumentElement` 无 isFocused / isSelected / selection 字段）
- [ ] 依赖方向守门通过（`blocks/<type>/` 不 import `editor/` / `panels/` / `chrome/`，更新 `TC-ARCH-UI-5 ~ 7` 断言）
- [ ] BlockRenderer exhaustive switch（新增 case 分支，无 `_ =>` fallback）
- [ ] 无 God Object（`blocks/shared/` 3 个文件职责单一，无 BlockUtils 大杂烩）
- [ ] WebView 复用（MathBlock / MermaidBlock 共享 `WebViewPool`，无各自管理 WebView 实例）
- [ ] §3.0 决策点已实施（方案 A 或方案 B，消除 `buildRenderContent` 死代码）

### 6.3 工程验证

- [ ] `flutter analyze` 0 error（warning 允许但应消除）
- [ ] `flutter test` 0 regression（Phase 3.1-A 的 922 tests 全 PASS）
- [ ] 新增 ~46 测试全 PASS（含 TC-BLOCK-* / TC-SHARED-* / TC-PERF-* / TC-ARCH-UI-*）
- [ ] `flutter build apk --debug` 成功
- [ ] `flutter build web` 成功
- [ ] 新增 `flutter_highlight` 依赖（若 §3.11 选 A）通过 `dependency_overrides` 锁定版本

### 6.4 性能验证

- [ ] WebView 预热后冷启动 < 500ms（`TC-PERF-WEBVIEW-1` 通过）
- [ ] 渲染缓存命中率 > 80%（相同 source 二次渲染，`TC-PERF-CACHE-1` 通过）
- [ ] 1000 行含 6 种 Block 的文档编辑 keystroke latency < 100ms（不触发 Phase 3.1-B）

### 6.5 文档验证

- [ ] [ROADMAP.md](../ROADMAP.md) Phase 3.2 任务状态更新为 ✅
- [ ] [design/ui-spec.md §7](../design/ui-spec.md) Phase 3.2 行 checkbox 全部勾选
- [ ] Phase 3.2 Verification Report 完成（参照 [phase3.0-verification-report.md](../releases/) 格式）
- [ ] 若引入新依赖，更新 [pubspec.yaml](../../flutter_app/pubspec.yaml) + ADR（若需要）

### 6.6 反馈信号

**成功信号**：
- 用户可在 `/editor` 打开含表格 / 引用 / Mermaid / 公式的 .md 文档
- WebView 冷启动 < 500ms
- 6 种新 Block 双态切换无闪烁

**失败信号**：
- 任何现有测试 regression
- `UnimplementedError` 仍然被触发（说明有 Block 未实现）
- WebView 内存泄漏（pool 借还不归还）
- Phase 3.1-B/C 触发条件被触发（性能 / undo 回归）

---

## 7. 回滚计划

### 7.1 回滚触发条件

- 现有 922 tests 出现 regression 且无法在 1 个 PR 内修复
- §3.0 方案 A 重构导致 EditorShell 不可用
- WebView 预热导致 App 启动崩溃

### 7.2 回滚步骤

1. `git revert <phase-3.2-commits>` 回滚所有 Phase 3.2 commit
2. 验证 `feat/phase3.1-wysiwyg-migration` 的 HEAD 仍可构建
3. 重新评估 §3.0 方案 A 的风险，考虑改用方案 B
4. 若 WebView 预热是根因，简化为单实例 WebView（跳过 pool 实现）

### 7.3 回滚边界

- **不回滚**：Phase 3.1-A 的已合并产出（EditorPage 默认 + BlockId 迁移通知）
- **可回滚**：Phase 3.2 的所有代码改动（在独立 branch 上）
- **不可回滚**：ROADMAP.md / ui-spec.md 的文档修订（已合并 main）

---

## 8. PR 策略

### 8.1 单 PR vs 分 PR

> **v1.2 修订**：原 PR 划分把 MathBlock / MermaidBlock 放入 PR #2,
> 但 §3.2 / §3.3 明确声明这两个任务依赖 §3.2.8 WebView 预热（原 PR #3）,
> 形成倒置依赖。修订后把 WebView 相关任务聚合到 PR #3,消除依赖冲突。
> 同时 §3.6 / §3.7 改为 inline rendering,PR #2 范围相应调整。

Phase 3.2 任务量大（10 个子任务），分 3 个 PR：

| PR | 范围 | 依赖 |
|----|------|------|
| PR #1 | §3.0 方案 A 重构 + 任务 3.2.7 目录重组 | 无（✅ 已合并 main） |
| PR #2 | 任务 3.2.3 QuoteBlock + 3.2.4 TableBlock + 3.2.5 Image inline 微调 + 3.2.6 Link inline 微调（纯 Flutter,4 项） | PR #1 |
| PR #3 | 任务 3.2.1 MathBlock + 3.2.2 MermaidBlock + 3.2.8 WebView 预热 + 3.2.9 渲染缓存 + 3.2.10 语法高亮（WebView 相关,5 项） | PR #2 |

**v1.2 修订理由**：
- MathBlock / MermaidBlock 依赖 WebViewPool（§3.2 / §3.3 明确声明）
- WebViewPool 是 §3.2.8 的产物,原 PR #3 内容
- 若 MathBlock / MermaidBlock 在 PR #2,则 PR #2 依赖 PR #3 → 倒置依赖错误
- 修订后依赖树正确：`WebViewPool → MathBlock → MermaidBlock`（PR #3 内部顺序）

### 8.2 分支命名

- `feat/phase3.2-block-runtime-base`（PR #1）
- `feat/phase3.2-block-types`（PR #2）
- `feat/phase3.2-perf-highlight`（PR #3）

---

## 9. Human Owner 决策事项（v1.1 已全部决策）

1. **§3.0 方案 A vs 方案 B**：BaseBlockState.buildRenderContent 死代码处理方案
   - **决策**：✅ 方案 A（基类统一调度）— Human Owner 审批 2026-07-21
   - 实施要点：`BaseBlockState.build()` 按 `currentMode` 分发到 `buildRenderContent` / `buildEditField`,子类只实现 `buildRenderContent` + 提供 `editStyle`,不再重写 `build()`
   - 影响：需重构现有 3 个 Block（paragraph / heading / code）

2. **§3.11 任务 3.2.10 选项 A vs B**：代码块语法高亮方案
   - **决策**：✅ 选项 A（`flutter_highlight` 纯 Dart）— Human Owner 审批 2026-07-21
   - 理由：性能更好,避免 WebView 滥用,不与 MathBlock/MermaidBlock 共享 pool

3. **新增依赖审批**：`flutter_highlight`
   - **决策**：✅ 批准加入 `pubspec.yaml` — Human Owner 审批 2026-07-21
   - 实施要点：用 `dependency_overrides` 锁定版本（若与 `flutter_inappwebview` 全家桶冲突）

4. **§8 PR 策略**
   - **决策**：✅ 分 3 个 PR — Human Owner 审批 2026-07-21
   - PR #1: §3.0 + §3.2.7 目录重组（`feat/phase3.2-block-runtime-base`）
   - PR #2: §3.2.1-3.2.6（6 个新 Block）（`feat/phase3.2-block-types`）
   - PR #3: §3.2.8-3.2.10（性能 + 高亮）（`feat/phase3.2-perf-highlight`）

5. **任务优先级**
   - **决策**：✅ 顺序执行（1→10）— Human Owner 审批 2026-07-21
   - 理由：简单清晰,避免并行引入冲突

---

**本文件由 AI Agent 起草,版本 v1.1（Human Owner 已审批 §9 决策事项）,生效日期 2026-07-21。**
**已进入执行阶段。**
