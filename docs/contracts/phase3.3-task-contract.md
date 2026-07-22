# Phase 3.3 Task Contract: Mobile Markdown Editing Experience

> **版本**：v1.4（架构评审 R3 + R4 细化:字号缩放 P1 + §3.3.9 选区菜单整体延期 + 新增 §3.3.10 模板插入菜单 + §9.1-9.5 架构决策细化 + R4 PR 拆分 + 优先级统计修正 6P0+3P1）
> **起草日期**：2026-07-22
> **v1.1 修订日期**：2026-07-22（架构评审 R1：快捷键 + 打字机模式延期至 Phase 4）
> **v1.2 修订日期**：2026-07-22（产品方向调整：从「桌面化快捷键」转为「移动端 Markdown 输入体验」,新增 3 个高价值任务）
> **v1.3 修订日期**：2026-07-22（架构评审 R2：① Toolbar 提升为核心任务 ② 选区菜单 Overlay 降级为可选项 ③ 自动配对缩减范围）
> **v1.4 R3 修订日期**：2026-07-22（架构评审 R3 9.0/10：① 字号缩放 P1 确认（v1.3 已落实）② §3.3.9 选区菜单整体延期 Phase 3.4 ③ 新增 §3.3.10 Markdown 模板插入菜单 P1,释放 Phase 3.2 TableBlock/MermaidBlock 成果）
> **v1.4 R4 细化日期**：2026-07-22（架构决策细化 9-10/10 评分后 Accepted：① 优先级统计修正 6P0+3P1 ② PR #4 拆分（模板菜单移至 PR #2,Toolbar → Template Menu 架构耦合）③ 验证计划同步（删 selection_format_test.dart,新增 template_menu_test.dart）④ 自动配对测试同步 4 种 ⑤ §9.1 TextSpan 缩放边界 ⑥ §9.2 PairInsertCommand 路径 ⑦ §9.3 A+B 混合 Toolbar ⑧ §9.4 Dirty 文档状态归属 ⑨ 新增 §9.5 Toolbar 状态来源）
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Accepted（v1.4,架构评审 R3 9.0/10 + R4 架构决策细化 9-10/10 评分后 Accepted,可启动 PR #1 实施）
> **前置阶段**：Phase 3.2 Block Runtime Expansion（✅ Conditionally Complete,Closure PR #56 已合并）
> **后继阶段**：Phase 3.4+ Advanced Capabilities（TOC / 文件树 / 主题 / 导出 / 选区菜单）
>
> **关联文档**：
> - [ROADMAP.md Phase 3.3](../ROADMAP.md)
> - [design/ui-spec.md §7 Phase 3.3](../design/ui-spec.md)
> - [ADR-0009 UI Architecture Design](../ADR/0009-ui-architecture-design.md)
> - [Phase 3.2 Task Contract v1.3](./phase3.2-task-contract.md)
> - [Phase 3.2 Verification Report](../releases/phase3.2-verification-report.md)

---

## 0. 任务缘起

Phase 3.1-A 完成了**架构层沉浸式**（移除 preview/editor 双模式,EditorPage 成为默认入口）。Phase 3.2 建立了完整的 Block Runtime（6 种 BlockType + 2 种 inline rendering）。但**移动端 Markdown 输入体验**仍完全空白：

- EditorAppBar 标题恒为 `'Phase 3.0 Demo'`,不显示文档标题,无修改状态指示
- EditorStatusBar 只显示调试信息（块数 / 聚焦 ID）,无字数统计
- 无撤销 / 重做按钮（HistoryManager 内核已就绪,仅缺 UI 接线）
- 无字号缩放（EditorTokens 全为 `static const`,运行时不可变）
- 无自动配对（`$` / `(` / `[` / `*`）
- **无 Markdown 工具栏**（用户需手敲 `**加粗**` / `[链接](url)` 等复杂语法）
- **无自动续列表**（输入 `- item` 回车后不会自动续 `- `）
- **无选区格式化菜单**（选中文字无浮动工具栏加粗/斜体/链接）

Phase 3.3 解决上述 9 项,聚焦移动端 Markdown 输入体验。

> **v1.2 产品方向调整（2026-07-22,Human Owner）**：
>
> 原 v1.1 把 Phase 3.3 定义为 "Editor UX Foundation",聚焦基础 chrome 接线。经产品评审调整为 **"Mobile Markdown Editing Experience"**：
>
> 核心洞察：**桌面用户靠键盘快捷键,手机用户靠输入辅助**。这是两套完全不同的交互体系。
>
> | 功能 | 桌面价值 | 手机价值 | Phase 3.3 处置 |
> |------|---------|---------|----------------|
> | Ctrl+Z / Ctrl+B / Ctrl+Shift+T / F11 | 高 | 低/无 | 延期 Phase 3.4 Desktop Enhancement |
> | 自动配对（`*`→`**` / `(`→`()` / `[`→`[]`） | 高 | 高 | ✅ 保留（P0） |
> | Markdown 工具栏（B/I/H1/代码/链接按钮） | 中 | **极高** | ✅ 新增（P0） |
> | 自动续列表 / 引用 / 代码块 | 中 | **极高** | ✅ 新增（P0） |
> | 选区格式化菜单（浮动工具栏） | 中 | **极高** | ✅ 新增（P1） |
> | 打字机模式 | 中 | 低 | 延期 Phase 3.4 |
>
> 调整后 Phase 3.3 = 9 个任务（6 项 P0 + 3 项 P1）。
>
> **为什么这些任务对手机价值极高**：
> 手机上输入 `**加粗**` 需要 4 次特殊符号切换 + 光标移动。输入 `[链接](url)` 更麻烦。输入 ```` ```dart ```` 需要连续敲多个反引号。对于普通用户,Markdown 语法本身就是摩擦力。Markdown 工具栏 + 自动续列表让用户**不用知道 Markdown 语法也能写出格式化文档**,这是手机 Markdown 编辑器最能拉开体验差距的部分。
>
> **v1.3 架构评审 R2 调整（2026-07-22,Human Owner 8.5/10 评分,三点修改后 Accepted）**：
>
> 1. **Markdown 工具栏（§3.7）提升为 Phase 3.3 核心任务**：是用户真正能感知到的「主功能」而非附属功能。单独成 PR #2,作为本阶段最重要的交付。
>
> 2. **选区格式化菜单（§3.9）Overlay 方案降级为可选项**：Flutter `TextSelection` + `Overlay` + `RenderBox` 在 Android/iOS/Web 三端行为不一致,容易出现菜单漂移、键盘遮挡、选区变化失效等问题。**优先采用工具栏选区包裹方案**（Toolbar 进入「选区包裹模式」）：用户选中文字后,底部工具栏自动切换为「包裹选区」模式,点击 B/I/Link 直接 `selected → **selected**`。**80% 价值,20% 实现复杂度**。Overlay 浮动菜单作为 Phase 3.4+ 的可选增强。
>
> 3. **自动配对（§3.6）缩减范围**：禁止对 Markdown 语义字符 `*`/`$`/`#`/`-`/`>` 做无条件补全。原因：
>    - `*` 在 Markdown 是无序列表前缀,自动补 `**` 会破坏列表输入
>    - `$` 用于公式,自动补 `$$` 会影响行内公式输入流
>    - `#` 用于标题,自动补 `##` 会破坏标题语法
>    - `-` 是列表前缀
>    - `>` 是引用前缀
>    这些字符必须有 Markdown 上下文判断（如检测是否在行首、前一个字符是否为空白）才能安全补全。Phase 3.3 仅保留无歧义的 4 种配对：`(`/`[`/`{`/`` ` ``。Markdown 语义字符的智能配对留 Phase 3.4+ 带 AST 上下文判断后再做。
>
> **调整后 Phase 3.3 = 9 个任务（5 项 P0 + 4 项 P1）,核心交付聚焦 Markdown 工具栏 + 自动续列表。**
>
> **v1.4 架构评审 R3 调整（2026-07-22,Human Owner 9.0/10 评分,三点修改后进入 Accepted）**：
>
> 1. **字号缩放（§3.3.2）P1 确认**：v1.3 已将字号缩放从 P0 降级到 P1,R3 确认此调整。用户写不出 Markdown 比字体大小不满意严重得多,字号缩放非关键路径。
>
> 2. **§3.3.9 选区格式化菜单整体延期至 Phase 3.4**：v1.3 将其降级为「可选项,优先工具栏选区包裹,Overlay 留 Phase 3.4+」。R3 进一步收缩：**整体移到 Phase 3.4**（包括工具栏选区包裹模式的独立验收）。原因：Flutter Overlay + TextSelection + 光标坐标计算 + 滚动同步复杂度高,即使工具栏包裹模式也需要选区状态管理,Phase 3.3 风险敏感。**§3.3.9 从 Phase 3.3 任务表移除**,Phase 3.4 §3.4.10 接管。**选区包裹能力作为 §3.3.7 Markdown 工具栏的内置模式保留**（用户选中文字后工具栏自动切换为包裹模式,无需独立任务）。
>
> 3. **新增 §3.3.10 Markdown 模板插入菜单（P1）**：工具栏中的 `+` 按钮弹出菜单,一键插入复杂模板：表格 / Mermaid / 代码块 / 任务列表 / 引用块 / 图片 / 链接。**核心价值**：释放 Phase 3.2 已建立的 TableBlock / MermaidBlock 能力。如果用户还要自己背 ```` ```mermaid ```` 语法,Phase 3.2 的成果价值没有完全释放出来。工具栏一键插入模板,反而能把 Phase 3.2 的成果真正用起来。
>
> **调整后 Phase 3.3 = 9 个任务（6 项 P0 + 3 项 P1）,核心交付聚焦 Markdown 工具栏 + 自动续列表 + 模板插入菜单。**

