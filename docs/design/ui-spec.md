# FormulaFix Editor Shell — UI Design Reference

> **版本**：v1.4（同步 Phase 3.3 Task Contract v1.4 R4 PR 拆分 + 优先级统计 6P0+3P1）
> **起草日期**：2026-07-21
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Phase 3.0 Reference（落地 [Phase 3.0 Task Contract §3.5](../contracts/phase3.0-task-contract.md)）
> **关联文档**：
> - [ADR-0009 UI Architecture Design](../ADR/0009-ui-architecture-design.md)（架构决策）
> - [UI-ARCHITECTURE.md](../UI-ARCHITECTURE.md)（心智模型 + 交互规则）
> - [lib/presentation/themes/editor_tokens.dart](../../flutter_app/lib/presentation/themes/editor_tokens.dart)（token 实现）

---

## 0. 文档定位

本文件是 **Phase 3.0 Editor Shell 的 UI 设计参考**，回答"用什么颜色 / 间距 / 字号 / 布局来渲染 Phase 3.0 的 EditorShell 与 3 种 Block（paragraph / heading / code）"。

**与 [docs/UI_SPEC.md](../UI_SPEC.md) 的关系**：
- [UI_SPEC.md](../UI_SPEC.md)（顶层）：**产品视觉设计 source of truth**，覆盖 14 个屏幕（含 5 张 Typora 化对比页），对应 `docs/assets/ui-prototype/pages/*.html` 高保真原型
- 本文件（design/ui-spec.md）：**Phase 3.0+ 工程实现参考**，仅覆盖 EditorShell + 3 种 Block + chrome 组件，对应 `lib/presentation/` 代码实现

