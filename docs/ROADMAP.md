# FormulaFix Roadmap

> 从"Markdown + 公式预览原型"演进为"移动端 Typora 类产品"的分阶段路线图。  
> 每个 Phase 内的任务尽量独立，可并行 / 可独立 PR。

---

## Phase 0：工程化 + UI Prototype Freeze（当前阶段）

**目标**：建立工程基础设施，让项目可构建、可测试、可协作；冻结当前 UI 作为重构基线。

**禁止**：修改业务代码、新增功能、修改 UI 行为。

**UI Prototype Freeze**：当前 UI 是原型，不是最终产品。本阶段不修改 UI，但需明确：
- 当前 UI 的交互流程作为 Phase 3 的参考基线
- Phase 1-2 期间 UI 可能出现退化，这不视为 bug
- 重构完成后（Phase 3）才会重新实现 UI

### 任务

| # | 任务 | 责任人 | 状态 |
|---|------|--------|------|
| 0.1 | 补齐 `pubspec.yaml`（含依赖最小集 + assets 声明） | 架构师 | ✅ 已完成 |
| 0.2 | 创建 `AGENTS.md`（AI 协作规范） | 架构师 | ✅ 已完成 |
| 0.3 | 建立 `docs/` 文档体系（ARCHITECTURE / ROADMAP / CODING_RULES / GIT_WORKFLOW / ADR） | 架构师 | ✅ 已完成 |
| 0.4 | 配置 GitHub Actions CI（pub get / analyze / test / build） | 架构师 | ✅ 已完成 |
| 0.5 | 建立 AI 工程治理层（`.agent/AI_POLICY.md` / `loading-rules.md` / `task-contract.md`） | 架构师 | ✅ 已完成 |
| 0.6 | 清理工程残留（`export_service_tail.txt` / `manifest.json` 默认描述） | 架构师 | ✅ 已完成 |
| 0.7 | Android 构建修复（依赖版本兼容性 + 构建工具链对齐） | 架构师 | ✅ 已完成 |
| 0.8 | 设计开发流程文档（`.github/pull_request_template.md` / `WORKFLOW.md`） | 架构师 | ✅ 已完成 |

### 退出条件

- [x] `flutter pub get` 在干净环境成功
- [x] `flutter analyze` 无 error
- [x] `flutter test` 全部通过
- [x] `flutter build apk --debug` 成功
- [x] `flutter build web` 成功
- [x] CI 在 PR 上自动运行全部步骤
- [x] AI 治理层文档到位

---

## Phase 1：底层重构（已完成 2026-07-19）

**目标**：解决阻塞性架构问题，统一数据层、状态层、解析层的基础。

**前置条件**：Phase 0 全部退出。

**UI 退化的接受**：本阶段聚焦底层，UI 可能出现退化（如预览/编辑切换失效、渲染异常），不视为 bug。UI 在 Phase 3 重新实现。

**关闭说明**：Phase 1 Close Candidate 经 PR #23 完成测试体系（314 tests / 0 regression）+ Verification Report + Human Owner 合并后正式关闭。详见 [docs/releases/phase1-verification-report.md](file:///d:/Projects/Active/math/docs/releases/phase1-verification-report.md)。

### 任务

| # | 任务 | 优先级 | 关联 ADR | 状态 |
|---|------|--------|---------|------|
| 1.1 | 合并重复 Provider（`sharedPreferencesProvider` / `darkModeProvider`） | P0 | ADR-0002 | ✅ ec76f06 |
| 1.2 | 存储统一为 .md 文件单一真相；废弃 `formula_fix_documents.json` 与 `pref_last_content` | P0 | ADR-0003 | ✅ b43e5c1 |
| 1.3 | 处理 `DocumentListScreen`：合并到 `FileManagerScreen` 或注册路由 | P0 | - | ✅ b36d930 |
| 1.4 | 修正路由初始位置为文件列表，而非空白编辑器 | P0 | - | ✅ b36d930 |
| 1.5 | 补齐解析器：行内代码 / 链接 / 图片 / 斜体 / 删除线 / 任务列表 / 引用链接 | P0 | ADR-0004 | ✅ da4ab00 |
| 1.6 | 修复工具栏与解析器矛盾（移除不支持的按钮，或同步实现） | P0 | ADR-0004 | ✅ d57d2f2 |
| 1.7 | 修复错误消息透传 `detail`（[editor_screen.dart:221-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L221-253)） | P1 | - | ✅ f6a73af |
| 1.8 | 补齐 UI / 路由 / Provider 集成测试 | P1 | - | ✅ PR #23（314 tests / 0 regression，详见 [Verification Report](file:///d:/Projects/Active/math/docs/releases/phase1-verification-report.md)） |

### 退出条件