---

## 1. 目标与范围

### 1.1 核心目标

完成移动端 Markdown 输入体验（Mobile Markdown Editing Experience）。聚焦手机端真正高价值的输入辅助能力：

- 基础 chrome 接线（标题 / Dirty 状态 / 字数 / Undo/Redo / 字号缩放）
- **Markdown 输入辅助核心**（自动配对 + Markdown 工具栏 + 自动续列表 + 选区格式化菜单）

**不追求**：桌面化能力（快捷键、打字机模式留 Phase 3.4 Desktop Enhancement）。

### 1.2 范围（9 个任务,6 项 P0 + 3 项 P1）

**v1.4 调整说明**：
- §3.3.2 字号缩放 P1（v1.3 已降级,R3 确认）
- §3.3.6 自动配对范围缩减（`*`/`$`/`#`/`-`/`>` 移出无条件补全）
- §3.3.7 Markdown 工具栏提升为**核心任务**（单独成 PR #2）,内置选区包裹模式（替代独立 §3.3.9）
- **§3.3.9 选区格式化菜单整体延期至 Phase 3.4**（v1.4 新增调整,从 Phase 3.3 任务表移除）
- **§3.3.10 Markdown 模板插入菜单（v1.4 新增 P1）**：释放 Phase 3.2 TableBlock/MermaidBlock 成果

| # | 任务 | 优先级 | 扩展点 | 不破坏的契约 |
|---|------|--------|--------|-------------|
| 3.3.1 | AppBar 显示文档标题 + 修改状态（`•`） | P0 | EditorAppBar 内部 + EditorCoordinator dirty tracking | EditorShell 布局不变 |
| 3.3.2 | 字号缩放（双指缩放 + 按钮 + 重置） | P1（v1.3 降级,R3 确认） | EditorTokens 改造 + EditorViewport GestureDetector | 所有 token 引用不变 |
| 3.3.3 | 焦点模式（隐藏 chrome,双击退出） | P1 | EditorShell → StatefulWidget | EditorShell 对外 API 不变 |
| 3.3.4 | 实时字数统计（底部状态栏） | P0 | EditorStatusBar 内部 + EditorCoordinator wordCount getter | EditorShell 布局不变 |
| 3.3.5 | 撤销 / 重做按钮接入 UI | P0 | EditorAppBar actions + EditorStatusBar | EditorCoordinator API 不变 |
| 3.3.6 | 自动配对（**仅 `(`/`[`/`{`/`` ` ``,v1.3 缩减范围**） | P0 | BaseBlockState buildEditField | CommandHandler 路径不变 |
| 3.3.7 | **Markdown 工具栏（核心任务）**：11 按钮 + 选区包裹模式（替代独立 §3.3.9） | **P0 核心** | 新增 `chrome/markdown_toolbar.dart` | EditorShell 布局可扩展（新增 BottomBar slot） |
| 3.3.8 | 自动续列表 / 引用 / 代码块（回车自动续行） | P0 | BaseBlockState onSubmitted 回调 | CommandHandler 路径不变 |
| 3.3.10 | **Markdown 模板插入菜单（v1.4 新增 P1）**：`+` 按钮弹出菜单,一键插入表格/Mermaid/代码块/任务列表模板 | P1 | chrome/markdown_toolbar.dart 扩展（同 §3.3.7 组件） | CommandHandler 路径不变 |

### 1.3 不在 Phase 3.3 范围内（明确边界）

- **快捷键支持**（Ctrl+Z / Ctrl+B / Ctrl+/- 等）→ **Phase 3.4 Desktop Enhancement**
- **打字机模式**（光标行居中）→ **Phase 3.4 Desktop Enhancement**
- **选区格式化菜单**（浮动工具栏 / Overlay）→ **Phase 3.4 §3.4.10**（v1.4 整体延期,选区包裹能力已作为 §3.3.7 工具栏内置模式保留）
- **主题切换**（GitHub / Night / Sepia）→ Phase 3.4+
- **TOC / 大纲面板** → Phase 3.4+
- **文件树侧滑** → Phase 3.4+
- **导出集成** → Phase 3.4+
- **MathBlock** → Phase 3.5
- **blocks/shared/ 共享组件**（BlockToolbar / BlockSelection / BlockDragHandle）→ Phase 3.5+
- **自动保存**（dirty tracking 只做状态,不做自动保存逻辑）→ Phase 3.4+
- **页面宽度控制**（max-width 720px）→ Phase 3.4+
- **Markdown 块拖拽重排序** → Phase 3.5+（依赖 BlockDragHandle）
- **Markdown 图片插入**（从相册选图）→ Phase 3.4+
- **Markdown 语义字符智能配对**（`*`/`$`/`#`/`-`/`>` 带上下文判断）→ Phase 3.4+（依赖 AST 上下文）

---

## 2. 关键架构约束（Hard Rules）

### 2.1 EditorShell 布局可扩展（v1.2 调整）

