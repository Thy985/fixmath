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
| 2.7 | Markdown 快捷输入映射（`# ` → 标题块，`- ` → 列表块 等） | 用户习惯保留 | ✅ 已完成（`block_operations.dart:tryTransform` + `BlockOpType.transform` + split 自动 transform + `command_handler.dart` 集成） |

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

- [x] 块编辑内核可脱离 UI 独立运行（纯 Dart 逻辑）— Phase 2.8 已验证
- [x] 所有块类型有单元测试覆盖 — Phase 2.8 已验证（9 种 BlockType 全覆盖）
- [x] 1000 行文档增量解析 < 16ms — Phase 2.8 已验证（per-block 0.0752ms）
- [x] 中文输入法组合态正确处理 — Phase 2.8 已验证（TC-EDIT-8.3 16 测试）

> Phase 2 退出条件已于 Phase 2.8 Exit Gate 通过时全部满足，详见 [Phase 2 Exit Gate Report](./releases/phase2-exit-gate-report.md)。

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

- [x] 5 个设计文档定稿（Human Owner 签字）— UI-ARCHITECTURE.md / Interaction-Model.md / Component-Tree.md / ui-spec.md 已定稿
- [x] ADR-0009 Accepted（Human Owner 签字）
- [x] ROADMAP 新增 Phase 2.9 节（Human Owner commit）
- [x] 4 个 Demo 可运行 + 通过手动验证场景 — `lib/presentation/prototype/demo1-4_*.dart`
- [x] flutter analyze 0 warning
- [x] flutter test 0 regression（Phase 2.8 的 841 tests 仍 PASS）
- [x] **核心接口冻结**：BlockEditor API / Transaction / BlockRenderer 接口在 Phase 3 不再变更 — Phase 3.0~3.7 全部基于冻结接口实现，无回头修改 Phase 2 接口

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
| 3.3.1 | AppBar 显示文档标题 + 修改状态（`•`） | P0 | ✅ 已合入 main（PR #58/#60：`EditorAppBar`） |
| 3.3.2 | 字号缩放（双指缩放 + 按钮 + 重置） | **P1**（v1.3 降级,R3 确认） | ✅ 已合入 main（PR #65：`EditorShell._zoomScale` + `MediaQuery.textScaler`） |
| 3.3.3 | 焦点模式（隐藏 chrome,双击退出） | P1 | ✅ 已合入 main（PR #65：`EditorShell._focusMode` + `_toggleFocus`） |
| 3.3.4 | 实时字数统计（底部状态栏） | P0 | ✅ 已合入 main（PR #60：`EditorStatusBar` 显示 `coordinator.wordCount`） |
| 3.3.5 | 撤销 / 重做按钮接入 UI（`HistoryManager` 已实现） | P0 | ✅ 已合入 main（PR #58/#60：`EditorAppBar` Undo/Redo 按钮） |
| 3.3.6 | 自动配对（**仅 `(`/`[`/`{`/`` ` ``,v1.3 缩减范围**） | P0 | ✅ 已合入 main（PR #63：`InputHandler` + `AutoPairRules`） |
| 3.3.7 | **Markdown 工具栏（核心任务）**：11 按钮 + 选区包裹模式（内置） | **P0 核心** | ✅ 已合入 main（PR #59/#61：`MarkdownToolbar` 11 按钮 + 横向滚动） |
| 3.3.8 | 自动续列表 / 引用 / 代码块（回车自动续行） | P0 | ✅ 已合入 main（PR #63：`InputHandler` + `AutoContinueRules`） |
| 3.3.10 | **Markdown 模板插入菜单（v1.4 新增 P1）**：`+` 按钮,表格/Mermaid/代码块/任务列表模板 | P1 | ✅ 已合入 main（PR #62：`TemplateMenuButton` 8 模板 + `InsertTemplateCommand`） |

### Phase 3.3 关闭说明

Phase 3.3 Mobile Markdown Editing Experience 全部 9 个任务已完成并合入 main（PR #58-#67）：

- **Chrome 集成**（PR #58/#60）：`EditorAppBar`（标题+修改状态+Undo/Redo） + `EditorStatusBar`（字数统计+缩放控制）
- **Markdown 工具栏**（PR #59/#61）：11 按钮 + 选区包裹 + 横向滚动 + CodeBlock 禁用
- **模板插入菜单**（PR #62）：8 模板（表格/Mermaid/代码块/任务列表/引用/分隔线/图片/链接）
- **自动配对 + 自动续行**（PR #63）：`InputHandler` 统一调度 + `AutoPairRules`/`AutoContinueRules`
- **字号缩放 + 焦点模式**（PR #65）：双指缩放 + 按钮 + 重置 + 隐藏 chrome 焦点模式
- **E2E 门禁**（PR #66/#67）：E2E gate 全绿 + God Object 守门合规

**延期项**：选区格式化菜单（原 3.3.9）按 Task Contract 决策整体移入 Phase 3.4 §3.4.10。

### 已延期至 Phase 3.4 Desktop Enhancement（v1.4 调整）

| 原任务 | 去向 | 理由 |
|--------|------|------|
| 3.3.7 快捷键支持（v1.0） | Phase 3.4 §3.4.5 | 手机端无 Ctrl 键,ROI 极低。手机用户靠输入辅助,不靠键盘快捷键 |
| 3.3.3 打字机模式（v1.0） | Phase 3.4 §3.4.6 | 手机端软键盘已占半屏,TextField 自带滚动 |
| 3.3.9 选区格式化菜单（v1.2,v1.4 整体延期） | Phase 3.4 §3.4.10 | Flutter Overlay + TextSelection + 光标坐标 + 滚动同步复杂度高,Phase 3.3 风险敏感。选区包裹能力已作为 §3.3.7 工具栏内置模式保留 |

### 阶段状态评估（2026-08-03 更新，Phase 3.4.5 已落地）

> Phase 3.4.5 Design System Alignment 已落地：主色 `#1E3A5F` / 衬线字体 / 暖纸背景 / 公式块已完成。视觉完成度从 ~40% 提升至 ~60%。

