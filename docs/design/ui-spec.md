# FormulaFix Editor Shell — UI Design Reference

> **版本**：v1.0
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
- [UI_SPEC.md](../UI_SPEC.md)（顶层）：**产品视觉设计 source of truth**，覆盖 9 个屏幕（Home / Editor / Reader / Formula Sheet / Export / Files / Profile），对应 `docs/assets/ui-prototype/pages/*.html` 高保真原型
- 本文件（design/ui-spec.md）：**Phase 3.0+ 工程实现参考**，仅覆盖 EditorShell + 3 种 Block + chrome 组件，对应 `lib/presentation/` 代码实现

**已知视觉规范冲突**（待 Human Owner 决策，详见 [UI_SPEC.md 头部冲突表](../UI_SPEC.md#已知视觉规范冲突待-human-owner-决策)）：
- 正文字号：UI_SPEC.md 用 15px serif / 1.85，本文件用 16sp sans-serif / 1.5
- H1 字号：UI_SPEC.md 用 26px，本文件用 28sp
- 编辑器背景：UI_SPEC.md 用 `#FDFDFB` immersive paper，本文件依赖 Material Theme
- 顶部栏高度：UI_SPEC.md 用 48px Floating Top Bar，本文件用 56dp AppBar

冲突未解决前，Phase 3.0 代码以本文件为准（因为已落地为 [EditorTokens](../../flutter_app/lib/presentation/themes/editor_tokens.dart)）。

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
| Notion | Block-based 编辑模型（块作为第一公民） |

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

#### Inline 元素样式

| Inline 类型 | Render 视觉 | Edit source |
|------------|------------|-------------|
| TextElement | 普通文本 | 普通文本 |
| BoldElement | **粗体**（FontWeight.bold） | `**text**` |
| ItalicElement | *斜体*（FontStyle.italic） | `*text*` |
| StrikethroughElement | ~~删除线~~（TextDecoration.lineThrough） | `~~text~~` |
| InlineCodeElement | `monospace`（fontFamily: monospace） | `` `code` `` |
| FormulaElement | LaTeX 渲染（Phase 3.2+ 接入 WebView） | `$latex$` |
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

## 7. Phase 3.1+ 扩展点

Phase 3.0 建立的 EditorShell 为后续阶段提供以下插槽：

| Phase | 任务 | 扩展点 | 不破坏的契约 |
|-------|------|--------|-------------|
| 3.1 | 移除 previewModeProvider | EditorPage 路由切换 | EditorShell 布局不变 |
| 3.2 | 实现 6 种剩余 BlockType | BlockRenderer 新增 case | exhaustive switch 守门 |
| 3.3 | 公式渲染（MathJax / KaTeX） | FormulaBlock 新增 | BlockViewState 不变 |
| 3.4 | 双态切换动画 | ParagraphBlock 内部 | EditorCoordinator API 不变 |
| 3.5 | 图片管理 | ImageElement 渲染 | AST 不污染 |
| 3.6 | 快捷键 | EditorCommand 新增 | CommandHandler 路径不变 |
| 3.7 | TOC 面板 | SidePanelHost 显示 | EditorShell 布局不变 |
| 3.8 | 文件树面板 | SidePanelHost 显示 | EditorShell 布局不变 |
| 3.9 | 主题切换 | EditorTokens 升级为 ThemeExtension | 所有 token 引用不变 |
| 3.10 | 字号缩放 | EditorTokens 新增 scale 参数 | 所有 token 引用不变 |
| 3.11 | 焦点模式 | EditorAppBar 隐藏 + SidePanel 隐藏 | EditorShell 布局不变 |
| 3.12 | 导出集成 | EditorAppBar action | EditorCoordinator 不变 |

---

## 8. 验证清单

Phase 3.0 完成时，本文件应满足以下验证：

- [x] 所有颜色 / 间距 / 字号 magic number 都在 [EditorTokens](../../flutter_app/lib/presentation/themes/editor_tokens.dart) 中定义
- [x] ParagraphBlock / HeadingBlock / CodeBlock 视觉实现与本文件规范一致
- [x] EditorAppBar / EditorStatusBar 视觉实现与本文件规范一致
- [x] 双态切换（render ↔ edit）流程符合 §5.2 描述
- [x] 依赖方向符合 §6 描述（守门测试全 PASS）
- [x] Phase 3.1+ 扩展点已在代码中预留（SidePanelHost 占位、EditorAppBar actions 占位）

---

**本文件由 AI Agent 起草，版本 v1.0，生效日期 2026-07-21。**