v1.2 新增 Markdown 工具栏（§3.7）需要在 EditorShell 增加底部工具栏 slot。允许在 `Scaffold.bottomNavigationBar` 与 `body` 之间新增工具栏区域,但 `appBar` + `body` + `bottomNavigationBar` 的三层结构不变。

### 2.2 EditorTokens 向后兼容（沿用 v1.1）

EditorTokens 改造后,所有现有 `EditorTokens.paragraphFontSize` 等引用必须继续工作。

### 2.3 Command Layer 强制（沿用 Phase 3.0）

所有文本修改（自动配对、Markdown 工具栏插入、自动续列表、选区格式化包裹）必须通过 `EditorCommand` → `EditorCoordinator.handle()` 路径,不直接修改 `TextEditingController`。

**Phase 3.3 新增 Command 子类（R4 补充说明,集中声明）**：

| Command 类 | 用途 | 来源任务 | 文件位置 |
|-----------|------|---------|---------|
| `PairInsertCommand` | §3.3.6 自动配对（追加配对符右半部分） | §3.3.6 | `lib/presentation/commands/editor_command.dart`（同 ADR-0008 sealed class） |
| `InsertTextCommand` | §3.3.7 Markdown 工具栏按钮插入文本 | §3.3.7 | 同上 |
| `WrapSelectionCommand` | §3.3.7 选区包裹模式（选中 → `**selected**`） | §3.3.7 | 同上 |
| `InsertNewLineWithPrefixCommand` | §3.3.8 自动续列表（回车 + 前缀） | §3.3.8 | 同上 |
| `InsertTemplateCommand` | §3.3.10 模板插入菜单 | §3.3.10 | 同上 |

所有新 Command 子类位于同一文件（符合 [ADR-0008](../ADR/0008-editor-transaction-model.md) sealed class 约束）,并在 [commands.dart](../../flutter_app/lib/presentation/commands/commands.dart) re-export 桥接文件中 show。详见 [ADR-0011](../ADR/0011-phase3.3-architecture-decisions.md) §5。

**Timeline 集成说明（R4 补充,避免实施时疑问）**：所有新 Command 子类（含 `InsertTemplateCommand` 产生的多 Block 变更,如插入表格模板生成 TableBlock + 多行行内文本）自动通过 `EditorCoordinator.handle() → CommandHandler` 路径接入 `HistoryManager`;**Timeline PR 6 集成由 EditorCoordinator 统一处理,各 Command 不单独处理 Timeline**。这与现有 8 个 Command 的处理路径一致,无需为新 Command 子类单独写 Timeline 接入代码。

### 2.4 依赖方向严格（沿用 Phase 3.0 Hard Rule 8）

`chrome/` → `editor/` → `core/editing/` 单向依赖。Markdown 工具栏属于 `chrome/`,通过 `EditorCoordinator` 间接访问编辑能力。

### 2.5 避免全局静态状态（沿用 v1.1）

所有状态通过 `EditorCoordinator`（`CoordinatorState` 字段）或 Riverpod Provider 管理。

### 2.6 旧 UI 不动（沿用 Phase 3.2）

`lib/presentation/screens/` 旧代码不修改。

### 2.7 CodeBlock 例外（v1.2 新增）

CodeBlock 不应用自动配对（§3.6）、自动续列表（§3.8）、选区格式化菜单（§3.9）。代码内容应原样保留,不被 Markdown 语法干扰。CodeBlock 仅支持 Markdown 工具栏（§3.7）插入代码块包裹语法。

---

## 3. 任务详细分解

### 3.1 任务 3.3.1：AppBar 显示文档标题 + 修改状态（P0）

**现状**：[editor_app_bar.dart](../../flutter_app/lib/presentation/chrome/editor_app_bar.dart) 已实现骨架,接受 `title` + `isModified` 参数,但 EditorShell 未传参（标题恒为 `'Phase 3.0 Demo'`,isModified 恒为 false）。

**实施要点**：

1. **Dirty tracking**：在 `CoordinatorState` 新增 `bool isDirty` 字段
   - `EditorCoordinator.handle()` 成功后置 `isDirty = true`
   - save / load / clear 时置 `isDirty = false`
   - 通过 `coordinator.isDirty` getter 暴露

2. **文档标题**：
   - `InMemoryDocumentEditor` 新增 `String title` 字段（从种子文档元数据取）
   - `EditorCoordinator` 新增 `String get documentTitle` getter
   - `EditorShell` 透传 `title: coordinator.documentTitle` + `isModified: coordinator.isDirty`

3. **EditorAppBar**：已实现 `isModified == true` 显示 `•`,无需改动

### 3.2 任务 3.3.2：字号缩放（P1,v1.3 降级,R3 确认）

**现状**：[editor_tokens.dart](../../flutter_app/lib/presentation/themes/editor_tokens.dart) 全为 `static const`,不支持运行时缩放。

**架构决策（需 Human Owner 审批）**：见 §9.1。

**实施要点**（假设方案 B：`MediaQuery.textScaler`）：

1. **EditorViewport** 外层包裹 `GestureDetector(onScaleUpdate: ...)` 检测双指缩放
2. 缩放因子存储在 `CoordinatorState.fontScale`（默认 1.0,范围 0.8~1.5）
3. `EditorShell` 在 build 时用 `MediaQuery(textScaler: TextScaler.linearScale(coordinator.fontScale), child: ...)` 注入
4. AppBar / StatusBar 新增字号缩放按钮（`Icons.zoom_in` / `Icons.zoom_out` / `Icons.zoom_out_map` 重置）

### 3.3 任务 3.3.3：焦点模式（P1）

**现状**：[editor_shell.dart](../../flutter_app/lib/presentation/editor/editor_shell.dart) 是 StatelessWidget,无法条件隐藏 chrome。

**实施要点**：

1. **EditorShell → StatefulWidget**：
   - 持有 `bool _focusMode`（或从 `CoordinatorState` 读）
   - `Scaffold(appBar: _focusMode ? null : EditorAppBar(...), bottomNavigationBar: _focusMode ? null : ...)`

2. **触发方式**：
   - AppBar action 图标按钮（`Icons.fullscreen`）
   - 双击编辑区域切换

> **注**：打字机模式已延期 Phase 3.4。本任务仅保留焦点模式（隐藏 chrome）。

### 3.4 任务 3.3.4：实时字数统计（P0）

**现状**：[editor_status_bar.dart](../../flutter_app/lib/presentation/chrome/editor_status_bar.dart) 只显示调试信息,无字数统计。

**实施要点**：

1. **字数计算**：
   - `EditorCoordinator` 新增 `int get wordCount` getter
   - 遍历 `allIds`,累加 `sourceOf(id)` 的字符数
   - 中英文混合：按字符计数（简单实现,Phase 3.4+ 可优化为中文按字 + 英文按 word）

2. **EditorStatusBar 改造**：
   - 替换调试信息为 `'字数: ${coordinator.wordCount}'`
   - 移除 `'聚焦: ${coordinator.focusedId}'` 调试信息

### 3.5 任务 3.3.5：撤销 / 重做按钮接入 UI（P0）

**现状**：[HistoryManager](../../flutter_app/lib/core/utils/history_manager.dart) + `EditorCoordinator.undo() / redo()` 内核完整就绪,仅缺 UI 按钮。

**实施要点**：