### 双线模型

FormulaFix 当前状态：

| 维度 | 完成度 | 说明 |
|------|--------|------|
| **Engineering Foundation（工程地基）** | **~95%** | 编辑内核 / 块运行时 / 持久化链 / 自动保存 / 文件树 / TOC / 导出进度 / 图片全链路 / 可观测系统 / Core+Extended E2E 均已落地并通过 |
| **Visual / Product Identity（视觉与产品识别）** | **~60%** | Design System 对齐（主色 `#1E3A5F`/衬线字体/暖纸背景/公式块）已落地；UI 修复 P0-P1 完成，P2-P3 进行中 |

当前架构已建立完整链路：

```
设计 Token ─→ ThemeExtension ─→ Widget ─→ Renderer   ← 已建立（Phase 3.4.5）
```

---

## Phase 3.4+ — Advanced Capabilities

**目标**：高级能力扩展（TOC / 文件树 / 主题 / 导出 / 协作 / 桌面化等）。

### 任务

| # | 任务 | 来源 | 状态 |
|---|------|------|------|
| 3.4.1 | 大纲 / TOC 侧滑面板，点击跳转标题 | Phase 3.1 原 3.7 | ✅ 已合入 main（PR #69） |
| 3.4.2 | 文件树侧栏（EditorShell 内嵌 ☰，与 /files 共存共享 DocumentRepository，不复制逻辑） | Phase 3.1 原 3.8 | ✅ (#77) |
| 3.4.3 | 多套主题（light / dark / sepia 三值循环切换） | Phase 3.1 原 3.9 | ✅ 已合入 main（PR #71：`AppThemeMode` + `themeFor()` + `onCycleTheme`） |
| 3.4.4 | 导出进度反馈（Idle/InProgress/Completed/Failed 状态机） | Phase 3.1 原 3.17 | ✅ 已合入 main（PR #78：`ExportProgressOverlay` + `ExportProgressNotifier`） |
| 3.4.5 | 快捷键支持（Android 物理键盘 + Web） | Phase 3.3 v1.0 原 3.3.7 | ⏳（按 Task Contract 决策移 Phase 4 Desktop Enhancement） |
| 3.4.6 | 打字机模式（光标行居中） | Phase 3.3 v1.0 原 3.3.3 打字机部分 | ⏳（按 Task Contract 决策移 Phase 4 Desktop Enhancement） |
| 3.4.7 | 自动保存（独立 AutosaveService,debounce 1.5s + 失败退避重试） | Phase 3.3 v1.2 边界 | ✅ 已合入 main（PR #70） |
| 3.4.8 | 页面宽度控制（max-width 720px） | Phase 3.3 v1.2 边界 | ✅ 已合入 main：`kMaxPageWidth = 720.0`（workspace.dart） |
| 3.4.9 | Markdown 图片插入（从相册选图,assets/ 副本） | Phase 3.3 v1.2 边界 | ✅ 已合入 main：`imagePickAndImportProvider` + `AssetService.pickAndImportImage` |
| 3.4.10 | 选区格式化菜单（Overlay 浮动菜单,选区包裹已作为 §3.3.7 工具栏内置模式） | Phase 3.3 v1.2 原 3.3.9 | ⏳ 未实现 |

> **状态图例**：✅ 已合入 main ／ 🔶 已实现·PR 评审中（未合入 main）／ ⏳ 未启动。
> **进度同步自** [Phase 3.4 Task Contract v1.2](contracts/phase3.4-task-contract.md)（PR #68 已合入 main）；切片 1/2/3/7 分别对应 PR #69 / #70 / #71 / #78。
> 3.4.5 / 3.4.6 快捷键 / 打字机按 Task Contract §9.5 决策整体移入 Phase 4 Desktop Enhancement 子阶段,本阶段不再跟踪。

## Phase 3.4.5 — Design System Alignment（产品化对齐）

**目标**：从 "Functional Editor" 变成 "FormulaFix Product Identity"。把 redesign 的视觉语言（深蓝主色 + 暖纸 + 衬线 + 公式块）接入生产 UI，建立 `Design Token → ThemeExtension → Widget → Renderer` 的单向链路。

**前置条件**：Phase 3.4+ Advanced Capabilities 主体完成（TOC / 自动保存 / 主题架构 / 文件树 / 图片链路已落地）。

**核心理念**：本阶段只做"换皮 + 公式块 UI 原型"，不做公式渲染内核（内核留 Phase 3.5）。最高 ROI 在 **P0-1（主色）+ P0-2（字体）**，单项即可让观感接近设计 ~60%。

**关联 ADR**：[ADR-0017 Design System Token & Typography Alignment](ADR/0017-design-system-alignment.md)（新增，定义 token 单一真相源 + 字体系统 + "Widget 禁止硬编码颜色" 守门）；[ADR-0015 Theme Architecture Migration](ADR/0015-theme-architecture-migration.md)（机制：static const → ThemeExtension，本阶段补**值**）。

### 任务

| # | 任务 | 优先级 | 来源 | 状态 |
|---|------|--------|------|------|
| 3.4.5.1 | **Design Token Migration**：建立 `AppColors`（`primary=#1E3A5F` / `accent=#E76F51` / `paper=#FAFAF7` / `textPrimary` / `textSecondary` / `border` / `success` / `warning` / `error`），经 `EditorTokens`（ThemeExtension）注入；所有散落颜色改为引用 token，**Widget 禁止硬编码颜色** | **P0** | ADR-0017 | ✅ 已交付（feat/design-system-alignment） |
| 3.4.5.2 | **Typography System**：建立 `AppTypography`（display / h1 / h2 / body / caption / formula / code），正文+标题+公式用 serif（`Source Han Serif SC` 中文回退），代码用 mono（`JetBrains Mono`）；`ThemeData` 设 `fontFamily` | **P0** | ADR-0017 | ✅ 已交付（feat/design-system-alignment） |
| 3.4.5.3 | **Theme Refinement**：`light` / `dark` / `sepia` 三套主题对齐 token 值（背景/语义色/公式块底）；间距/圆角/字号微调（页边距 24 / 段距 20 / 圆角 6·10·16 / 状态栏 32px） | **P0** | ADR-0017 / ui-spec | ✅ 已交付（feat/design-system-alignment） |
| 3.4.5.4 | **Formula Block（Typora 严格还原）**：`FormulaBlock` 渲染块级公式 `$$...$$`——纯 serif italic、居中、**无卡片**（ui-spec 权威裁定，覆盖 `tokens.json` 旧卡片规格）；真实渲染经 `FormulaSvgService` 渲染 MathJax SVG（与 Mermaid 共享 WebView），未就绪降级为 serif italic 源码；颜色经 `EditorTokens`、字族经 `AppTypography.formula`。集成于 `ParagraphBlock`（纯块级公式委派，不新增 BlockRenderer case） | **P0**（用户提前拉入 P0-3） | ui-spec / Phase 3.5 | ✅ 已交付（feat/design-system-alignment） |

### 实施原则（来自审计结论）

1. **不散落改色**：所有颜色进 `AppColors` / `EditorTokens`，Widget 经 `EditorTokens.of(context)` 取色；grep 守门 `Color(0x` 字面量在 presentation 层零残留（豁免：token 定义文件本身）。
2. **字体拆 Typography**：公式样式不写死在 `FormulaBlock`，由 `AppTypography.formula` 提供（serif + italic + 18sp）。
3. **公式块真实渲染（已落地）**：3.4.5.4 经 `FormulaSvgService` 渲染真实 MathJax SVG（与 Mermaid 共享 WebView），未就绪降级为 serif italic 源码，**不再造假卡片**。设计冲突以 ui-spec 为准：公式块为 Typora 无卡片（非 `tokens.json` 旧卡片规格，已在 tokens.json 修订对齐）。
4. **首页降级为 P1**：核心用户路径是 打开→编辑→公式→保存，非首页浏览；Home redesign 作为 Phase 3.5+ 的 P1 跟进（当前 `DocumentListScreen` 为占位桩）。

### 退出条件（Phase 3.4.5 Exit Gate）

- [x] `AppColors` 为颜色单一真相源；`EditorTokens`（ThemeExtension）三主题注入 redesign token 值
- [x] 主色从 `#165DFF` 切换为 `#1E3A5F`；accent `#E76F51` 生效
- [x] `ThemeData` 设 serif `fontFamily`（含中文 serif 回退），正文/标题/公式为衬线、代码为 mono
- [x] 背景暖纸 `#FAFAF7`、border / 语义色对齐 token
- [x] presentation 层无 `Color(0x..)` 硬编码（grep 守门；仅 token 定义文件 `app_theme.dart`/`editor_tokens.dart` 保留字面量，Widget 层经 `AppColors`/`EditorTokens` 取色）
- [x] FormulaBlock 渲染出 Typora 规格公式块（纯 serif italic + 居中 + 无卡片；真实 SVG 或源码降级；颜色/字族走 token）
- [x] `flutter analyze` 0 warning；`flutter test` 0 regression
- [x] Phase 3.4.5 Verification Report 完成（docs/releases/phase3.4.5-verification-report.md）

---

### 退出条件（Phase 3.1+ 整体）

- [x] 用户不再需要切换"编辑/预览"模式（Phase 3.1-A 已完成）
- [x] WebView 预热机制建立（Phase 3.2 已交付,退化实现：复用 MermaidService.awaitPageLoaded）
- [x] 8 种 BlockType 支持双态切换（Phase 3.2 已交付：paragraph / heading / code / quote / table / mermaid + image/link inline）
- [ ] MathBlock 双态切换（Phase 3.5：原 Phase 3.2 §3.2.1 延期）
- [x] blocks/shared/ 3 个共享组件（Phase 3.5.3-5 已交付：BlockToolbar / BlockSelection / BlockDragHandle）
- [x] **Phase 3.3 Mobile Markdown Editing Experience**（9 个任务全部完成，详见 Phase 3.3 节）
- [x] **Phase 3.4.5 Design System Alignment 完成**（主色 `#1E3A5F` / 字体 serif / 背景暖纸 / 语义色对齐 redesign token）
- [ ] 21 项 Typora 核心特性对齐度 ≥ 80%（Phase 3.3+ 体验增强）

### Phase 3.5 — Formula Rendering System（公式渲染系统）

**目标**：FormulaFix 的差异化立身之本——把 "Markdown 编辑器 + 数学公式 + WYSIWYG" 真正打通。承接 Phase 3.4.5 的 FormulaBlock UI 原型（§3.4.5.4），落地真实公式渲染内核。

**前置条件**：Phase 3.4.5 Design System Alignment 完成（公式块视觉原型就绪 + token 体系到位）。

**核心理念**：市场上 Markdown + WYSIWYG 编辑器很多，但 "Markdown + 数学公式 + WYSIWYG" 才是 FormulaFix 的定位。公式块不能提前做假卡片（见 §3.4.5.4），必须等 **ADR + AST 定稿** 后实施。公式渲染不应直接走 Mermaid 路径，`FormulaSvgService` 成熟度 + AST 表达方式（`FormulaElement` vs 新类型）需评审。

### 任务（Formula Rendering 主线）

| # | 任务 | 来源 | 状态 |
|---|------|------|------|
| 3.5.1 | **Formula Rendering System**：统一 `FormulaRenderer`（行内/块级单路径，ui-spec §7 无卡片 serif italic 落地）、`FormulaElement` AST 评审（inline 元素 + `displayMode` 字段，不新增块类型守 exhaustive-switch）、行内公式统一渲染路径、`FormulaRenderer` 抽取、块级公式**编号**（serif italic 居中，无卡片）、双内核降级（块级 `FormulaSvgService` MathJax SVG 优先 + `flutter_math_fork` 兜底；行内 `flutter_math_fork` 优先 + serif 源码兜底） | Phase 3.2 §3.2.1 延期 + Phase 3.4.5 Task 4 | ✅ 完成（分支 `feat/formula-rendering-system`） |
| 3.5.2 | 公式主题适配：公式块底色 / 编号色随 `EditorTokens` 三主题切换（依赖 §3.4.5.3） | ADR-0017 | ✅ 完成（`FormulaRenderer` 颜色读 `EditorTokens.textPrimary/textSecondary`，三主题切换） |

### 并行轨道：Deferred Block Runtime Items（非公式，原 Phase 3.5 延期项）

> 以下 3 项来自 Phase 3.2 延期，与公式渲染无直接耦合，按 Phase 3.3 交互推进需要择机拉回，不阻塞 Phase 3.5 主线。

| # | 任务 | 来源 | 状态 |
|---|------|------|------|
| 3.5.3 | `blocks/shared/block_toolbar.dart` — Block 工具栏（移动 / 删除 / 转换类型） | Phase 3.2 §3.2.7 延期 | ✅ 完成（分支 `feat/block-interaction`） |
| 3.5.4 | `blocks/shared/block_selection.dart` — Block 选中状态视觉反馈 | Phase 3.2 §3.2.7 延期 | ✅ 完成（分支 `feat/block-interaction`） |
| 3.5.5 | `blocks/shared/block_drag_handle.dart` — Block 拖拽重排序 | Phase 3.2 §3.2.7 延期 | ✅ 完成（分支 `feat/block-interaction`） |

**说明**：3.5.3-5 已于 2026-07-28 在分支 `feat/block-interaction` 合并实施：BlockToolbar（上移/下移/删除/转换类型，经 `EditorCoordinator.handle` 派发 Command）+ BlockSelectionChrome（focusedId 选中描边 + 悬浮工具条）+ BlockDragHandle（ReorderableDragStartListener）；`EditorViewport` 改为 `ReorderableListView.builder`（`buildDefaultDragHandles:false`）+ `onReorderItem` → `MoveBlockCommand` 自由拖拽重排。依赖守门 TC-ARCH-UI-1/5 保持。

---

## Phase 3.6：Editor Reliability & Behavioral Verification（E2E Test）

**目标**：建立编辑器可靠性验证层，覆盖用户真实路径和跨层协作链路。采用分层验证策略——Core E2E 验证核心状态机，Extended E2E 覆盖边界场景，Patrol 覆盖真机系统交互。

**前置条件**：Phase 3.5 完成（Block 交互三件套就绪）。

### Phase 3.6.1：Core E2E（✅ 已完成 2026-08-02）

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 3.6.1.1 | E2E 测试基础设施 | `integration_test/e2e/helpers/`（e2e_app / e2e_editor / e2e_assertions） | ✅ |
| 3.6.1.2 | Domain 层测试骨架 | `test/integration/e2e/`（split_merge / format / selection_cursor） | ✅ |
| 3.6.1.3 | E2E-CORE-001 持久化闭环 | 测试通过（编辑 → autosave → 关 App → 重开 → 一致） | ✅ |
| 3.6.1.4 | E2E-CORE-002 回车分块 | 测试通过（用户层 + 光标契约） | ✅ |
| 3.6.1.5 | E2E-CORE-003 Block Merge | 测试通过（用户层 + 光标契约） | ✅ |
| 3.6.1.6 | E2E-CORE-004 Transaction Undo | 测试通过（工具栏路径 + 跨 session） | ✅ |
| 3.6.1.7 | E2E-CORE-005 Format Roundtrip | 测试通过（真实选中 + 语义 round-trip） | ✅ |
| 3.6.1.8 | E2E-CORE-006 Typing Coalescing | 测试通过（工具栏 Undo 路径） | ✅ |

### Phase 3.6.2：Extended E2E + Patrol 接入（✅ 已完成 2026-08-03，真机/模拟器验证通过）

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 3.6.2.1 | Patrol 接入 | `pubspec.yaml` + `patrol/` 目录 + `patrol` CLI 4.8.0 | ✅ |
| 3.6.2.2 | E2E-EXT-001 CodeBlock Enter | 代码块内 Enter 不产生新 Block | ✅ |
| 3.6.2.3 | E2E-EXT-002 List Contract | 契约定义 + `skip: true` + TODO | ✅ |
| 3.6.2.4 | E2E-EXT-003 Transaction Failure Recovery | 异常后编辑器可继续编辑 | ✅ |
| 3.6.2.5 | E2E-EXT-004 Unsaved Mutation Isolation | 未保存修改不污染持久化 | ✅ |
| 3.6.2.6 | E2E-EXT-005 IME Composition | Patrol 测试（skip: 待真机环境） | ✅ |
| 3.6.2.7 | E2E-EXT-006 Physical Keyboard | Patrol 测试（skip: 待真机环境） | ✅ |

### 详细文档

详见 [E2E_TEST_PLAN.md](./E2E_TEST_PLAN.md)。

---

## Phase 3.7：Editor Observability System（编辑器可观测系统）

**目标**：从"验证失败"升级为"解释失败"。建立编辑器状态链路可见性，在每次 Transaction commit 后自动验证核心不变量，为开发者提供跨层（Interaction → Command → Transaction → AST）的因果链追踪能力。

**核心设计**：ADR-0023，五层架构 + Invariant Checker + Export Pipeline。

**前置条件**：Phase 3.6 全部退出。

### 任务

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 3.7.1 | 基础诊断（`EditorTraceContext`、`CommandTracer`、`TransactionTracer`、`InvariantChecker`、`CanonicalFingerprint`、`ObservabilityService`） | `lib/core/observability/` 8 文件 + CommandHandler/TransactionBuilder/EditorCoordinator 注入 | ✅ 已完成（2026-08-03） |
| 3.7.2 | 自动错误捕获（`ErrorSnapshotter` 在 Invariant Checker 失败时触发、`ErrorSnapshot` 结构化 JSON 序列化、`CaptureMode.light`/`full`） | `error_snapshotter.dart` + `error_snapshot.dart` | ✅ 已完成（capture/toJson/toJsonString 完整实现，LIGHT/FULL 双模式 + 隐私保护） |
| 3.7.3 | 真机调试模式 + Export Pipeline（`InteractionTracer`、`ExportPipeline` 生成 zip、电脑端分析工具 `tools/ffx-analyze/analyze.py`） | `interaction_tracer.dart` + `export_pipeline.dart` + `tools/ffx-analyze/analyze.py` | ✅ 已完成（zip 完整生成 metadata/trace/snapshot/invariant_report/README，`onExportDiagnostics` 已在 `editor_app_bar.dart` / `editor_shell.dart` / `editor_page.dart` 接线） |
| 3.7.4 | Command Replay（`CommandReplayer` 骨架、确定性重放引擎、session 导出/导入） | `command_replayer.dart` + `replay_session.dart` | ✅ 已完成（replay/replayFrom + fingerprint 对比 + 14 类 Command 序列化/反序列化全套实现） |

### 退出条件（Phase 3.7 Exit Gate）

- [x] `EditorTraceContext` 建立跨层 traceId/spanId/parentSpanId 链路
- [x] `CommandTracer` + `TransactionTracer` 通过 RingBuffer 记录最近 N 条轨迹
- [x] `CanonicalFingerprint` 基于 SHA-256 检测仅 AST 变化但 source 不变的场景
- [x] `InvariantChecker` 在 Transaction commit 后自动验证 5 项核心不变量
- [x] `ObservabilityService` 统一 Facade，通过可选参数注入到 CommandHandler/TransactionBuilder
- [x] LIGHT 模式在 release build 默认开启，无磁盘 I/O 和网络开销
- [x] `flutter analyze` 0 error/warning
- [x] `flutter test` 0 regression（Architecture 70 tests + Commands 35 tests + Editor 64 tests 全部 PASS）
- [x] `ErrorSnapshot` 结构化 JSON 序列化（Phase 3.7.2）
- [x] `ExportPipeline` 生成诊断 zip 包（Phase 3.7.3）
- [x] `CommandReplayer` 确定性重放（Phase 3.7.4）

---

## Phase 3.8：Agent Diagnostic Interface（ADI）

> **状态**：Accepted — ADR-0024 由 AI Agent 起草于 2026-08-10，Human Owner 同日评审签字 Accepted，正式纳入 ROADMAP。v0.1 Core + v0.1.1 + v0.2 已合入 main（PR #133/#134/#135/#136）；**真机闭环验证待执行**（见 3.8.5）。

**目标**：在 Phase 3.7（证据采集）之上，建立 **Agent Runtime Interface**——标准化暴露诊断协议给 AI Agent，让 Agent 从 Observation 出发自主完成 **发现 → 复现 → 定位 → 修复 → 验证** 闭环。

**前置条件**：Phase 3.7 全部退出（已满足）+ ADR-0024 Accepted（已签字）。

**核心理念**：3.7 解决了"证据采集"，ADI 解决"证据消费"——尤其是被 AI Agent 直接消费。ADI **复用而非重采** 3.7 已建成的全部能力（ObservabilityService / ErrorSnapshotter / CommandReplayer / InvariantChecker），仅做协议封装 + 存储适配 + CLI 入口。

**关联文档**：
- [ADR-0024 Agent Diagnostic Interface](./ADR/0024-agent-diagnostic-interface.md)（Accepted）
- [ADI Design Document v1.0](./design/adi-design-v1.md)（实现细节）
- [ADR-0023 Editor Observability System](./ADR/0023-editor-observability-system.md)（直接前置，已完成）

### 任务（分阶段实施）

| # | 任务 | 优先级 | 状态 |
|---|------|--------|------|
| 3.8.1 | **v0.1 Core**：4 个核心命令（`adi latest-error` / `adi trace show` / `adi replay` / `adi agent-context`）+ Extract `replay_engine` 到 `core/replay/` | P0 | ✅ PR #133（2026-08-11） |
| 3.8.2 | **v0.1.1 工程化收尾**：`.adi/` Storage 完整实现 + `schema_version` + 架构守门 + `.gitignore` + LIGHT 隐私守门 + 6 个测试文件 | P0 | ✅ PR #134 |
| 3.8.3 | **v0.2 验证闭环**：`adi validate --after-fix`（Replay + Invariant）+ `adi failures list`（index.json 索引）+ 保留窗口清理 | P1 | ✅ PR #134 |
| 3.8.4 | **v0.3 Change Impact Analysis** | P2 | ⏳ 拆为独立 ADR-0026 |
| 3.8.5 | **真机闭环验证**：真机 APK 采集 + `adi replay` reproduced + `adi validate --after-fix` pass（见 ADR-0024 §9 E2E-ADI-005） | P0 | 🟡 首次执行：v0.1 标准 5 步全 PASS；v0.2 `replay→reproduced` 受 AS-RG.1（replay 证据录制）阻塞，安全网行为验证正确。详见 [E2E-ADI-005 真机闭环验证报告](file:///d:/Projects/Active/math2/docs/releases/adi-e2e-005-realdevice-verification-report.md) |

### 退出条件

- [x] v0.1 Core：Agent 能完成 发现 → 复现 → 定位 闭环（4 个核心命令可用）— PR #133
- [x] v0.1.1：`.adi/` Storage 通过架构守门 + `flutter analyze` 0 warning + `flutter test` 0 regression — PR #134
- [x] v0.2：`adi validate --after-fix` 完成 Replay + Invariant 验证闭环 — PR #134
- [ ] **真机闭环验证（v0.1 标准）**：真机 APK 采集成功（非 `flutter test`）+ zip 经 `adi import` 可消费 + `adi trace show` 返回完整 6 层链路（interaction → command → transaction → render → error，非手工构造 fixture）
- [ ] **真机闭环验证（v0.2 标准）**：`adi replay` 真机 session → `reproduced`（非 inconclusive）+ Agent 真实代码修复（非覆写 replay.json 模拟）+ `adi validate --after-fix` → `pass`（Replay + Invariant + Regression 全 PASS）
- [ ] v0.3 退出条件 → 见独立 ADR-0026

### Open Questions

1. ~~ADI 是否正式纳入 ROADMAP Phase 3.8？~~ ✅ 已确认纳入（Human Owner 2026-08-10 签字）
2. `CommandReplayer` Extract 的 0 行为变化如何验证？（复用 `replay_determinism_test.dart` + Extract 前后对比）
3. `candidate_causes` 源码反向映射实现方式？（v0.1 只给 trace chain，v0.3 实现 Source Mapper）
4. `.adi/` 跨设备同步？（v0.1 假设 `.adi/` 已在 Agent 可访问路径，v0.2 评估自动同步）

---

## Phase 3.10：FFX Verification Orchestrator（验证编排器）

> **状态**：🟡 进行中（2026-08-19）— ADR-0030 Accepted（Human Owner 授权提交 PR #158），
> P0 实现已提交待 review。文档族：
> [ADR-0030（架构决策根）](./ADR/0030-ffx-verification-orchestrator.md)、
> [PHASE3.10-ENGINEERING-BASELINE-v1.md](./PHASE3.10-ENGINEERING-BASELINE-v1.md)（锚点）、
> [FFX-VERIFICATION-ORCHESTRATOR-v1.md](./FFX-VERIFICATION-ORCHESTRATOR-v1.md)、
> [FEATURE-CAPABILITY-COVERAGE-MATRIX-v1.md](./FEATURE-CAPABILITY-COVERAGE-MATRIX-v1.md)、
> [FEATURE-COMPLETION-EVIDENCE-MATRIX-v1.md](./FEATURE-COMPLETION-EVIDENCE-MATRIX-v1.md)、
> [PHASE3.10-TYPORA-GAP-ANALYSIS.md](./PHASE3.10-TYPORA-GAP-ANALYSIS.md)。

**目标**：能力无关的验证编排器——Agent 通过 `ffx capability verify/diagnose/repair-verify`
驱动真实 FormulaFix 生产路径（runtime_bridge），按契约（contracts/*.json）判定能力完成度，
形成「审计 → 修复 → 资产化」的自反馈工程基线。

**节奏（2026-08-19 Owner 修订）**：**不做串行「实现完再测」**——P0 可运行即开始
Dogfood，两条线并行：

```text
                 Phase 3.10
                     │
          ┌──────────┴──────────┐
          ↓                     ↓
   Orchestrator Build       Dogfood
   3.10.1（+3.10.2 最小版）   FormulaFix
          │                     │
          └──────────┬──────────┘
                     ↓
              Orchestrator 验收（5 条证据链）
```

**Golden Failure Corpus**（验收基准集）：已有 Bug 作为金标准，不找新 Bug——
BUG-1~6（parser）/ BUG-WORD-001（word）/ RenderOverflow（render）/ Undo 错块 /
Coalescing / Focus / IME（editor）。每例登记
`tests/verification_cases/<capability>/<case_id>.json`
（case_id / capability / expected.status / diagnostic_expected / repair_expected）。

**前置条件**：Phase 3.7（可观测）/ 3.8（ADI）/ 3.9（审计收口）已建立证据采集与消费能力。

**关联文档**：
- [ADR-0030 FFX Verification Orchestrator](./ADR/0030-ffx-verification-orchestrator.md)（Accepted）
- [FFX Verification Orchestrator v1 设计](./FFX-VERIFICATION-ORCHESTRATOR-v1.md)（已批准，进入 P0）

### 任务

| # | 任务 | 优先级 | 状态 |
|---|------|--------|------|
| 3.10.1 | **P0 Orchestrator 核心**：`ffx capability verify/diagnose/repair-verify` + harness（orchestrator/contract/evidence/runtime_bridge/adapters）+ contracts/markdown_parser.json + Python 单元测试（14 项） | P0 | 🟡 PR #158 待 review（Review R1-R15 已修复） |
| 3.10.1D | **Dogfood（并行，P0 可运行即启动）**：① Smoke（verify markdown，断言 real_runtime_path=true）→ ② Known-Good（markdown/serializer）→ ③ Known-Bad Golden Cases（故意回退已修 Bug，verify 必须 FAIL 不误报）→ ④ ADI/Consumer 联合（RenderOverflow → verify→diagnose→replay；BUG-WORD-001 → pdf2txt ❌ 不误报 PASS）→ ⑤ Real Agent Repair（before=fail → patch → after=pass → regression=pass） | P0 | ⏳ 待 3.10.1 review 后启动 |
| 3.10.2 | **contract sync 防矩阵漂移**（提前：最小版在 Dogfood 前落地，防 FFX 读错契约；Matrix says S4 ≠ Contract says S3 必须被机器发现） | P1 | ⏳ |
| 3.10.3 | **consumer adapter 扩展**（design §14 已批准进 P1） | P1 | ⏳ |

### Dogfood 五轮（3.10.1D 细化）

```text
① Smoke        ffx capability verify markdown → real_runtime_path=true（非 fixture/mock）
② Known-Good   verify markdown + serializer → pass + 与 Feature Capability Matrix 对照
③ Known-Bad    故意回退 BUG-1 → verify FAIL（Agent 发现 round-trip mismatch）
④ ADI/Consumer 注入 RenderOverflow → verify→diagnose→replay；BUG-WORD-001 公式丢失 → pdf2txt ❌ 不误报
⑤ Real Repair  Known Bug → verify FAIL → diagnose → Agent patch → repair-verify
                → before=failed / after=pass / regression=pass（repair-verify 不自己修代码，只重新证明）
```

### 退出条件

- [ ] **Orchestrator 自身**：capability registry / contracts / runtime bridge /
      evidence graph / exit code 语义 / diagnose / repair-verify 全部可用
- [ ] **Dogfood 5 条证据链全通**：PASS path + FAIL path + DIAGNOSE path +
      REPAIR path + REGRESSION path（各 ≥1 例，用 Golden Failure Corpus）
- [ ] contract sync：矩阵与契约无漂移（机器强制，Dogfood 前最小版落地）
- [ ] 每个真实 Bug 自动进入 `Bug → 最小复现 → Capability Case → FFX Verification
      Case → Regression → Permanent corpus`（质量资产复利）
- [ ] Phase 3.10 文档族全部挂入 docs/README.md 导航（2026-08-19 已挂）

---

## Phase 3.11：FormulaFix Capability Hardening Loop（能力加固循环）

> **状态**：✅ **已关闭（PHASE_3_11_EXIT，2026-08-22 Owner 判定通过）**
> 开启时间：2026-08-20（Phase 3.10 G0-G12 Final Gate 通过后）
> **边界**：Phase 3.10 验证「验证系统本身」（FFX Orchestrator 闭环验收 ✅）；
> **Phase 3.11 用已建成的 Agent Verification Harness 系统性清算 FormulaFix
> 剩余能力与技术债**——不是「测试阶段」，是「逐个能力加固循环」。

**目标**：把 Feature Capability Coverage Matrix 从「Conditionally Complete」
推进到「Complete」——11 个产品能力逐个：
`Capability Contract → FFX verify → 发现问题 → ADI/Consumer diagnosis →
Agent 修复 → repair-verify → Regression Asset → Capability Baseline 更新`。

**核心循环（每能力）**：

```text
现有能力
   ↓
FFX Audit（ffx capability verify <cap>）
   ↓
真实问题（BUG-00X）
   ↓
最小复现
   ↓
Agent 修复（真实生产代码）
   ↓
FFX Re-verify（repair-verify：before=failed → after=pass → regression=pass）
   ↓
Regression Asset（tests/verification_cases/<cap>/corpus/）
   ↓
Capability Baseline 更新（Matrix S 级推进）
```

### 任务

| # | 任务 | 优先级 | 状态 |
|---|------|--------|------|
| 3.11.1 | **独立 runner 化**：7 个资产引用型能力（undo/pdf/autosave/file/ime/theme/block）从「测试资产存在」验证 → 真实 runner 执行验证 | P0 | ✅ 完成（2026-08-20：5 能力真实 flutter test 执行，2 能力 Evidence Gap 登记） |
| 3.11.2 | **Markdown 加固**：verify markdown → 发现 BUG-009+ → 修复 → repair-verify → regression corpus 追加（S 级推进） | P0 | ✅ 完成（2026-08-20：Golden Loop 首轮闭环，before=failed/after=pass/regression=pass） |
| 3.11.3 | **Serializer 加固**：同上循环 | P1 | ✅ 完成（2026-08-20：Golden Loop 第二轮——回退 separator → FAIL 0.9375 → 修复 → repair-verify pass） |
| 3.11.4 | **Formula 加固**：physical visual fidelity（E6/E8 缺口）→ 真实渲染 corpus（首次高等级证据突破） | P1 | ✅ 完成（2026-08-21~22：F3 Formula Real Defect Loop + E6 模拟器渲染截图 + E8 三层 Pipeline + E8 Evaluator，见 RUN-010/012/013/014） |
| 3.11.5 | **Contract Sync 增强**：s0 声明数 vs unknown_max 自洽机器校验 + fingerprint v2/owner_cross_required_for schema 校验（评审 §8：先冻结「系统如何描述验证结果」，再扩大验证对象） | P0 | ✅ 完成（2026-08-20：四套 schema 自洽冻结，见 RUN-009） |
| 3.11.6 | **Word/PDF 加固（F4 Consumer）**：word 全链路（输入 md→导出→消费端）+ PDF 渲染 | P1 | ✅ 完成（2026-08-21：Word Full Golden Loop + PDF Real Defect Repair Loop，见 RUN-007/011） |
| 3.11.7 | **Undo/IME/Theme/File/Autosave/Block 加固（F2 Behavior）**：逐个能力循环 | P1 | ✅ 完成（2026-08-21：Behavior Family 压力测试——Undo Golden Loop，见 RUN-008） |

### 退出条件（PHASE_3_11_EXIT，2026-08-20 定义）

```text
PHASE_3_11_EXIT =
    GoldenLoopTemplateStable
    ∧ N capabilities hardened
    ∧ every discovered bug becomes regression asset
    ∧ no false-positive regression classification
    ∧ capability completion status updated
```

- [x] **GoldenLoopTemplateStable**：Golden Loop（verify → FAIL → diagnose → 修复 → repair-verify → regression asset）模板已在 ≥2 个能力稳定跑通（Markdown ✅ / Serializer ✅，后续 Formula/Word/PDF/Undo 复用）
- [x] **N capabilities hardened（N = 4 capability families，评审 §4 冻结——与 Quality Layers 分离）**：
  - **F1 Data**（Parse/Serialize/Round-trip）→ Markdown ✅ / Serializer ✅
  - **F2 Behavior**（Undo/Transaction/IME/Autosave）→ ✅（Undo Golden Loop，RUN-008）
  - **F3 Runtime**（Flutter Render/WebView/Persistence/Device）→ ✅（Formula Real Defect Loop，RUN-010）
  - **F4 Consumer**（WPS/OfficeCLI/Screenshot）→ ✅（Word Full Golden Loop + PDF，RUN-007/011）
  - Physical/Visual **不是**第 5 个 family——归 Evidence Dimension（E6 Physical Runtime / E8 Visual Fidelity，release-gate）
- [x] **每个发现 bug 资产化**：Bug → minimal repro → capability case → regression corpus（无遗漏）
- [x] **无误报回归**：regression 判定用 baseline failure set + fingerprint diff（3.11.4 升级为四层 Failure Identity：capability+check+failure_class+evidence_signature），既有失败 ≠ 新增回归
- [x] **capability completion status 更新**：Feature Completion Matrix 按 Evidence Profile（E2/E3/E5/E6）推进

### Quality Layers 与 Capability Families（Phase 3.11 体系，评审 §4 冻结）

```text
Quality Layers（验证质量层级）：
  L1 Data              Parse / Serialize / Round-trip        （Run-002/003 ✅）
  L2 Behavior          Undo / Transaction / IME / Autosave
  L3 Runtime           Flutter Render / WebView / Persistence / Device
  L4 Consumer/体验      WPS / OfficeCLI / Screenshot / Visual / Human UX

Capability Families（能力族，N=4）：
  F1 Data    → Markdown ✅ / Serializer ✅
  F2 Behavior → Undo / IME / Autosave / File / Theme / Block（✅ Undo Golden Loop，RUN-008）
  F3 Runtime → Formula（✅ Real Defect Loop，RUN-010）
  F4 Consumer → Word / PDF（✅ Full Golden Loop，RUN-011）

Evidence Dimension（证据维度，非能力族）：
  E6 Physical Runtime / E8 Visual Fidelity —— release-gate
  （Physical/Visual 不是第 5 个 family；E6/E8 是 Evidence Profile 的维度）

Golden Loop 逐层覆盖：
  Run-002 → Data ✅       Run-003 → Data ✅
  Run-004 → Runtime 🟡（F3 Formula）     Run-005 → Consumer 🟡（F4 Word/PDF）
  后续 → Behavior 🟡（F2 Undo/IME）+ E6/E8 Evidence Dimension 🟡
```

> **状态声明（2026-08-22，PHASE_3_11_EXIT Owner 判定通过后）**：
> ```text
> PHASE_3_11_ARCHITECTURE       = FROZEN / VALIDATED      ✅（taxonomy + ontology 冻结）
> PHASE_3_11_CAPABILITY_COVERAGE = COMPLETE               ✅（F1/F2/F3/F4 四 family 全部验证）
> PHASE_3_11_RUNTIME_VALIDATION = FULLY VALIDATED        ✅（Formula Real Defect Loop 闭环）
> PHASE_3_11_REAL_DEFECT_REPAIR = VALIDATED              ✅（Formula / PDF / Undo 真实缺陷闭环）
> PHASE_3_11_E6/E8              = RELEASE-GATE SATISFIED ✅（真机 zorn 4/4 PASS + E8 视觉语义验证，2026-08-22）
> ```
> 五维全部满足 → PHASE_3_11_EXIT 判定通过（Owner，2026-08-22）。

> **逐项真实位置（2026-08-22，评审 §8 十项）**：
> ```text
> Architecture        ✅ FROZEN / VALIDATED
> Failure Identity    ✅ FROZEN（v2 四层）
> Repair Semantics    ✅ FROZEN（target_failure 四态）
> Capability Taxonomy ✅ FROZEN（Layers/Families/Evidence Dimension）
> Cross-Family Reuse  ✅ PRELIMINARY VALIDATION（Word env_missing + PDF real runner）
> Data Family         ✅ VALIDATED（Markdown + Serializer Golden Loop）
> Runtime Family      ✅ VALIDATED（Formula Real Defect Loop，RUN-010）
> Consumer Family     ✅ VALIDATED（Word Full Golden Loop + PDF，RUN-011）
> Behavior Family     ✅ VALIDATED（Undo Golden Loop，RUN-008）
> E6/E8               ✅ RELEASE-GATE SATISFIED（真机 zorn 4/4 PASS + E8 Evaluator/VLM，RUN-012~016）
> ```
> 十项逐条可审计——比「Phase 3.11 architecture done」更准确，适合 CI/dashboard 消费。

> **工程边界（2026-08-20）**：3.11.1 仅升级 **Evidence Execution Level**
> （测试证据从「资产存在」→「真实执行」），**不升级 Feature Completion
> Status**——`flutter test` 真实执行 ≠ 产品功能真实运行（production_runtime
> 区分：markdown/serializer/word/formula=true，测试层能力=false）。
> 每能力证据按 evidence_profile（E2/E3/E5/E6）分级验收，Completion 判定
> 需 Evidence Profile 全维度，禁止「151 tests passed → 能力 COMPLETE」跳跃。

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

**当前阶段**：Phase 3.3 Mobile Markdown Editing Experience（✅ 全部 9 个任务已完成并合入 main）+ **Phase 3.4 Advanced Capabilities（主体完成：TOC / 自动保存 / 主题 / 导出进度 / 文件树 / 页面宽度 / 图片链路；仅 3.4.10 选区格式化菜单未启动）** + **Phase 3.4.5 Design System Alignment（✅ 全部退出条件达成）** + **Phase 3.5 Formula Rendering System（✅ 主线 3.5.1 + 主题 3.5.2 + 延期项 3.5.3/4/5 Block 交互三件套 全部完成并合入 main）** + **Phase 3.6 E2E（✅ Core E2E + Extended E2E + Patrol 接入全部完成）** + **Phase 3.7 Editor Observability（✅ 3.7.1 基础诊断 + 3.7.2 ErrorSnapshot + 3.7.3 ExportPipeline + 3.7.4 CommandReplayer 全部完成，退出条件全部满足）**
**最近更新**：2026-08-06（文档清理：Phase 2.7 标记 ✅ 完成（tryTransform 已实现）；Phase 2/2.9 退出条件勾选；Phase 3.7.2/3/4 从 🔶 更正为 ✅）
**维护人**：首席架构工程师