- [x] 单一存储源，.md 文件为唯一数据源
- [x] 解析器与工具栏一致，无自相矛盾（1.6 已修复）
- [x] 所有 Provider 定义唯一
- [x] 路由无死代码
- [x] 错误消息对用户友好
- [x] 核心模块测试覆盖（1.8 已通过：314 tests / 0 regression，详见 [Verification Report](file:///d:/Projects/Active/math/docs/releases/phase1-verification-report.md)）

---

## Phase 2：编辑模型

**目标**：设计并实现块级编辑模型，建立 AST 驱动的编辑内核。

**前置条件**：Phase 1 全部退出。

**核心理念**：本阶段定义"怎么编辑"，不定义"长什么样"。UI 在 Phase 3 实现。

### 任务

| # | 任务 | 备注 | 状态 |
|---|------|------|------|
| 2.1 | 设计 `BlockEditor` 抽象：块类型、聚焦态/非聚焦态、光标模型 | 参考 Notion / Typora 块编辑 | ✅ PR #27 |
| 2.2 | 实现"光标所在块渲染为可编辑组件，离开光标渲染为最终样式" | 核心机制 | ✅ PR #27 |
| 2.3 | 增量解析：只重解析光标所在块 | 性能优化 | ✅ PR #29 |
| 2.4 | AST 重构：Document 模型对齐 BlockEditor 的块类型 | 类型系统完善 | ✅ PR #30 |
| 2.5 | 输入法（IME）兼容：中文输入组合态在块编辑中的正确处理 | 移动端关键 | ✅ PR #32 |
| 2.6 | 块级操作：插入/删除/合并/拆分/移动块 | 编辑原语 | ✅ feat/phase2.6-block-operations（待合并 main） |
| 2.7 | Markdown 快捷输入映射（`# ` → 标题块，`- ` → 列表块 等） | 用户习惯保留 | 🚧 进行中（feat/phase2.7-markdown-shortcuts） |

### Phase 2.6 关闭说明

Phase 2.6 块级操作五原语（insert / delete / merge / split / move）+ Transaction 模型（EditOperation / TransactionBuilder / EditorHistory / Coalescing）已在 `feat/phase2.6-block-operations` 分支完成实现：

- 5 类 BlockOperation apply/revert 幂等性单测覆盖（TC-EDIT-6.1）
- TransactionBuilder commit/rollback + 嵌套合并（TC-EDIT-6.2）
- EditorHistory coalescing 7 触发条件（TC-EDIT-6.3）
- BlockOperations 高层 API + eager apply 语义（TC-EDIT-6.4 ~ 6.9）
- IME 三铁律集成（铁律 1 由 `assertBlockMutationAllowed` 守门）
- 全量测试：671 passed / 8 skipped / 0 regression（详见 [Phase 2.6 Verification Report](file:///d:/Projects/Active/math/docs/releases/phase2.6-verification-report.md)）
- ADR-0008 v1.1 修订：新增 §9 BlockId 生命周期声明 + §10 TransactionExecutor 设计方向（Phase 2.8+ 候选）

**待 Human Owner 操作**：将 `feat/phase2.6-block-operations` 合并到 main（当前 Phase 2.7 从该分支切出，待 2.6 合并后可 rebase）。

### 退出条件

- [ ] 块编辑内核可脱离 UI 独立运行（纯 Dart 逻辑）
- [ ] 所有块类型有单元测试覆盖
- [ ] 1000 行文档增量解析 < 16ms
- [ ] 中文输入法组合态正确处理

---

## Phase 2.8：Integration Hardening（集成加固）

**目标**：用 5 类集成测试验证"零件正确 → 系统正确"，输出 Phase 2 Exit Gate Report + Architecture Review Report。

**前置条件**：Phase 2.7 完成。

**核心理念**：Phase 2.1~2.7 验证"零件正确"（单测覆盖每个原语），Phase 2.8 验证"系统正确"（5 类集成测试覆盖完整编辑闭环）。

### 任务

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 2.8.1 | 编辑闭环集成测试（TC-EDIT-8.1） | 11 tests | ✅ feat/phase2.8-integration-hardening |
| 2.8.2 | Transaction+History 集成测试（TC-EDIT-8.2） | 12 tests | ✅ feat/phase2.8-integration-hardening |
| 2.8.3 | IME+Transaction 集成测试（TC-EDIT-8.3） | 16 tests | ✅ feat/phase2.8-integration-hardening |
| 2.8.4 | Parser/Serializer 一致性集成测试（TC-EDIT-8.4） | 17 tests | ✅ feat/phase2.8-integration-hardening |
| 2.8.5 | Performance Baseline 集成测试（TC-EDIT-8.5） | 9 tests | ✅ feat/phase2.8-integration-hardening |
| 2.8.6 | Phase 2 Exit Gate Report | [phase2-exit-gate-report.md](file:///d:/Projects/Active/math/docs/releases/phase2-exit-gate-report.md) | ✅ |
| 2.8.7 | Architecture Review Report | [phase2-architecture-review.md](file:///d:/Projects/Active/math/docs/releases/phase2-architecture-review.md) | ✅ |

### Phase 2.8 期间发现并修复的 P0/P1

- **P0**：`BlockOperation._applyInsert` redo 时不复用首次分配的 newId，导致后续依赖该 BlockId 的 op redo 时 apply 失败。修复方式：用 `revertContext[kNewId]` 作为 `preserveId` 传给 `editor.insertBlock`
- **P1**：`EditorHistory` 未暴露 `maxHistorySize` 参数，1000 次 undo 受默认 50 限制。修复：新增 `maxHistorySize` 可选构造参数（向后兼容）

### 退出条件（Phase 2 Exit Gate）

- [x] 块编辑内核可脱离 UI 独立运行（纯 Dart 逻辑，0 反向依赖）
- [x] 所有块类型有单元测试覆盖（9 种 BlockType 全覆盖）
- [x] 1000 行文档增量解析 < 16ms（per-block 0.0752ms）
- [x] 中文输入法组合态正确处理（TC-EDIT-8.3 16 测试验证三铁律）

详见 [Phase 2 Exit Gate Report](file:///d:/Projects/Active/math/docs/releases/phase2-exit-gate-report.md) + [Architecture Review Report](file:///d:/Projects/Active/math/docs/releases/phase2-architecture-review.md)。

---

## Phase 2.9：UI Architecture Prototype（UI 架构原型）

**目标**：用 **设计 + 4 个 Prototype Demo** 验证"用户体验 → UI Interaction Model → BlockEditor API → Transaction → AST"五层映射的正确性，**不写正式 UI 代码**。

**前置条件**：Phase 2.8 完成（Phase 2 Exit Gate PASS）。

**核心理念**：Phase 2.1~2.8 解决"数据和逻辑正确性"，Phase 2.9 验证"前面设计是否真的适合用户交互"。直接进入 Phase 3 写 Widget 可能出现 UI 推翻核心模型的问题——Phase 2.9 用设计 + Prototype 提前暴露风险。

**关键架构约束（Hard Rules）**：

1. **AST 零污染**：禁止在 `DocumentElement` / `document.dart` 新增 UI 状态字段（isFocused / isSelected / selection 等）。UI 状态单独建模（`BlockViewState`），通过 `BlockId` 关联到 AST
2. **Command Layer 强制**：所有 UI 事件必须经 `EditorCommand` → `TransactionBuilder` → `BlockOperation`，禁止 UI 直接调 `BlockOperations`
3. **BlockRenderer 抽象**：新增 Block 类型只增加 renderer，不改 BlockEditor 核心
4. **Phase 3 冻结边界**：Phase 2.9 只产出设计文档 + Prototype Demo，不修改 `lib/presentation/` 正式代码、不接入生产路由

详见 [Phase 2.9 Task Contract](file:///d:/Projects/Active/math/docs/contracts/phase2.9-task-contract.md) + [ADR-0009](file:///d:/Projects/Active/math/docs/ADR/0009-ui-architecture-design.md)。

### 任务

| # | 任务 | 产出 | 类型 |
|---|------|------|------|
| 2.9.1 | UI 心智模型定义 | [UI-ARCHITECTURE.md](file:///d:/Projects/Active/math/docs/UI-ARCHITECTURE.md) §1-2 | 架构决策类（草案） |
| 2.9.2 | UI 状态模型设计 | UI-ARCHITECTURE.md §3 + [ADR-0009](file:///d:/Projects/Active/math/docs/ADR/0009-ui-architecture-design.md) | 架构决策类（草案） |
| 2.9.3 | 交互事件模型设计 | [Interaction-Model.md](file:///d:/Projects/Active/math/docs/Interaction-Model.md) + ADR-0009 | 架构决策类（草案） |
| 2.9.4 | UI Prototype 验证（4 个 Demo） | `flutter_app/lib/presentation/prototype/` | 新建代码目录 |
| 2.9.5 | 核心接口冻结 | [Component-Tree.md](file:///d:/Projects/Active/math/docs/Component-Tree.md) + ADR-0009 | 架构决策类（草案） |

### 4 个 Prototype Demo

| Demo | 验证内容 | 文件 |
|------|---------|------|
| Demo 1 | 单 Block 双态切换（render ↔ edit + 修改 source round-trip） | `demo1_dual_state_block.dart` |
| Demo 2 | 两个 Block 导航（ArrowDown/Up 在块间移动 focus） | `demo2_block_navigation.dart` |
| Demo 3 | Undo/Redo（UI → Transaction → History 闭环 3 次） | `demo3_undo_redo.dart` |
| Demo 4 | 复杂 Block 共存（Paragraph + 公式 + 代码块 + focus 切换） | `demo4_complex_blocks.dart` |

### 退出条件（Phase 2.9 Exit Gate）

- [ ] 5 个设计文档定稿（Human Owner 签字）
- [ ] ADR-0009 Accepted（Human Owner 签字）
- [ ] ROADMAP 新增 Phase 2.9 节（Human Owner commit）
- [ ] 4 个 Demo 可运行 + 通过手动验证场景
- [ ] flutter analyze 0 warning
- [ ] flutter test 0 regression（Phase 2.8 的 841 tests 仍 PASS）
- [ ] **核心接口冻结**：BlockEditor API / Transaction / BlockRenderer 接口在 Phase 3 不再变更

---

## Phase 3.0：Editor Shell Architecture & Presentation Foundation（编辑器外壳架构与表现层基础）

**目标**：建立 production UI 层的承载结构，把 Phase 2.9 Prototype 验证过的"用户行为 → EditorCommand → CommandHandler → Transaction → BlockViewState → Widget Tree"运行时通路落地到 production 路径，让 Phase 3.1+ 的所有功能有稳定挂载位置。

**定位**：不是"做 UI"，而是**建立 Editor Shell Architecture & Presentation Foundation**。Phase 2 完成的是"编辑内核（Editing Engine）"，Phase 3.0 完成的是"把用户行为接入内核"的运行时层 + 建立 EditorShell（TopBar / Workspace / LeftPanel / EditorViewport / BlockRenderer / StatusBar）的外壳架构。

**类比 VS Code**：VS Code 不是先做插件，而是先建立 Window（Activity Bar / Side Bar / Editor Group / Status Bar / Command System），插件只是挂进去。FormulaFix 的 TOC / 文件树 / 主题 / 字号 / 焦点模式等全部只是插槽扩展。

**前置条件**：Phase 2.9 全部退出（核心接口冻结 + 4 个 Prototype 验证通过 + PR 合并 main）。

**核心理念**：直接进入 Phase 3.1 实现"移除 previewModeProvider / 沉浸式全屏编辑"会面临三大风险——Widget 绕过 Transaction 直接操作 AST（架构落地风险）、为快速实现功能塞进一个"大万能 Controller"（God Object 风险）、3.7 大纲 / 3.8 文件树 / 3.9 主题等任务后补架构（补架构风险）。Phase 3.0 用 EditorShell 先建立稳定边界，让 Phase 3.1+ 变成"挂载到既有插槽"的工程实现。

**关键架构约束（Hard Rules）**：

1. **AST 零污染**（沿用 Phase 2.9）：禁止在 `DocumentElement` 新增 UI 状态字段
2. **Command Layer 强制**（沿用 Phase 2.9）：所有 UI 事件必须经 `EditorCommand` → `CommandHandler`
3. **BlockRenderer 抽象**（沿用 Phase 2.9）：新增 Block 类型只增加 renderer
4. **避免 God Object**（Phase 3.0 新增）：拆为 `EditorCoordinator`（协调）+ `CommandHandler` + `BlockViewModelProvider` + `FocusManager`，Coordinator 只协调不持有业务状态
5. **旧 UI 并存**（Phase 3.0 新增）：旧 `lib/presentation/screens/editor_screen.dart` 保留为 fallback，新 UI 通过 feature flag 切换
6. **复用 Phase 2.9 产出**（Phase 3.0 新增）：commands / states 原位保留，prototype/_shared 迁移到 editor/（重命名为 editor_coordinator.dart）
7. **chrome/ 单独分离**（v1.1 修订）：AppBar / StatusBar / Toolbar 既不是 panel 也不是 editor，按 IDE 架构惯例单独分离到 `chrome/` 目录
8. **依赖方向严格**（v1.1 修订）：`blocks/` 不 import `editor/` / `panels/` / `chrome/`；`editor/` 不 import `panels/`；`chrome/` 不 import `blocks/` / `panels/`
9. **BlockRenderer exhaustive switch**（v1.1 修订）：不允许 `_ =>` fallback 到 GenericBlock，新增 Block 类型必须显式增加 case 分支

详见 [Phase 3.0 Task Contract](file:///d:/Projects/Active/math/docs/contracts/phase3.0-task-contract.md)。

### 任务

| # | 任务 | 产出 | 类型 |
|---|------|------|------|
| 3.0.1 | Presentation Layer 目录结构 | `lib/presentation/{editor,blocks,chrome,panels,themes}/` | 代码骨架 |
| 3.0.2 | Editor Shell（EditorPage + EditorShell + 占位插槽） | `lib/presentation/editor/editor_page.dart` 等 | 代码骨架 |
| 3.0.3 | BlockRenderer（3 类型：paragraph / heading / code，exhaustive switch） | `lib/presentation/blocks/block_renderer.dart` 等 | 代码骨架 |
| 3.0.4 | 数据源接入（InMemoryDocumentEditor + 种子数据 + EditorCoordinator） | `lib/presentation/editor/editor_coordinator.dart` | 代码骨架 |
| 3.0.5 | UI Design Reference | `docs/design/ui-spec.md` | 设计规范 |

### EditorShell 布局

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

### 退出条件（Phase 3.0 Exit Gate）

#### UI 验证
- [ ] `flutter run` 看到 EditorShell 正常显示
- [ ] 3 种 Block（paragraph / heading / code）渲染正确
- [ ] Block 双态切换（render ↔ edit）Demo 可用
- [ ] SidePanel / StatusBar 插槽存在（占位即可）

#### 架构验证
- [ ] Widget 不直接访问 AST（通过 EditorCoordinator）
- [ ] Widget 不直接调用 DocumentEditor mutation（通过 CommandHandler）
- [ ] Command 是唯一用户行为入口
- [ ] EditorCoordinator 不持有业务状态（只协调，文件 ≤ 200 行）
- [ ] AST 零污染（grep 守门通过）
- [ ] **依赖方向守门**（v1.1 修订）：blocks 不 import editor/panels/chrome；editor 不 import panels；chrome 不 import blocks/panels
- [ ] **BlockRenderer exhaustive switch**（v1.1 修订）：不允许 `_ =>` fallback 到 GenericBlock

#### 工程验证
- [ ] `flutter analyze` 0 warning
- [ ] `flutter test` 0 regression（Phase 2.9 的 843 tests 仍 PASS）
- [ ] 新增架构守门测试全 PASS（TC-ARCH-UI-1 ~ 8）

#### 文档验证
- [ ] `docs/design/ui-spec.md` 定稿（Human Owner 签字）
- [ ] Phase 3.0 Verification Report 完成

---

## Phase 3.1+：UI Feature Implementation

**目标**：基于 Phase 3.0 的 UI Runtime Foundation，实现所见即所得 UI 的具体功能。

**前置条件**：Phase 3.0 全部退出（UI Skeleton 建立 + 架构守门通过）。

### 阶段重新划分说明（2026-07-21 修订）

**修订背景**：原 ROADMAP 把"移除预览卡片包裹，改为沉浸式全屏编辑"列为 Phase 3.2 任务。但 Phase 3.1-A 的实际落地（`/editor` → EditorPage 默认入口 + 移除 PreviewContent 卡片包裹 + 移除 `previewModeProvider`）已经**提前完成架构层沉浸式**。继续保留旧 3.2 定义会造成 roadmap drift（开发者看到任务已存在但状态仍为待办，可能误修改已稳定的 EditorShell）。

**沉浸式概念拆分**：

- **架构层沉浸式**（已完成）：无 preview/editor 两个模式、无 PreviewContent 卡片包裹。Phase 3.1-A 已完成。
- **体验层沉浸式**（未完成）：隐藏 chrome、自动隐藏工具栏、打字机模式、焦点模式、页面宽度控制、阅读体验。归入 Phase 3.3。

**新阶段划分**：

| Phase | 主题 | 目标 |
|-------|------|------|
| 3.1 | WYSIWYG Migration | 完成 WYSIWYG 架构迁移（沉浸式基础）✅ |
| 3.2 | Block Runtime Expansion | 完成 Block Runtime 扩展（内容能力） |
| 3.3 | Immersive Experience | 完成 Typora 级沉浸体验（交互体验） |
| 3.4+ | Advanced Capabilities | 高级能力（TOC / 文件树 / 主题 / 导出 / 协作） |

### Phase 3.1 — WYSIWYG Migration（已完成）

**目标**：移除 preview/editor 双模式，EditorPage 成为默认入口，EditorCommand 转 sealed class，BlockId 迁移通知机制建立。

**状态**：✅ Phase 3.1-A 已完成（PR #1 + PR #2 已合并）。Phase 3.1-B/C 为触发制延后项，不阻塞 Phase 3.2。

**Phase 3.1-B/C 可量化触发条件**（避免主观判断）：

| 阶段 | 触发条件（任一满足即启动） | 自动化检测 |
|------|--------------------------|-----------|
| 3.1-B 性能 | (a) `TC-PERF-BLOCK-*` benchmark 回归测试 fail（per-block 解析 > 0.1ms 或 1000 行文档 keystroke latency > 100ms）；(b) 用户反馈编辑卡顿且本地复现 latency > 100ms | benchmark test 在 CI 中每次 PR 自动运行 |
| 3.1-C Undo 正确性 | (a) `undo_redo_test.dart` 等回归测试 fail；(b) 用户反馈 undo 异常且能复现（提供复现步骤） | undo/redo 相关测试在 CI 中每次 PR 自动运行 |

**未触发前的状态**：3.1-B/C 不阻塞 Phase 3.2 / 3.3 / 3.4+，但每次 Phase 3.x PR 的 CI 必须包含上述 benchmark + undo 测试，fail 立即触发对应延后项。

**已交付**：
- `kEnableNewEditor = true`（新 UI 成为默认）
- `/editor` → EditorPage，`/editor-legacy` → EditorScreen（fallback），移除 `/editor3`
- 移除 `previewModeProvider` 重复定义
- `EditorCommand` 转 sealed class
- `replaceBlock` / `replaceBlockKeepId` / `replaceBlockWithMigration` 三方法建立 BlockId 迁移通知机制
- `BaseBlockState.previousMode` 改为抽象方法（强制子类实现）
- `EditorScope` 移除 `maybeOf` 变体

### Phase 3.2 — Block Runtime Expansion（Conditionally Complete）

**目标**：从最小可编辑系统（paragraph / heading / code 三种 BlockType）扩展为完整 Markdown Block Runtime，支持剩余 BlockType + 建立 `blocks/<type>/` 目录结构。

**前置条件**：Phase 3.1-A 完成（已满足）。

**状态**：⚠️ Conditionally Complete（核心能力已交付,2 项延期至 Phase 3.5+。详见 [Phase 3.2 Verification Report](./releases/phase3.2-verification-report.md)）

**核心理念**：Phase 3.0 只验证了 3 种 BlockType 的 BlockRenderer exhaustive switch 通路。Phase 3.2 解决"从最小可编辑系统 → 完整 Markdown Block Runtime"。Block 数量增加后，真正的问题会出现（Block 间共享逻辑、Block 工具栏、Block 选中、Block 拖拽），所以 Phase 3.2 必须同时建立 `blocks/<type>/` 目录结构 + `blocks/shared/` 共享组件，避免 Phase 3.5+ 再次重构。

> **Closure 修订（2026-07-22）**：原计划 10 个任务,实际交付 8 个 + 2 个延期至 Phase 3.5+。延期项不影响"完整 Markdown Block Runtime"核心能力达成（用户可打开含表格/引用/Mermaid 的 .md 文档正常编辑）。详见 §任务表与 Verification Report。

### 任务

| # | 任务 | 来源 | 状态 | 备注 |
|---|------|------|------|------|
| 3.2.1 | MathBlock（行内 + 块级公式） | ui-spec.md §7 | 🔻 **延期** | 延期至 Phase 3.5：依赖 `FormulaSvgService` 成熟 + AST 表达方式评审 |
| 3.2.2 | MermaidBlock（流程图 / 时序图） | ui-spec.md §7 | ✅ 已交付 | PR #3：封装 MermaidElementWidget + WebView 未就绪 fallback |
| 3.2.3 | QuoteBlock（引用块） | ui-spec.md §7 | ✅ 已交付 | PR #2 |
| 3.2.4 | TableBlock（基本渲染 + 双态,可视化编辑留 Phase 3.3） | ui-spec.md §7 | ✅ 已交付 | PR #2 |
| 3.2.5 | Image Inline Rendering Enhancement | ui-spec.md §7 | ✅ 已交付 | PR #2：扩展 ParagraphBlock inline renderer |
| 3.2.6 | Link Inline Rendering Enhancement | ui-spec.md §7 | ✅ 已交付 | PR #2：扩展 ParagraphBlock inline renderer |
| 3.2.7 | `blocks/<type>/` 目录结构 + `blocks/shared/`（block_toolbar / block_selection / block_drag_handle） | 架构演进 | 🟡 **部分** | 目录重组 ✅（PR #1）,shared/ 3 个组件延期 Phase 3.5+（见下） |
| 3.2.8 | WebView 预热机制 | Phase 3.1 原 3.4 | ✅ 已交付（退化） | PR #3：复用 MermaidService,退化为预热机制 |
| 3.2.9 | Mermaid 渲染缓存 | Phase 3.1 原 3.5 | ✅ 已交付 | PR #3：复用 MermaidService LRU（256 entries / 32MB） |
| 3.2.10 | 代码块语法高亮 | Phase 3.1 原 3.6 | ✅ 已交付 | PR #3：flutter_highlight 0.7.0 + githubTheme |

**Closure 决议（2026-07-22,Human Owner 审批）**：

1. **MathBlock（§3.2.1）延期至 Phase 3.5**：
   - 公式渲染不应直接走 Mermaid 路径,`FormulaSvgService` 尚未成熟
   - AST 表达方式（`FormulaElement` vs 新类型）需评审
   - Phase 3.5 设立专门的 "Formula Rendering" 任务

2. **blocks/shared/ 3 个共享组件延期至 Phase 3.5+**：
   - 实际验证发现系统在缺少 BlockToolbar / BlockSelection / BlockDragHandle 时仍正常工作
   - 原设计被高估,3 个组件并非 Phase 3.2 核心能力
   - 为避免"为满足合同而写死代码"（技术债）,正式延期

详见 [Phase 3.2 Task Contract v1.3](./contracts/phase3.2-task-contract.md) §10 Closure Decisions 与 [Phase 3.2 Verification Report](./releases/phase3.2-verification-report.md)。

### Phase 3.3 — Mobile Markdown Editing Experience

**目标**：完成移动端 Markdown 输入体验。聚焦手机端真正高价值的输入辅助能力。**不追求**桌面化能力（快捷键、打字机模式延期至 Phase 3.4 Desktop Enhancement）。

**核心洞察**（v1.2 产品方向调整,Human Owner 2026-07-22）：桌面用户靠键盘快捷键,手机用户靠输入辅助。这是两套完全不同的交互体系。

**v1.4 架构评审 R3 调整（Human Owner 2026-07-22,9.0/10 评分后 Accepted）**：
- Markdown 工具栏（§3.3.7）提升为 Phase 3.3 **核心任务**,单独成 PR #2（v1.3 已落实）
- 自动配对（§3.3.6）缩减范围：禁止 `*`/`$`/`#`/`-`/`>` 无条件补全（v1.3 已落实）
- 字号缩放（§3.3.2）P1 确认（v1.3 已降级,R3 确认）
- **§3.3.9 选区格式化菜单整体延期至 Phase 3.4 §3.4.10**（v1.4 新增,选区包裹能力作为 §3.3.7 工具栏内置模式保留）
- **新增 §3.3.10 Markdown 模板插入菜单（P1）**：释放 Phase 3.2 TableBlock/MermaidBlock 成果

**v1.4 R4 PR 拆分调整（Human Owner 2026-07-22）**：
- §3.3.10 模板插入菜单从 PR #4 移至 PR #2 扩展（架构耦合：Toolbar → Template Menu）
- PR #4 仅保留 §3.3.2 + §3.3.3（字号缩放 + 焦点模式）,与工具栏解耦
- 详见 [Phase 3.3 Task Contract §8.1](./contracts/phase3.3-task-contract.md#81-分-pr-建议4-个-prv14-调整--r4-pr-拆分)

**详细 Task Contract**：[Phase 3.3 Task Contract v1.4](./contracts/phase3.3-task-contract.md)（Accepted,架构评审 R3 9.0/10）

### 任务（9 个,6 项 P0 + 3 项 P1）

| # | 任务 | 优先级 | 状态 |
|---|------|--------|------|
| 3.3.1 | AppBar 显示文档标题 + 修改状态（`•`） | P0 | ⏳ |
| 3.3.2 | 字号缩放（双指缩放 + 按钮 + 重置） | **P1**（v1.3 降级,R3 确认） | ⏳ |
| 3.3.3 | 焦点模式（隐藏 chrome,双击退出） | P1 | ⏳ |
| 3.3.4 | 实时字数统计（底部状态栏） | P0 | ⏳ |
| 3.3.5 | 撤销 / 重做按钮接入 UI（`HistoryManager` 已实现） | P0 | ⏳ |
| 3.3.6 | 自动配对（**仅 `(`/`[`/`{`/`` ` ``,v1.3 缩减范围**） | P0 | ⏳ |
| 3.3.7 | **Markdown 工具栏（核心任务）**：11 按钮 + 选区包裹模式（内置） | **P0 核心** | ⏳ |
| 3.3.8 | 自动续列表 / 引用 / 代码块（回车自动续行） | P0 | ⏳ |
| 3.3.10 | **Markdown 模板插入菜单（v1.4 新增 P1）**：`+` 按钮,表格/Mermaid/代码块/任务列表模板 | P1 | ⏳ |

### 已延期至 Phase 3.4 Desktop Enhancement（v1.4 调整）

| 原任务 | 去向 | 理由 |
|--------|------|------|
| 3.3.7 快捷键支持（v1.0） | Phase 3.4 §3.4.5 | 手机端无 Ctrl 键,ROI 极低。手机用户靠输入辅助,不靠键盘快捷键 |
| 3.3.3 打字机模式（v1.0） | Phase 3.4 §3.4.6 | 手机端软键盘已占半屏,TextField 自带滚动 |
| 3.3.9 选区格式化菜单（v1.2,v1.4 整体延期） | Phase 3.4 §3.4.10 | Flutter Overlay + TextSelection + 光标坐标 + 滚动同步复杂度高,Phase 3.3 风险敏感。选区包裹能力已作为 §3.3.7 工具栏内置模式保留 |

### Phase 3.4+ — Advanced Capabilities

**目标**：高级能力扩展（TOC / 文件树 / 主题 / 导出 / 协作 / 桌面化等）。

### 任务

| # | 任务 | 来源 | 状态 |
|---|------|------|------|
| 3.4.1 | 大纲 / TOC 侧滑面板，点击跳转标题 | Phase 3.1 原 3.7 | ⏳ |
| 3.4.2 | 文件树侧滑（替代文件管理独立屏幕） | Phase 3.1 原 3.8 | ⏳ |
| 3.4.3 | 多套主题（GitHub / Night / Sepia / Newsprint） | Phase 3.1 原 3.9 | ⏳ |
| 3.4.4 | 导出进度反馈（百分比 + 当前公式计数） | Phase 3.1 原 3.17 | ⏳ |
| 3.4.5 | 快捷键支持（Android 物理键盘 + Web,Phase 3.3 v1.0 延期项） | Phase 3.3 v1.0 原 3.3.7 | ⏳ |
| 3.4.6 | 打字机模式（光标行居中,Phase 3.3 v1.0 延期项） | Phase 3.3 v1.0 原 3.3.3 打字机部分 | ⏳ |
| 3.4.7 | 自动保存（dirty tracking 只做状态,自动保存逻辑留 Phase 3.4+） | Phase 3.3 v1.2 边界 | ⏳ |
| 3.4.8 | 页面宽度控制（max-width 720px） | Phase 3.3 v1.2 边界 | ⏳ |
| 3.4.9 | Markdown 图片插入（从相册选图） | Phase 3.3 v1.2 边界 | ⏳ |
| 3.4.10 | 选区格式化菜单（Overlay 浮动菜单,Phase 3.3 v1.4 延期项,选区包裹已作为 §3.3.7 工具栏内置模式） | Phase 3.3 v1.2 原 3.3.9 | ⏳ |

### 退出条件（Phase 3.1+ 整体）

- [x] 用户不再需要切换"编辑/预览"模式（Phase 3.1-A 已完成）
- [x] WebView 预热机制建立（Phase 3.2 已交付,退化实现：复用 MermaidService.awaitPageLoaded）
- [x] 8 种 BlockType 支持双态切换（Phase 3.2 已交付：paragraph / heading / code / quote / table / mermaid + image/link inline）
- [ ] MathBlock 双态切换（Phase 3.5：原 Phase 3.2 §3.2.1 延期）
- [ ] blocks/shared/ 3 个共享组件（Phase 3.5+：原 Phase 3.2 §3.2.7 部分延期）
- [ ] 21 项 Typora 核心特性对齐度 ≥ 80%（Phase 3.3+）

### Phase 3.5 — Deferred Block Runtime Items

**目标**：承接 Phase 3.2 延期项 + 公式渲染系统专项。Phase 3.3 / 3.4 可并行推进,不阻塞本阶段。

**前置条件**：Phase 3.2 Conditionally Complete（已满足）。

### 任务

| # | 任务 | 来源 | 状态 |
|---|------|------|------|
| 3.5.1 | MathBlock（行内 + 块级公式） — 依赖 `FormulaSvgService` 成熟 + AST 表达方式评审（`FormulaElement` vs 新类型） | Phase 3.2 §3.2.1 延期 | ⏳ |
| 3.5.2 | `blocks/shared/block_toolbar.dart` — Block 工具栏（移动 / 删除 / 转换类型） | Phase 3.2 §3.2.7 延期 | ⏳ |
| 3.5.3 | `blocks/shared/block_selection.dart` — Block 选中状态视觉反馈 | Phase 3.2 §3.2.7 延期 | ⏳ |
| 3.5.4 | `blocks/shared/block_drag_handle.dart` — Block 拖拽重排序 | Phase 3.2 §3.2.7 延期 | ⏳ |

**说明**：3.5.2-4 是否合并实施取决于 Phase 3.3 交互体验推进时是否真正需要这些组件。若 Phase 3.3 推进中发现 BlockToolbar 是硬需求,可提前从 Phase 3.5 拉回 Phase 3.3 实施。

---

## Phase 4：多平台与高级功能

**目标**：扩展到桌面 / Web，并加入协同等高级功能。

### 任务（暂不细化）

- 4.1 桌面端适配（macOS / Windows / Linux）：键盘快捷键、多窗口
- 4.2 Web 端 PWA 优化
- 4.3 iCloud / Dropbox 同步
- 4.4 文档加密（生物识别解锁）
- 4.5 自定义 CSS 主题
- 4.6 插件系统

---

## 风险与依赖

| 风险 | 影响范围 | 缓解措施 |
|------|---------|---------|
| `flutter_app/android/` 目录缺失 | build-android job | ~~CI 中 `flutter create --platforms=android .` 动态生成~~ ✅ 已补齐（AGP 8.7.3 + compileSdk 36） |
| 依赖版本兼容性（inappwebview / file_picker / pdf） | Phase 0 阻塞 | ~~逐个 pin 版本或 dependency_overrides~~ ✅ 已解决（0.7） |
| 范式重构失败 | Phase 2 延期 | 渐进式、feature flag |
| 数据迁移丢用户文档 | Phase 1.2 | 备份 + 回滚脚本 |
| WebView 性能瓶颈 | Phase 3 | 预热 + 缓存 + 异步渲染 |
| 测试覆盖不足 | 全程 | Phase 1.8 补齐 |
| UI 在 Phase 1-2 退化 | 用户体验 | Phase 0 UI Prototype Freeze 明确预期 |

---

## 节奏

- **不预测时间**：每个任务完成后才进入下一个，不强行按时间表
- **不跳阶段**：Phase 0 不完成不进 Phase 1
- **不混阶段**：底层重构不与 UI 实现混在同一 PR
- **Phase 1-2 UI 退化可接受**：这是"UI Prototype Freeze"策略的核心——底层重构优先，UI 在 Phase 3 重建

---

**当前阶段**：Phase 3.3 — Mobile Markdown Editing Experience（v1.4 Accepted,启动 PR 待人工创建）
**最近更新**：2026-07-22（Phase 3.2 Closure Conditionally Complete + Phase 3.3 Task Contract v1.4 R4 PR 拆分调整 + 优先级统计修正 6P0+3P1）
**维护人**：首席架构工程师