**已知视觉规范冲突**（待 Human Owner 决策，详见 [UI_SPEC.md 头部冲突表](../UI_SPEC.md#已知视觉规范冲突待-human-owner-决策)）：
- 正文字号：UI_SPEC.md 用 15px serif / 1.85，本文件用 16sp sans-serif / 1.5
- H1 字号：UI_SPEC.md 用 26px，本文件用 28sp
- 编辑器背景：UI_SPEC.md 用 `#FDFDFB` immersive paper，本文件依赖 Material Theme
- 顶部栏高度：UI_SPEC.md 用 48px Floating Top Bar，本文件用 56dp AppBar

冲突未解决前，Phase 3.0 代码以本文件为准（因为已落地为 [EditorTokens](../../flutter_app/lib/presentation/themes/editor_tokens.dart)）。

**Phase 3.1 Typora 化新增冲突**（待 Phase 3.1 实现时统一）：
- Edit 态视觉：本文件 §3.1/3.2/3.3 规定 edit 态有左侧蓝色竖线 + 淡色背景，Typora 化原则要求 edit/render 视觉无差异
- 公式渲染：本文件 §3.1 FormulaElement 原未规定卡片背景，Typora 化要求纯 serif italic 无卡片
- Blockquote：本文件原未规定，Typora 化要求左侧 3dp 灰色竖线 + serif 正文

Phase 3.1 实现时，以 [UI_SPEC.md](../UI_SPEC.md) Typora 化对比页为准，本文件相应条款已标注为"Phase 3.1 演进方向"。

**不是**：
- ❌ 完整设计系统（Phase 3.9+ 主题切换时再补）
- ❌ Phase 3.1+ 的功能交互设计（沉浸模式 / 快捷键 / TOC 等）
- ❌ Home / Viewer 等非编辑器页面（见 [UI_SPEC.md](../UI_SPEC.md)）

**是**：
- ✅ Phase 3.0 落地代码的"设计锚点"：所有 magic number 都应有本文件的依据
- ✅ Phase 3.1+ UI 实现的"复用基础"：颜色 / 字号 / 间距 token 不应在 Widget 中硬编码

---

## 1. 设计原则

### 1.1 三条铁律

1. **Token 先行**：所有颜色 / 间距 / 字号必须使用 [EditorTokens](../../flutter_app/lib/presentation/themes/editor_tokens.dart)，不允许硬编码 magic number
2. **双态分离**：每个 Block 有 render 态（最终样式）和 edit 态（Markdown source），视觉差异通过 token 切换
3. **AST 零污染**：UI 视觉状态（focus / hover / selection）由 `BlockViewState` 承载，不污染 `DocumentElement`

### 1.2 设计参考来源

| 来源 | 借鉴点 |
|------|--------|
| Material Design 3 | type scale（headline / body / caption）、spacing grid（4dp baseline） |
| Apple HIG | 字号梯度（28/24/22/20/18/16）、圆角（4dp chip / block） |
| Typora | 双态切换体验（render ↔ edit 无缝过渡） |
| VS Code | chrome / workspace 分离（AppBar / Editor / StatusBar 三层） |
| Typora（v2.0 确立） | Document-first 体验（用户看到的是 Document 而不是 Block；块是工程抽象，不暴露给用户） |

---

## 2. 布局规范

### 2.1 EditorShell 整体布局

```
┌─────────────────────────────────────────────────┐
│ EditorAppBar（高度 = kToolbarHeight = 56dp）    │
│ ┌─────────────────────────────────────────────┐ │
│ │ ← 标题（Phase 3.0 Demo）  •（修改标记）  ⋮ │ │
│ └─────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────┤
│ Workspace（剩余高度）                          │
│ ┌──────┬──────────────────────────────────────┐ │
│ │ Side │  EditorViewport                     │ │
│ │ Panel│  ┌──────────────────────────────┐  │ │
│ │ (占位│  │ BlockRenderer               │  │ │
│ │ 不显 │  │  ┌─ ParagraphBlock ──────┐ │  │ │
│ │ 示)  │  │  │ Hello, Block Editor!  │ │  │ │
│ │      │  │  └────────────────────────┘ │  │ │
│ │      │  │  ┌─ HeadingBlock ─────────┐ │  │ │
│ │      │  │  │ # 标题一（render）    │ │  │ │
│ │      │  │  └────────────────────────┘ │  │ │
│ │      │  │  ┌─ CodeBlock ────────────┐ │  │ │
│ │      │  │  │ dart  void main() {…} │ │  │ │
│ │      │  │  └────────────────────────┘ │  │ │
│ │      │  └──────────────────────────────┘  │ │
│ └──────┴──────────────────────────────────────┘ │
├─────────────────────────────────────────────────┤
│ EditorStatusBar（高度 = 24dp）                  │
│ ┌─────────────────────────────────────────────┐ │
│ │ 块数: 3  |  字数: 42  |  Undo: ✓ Redo: ✗ │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### 2.2 尺寸规范

| 区域 | 高度 | 内边距 | 引用 token |
|------|------|--------|-----------|
| EditorAppBar | `kToolbarHeight` (56dp) | horizontal 16dp | `EditorTokens.appBarHeight` |
| SidePanel | 0dp（Phase 3.0 占位不显示） | — | `SidePanelHost.shouldShow() == false` |
| EditorViewport | flex（剩余高度） | all 16dp | `EditorTokens.viewportPadding` |
| EditorStatusBar | 24dp | horizontal 12dp | `EditorTokens.statusBarHeight` |
| Block 间距 | 8dp（垂直块间） | — | `EditorTokens.blockSpacing` |
| Block 内边距 | horizontal 12dp / vertical 6dp | — | `EditorTokens.blockPaddingHorizontal/Vertical` |

### 2.3 颜色规范（Phase 3.0 占位）

| 用途 | 颜色值 | 引用 token |
|------|--------|-----------|
| 主文本（light） | `#1A1A1A` | `EditorTokens.textPrimary` |
| 次要文本（标注 / 占位） | `#6B6B6B` | `EditorTokens.textSecondary` |
| 编辑态边框（聚焦） | `#2196F3`（Material Blue） | `EditorTokens.borderFocused` |
| 渲染态边框（hover / 默认） | `#E0E0E0` | `EditorTokens.borderDefault` |
| 代码块背景 | `#F5F5F5` | `EditorTokens.codeBackground` |
| 代码 language chip | `#E0E0E0` | `EditorTokens.codeLanguageChip` |
| 公式（行内/块级）render | serif italic，无卡片背景 | Typora 化原则（Phase 3.1 演进） |
| Blockquote 引用 | 左侧 3dp `#C0C0C0` 竖线 + serif 正文 | Typora 化原则（Phase 3.1 演进） |

**Phase 3.9+ 演进**：以上颜色将升级为 `light` / `dark` / `sepia` 三主题，通过 `ThemeExtension<EditorTokens>` 注入。

---

## 3. Block 视觉规范

### 3.1 ParagraphBlock（段落块）

#### Render 态

```
┌────────────────────────────────────────────┐
│ Hello, Block Editor!                        │  ← 16sp, textPrimary
│ This is a paragraph with **bold** text.    │
└────────────────────────────────────────────┘
```

- **字号**：`paragraphFontSize` = 16.0
- **行高**：1.5 × fontSize = 24.0
- **颜色**：`textPrimary`
- **内边距**：horizontal 12dp / vertical 6dp
- **背景**：透明
- **边框**：无

#### Edit 态

```
┌────────────────────────────────────────────┐
│ Hello, Block Editor!|                       │  ← 16sp, 普通字号
│                                            │     光标 |
└────────────────────────────────────────────┘
   ↑
   左侧蓝色竖线（borderFocused, 2dp）
```

- **字号**：`paragraphFontSize` = 16.0（与 render 态一致）
- **颜色**：`textPrimary`
- **内边距**：horizontal 12dp / vertical 6dp
- **边框**：左侧 2dp 蓝色竖线（`borderFocused`）
- **背景**：淡灰色（`codeBackground`，待 Phase 3.1 接入主题后调整）

> **Phase 3.1 Typora 化演进**：移除左侧蓝色竖线与淡色背景，edit 态与 render 态视觉无差异，仅靠光标位置区分（Document-first，不暴露 Block 感）。

#### Inline 元素样式

| Inline 类型 | Render 视觉 | Edit source |
|------------|------------|-------------|
| TextElement | 普通文本 | 普通文本 |
| BoldElement | **粗体**（FontWeight.bold） | `**text**` |
| ItalicElement | *斜体*（FontStyle.italic） | `*text*` |
| StrikethroughElement | ~~删除线~~（TextDecoration.lineThrough） | `~~text~~` |
| InlineCodeElement | `monospace`（fontFamily: monospace） | `` `code` `` |
| FormulaElement | LaTeX 渲染（Phase 3.2+ 接入 WebView）；**Typora 化：纯 serif italic，无卡片背景** | `$latex$` |
| LinkElement | 蓝色文本 + 下划线 | `[text](url)` |
| ImageElement | 占位 + alt 文本（Phase 3.5+ 接入图片管理） | `![alt](url)` |

### 3.2 HeadingBlock（标题块）

#### Render 态（6 级标题字号梯度）

| Level | 字号 | 字重 | 行高 | 示例 |
|-------|------|------|------|------|
| 1 | 28sp | bold (700) | 1.3 | `# 一级标题` |
| 2 | 24sp | bold (700) | 1.3 | `## 二级标题` |
| 3 | 22sp | bold (700) | 1.3 | `### 三级标题` |
| 4 | 20sp | w600 (600) | 1.3 | `#### 四级标题` |
| 5 | 18sp | w600 (600) | 1.3 | `##### 五级标题` |
| 6 | 16sp | w600 (600) + italic | 1.3 | `###### 六级标题` |

引用：`EditorTokens.headingFontSizes[level - 1]`

#### Edit 态

- 与 render 态字号一致（不放大不缩小）
- 左侧 2dp 蓝色竖线（`borderFocused`）
- 行首显示 `#` 前缀（用户编辑时可见）

> **Phase 3.1 Typora 化演进**：移除左侧蓝色竖线，edit 态与 render 态视觉无差异，仅行首 `#` 前缀提示当前在 edit 态。

### 3.3 CodeBlock（代码块）

#### Render 态

```
┌──────────────────────────────────────────────┐
│ [dart]                                       │  ← language chip
│ void main() {                                │  ← 14sp monospace
│   debugPrint("hi");                          │     codeBackground
│ }                                            │
└──────────────────────────────────────────────┘
   ↑
   圆角 4dp，背景 #F5F5F5
```

- **字号**：`codeFontSize` = 14.0
- **字体**：monospace
- **颜色**：`textPrimary`
- **背景**：`codeBackground` (#F5F5F5)
- **圆角**：`blockRadius` = 4dp
- **内边距**：horizontal 12dp / vertical 6dp
- **Language chip**：
  - 灰色背景（`codeLanguageChip`）
  - 字号 11sp（与状态栏一致）
  - 圆角 `chipRadius` = 3dp
  - 显示在代码块右上角

#### Edit 态

- 与 render 态视觉一致（字号 / 颜色 / 背景不变）
- 左侧 2dp 蓝色竖线（`borderFocused`）
- 行首显示 ```` ```dart ```` fence（用户编辑时可见）

> **Phase 3.1 Typora 化说明**：代码块保留卡片感（背景 + chip + 圆角）是 Typora 本身的做法，不算 Block 感泄漏；但 edit 态左侧蓝色竖线应移除，仅靠 fence 标记区分。

---

## 4. Chrome 组件规范

### 4.1 EditorAppBar

**职责**：
- 显示当前文档标题（Phase 3.0 用种子文档名 "Phase 3.0 Demo"）
- 显示修改状态指示器（Phase 3.0 占位：恒为未修改）
- 提供返回按钮（返回到文件管理页）
- 提供更多操作菜单（Phase 3.0 占位）

**视觉**：

```
┌─────────────────────────────────────────────────┐
│ [←]  Phase 3.0 Demo                     [⋮]    │
└─────────────────────────────────────────────────┘
```

- **高度**：`kToolbarHeight` (56dp)
- **背景**：Material 默认（依赖 Theme）
- **标题**：默认字号（Material `titleTextStyle`）
- **修改标记**：标题右侧显示 "•"（字号 20sp），仅在 `isModified == true` 时显示
- **返回按钮**：`Icons.arrow_back`，tooltip "返回"
- **更多按钮**：`Icons.more_vert`，tooltip "更多（Phase 3.2+）"，Phase 3.0 期间 `onPressed: null`

**Phase 3.1+ 演进**：
- 修改状态接入 dirty tracking
- 更多菜单接入字号缩放 / TOC 切换 / 主题切换

### 4.2 EditorStatusBar

**职责**：
- 显示当前文档的块数 / 字数
- 显示 Undo / Redo 可用状态
- 显示当前 focused BlockId（Phase 3.1+）

**视觉**：

```
┌─────────────────────────────────────────────────┐
│ 块数: 3  |  字数: 42  |  Undo: ✓  Redo: ✗     │
└─────────────────────────────────────────────────┘
```

- **高度**：`statusBarHeight` = 24dp
- **字号**：`statusBarFontSize` = 11sp
- **颜色**：`textSecondary`
- **背景**：依赖 Theme（默认 surfaceColor）
- **分隔符**：` | `（前后各一空格）

**Phase 3.1+ 演进**：
- 显示当前 focused BlockId
- 显示当前光标位置（line:column）
- 显示 IME composing 状态

---

## 5. 双态切换规范

### 5.1 切换触发

| 操作 | 当前态 | 目标态 | 行为 |
|------|--------|--------|------|
| 点击块内 | render | edit | 光标定位到点击位置 |
| 点击块外 | edit | render | commit 修改 + 失焦 |
| 失焦 | edit | render | commit 修改 + 失焦 |
| Tab（块末） | edit | edit（下一块） | focus 移到下一块开头 |
| Shift+Tab（块首） | edit | edit（上一块） | focus 移到上一块末尾 |
| Esc | edit | render | commit 修改 + 失焦（Phase 3.1+ 可能改为撤销） |

### 5.2 commit 流程

```
用户在 edit 态修改 TextEditingController
     │
     ↓
_onFocusChange 触发（或 tap outside）
     │
     ↓
_commitSource(source)
     │
     ↓
EditorCoordinator.handler.handle(
  EditTextCommand(blockId, newSource)
)
     │
     ↓
CommandHandler → TransactionBuilder → BlockOperation
     │
     ↓
AST 更新 + EditorCoordinator.notifyListeners()
     │
     ↓
AnimatedBuilder 重建 EditorShell → BlockRenderer
     │
     ↓
新 AST 渲染为 render 态
```

### 5.3 视觉过渡

Phase 3.0 期间**不做**动画过渡（render ↔ edit 即时切换）。Phase 3.4+ 考虑加入：
- 200ms fade 过渡
- 光标位置保持（edit → render 时记住光标位置）

---

## 6. 依赖方向（Hard Rule 8）

```
editor/  ─────────────────────────────────┐
   ↓                                     │
chrome/ ── (通过 EditorCoordinator) ──────┤
   ↓                                     │
blocks/ ←── EditorCoordinator 注入 ──────┘
   ↓
core/editing  (内核，UI 不直接访问 mutation)
```

**规则**：
- `blocks/` 只能 import `editor/editor_coordinator.dart`，禁止 import editor/ 下其他文件
- `blocks/` 不允许 import `panels/` / `chrome/`
- `editor/` 不允许 import `panels/`
- `chrome/` 不允许 import `blocks/` / `panels/`
- `chrome/` 通过 `EditorCoordinator` 接收数据

**守门测试**：[TC-ARCH-UI-5 ~ 7](../../flutter_app/test/architecture/ui_dependency_direction_test.dart)

---

## 7. Phase 3.1+ 扩展点（v1.2 同步 ROADMAP 阶段重新划分）

Phase 3.0 建立的 EditorShell 为后续阶段提供以下插槽。

**阶段重新划分说明**（2026-07-21 修订，详见 [ROADMAP.md §Phase 3.1+ 阶段重新划分说明](../ROADMAP.md)）：
- 原 Phase 3.2"移除预览卡片包裹，改为沉浸式全屏编辑"已被 Phase 3.1-A 提前完成（架构层沉浸式），此条不再作为独立任务
- **沉浸式概念拆分**：架构层沉浸式（已完成）vs 体验层沉浸式（Phase 3.3）
- 新阶段划分：3.1 WYSIWYG Migration（✅ 已完成） / 3.2 Block Runtime Expansion / 3.3 Immersive Experience / 3.4+ Advanced Capabilities

### Phase 3.1 — WYSIWYG Migration（✅ 已完成）

- [x] EditorPage 路由切换（`/editor` → EditorPage 默认入口，`/editor-legacy` → EditorScreen fallback）
- [x] 无 preview mode（移除 `previewModeProvider` 重复定义）
- [x] 无 PreviewContent 卡片包装（架构层沉浸式已达成）

**契约不变**：EditorShell 布局不变。

### Phase 3.2 — Block Runtime Expansion（Conditionally Complete）

> **状态**：⚠️ Conditionally Complete（2026-07-22）。8 项已交付,2 项延期至 Phase 3.5+。详见 [Phase 3.2 Verification Report](../releases/phase3.2-verification-report.md)。

| # | 任务 | 扩展点 | 不破坏的契约 | 状态 |
|---|------|--------|-------------|------|
| 3.2.1 | MathBlock（行内 + 块级公式） | BlockRenderer 新增 case | exhaustive switch 守门 | 🔻 **延期 Phase 3.5**（依赖 FormulaSvgService 成熟） |
| 3.2.2 | MermaidBlock | BlockRenderer 新增 case | exhaustive switch 守门 | ✅ 已交付（PR #3） |
| 3.2.3 | QuoteBlock | BlockRenderer 新增 case | exhaustive switch 守门 | ✅ 已交付（PR #2） |
| 3.2.4 | TableBlock（基本渲染,可视化编辑留 Phase 3.3） | BlockRenderer 新增 case | exhaustive switch 守门 | ✅ 已交付（PR #2） |
| 3.2.5 | Image Inline Rendering Enhancement | ParagraphBlock inline renderer | 不进入 BlockRenderer（违反 TC-ARCH-UI-8） | ✅ 已交付（PR #2） |
| 3.2.6 | Link Inline Rendering Enhancement | ParagraphBlock inline renderer | 不进入 BlockRenderer（违反 TC-ARCH-UI-8） | ✅ 已交付（PR #2） |
| 3.2.7 | `blocks/<type>/` 目录结构 + `blocks/shared/` | 目录重组 | 依赖方向守门（Hard Rule 8） | 🟡 **部分**（目录 ✅,shared/ 3 个组件延期 Phase 3.5+） |
| 3.2.8 | WebView 预热机制 | 后台预热通道 | EditorCoordinator API 不变 | ✅ 已交付（退化：复用 MermaidService.awaitPageLoaded） |
| 3.2.9 | Mermaid 渲染缓存 | 缓存层 | AST 不污染 | ✅ 已交付（复用 MermaidService LRU 256 entries） |
| 3.2.10 | 代码块语法高亮 | CodeBlock 内部 | BlockViewState 不变 | ✅ 已交付（flutter_highlight 0.7.0 + githubTheme） |

> **v1.2 修订**（2026-07-22）：任务 3.2.5 / 3.2.6 扩展点从
> "BlockRenderer 新增 case" 改为 "ParagraphBlock inline renderer"。
> 原描述违反 AST 事实：[ImageElement](../../flutter_app/lib/data/models/document.dart)
> 和 [LinkElement](../../flutter_app/lib/data/models/document.dart) 都是
> `extends InlineElement`,不进入 BlockRenderer 的 exhaustive switch。
> 详见 [Phase 3.2 Task Contract §3.6 / §3.7](../contracts/phase3.2-task-contract.md)。

> **v1.3 修订**（2026-07-22 Closure）：MathBlock（§3.2.1）正式延期至 Phase 3.5
> （依赖 FormulaSvgService 成熟 + AST 表达方式评审）。
> blocks/shared/ 3 个共享组件（block_toolbar / block_selection / block_drag_handle）
> 正式延期至 Phase 3.5+（实际验证发现非 Phase 3.2 核心能力,避免技术债）。
> 详见 [Phase 3.2 Verification Report §3 延期决议](../releases/phase3.2-verification-report.md)。

### Phase 3.3 — Mobile Markdown Editing Experience（移动端 Markdown 输入体验）

> **v1.4 修订（2026-07-22,架构评审 R3,9.0/10 评分后 Accepted）**：三点修改后进入 Accepted：
> 1. 字号缩放（§3.3.2）P1 确认（v1.3 已降级,R3 确认）
> 2. **§3.3.9 选区格式化菜单整体延期至 Phase 3.4 §3.4.10**（v1.4 新增,选区包裹能力作为 §3.3.7 工具栏内置模式保留）
> 3. **新增 §3.3.10 Markdown 模板插入菜单（P1）**：释放 Phase 3.2 TableBlock/MermaidBlock 成果
>
> **v1.4 R4 PR 拆分调整（2026-07-22,Human Owner）**：优先级统计修正为 **9 个任务,6 项 P0 + 3 项 P1**;§3.3.10 模板插入菜单从 PR #4 移至 PR #2 扩展（架构耦合：Toolbar → Template Menu,模板菜单与工具栏同 PR 交付）;PR #4 仅保留 §3.3.2 + §3.3.3（字号缩放 + 焦点模式,与工具栏解耦,延期不影响模板菜单）。详见 [Phase 3.3 Task Contract §8.1](../contracts/phase3.3-task-contract.md#81-分-pr-建议4-个-prv14-调整--r4-pr-拆分)。

| # | 任务 | 优先级 | 扩展点 | 不破坏的契约 |
|---|------|--------|--------|-------------|
| 3.3.1 | AppBar 显示文档标题 + 修改状态 | P0 | EditorAppBar 内部 + CoordinatorState.isDirty | EditorShell 布局不变 |
| 3.3.2 | 字号缩放（双指缩放 + 按钮 + 重置） | **P1**（v1.3 降级,R3 确认） | MediaQuery.textScaler + EditorViewport GestureDetector | EditorTokens 常量不变（向后兼容） |
| 3.3.3 | 焦点模式（隐藏 chrome） | P1 | EditorShell → StatefulWidget | EditorShell 对外 API 不变 |
| 3.3.4 | 实时字数统计 | P0 | EditorStatusBar 内部 + EditorCoordinator.wordCount | EditorShell 布局不变 |
| 3.3.5 | 撤销 / 重做按钮接入 UI | P0 | EditorAppBar action | EditorCoordinator API 不变 |
| 3.3.6 | 自动配对（**仅 `(`/`[`/`{`/`` ` ``,v1.3 缩减范围**） | P0 | BaseBlockState onChanged 拦截 | CommandHandler 路径不变 |
| 3.3.7 | **Markdown 工具栏（核心任务）**：11 按钮 + 选区包裹模式（内置,替代独立 §3.3.9） | **P0 核心** | 新增 chrome/markdown_toolbar.dart,底部固定栏 | EditorShell 三层结构不变（仅扩展 BottomBar slot） |
| 3.3.8 | 自动续列表 / 引用 / 代码块 | P0 | BaseBlockState onSubmitted 回调 | CommandHandler 路径不变 |
| 3.3.10 | **Markdown 模板插入菜单（v1.4 新增 P1）**：`+` 按钮,表格/Mermaid/代码块/任务列表模板 | P1 | chrome/markdown_toolbar.dart 扩展（同 §3.3.7） | CommandHandler 路径不变 |

**CodeBlock 例外**（v1.3 Hard Rule）：CodeBlock 不应用 3.3.6 / 3.3.8 / 3.3.10（代码内容原样保留,不被 Markdown 语法干扰）。CodeBlock 仅支持 3.3.7 的「代码块」按钮插入语法。

### 已延期至 Phase 3.4 Desktop Enhancement（v1.4 调整）

| 原任务 | 去向 | 理由 |
|--------|------|------|
| 3.3.7 快捷键支持（v1.0） | Phase 3.4 §3.4.5 | 手机端无 Ctrl 键,ROI 极低 |
| 3.3.3 打字机模式（v1.0） | Phase 3.4 §3.4.6 | 手机端软键盘已占半屏 |
| 3.3.9 选区格式化菜单（v1.2,v1.4 整体延期） | Phase 3.4 §3.4.10 | Flutter Overlay + TextSelection + 光标坐标 + 滚动同步复杂度高,Phase 3.3 风险敏感。选区包裹能力已作为 §3.3.7 工具栏内置模式保留 |

### Phase 3.4+ — Advanced Capabilities

| # | 任务 | 扩展点 | 不破坏的契约 |
|---|------|--------|-------------|
| 3.4.1 | TOC 面板 | SidePanelHost 显示 | EditorShell 布局不变 |
| 3.4.2 | 文件树面板 | SidePanelHost 显示 | EditorShell 布局不变 |
| 3.4.3 | 主题切换 | EditorTokens 升级为 ThemeExtension | 所有 token 引用不变 |
| 3.4.4 | 导出集成 | EditorAppBar action | EditorCoordinator 不变 |
| 3.4.5 | 快捷键支持（Phase 3.3 v1.0 延期项） | Shortcuts + Actions widget | CommandHandler 路径不变 |
| 3.4.6 | 打字机模式（Phase 3.3 v1.0 延期项） | EditorViewport ScrollController | EditorShell 布局不变 |
| 3.4.7 | 自动保存 | EditorCoordinator 定时器 | CoordinatorState 不变 |
| 3.4.8 | 页面宽度控制 | ConstrainedBox(maxWidth: 720) | EditorViewport 布局不变 |
| 3.4.9 | Markdown 图片插入 | file_picker + ImageElement | BlockRenderer 不变 |
| 3.4.10 | 选区格式化菜单（Overlay 浮动菜单,Phase 3.3 v1.4 延期项） | Overlay + TextSelection 定位 | BlockViewState 不变 |

---

## 8. 验证清单

Phase 3.0 完成时，本文件应满足以下验证：

- [x] 所有颜色 / 间距 / 字号 magic number 都在 [EditorTokens](../../flutter_app/lib/presentation/themes/editor_tokens.dart) 中定义
- [x] ParagraphBlock / HeadingBlock / CodeBlock 视觉实现与本文件规范一致
- [x] EditorAppBar / EditorStatusBar 视觉实现与本文件规范一致
- [x] 双态切换（render ↔ edit）流程符合 §5.2 描述
- [x] 依赖方向符合 §6 描述（守门测试全 PASS）
- [x] Phase 3.1+ 扩展点已在代码中预留（SidePanelHost 占位、EditorAppBar actions 占位）

### Phase 3.3 验证清单（R4 新增,待 PR #5 Closure 时勾选）

> **说明**：以下验证点在 Phase 3.3 实施过程中逐步勾选,Phase 3.3 Closure PR（PR #5）统一审核。

- [ ] §3.3.1 AppBar 显示文档标题 + 修改状态 `•`
- [ ] §3.3.2 字号缩放（双指 + 按钮 + 重置）,Text Widget 生效（TextSpan 不缩放是已知边界,见 [Task Contract §9.1](../contracts/phase3.3-task-contract.md#91-editortokens-字号缩放方案)）
- [ ] §3.3.3 焦点模式（隐藏 chrome,双击退出）
- [ ] §3.3.4 状态栏字数统计
- [ ] §3.3.5 Undo/Redo 按钮可点击,功能正常
- [ ] §3.3.6 自动配对 4 种配对符（`(`/`[`/`{`/`` ` ``）,经 PairInsertCommand 路径
- [ ] §3.3.7 Markdown 工具栏 A+B 混合（位置 A + 内部布局 B 横向滚动）
- [ ] §3.3.7 选区包裹模式（选中文字后工具栏切换为包裹模式）
- [ ] §3.3.8 自动续列表 5 种前缀 + 退出规则 + CodeBlock 例外 + 平级单层范围（嵌套留 Phase 3.4）
- [ ] §3.3.10 模板插入菜单 8 种模板（表格/Mermaid/代码块/任务列表/引用/分隔线/图片/链接）
- [ ] **Toolbar 状态来源**：只读 CoordinatorState,不直接访问 TextEditingController（[ADR-0011 §5](../ADR/0011-phase3.3-architecture-decisions.md)）

---

**本文件由 AI Agent 起草，版本 v1.4（Phase 3.3 Task Contract v1.4 Accepted：6P0+3P1 优先级统计修正 + R4 PR 拆分调整 Toolbar → Template Menu），生效日期 2026-07-22。**