1. **EditorAppBar actions** 新增两个 `IconButton`：
   - `Icons.undo`（`onPressed: coordinator.canUndo ? coordinator.undo : null`）
   - `Icons.redo`（`onPressed: coordinator.canRedo ? coordinator.redo : null`）

2. **已知限制修复（可选）**：
   - `editor_coordinator.dart` 第 124-126 行注释：redo → undo 链在第 2 步会丢失状态记录
   - 评估是否在 Phase 3.3 范围内修复

### 3.6 任务 3.3.6：自动配对（P0）

**现状**：完全未实现。`BaseBlockState.buildEditField` 是最朴素的 `TextField`,无任何拦截。

**架构决策（需 Human Owner 审批）**：见 §9.2。

**实施要点**（假设方案 B：onChanged 拦截）：

1. **配对规则表（v1.3 缩减范围,仅保留 4 种无歧义配对）**：
   | 输入 | 配对 | 光标位置 | 说明 |
   |------|------|----------|------|
   | `(` | `()` | 中间 | 括号,无 Markdown 语义 |
   | `[` | `[]` | 中间 | 括号,无 Markdown 语义（链接语法 `[]()` 由工具栏插入） |
   | `{` | `{}` | 中间 | 括号,无 Markdown 语义 |
   | `` ` `` | ` `` `` | 中间 | 反引号配对（代码标记） |

2. **禁止无条件补全的字符（v1.3 新增硬规则）**：
   - ❌ `*`：在 Markdown 是无序列表前缀,自动补 `**` 会破坏列表输入
   - ❌ `$`：用于公式,自动补 `$$` 会影响行内公式输入流
   - ❌ `#`：用于标题,自动补 `##` 会破坏标题语法
   - ❌ `-`：是无序列表前缀
   - ❌ `>`：是引用前缀
   - 这些字符必须有 Markdown 上下文判断（行首位置 / 前一字符空白）才能安全补全,Phase 3.3 不实现上下文判断,留 Phase 3.4+ 带 AST 上下文后处理

3. **选区处理**：当选区非空时,`(` 包裹选区变为 `(selection)` 而非插入 `()`

4. **集成点**：`BaseBlockState.buildEditField` 统一接入 `onChanged` 回调

5. **CodeBlock 例外**：CodeBlock 禁用自动配对

### 3.7 任务 3.3.7：Markdown 工具栏（P0 核心,v1.3 提升为核心任务）

**现状**：完全未实现。用户需手敲 `**加粗**` / `[链接](url)` / ```` ```dart ```` 等复杂语法。

**v1.3 提升**：从「附属功能」提升为 **Phase 3.3 核心任务**。是用户真正能感知到的「主功能」,单独成 PR #2 作为本阶段最重要的交付。同时承担 §3.3.9 选区格式化菜单的「工具栏选区包裹模式」实现（替代 Overlay 浮动菜单）。

**架构决策（已确认）**：§9.3 方案 A 底部固定栏。

**实施要点**：

1. **工具栏按钮清单（11 种）**：
   | 按钮 | 图标 | 插入内容 | 光标位置 | 模式 |
   |------|------|----------|----------|------|
   | H1 | `Icons.title` | `# ` | 末尾 | 插入 |
   | H2 | `Icons.title`（小） | `## ` | 末尾 | 插入 |
   | H3 | `Icons.title`（更小） | `### ` | 末尾 | 插入 |
   | 加粗 | `Icons.format_bold` | `**\|**` | 中间 | 插入 / **选区包裹** |
   | 斜体 | `Icons.format_italic` | `*\|*` | 中间 | 插入 / **选区包裹** |
   | 行内代码 | `Icons.code` | `` `\|` `` | 中间 | 插入 / **选区包裹** |
   | 链接 | `Icons.link` | `[\|](url)` | 中间（url 待填） | 插入 / **选区包裹** |
   | 引用 | `Icons.format_quote` | `> ` | 末尾 | 插入 |
   | 无序列表 | `Icons.format_list_bulleted` | `- ` | 末尾 | 插入 |
   | 有序列表 | `Icons.format_list_numbered` | `1. ` | 末尾 | 插入 |
   | 代码块 | `Icons.data_object` | ```` ```dart\n\|\n``` ```` | 中间 | 插入 |

2. **选区包裹模式（v1.3 新增,替代 §3.3.9 Overlay 浮动菜单）**：
   - 检测 `TextEditingController.selection` 是否非空且非折叠
   - 若有选区,工具栏按钮行为从「插入」切换为「包裹选区」：
     | 按钮 | 无选区（插入） | 有选区（包裹） |
     |------|---------------|---------------|
     | 加粗 | `**\|**` | `**selection**` |
     | 斜体 | `*\|*` | `*selection*` |
     | 行内代码 | `` `\|` `` | `` `selection` `` |
     | 链接 | `[\|](url)` | `[selection](url)` |
   - **80% 价值,20% 实现复杂度**（替代 Overlay 方案的 100% 复杂度）
   - 视觉提示：有选区时工具栏背景色变化（如 `EditorTokens.codeBackground`）提示用户当前为包裹模式

3. **位置**：底部固定栏（方案 A）,与 EditorStatusBar 共存（可堆叠为底部双栏：StatusBar 上 + Toolbar 下,或合并为单行）

4. **集成点**：新增 `chrome/markdown_toolbar.dart`,通过 `EditorCoordinator.handle()` 提交 `InsertTextCommand` / `WrapSelectionCommand`

5. **CodeBlock 例外**：CodeBlock 内仅显示「代码块」按钮,其他按钮禁用

### 3.8 任务 3.3.8：自动续列表 / 引用 / 代码块（P0,v1.2 新增）

**现状**：完全未实现。用户输入 `- item` 回车后不会自动续 `- `。

**实施要点**：

