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

## Phase 3：UI Implementation

**目标**：基于 Phase 2 的编辑模型，实现所见即所得 UI。

**前置条件**：Phase 2.9 全部退出（核心接口冻结 + 4 个 Prototype 验证通过）。

### 任务

| # | 任务 | 来源 |
|---|------|------|
| 3.1 | 移除 `previewModeProvider` 与"编辑/预览"切换按钮 | 范式完成的标志 |
| 3.2 | 移除预览卡片包裹，改为沉浸式全屏编辑 | [preview_content.dart:38-47](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L38-47) |
| 3.3 | AppBar 显示当前文档标题 + 修改状态（`•`） | - |
| 3.4 | WebView 预热机制（App 启动后并行加载，不阻塞首屏） | - |
| 3.5 | 公式 / Mermaid 渲染缓存策略改造（不退出清空） | - |
| 3.6 | 代码块语法高亮 | highlight.js / flutter_highlight |
| 3.7 | 大纲 / TOC 侧滑面板，点击跳转标题 | - |
| 3.8 | 文件树侧滑（替代文件管理独立屏幕） | - |
| 3.9 | 多套主题（GitHub / Night / Sepia / Newsprint） | - |
| 3.10 | 字号可缩放（Ctrl +/- / 双指缩放） | - |
| 3.11 | 焦点模式 / 打字机模式 | - |
| 3.12 | 实时字数统计（底部状态栏） | - |
| 3.13 | 撤销 / 重做按钮接入 UI（`HistoryManager` 已实现） | - |
| 3.14 | 自动配对（`$` / `(` / `[` / `*` 等） | - |
| 3.15 | 表格可视化编辑（点击 cell 直接编辑） | - |
| 3.16 | 快捷键支持（Android 物理键盘 + Web） | - |
| 3.17 | 导出进度反馈（百分比 + 当前公式计数） | - |

### 退出条件

- [ ] 用户不再需要切换"编辑/预览"模式
- [ ] WebView 冷启动时间 < 500ms 或预热完成后才显示编辑器
- [ ] 21 项 Typora 核心特性对齐度 ≥ 80%

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

**当前阶段**：Phase 2.9 启动中（UI Architecture Prototype）  
**最近更新**：2026-07-20（Phase 2.8 完成 + Phase 2 Exit Gate PASS + Phase 2.9 启动 + ADR-0009 草案）  
**维护人**：首席架构工程师