1. **触发规则**：
   | 当前行模式 | 回车后续行 |
   |-----------|------------|
   | `- item` | `- ` |
   | `* item` | `* ` |
   | `1. item` | `2. `（自动编号） |
   | `> quote` | `> ` |
   | `- [ ] task` | `- [ ] ` |
   | ```` ``` ```` | 不续（代码块内回车原样） |

2. **退出规则**：
   - 当前行为空模式（如 `- ` 后无内容）,回车清除前缀,退出续行
   - 连续两次回车退出续行

3. **集成点**：`BaseBlockState.buildEditField` 的 `onSubmitted` 回调,检测当前行前缀,通过 `EditorCoordinator.handle()` 提交 `InsertNewLineWithPrefixCommand`

4. **CodeBlock 例外**：CodeBlock 内回车原样插入换行,不续行

5. **Phase 3.3 范围边界（R4 补充,避免实施时蔓延）**：
   - **嵌套列表不支持**：Phase 3.3 仅支持**平级单层续行**,不追踪缩进嵌套（如 `  - subitem`）。嵌套续行留 Phase 3.4+（需 AST 上下文判断缩进层级）
   - **编号列表起始编号不验证**：续行规则仅做简单 `数字 + 1` 递增,不验证起始编号。若用户输入 `3. item` 回车后续 `4. `,不检查 `3.` 是否合法起始
   - **混合前缀不识别**：不识别 `- ` 紧接 `1. ` 的混合场景（如 `- ` 后续行不会变成 `1. `）。用户切换列表类型需通过 Markdown 工具栏或手动改前缀

6. **onSubmitted IME 兼容性（R4 补充,PR #3 实施前需确认）**：
   - **风险**：Flutter `TextField.onSubmitted` 在部分 IME（如 Gboard 中文输入法）下不触发——IME 的「回车」可能直接提交文字而非触发 `onSubmitted` 回调
   - **Fallback 方案**：若 PR #3 实施时验证 `onSubmitted` 不可靠,改用 `onChanged` 检测 `\n` 换行符作为兜底:
     ```dart
     onChanged: (text) {
       if (text.endsWith('\n')) {
         // 检测到换行,触发续列表逻辑
         _handleAutoContinue(text);
       }
     }
     ```
   - **PR #3 实施前确认事项**：在真机（Android Gboard 中文输入法 + iOS 系统输入法）测试 `onSubmitted` 触发可靠性,若不可靠则采用 onChanged + `\n` 检测方案。此决策影响 §9.2 类似（onChanged 拦截路径已建立,可复用）
   - **架构影响**：无论采用 onSubmitted 还是 onChanged + `\n`,都通过 `InsertNewLineWithPrefixCommand → Coordinator.handle()` 路径,不绕过 Command Layer

### 3.9 任务 3.3.9：选区格式化菜单（v1.4 整体延期至 Phase 3.4）

**v1.4 决策**：整体延期至 Phase 3.4 §3.4.10。原因：Flutter Overlay + TextSelection + 光标坐标计算 + 滚动同步复杂度高,即使工具栏包裹模式也需要选区状态管理,Phase 3.3 风险敏感。

**选区包裹能力保留**：作为 §3.3.7 Markdown 工具栏的内置模式保留（用户选中文字后工具栏自动切换为包裹模式,无需独立任务）。

**Phase 3.4 §3.4.10 实施时参考**：
- 工具栏选区包裹模式（已作为 §3.3.7 内置模式落地,Phase 3.4 仅需独立验收）
- Overlay 浮动菜单（Phase 3.4 新增,可选增强）
- 菜单项：加粗 / 斜体 / 行内代码 / 链接 / 删除线

### 3.10 任务 3.3.10：Markdown 模板插入菜单（P1,v1.4 新增）

**现状**：完全未实现。Phase 3.2 已建立 TableBlock / MermaidBlock / CodeBlock 能力,但用户仍需手敲复杂语法（```` ```mermaid ```` / 表格 `| 列1 | 列2 |` 等）,Phase 3.2 成果价值未完全释放。

**核心价值**：释放 Phase 3.2 已建立的 Block 能力。用户一键插入模板,不用背 Markdown 语法也能写出含表格 / Mermaid 图 / 代码块的复杂文档。

**实施要点**：

1. **入口**：§3.3.7 Markdown 工具栏新增 `+` 按钮（`Icons.add_box` 或 `Icons.more_horiz`）

2. **弹出菜单**：点击 `+` 后弹出 BottomSheet 或 PopupMenu,展示模板清单

3. **模板清单**：
   | 模板 | 插入内容 | 释放的 Phase 3.2 能力 |
   |------|----------|----------------------|
   | 表格 | `\| 列1 \| 列2 \|\n\| --- \| --- \|\n\| 内容 \| 内容 \|` | TableBlock |
   | Mermaid 图 | ```` ```mermaid\ngraph TD\nA-->B\n``` ```` | MermaidBlock |
   | 代码块 | ```` ```dart\n\|\n``` ```` | CodeBlock |
   | 任务列表 | `- [ ] 任务1\n- [ ] 任务2` | ListElement（Phase 3.5+） |
   | 引用块 | `> 引用内容` | BlockquoteElement |
   | 分隔线 | `---` | HorizontalRuleElement |
   | 图片 | `![alt](url)` | ImageElement |
   | 链接 | `[文本](url)` | LinkElement |

4. **集成点**：扩展 `chrome/markdown_toolbar.dart`（同 §3.3.7 组件）,通过 `EditorCoordinator.handle()` 提交 `InsertTemplateCommand`

5. **CodeBlock 例外**：CodeBlock 内 `+` 按钮禁用（代码内容原样保留）

### 3.11 已移出任务（延期至 Phase 3.4）

| 原任务 | 去向 | 理由 |
|--------|------|------|
| 3.3.7 快捷键支持（v1.0） | Phase 3.4 §3.4.5 Desktop Enhancement | 手机端无 Ctrl 键,ROI 极低 |
| 3.3.3 打字机模式（v1.0） | Phase 3.4 §3.4.6 Desktop Enhancement | 手机端软键盘已占半屏,TextField 自带滚动 |
| 3.3.9 选区格式化菜单（v1.2,v1.4 整体延期） | Phase 3.4 §3.4.10 | Flutter Overlay + TextSelection + 光标坐标 + 滚动同步复杂度高,Phase 3.3 风险敏感。选区包裹能力已作为 §3.3.7 工具栏内置模式保留 |

---

## 4. 验证计划

### 4.1 自动化验证

| 维度 | 测试文件 | 测试内容 |
|------|----------|----------|
| Dirty tracking | `test/presentation/chrome/dirty_tracking_test.dart` | handle() 后 isDirty=true,save 后 isDirty=false |
| 字数统计 | `test/presentation/chrome/word_count_test.dart` | wordCount 正确计算 |
| 字号缩放 | `test/presentation/editor/font_scale_test.dart` | fontScale 范围 0.8~1.5,缩放后 token 引用不变 |
| 焦点模式 | `test/presentation/editor/focus_mode_test.dart` | 焦点模式隐藏 chrome |
| 自动配对 | `test/presentation/blocks/auto_pair_test.dart` | 4 种配对符（`(`/`[`/`{`/`` ` ``）正确补全 + 选区包裹 + CodeBlock 例外 |
| Markdown 工具栏 | `test/presentation/chrome/markdown_toolbar_test.dart` | 11 种按钮正确插入 + 光标位置 + 选区包裹模式 + CodeBlock 例外 |
| 自动续列表 | `test/presentation/blocks/auto_continue_test.dart` | 5 种前缀续行 + 退出规则 + CodeBlock 例外 |
| 模板插入菜单 | `test/presentation/chrome/template_menu_test.dart` | 8 种模板正确插入（表格/Mermaid/代码块/任务列表/引用/分隔线/图片/链接）+ CodeBlock 例外 |

### 4.2 功能验证

- 打开含多种 Block 的 .md 文档,AppBar 显示标题 + 修改状态
- 双指缩放字号生效,缩放按钮生效
- 焦点模式图标按钮切换 chrome 显隐
- 状态栏显示字数
- Undo/Redo 按钮可点击,功能正常
- 输入 `(` 自动配对为 `()`,光标在中间（4 种配对符）
- 点击 Markdown 工具栏「加粗」按钮,插入 `**|**`,光标在中间
- 输入 `- item` 回车,自动续 `- `
- 选中文字,工具栏切换为选区包裹模式,点击「加粗」包裹为 `**selection**`
- 点击工具栏 `+` 按钮,弹出模板菜单,选择「表格」插入表格模板

### 4.3 架构验证

- EditorShell 布局守门（TC-ARCH-UI-*）
- 依赖方向守门
- 无全局静态状态
- EditorTokens 向后兼容（现有引用不变）
- CodeBlock 例外守门（CodeBlock 不应用 Markdown 输入辅助）

---

## 5. 风险评估

| 风险 | 影响 | 缓解 |
|------|------|------|
| EditorShell → StatefulWidget 破坏重建机制 | 高 | AnimatedBuilder 仍可包裹 StatefulWidget,不影响 |
| EditorTokens 改造破坏现有引用 | 高 | 方案 B（MediaQuery.textScaler）不改变 token 常量 |
| 自动配对在 IME 输入法下失效 | 中 | 方案 B（onChanged）对 IME 友好 |
| Markdown 工具栏位置与键盘冲突 | 中 | 监听 `MediaQuery.viewInsets.bottom` 动态调整 |
| 自动续列表在多行 Block 内逻辑复杂 | 中 | Phase 3.3 仅支持单行前缀续行,多行嵌套留 Phase 3.4+ |
| 选区格式化菜单 Overlay 定位不准 | 中 | 用 `TextEditingController.selection` 的 `TextSelection.start/end` 计算位置 |
| **TextSpan 缩放不一致被用户误报为 Bug** | 中 | §9.1 已明确边界,Phase 3.4 Typography Refactor 统一;Issue 引用本节或 ADR-0011 §1 标 wontfix |
| **Toolbar 三份选区状态不同步** | 高 | §9.5 强制 Toolbar 只读 CoordinatorState,禁止直接访问 TextEditingController |
| **自动配对绕过 Command Layer 导致 History 丢失** | 高 | §9.2 强制 PairInsertCommand → Coordinator.handle(),禁止 onChanged 直接改 controller.text |

---

## 6. 成功标准（Phase 3.3 Exit Gate）

### 6.1 UI 验证

- [ ] AppBar 显示文档标题 + 修改状态 `•`
- [ ] 双指缩放字号生效,缩放按钮生效（P1）
- [ ] 焦点模式图标按钮切换 chrome 显隐（P1）
- [ ] 状态栏显示字数
- [ ] Undo/Redo 按钮可点击,功能正常
- [ ] 输入 `(` / `[` / `{` / `` ` `` 自动配对（4 种配对符）
- [ ] Markdown 工具栏 11 种按钮可点击,插入正确
- [ ] 选中文字后,工具栏切换为选区包裹模式,点击 B/I/Code/Link 包裹正确（§3.3.7 内置模式）
- [ ] 输入 `- item` 回车自动续 `- `
- [ ] 点击工具栏 `+` 按钮,弹出模板菜单,选择「表格」/「Mermaid」模板插入正确（P1,§3.3.10）

### 6.2 架构验证

- [ ] EditorShell 布局守门通过
- [ ] EditorTokens 向后兼容
- [ ] 依赖方向守门通过
- [ ] 无新增全局静态状态
- [ ] CodeBlock 例外守门通过

### 6.3 工程验证

- [ ] `flutter analyze` 0 error
- [ ] `flutter test` 0 regression
- [ ] `flutter build apk --debug` 成功
- [ ] `flutter build web` 成功

### 6.4 文档验证

- [ ] ROADMAP.md Phase 3.3 状态更新
- [ ] ui-spec.md §7 Phase 3.3 checkbox 同步
- [ ] Phase 3.3 Verification Report 完成

---

## 7. 回滚计划

### 7.1 回滚触发条件

- EditorShell 改造导致 UI 崩溃
- EditorTokens 改造破坏现有 Block 渲染
- Markdown 工具栏与键盘冲突无法解决
- 自动续列表导致输入法异常

### 7.2 回滚步骤

> **R4 修订**：原引用 PR 编号（如 PR #2 / #3 / #4）在实际创建时可能变化,改为范围描述。

1. revert 对应 PR（按范围描述定位,非按编号）
2. 恢复 EditorShell 为 StatelessWidget（如「字号缩放 + 焦点模式 PR」回滚）
3. 恢复 EditorTokens 为纯 static const（如「字号缩放 + 焦点模式 PR」回滚,EditorTokens 改造仅在此 PR）
4. 移除 Markdown 工具栏（如「Markdown 工具栏 + 模板插入菜单 PR」回滚）
5. 移除自动配对 + 自动续列表逻辑（如「自动配对 + 自动续列表 PR」回滚,恢复 BaseBlockState 原 onChanged / onSubmitted）

**按范围定位 PR**：
- 「chrome 接线 PR」= §3.3.1 + §3.3.4 + §3.3.5
- 「Markdown 工具栏 + 模板插入菜单 PR」= §3.3.7 + §3.3.10
- 「自动配对 + 自动续列表 PR」= §3.3.6 + §3.3.8
- 「字号缩放 + 焦点模式 PR」= §3.3.2 + §3.3.3

---

## 8. PR 策略

### 8.1 分 PR 建议（4 个 PR,v1.4 调整 + R4 PR 拆分）

> **v1.4 R4 PR 拆分调整（2026-07-22,Human Owner）**：
>
> 模板菜单（§3.3.10）原归入 PR #4（字号缩放 + 焦点模式 + 模板插入菜单,P1 可整体延期）。但**架构耦合关系是 Toolbar → Template Menu**：模板菜单依赖 §3.3.7 Markdown 工具栏组件,不依赖字号缩放/焦点模式。若 PR #4 P1 整体延期时被强行绑定,会迫使模板菜单一起延期,这与「释放 Phase 3.2 TableBlock/MermaidBlock 成果」的核心价值相悖。
>
> 调整后：**模板菜单移入 PR #2 扩展**,与工具栏组件同 PR 交付;PR #4 仅保留字号缩放 + 焦点模式。

| PR | 范围 | 分支 | 依赖 | 优先级 |
|----|------|------|------|--------|
| **#1** | 3.3.1 + 3.3.4 + 3.3.5（chrome 接线：标题 + dirty + 字数 + undo/redo 按钮） | `feat/phase3.3-chrome-wiring` | 无 | P0 |
| **#2** | 3.3.7 + 3.3.10（**Markdown 工具栏核心 + 选区包裹模式 + Markdown 模板插入菜单**,架构耦合：Toolbar → Template Menu,模板菜单与工具栏同 PR 交付以释放 Phase 3.2 成果） | `feat/phase3.3-markdown-toolbar` | PR #1（需 dirty tracking 基础） | **P0 核心** |
| **#3** | 3.3.6 + 3.3.8（自动配对（缩减范围 4 种）+ 自动续列表,合并因都改 BaseBlockState 输入行为） | `feat/phase3.3-auto-pair-continue` | PR #1 | P0 |
| **#4** | 3.3.2 + 3.3.3（字号缩放 + 焦点模式,P1 可选,时间不够整体延期 Phase 3.4,与工具栏解耦,延期不影响模板菜单） | `feat/phase3.3-ux-enhancement` | PR #1 | P1 |

### 8.2 分支命名

- `feat/phase3.3-<scope>-<short-desc>`

### 8.3 实施顺序

1. PR #1 先行（chrome 接线,基础设施：dirty tracking + wordCount）
2. PR #2 依赖 PR #1（**Markdown 工具栏核心 + 模板插入菜单**,Phase 3.3 最重要交付,Toolbar + Template Menu 同 PR 因架构耦合）
3. PR #3 依赖 PR #1（自动配对 + 自动续列表,移动端输入辅助）
4. PR #4 依赖 PR #1（P1 可选：字号缩放 + 焦点模式,可整体延期 Phase 3.4,与 PR #2 解耦）

---

## 9. Human Owner 决策事项（待审批）

### 9.1 EditorTokens 字号缩放方案

**选项 A**：InheritedWidget 注入（`EditorThemeScope`）
- 优点：精确控制每个 token
- 缺点：`TextSpan` 内联渲染需改用 `DefaultTextStyle`,改造量大

**选项 B**（推荐,R4 确认）：`MediaQuery.textScaler`（Flutter 内置）
- 优点：代价最小,利用 Flutter 内置机制,不改变 EditorTokens 常量。`EditorTokens.paragraphFontSize` 等调用遍布全项目,选 C 等于整个渲染层重构,完全不值
- 缺点：只影响 `Text` widget,`TextSpan` 硬编码 fontSize 不生效

**选项 C**：EditorTokens 实例化（改为非 const）
- 优点：最灵活
- 缺点：破坏性大,影响所有引用方

**架构约束（R4 新增,避免后续踩坑）**：
- Phase 3.3 字号缩放**仅保证 Text Widget 生效**
- Inline `TextSpan` 的缩放一致性**不作为 Exit Gate**
- 统一 `TextSpan` 缩放方案留 **Phase 3.4 Typography Refactor**

否则会出现以下场景：
```
ParagraphBlock → 正常缩放
InlineBold     → 不缩放
InlineCode     → 不缩放
```
导致无限修 Bug。明确边界后,Phase 3.3 专注 Text Widget 缩放路径。

**用户可见影响（R4 补充,避免 Issue 误报）**：

Phase 3.3 实施后,用户缩放字号时可能出现以下现象：
- `ParagraphBlock` 正文 → **正常缩放**（Text Widget 路径）
- `InlineBold` / `InlineCode` / `InlineFormula` → **不缩放**（TextSpan 硬编码 fontSize）

**这不是 Bug,是 Phase 3.3 已知边界**。统一方案留 Phase 3.4 Typography Refactor（届时考虑方案 A `InheritedWidget` 或方案 C `EditorTokens` 实例化）。

Issue 误报处理：引用本节或 ADR-0011 §1 关闭,标注 `wontfix` + `phase-3.4-typography` label。

### 9.2 自动配对实现位置

**选项 A**：`TextInputFormatter` 子类
- 优点：跨平台一致
- 缺点：无法感知光标上下文（无法判断是否在代码块内）

**选项 B**（推荐,R4 确认）：`onChanged` 拦截（在 `BaseBlockState` 中监听 `textController` 变化）
- 优点：对 IME 友好,可感知 Block 类型（CodeBlock 可禁用配对）。**移动端最大敌人是 IME（中文/日文/韩文输入法）,很多 KeyEvent 根本拿不到,选 C 直接淘汰**
- 缺点：需手动管理光标位置

**选项 C**：`FocusNode.onKeyEvent` 回调
- 优点：可拦截物理按键
- 缺点：对 IME 不友好（中文输入法不触发 KeyEvent）,移动端淘汰

**架构约束（R4 新增,严格遵守 Hard Rule 2.3）**：

禁止以下反模式：
```dart
onChanged
  ↓
直接修改 controller.text  // ❌ 违反 Hard Rule 2.3
```

必须采用：
```
检测到触发
  ↓
生成 PairInsertCommand
  ↓
Coordinator.handle()
  ↓
Controller 更新（由 Coordinator 统一管理）
```

原因：Hard Rule 2.3 要求所有文本修改必须经过 Command Layer。很多项目在自动配对场景偷偷绕过,导致 History 丢失配对操作 / Coordinator 状态不一致。Phase 3.3 必须为自动配对设计专用 `PairInsertCommand`。

**onChanged 拦截时序说明（R4 补充,明确实现路径）**：

`onChanged` 在 controller 已被修改后才触发,因此 `PairInsertCommand.apply()` 流程：

```
1. 用户输入 '('
2. controller.text 已变成 "...("   ← IME 已提交原始字符
3. onChanged(text) 触发
4. 检测到 '(' 在末尾且需要配对
5. 构造 PairInsertCommand(
     blockId,
     insertOffset: 光标位置,
     pairChar: ')',
     mode: PairInsertMode.appendAfterCursor,  // 不修改原始输入,只追加右半部分
   )
6. Coordinator.handle(command)
7. CommandHandler 生成 UpdateBlockSourceCommand 包含完整 "...()"
8. controller.text 更新为 "...()"
9. 光标移到 '()' 之间
```

**关键约束**：PairInsertCommand 不修改原始用户输入,只追加配对符右半部分。这避免了「先 undo 再 redo」的复杂时序。实现可采用 `TextEditingController.selection` + `TextEditingValue` 快照比对方式检测变化。

### 9.3 Markdown 工具栏位置（v1.2 新增决策,R4 修订为 A+B 混合）

**选项 A**：底部固定栏（替代 EditorStatusBar,或合并为底部双栏）
- 优点：与手机输入法位置接近,操作路径短
- 缺点：占用屏幕底部空间,需处理与 EditorStatusBar 共存

**选项 B**：底部可滚动栏（横向滚动,容纳更多按钮）
- 优点：可容纳更多按钮（如未来加表格 / 图片 / 分隔线）
- 缺点：用户需滑动找按钮,体验略差

**选项 C**：键盘上方浮动栏（监听 `MediaQuery.viewInsets.bottom`,跟随键盘高度）
- 优点：与键盘一体,操作最近
- 缺点：实现复杂,需处理键盘动画 + 焦点切换

**R4 决策（A+B 混合,Obsidian Mobile / Joplin Mobile 方案）**：

A 与 B 并非互斥关系。最佳实现是：
```
位置选 A（底部固定栏）
  ↓
内部布局选 B（横向滚动）
```

视觉示意：
```
┌──────────────────────────────────────────┐
│ [B][I][H1][H2][Code][Link][Quote][List] │  ← 横向滚动
│ <------------------------------------->  │
└──────────────────────────────────────────┘
```

**理由**：
- 未来已规划 Table / Mermaid / Image / Divider / Math 等按钮（§3.3.10 模板菜单 + Phase 3.4+ 扩展）,按钮必然超过一屏
- 现在做固定不滚动,后面还得重构
- 直接采用「底部固定位置 + 内部横向滚动」避免未来返工

**采用方案**：位置 A + 内部布局 B（横向滚动）

### 9.4 Dirty tracking 状态归属

**选项 A**（推荐,R4 确认）：`CoordinatorState.isDirty` 字段
- 优点：与现有架构一致
- 缺点：CoordinatorState 字段增多

**选项 B**：独立 Riverpod `UIStateProvider`
- 优点：职责分离
- 缺点：引入新的状态源

**理由**：Dirty 本质属于**文档状态**,不是 UI 状态。AppBar 显示 `•` / 保存按钮可用 / 关闭时弹窗 / 自动保存判断都依赖它。归入 `CoordinatorState`（Document State）而非 UI State。

### 9.5 Toolbar 状态来源（R4 新增决策）

**问题背景**：Markdown Toolbar 需要知道：
- 当前聚焦 Block（用于判断 CodeBlock 例外）
- 当前选区（用于选区包裹模式）
- 是否 CodeBlock（用于禁用不适用按钮）

**选项 A**（推荐,R4 确认）：Toolbar 只读 `CoordinatorState`

```
Toolbar
  ↓
Coordinator
  ↓
FocusedBlockState
```

**选项 B**：Toolbar 直接访问 `TextEditingController`
- 优点：实现简单,直接拿选区
- 缺点：违反依赖方向（chrome → editor 反向访问）

**架构约束（R4 新增 Hard Rule）**：

禁止以下反模式：
```dart
Toolbar
  ↓
直接访问 TextEditingController  // ❌ 违反依赖方向
```

**原因**：否则会出现三份状态不同步：
```
Toolbar 维护一份选区
Block  维护一份选区
Coordinator 再维护一份选区
```

编辑器项目特别容易死在这里。Phase 3.3 必须明确：Toolbar 只读 CoordinatorState,选区/聚焦状态由 Coordinator 统一管理。

### 9.6 已确认决策（v1.1 + v1.2 + v1.3 架构评审,Human Owner 2026-07-22）

1. ✅ **快捷键支持延期至 Phase 3.4 Desktop Enhancement**：手机端无 Ctrl 键,ROI 极低
2. ✅ **打字机模式延期至 Phase 3.4 Desktop Enhancement**：手机端软键盘已占半屏
3. ✅ **Phase 3.3 重新定义为 Mobile Markdown Editing Experience**：聚焦移动端 Markdown 输入辅助
4. ✅ **新增 Markdown 工具栏（§3.7）**：手机端高价值,替代 Ctrl+B 等桌面快捷键
5. ✅ **新增自动续列表（§3.8）**：手机端高价值,Obsidian/Typora/Notion 标配
6. ✅ **新增选区格式化菜单（§3.9）**：手机端高价值,用户不用知道 Markdown 语法
7. ✅ **CodeBlock 例外**：CodeBlock 不应用自动配对 / 自动续列表 / 选区格式化（代码内容原样保留）
8. ✅ **§9.1-9.5 默认采用所有推荐方案**：MediaQuery.textScaler / onChanged 拦截 / A+B 混合（底部固定 + 内部横向滚动）/ CoordinatorState.isDirty / Toolbar 只读 CoordinatorState

### 9.7 v1.3 架构评审 R2 新增决策（Human Owner 2026-07-22,8.5/10 评分后 Accepted）

1. ✅ **Markdown 工具栏（§3.7）提升为 Phase 3.3 核心任务**：是用户真正能感知到的「主功能」,单独成 PR #2 作为本阶段最重要交付
2. ✅ **选区格式化菜单（§3.9）Overlay 方案降级为可选项**：Flutter Overlay 三端行为不一致,优先采用工具栏选区包裹方案（80% 价值,20% 复杂度）。Overlay 浮动菜单留 Phase 3.4+ 可选
3. ✅ **自动配对（§3.6）缩减范围**：禁止对 Markdown 语义字符 `*`/`$`/`#`/`-`/`>` 做无条件补全（会破坏列表/公式/标题/引用输入）。仅保留 4 种无歧义配对：`(`/`[`/`{`/`` ` ``。Markdown 语义字符智能配对留 Phase 3.4+ 带 AST 上下文判断
4. ✅ **§3.3.2 字号缩放 P0 → P1**：编辑器基础能力缺失时,字号缩放非关键路径
5. ✅ **PR 划分 4 个（v1.3 调整）**：PR #1 chrome 接线 / PR #2 Markdown 工具栏核心（含选区包裹）/ PR #3 自动配对+自动续列表 / PR #4 P1 可选增强（可整体延期）

### 9.8 v1.4 架构评审 R3 新增决策（Human Owner 2026-07-22,9.0/10 评分后 Accepted）

1. ✅ **字号缩放（§3.3.2）P1 确认**：v1.3 已将字号缩放从 P0 降级到 P1,R3 确认此调整。用户写不出 Markdown 比字体大小不满意严重得多,字号缩放非关键路径
2. ✅ **§3.3.9 选区格式化菜单整体延期至 Phase 3.4**：v1.3 将其降级为「可选项,优先工具栏选区包裹,Overlay 留 Phase 3.4+」。R3 进一步收缩：**整体移到 Phase 3.4 §3.4.10**（包括工具栏选区包裹模式的独立验收）。原因：Flutter Overlay + TextSelection + 光标坐标计算 + 滚动同步复杂度高,Phase 3.3 风险敏感。**选区包裹能力作为 §3.3.7 Markdown 工具栏的内置模式保留**（无需独立任务）
3. ✅ **新增 §3.3.10 Markdown 模板插入菜单（P1）**：工具栏 `+` 按钮弹出菜单,一键插入表格/Mermaid/代码块/任务列表/引用块/分隔线/图片/链接模板。**核心价值**：释放 Phase 3.2 已建立的 TableBlock/MermaidBlock 能力。如果用户还要自己背 ```` ```mermaid ```` 语法,Phase 3.2 成果价值没有完全释放
4. ✅ **PR 划分 4 个（v1.4 调整 + R4 PR 拆分）**：PR #1 chrome 接线 / PR #2 Markdown 工具栏核心 + 模板插入菜单（含选区包裹内置模式,架构耦合 Toolbar → Template Menu,同 PR 交付）/ PR #3 自动配对+自动续列表 / PR #4 P1 可选增强（字号缩放 + 焦点模式,与工具栏解耦,延期不影响模板菜单）

### 9.9 v1.4 R4 架构决策细化（Human Owner 2026-07-22,评分 9/10 ~ 10/10 后 Accepted）

Human Owner 对 §9.1-9.5 架构决策给出最终评分：

| 决策 | 评分 | 备注 |
|------|------|------|
| 9.1 字号缩放（MediaQuery.textScaler） | 9/10 | R4 新增 TextSpan 缩放一致性边界 |
| 9.2 自动配对（onChanged 拦截） | 9.5/10 | R4 新增 PairInsertCommand 路径约束 |
| 9.3 Toolbar 位置（A+B 混合） | 8.5/10 | R4 从 A 修订为 A+B 混合 |
| 9.4 Dirty Tracking（CoordinatorState） | 10/10 | R4 补充文档状态归属理由 |
| 9.5 Toolbar 状态来源（只读 CoordinatorState） | - | R4 新增决策 |

**R4 新增约束总结**：
1. ✅ **§9.1 字号缩放边界**：仅保证 Text Widget 生效,TextSpan 一致性不作为 Exit Gate,统一方案留 Phase 3.4 Typography Refactor
2. ✅ **§9.2 自动配对 Command Layer 路径**：禁止 onChanged → 直接修改 controller.text;必须经 PairInsertCommand → Coordinator.handle()
3. ✅ **§9.3 Toolbar A+B 混合**：位置 A（底部固定）+ 内部布局 B（横向滚动）,避免未来按钮超一屏后重构
4. ✅ **§9.4 Dirty 归属确认**：Dirty 属于 Document State（非 UI State）,归入 CoordinatorState.isDirty
5. ✅ **§9.5 新增 Toolbar 状态来源**：Toolbar 只读 CoordinatorState,禁止直接访问 TextEditingController（避免三份选区状态不同步）

**结论**：决策足够进入 Accepted 状态,无需继续设计讨论,可开始拆 PR 实施。最先做 PR #1（Dirty Tracking + Word Count + Undo/Redo）,然后直接进入 PR #2（Markdown Toolbar）。

---

**本文件由 AI Agent 起草,版本 v1.4（Accepted,架构评审 R3 9.0/10 + R4 架构决策细化 9-10/10 评分后 Accepted + R4 改进补充：TextSpan 用户可见影响 / onChanged 时序 / 续列表范围 / 回滚范围描述 / Command 子类集中声明 / ui-spec §7 验证清单）。**
