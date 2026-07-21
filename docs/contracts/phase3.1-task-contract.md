# Phase 3.1 Task Contract: WYSIWYG Paradigm Migration

> **版本**：v2.0（草案，待 Human Owner 复审）
> **起草日期**：2026-07-21
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Proposed (v2.0)
> **前置阶段**：Phase 3.0 Editor Shell Architecture & Presentation Foundation（PR #44 已合并 main）
> **后继阶段**：Phase 3.2 Immersive Full-screen Editing + Typora 体验对齐
>
> **依据**：
> - [docs/phase3.1-review-backlog.md](../phase3.1-review-backlog.md)（PR #44 评审 R1-R6）
> - [docs/ROADMAP.md Phase 3.1+](../ROADMAP.md)（UI Feature Implementation）
> - [docs/contracts/phase3.0-task-contract.md](./phase3.0-task-contract.md)
>
> **v2.0 重大调整**（Human Owner 审批反馈，2026-07-21）：
> 1. **拆分 3 个子阶段**：3.1-A（WYSIWYG Foundation）/ 3.1-B（Editor Performance，延后触发）/ 3.1-C（Undo Correctness，复用 Transaction）
> 2. **R1 + R3 延期**：Notifier 拆分与 InlineSpan 缓存是"架构投资"，无性能瓶颈数据支撑时不强制
> 3. **R2 重新设计**：复用 Phase 2 Transaction + inverse operation，不另立 snapshot 系统
> 4. **3.1.7 重命名**：从"移除 previewModeProvider"改为"Default Editor Migration"（保留 legacy fallback）
> 5. **补入产品价值描述**：明确"Before/After 用户体验目标"

---

## 0. 任务缘起

### 0.1 产品缘起

Phase 3.0 已落地 Editor Shell Architecture & Presentation Foundation。但 **当前用户仍依赖"编辑/预览"模式切换**，每次输入 Markdown 源码后切换预览才能看到排版——这是工具感，不是写作感。

**Phase 3.1 的产品价值**：

> **用户第一次感受到 FormulaFix 不再是 Markdown 编辑器，而是 WYSIWYG 文档编辑器。**

**Before（Phase 3.0 现状）**：
- 用户需要理解："我现在在编辑模式"
- 用户需要理解："切换到预览模式才能看效果"
- 用户需要理解："Markdown 语法 `#` `>` `*` 是什么意思"

**After（Phase 3.1 目标）**：
- 用户只需要：点击
- 用户只需要：输入
- 用户只需要：看到最终排版

Typora 成功的核心不是功能多，而是：**用户打开之后，没有"编辑器操作感"**。FormulaFix 的 Phase 3.1 解决的就是这个"操作感"问题。

### 0.2 战略定位

FormulaFix 的最终目标不是"做一个 Typora"，而是：
> **Typora 的极简写作体验 + 数学原生能力 + AI 原生工作流**

Phase 3.1 处在演化关键节点：

```
Phase 1 数据模型 → Phase 2 编辑引擎 → Phase 3.0 UI Runtime
                                          ↓
                              Phase 3.1 WYSIWYG 范式迁移
                                          ↓
                         Phase 3.2+ Typora 级体验 + AI 增强
```

Phase 3.1 不是"功能堆叠"，而是 **范式切换**：从"工具"变"作品"。

### 0.3 子阶段拆分理由

v1.0 草案一次性包含 7 个任务（架构补强 + 性能基建 + 范式切换 + undo 修复），存在"架构重构过载"风险——三个不同量级的事情混在一起。

**v2.0 拆分**：

| 子阶段 | 目标 | 风险 | 触发条件 |
|--------|------|------|---------|
| **3.1-A** WYSIWYG Foundation | 完成范式切换 + 关键架构强化 | 中 | 当前 Phase 3.1 |
| **3.1-B** Editor Performance | 性能优化（Notifier 拆分 / InlineSpan 缓存） | 高 | **触发制**：(a) 500 Block benchmark fail 或 (b) 真实输入卡顿 |
| **3.1-C** Undo Correctness | Transaction History 完整性 | 中 | **触发制**：(a) 用户报告 undo bug 或 (b) Phase 4 协同编辑需要 |

子阶段 3.1-B / 3.1-C 启动前必须新建独立 Task Contract，**不在 3.1-A 范围内强制完成**。

---

## 1. 目标与范围

### 1.1 Phase 3.1-A 核心目标

回答三个问题：

1. **范式切换**：何时能让新 UI（EditorPage + EditorShell）成为默认入口？
2. **类型强化**：如何让 `User Intent → Command → Transaction → Operation` 链路获得编译期类型安全？
3. **生命周期抽象**：如何在新增 6 种 BlockType 前消除重复样板？

### 1.2 Phase 3.1-A 范围（5 个任务）

| # | 任务 | 来源 | 类型 | 风险 |
|---|------|------|------|------|
| 3.1.A.1 | R6 - `EditorCommand` 改为 sealed class | R6 | 类型强化 | 低（编译期） |
| 3.1.A.2 | R4 - 提取 `BlockEditing` mixin | R4 | 重构 | 中（mixin 设计） |
| 3.1.A.3 | EditorCoordinator 内部 state 拆分（不拆 Notifier） | R1 调整为弱化版 | 状态建模 | 低（仅内部重组） |
| 3.1.A.4 | Default Editor Migration（新 UI 默认 + 旧 UI 降级为 fallback） | ROADMAP 3.1（重命名） | 范式切换 | 中（产品迁移） |
| 3.1.A.5 | R5 - BlockId 迁移通知机制（备用） | R5 | 修复 | 低（当前无调用路径） |

### 1.3 不在 Phase 3.1-A 范围内（明确边界）

#### Phase 3.1-B 延后项（性能优化）

- ⏸ **R1 完整版**：Notifier 拆分（FocusNotifier / ContentNotifier / UndoNotifier / StructureNotifier）
- ⏸ **R3**：InlineSpan 树缓存
- ⏸ **500 Block 性能基线**：当前无性能瓶颈数据，延后到真实场景需要时启动

**触发条件**（满足任一启动 3.1-B）：
- [ ] 性能基线测试失败（500 Block 输入 > 16ms）
- [ ] 真实用户反馈输入卡顿
- [ ] Phase 3.2+ 实时编辑场景下 EditorShell 重建超过 60fps 预算

#### Phase 3.1-C 延后项（Undo 正确性）

- ⏸ **R2**：undo/redo 在多步链第 2 步状态丢失问题

**触发条件**（满足任一启动 3.1-C）：
- [ ] 用户报告 undo bug
- [ ] Phase 4 协同编辑引入冲突解决需求
- [ ] Phase 3.2+ 多步连续操作场景下 redo 状态不一致

**当前对策**（Phase 3.1-A 期间）：
- 保留 R2 已知限制的代码注释（PR 评审 R2 注释已在 [editor_coordinator.dart:126-127](file:///d:/Projects/Active/math/flutter_app/lib/presentation/editor/editor_coordinator.dart#L126) 落地）
- 复用 Phase 2 `Transaction` + `inverse operation` 路径（不走 snapshot）
- 单步 undo/redo 行为正确（Phase 2 已稳定），仅多步链第 2 步有问题

#### 其他不属于 Phase 3.1 的项

- ❌ 移除预览卡片包裹，改为沉浸式全屏编辑（Phase 3.2）
- ❌ 实现 6 种剩余 BlockType（Phase 3.3+）
- ❌ AppBar 字号缩放控件 / TOC 面板 / 文件树 / 主题切换（Phase 3.6+）
- ❌ WebView 预热机制（Phase 3.4）
- ❌ 公式 / Mermaid 渲染缓存（Phase 3.5）
- ❌ 代码块语法高亮（Phase 3.6）
- ❌ 修改 `lib/core/editing/` 内核 mutation 逻辑（Phase 3.1-A 不动内核接口）

---

## 2. 关键架构约束

### 2.1 Hard Rules 沿用 Phase 3.0（9 项）

| # | Hard Rule | Phase 3.1-A 适用 | 守门测试 |
|---|-----------|------------------|---------|
| 1 | AST 零污染 | ✅ | TC-ARCH-UI-3 |
| 2 | Command Layer 强制 | ✅ | TC-ARCH-UI-1/2 |
| 3 | BlockRenderer 抽象 | ✅ | TC-ARCH-UI-8 |
| 4 | 避免 God Object | ✅ | TC-ARCH-UI-4 |
| 5 | 旧 UI 并存 | ✅（降级为 fallback，**不删除**） | TC-ARCH-UI-14（新增） |
| 6 | 复用 Phase 2.9 产出 | ✅ | — |
| 7 | chrome/ 单独分离 | ✅ | TC-ARCH-UI-7 |
| 8 | 依赖方向严格 | ✅ | TC-ARCH-UI-5/6/7 |
| 9 | BlockRenderer exhaustive switch | ✅ | TC-ARCH-UI-8 |

### 2.2 Phase 3.1-A 新增约束

**Hard Rule 10**：`EditorCommand` 必须是 sealed class（R6 落地后）

**理由**：
- `User Intent → Command → Transaction → Operation` 链路需要强类型
- sealed class 让 switch dispatch 获得编译期 exhaustive 保证
- 与 Phase 2.4 的 `BlockType.fromElement` exhaustive 设计一致

### 2.3 Phase 3.1-A 后的约束变化

**范式切换后**：
- ✅ `kEnableNewEditor = true`（新 UI 成为默认入口）
- ✅ `/editor` 路由指向 `EditorPage`（生产 UI）
- ✅ `/editor-legacy` 路由指向 `EditorScreen`（fallback，仅迁移期可用）
- ✅ 旧 `lib/presentation/screens/editor_screen.dart` **保留**（不删除）
- ❌ `previewModeProvider` 移除（不再需要"编辑/预览"切换）
- ❌ `/editor3` 路由移除（合并到 `/editor`）

**产品迁移策略**："产品迁移不是代码迁移"
- 用户可能仍依赖旧 UI 的某些功能（如多视图模式、特殊 Markdown 行为）
- 保留 fallback 一个 release 周期，收集用户反馈后再决定是否彻底删除
- 路由分流：`/editor` → 新 UI；`/editor-legacy` → 旧 UI（隐藏入口，从设置中可启用）

---

## 3. 任务详细分解

### 3.1 任务 3.1.A.1：R6 - `EditorCommand` 改为 sealed class

**输出**：`lib/presentation/commands/editor_command.dart` + `command_handler.dart`

**改动**：
1. `EditorCommand` 从 `abstract class` 改为 `sealed class`
2. 所有子类改为 `final class XCommand extends EditorCommand`
3. `CommandHandler.handle` 的 switch 从 `if-else` 链改为 `switch expression`（exhaustive）
4. 新增守门测试 TC-ARCH-UI-9

**理由**：
- 当前 [command_handler.dart:162](file:///d:/Projects/Active/math/flutter_app/lib/presentation/commands/command_handler.dart#L162) 用 if-else 链 dispatch，缺编译期 exhaustive
- sealed class 是 Dart 3 现代化核心特性，与 Phase 2.4 `BlockType.fromElement` 对齐

**风险**：低
- 不改变运行时行为
- 守门测试已覆盖 exhaustive
- 独立 PR

### 3.2 任务 3.1.A.2：R4 - 提取 `BlockEditing` mixin

**输出**：`lib/presentation/blocks/block_editing_mixin.dart` + 3 个 Block 改造

**改动**：
1. 提取 `mixin BlockEditing<T extends DocumentElement> on State<BlockWidget<T>>`
2. 共享逻辑：
   - `late final TextEditingController textController`
   - `late final FocusNode focusNode`
   - `initState` / `didUpdateWidget` / `dispose`
   - `_onFocusChange` listener
   - `_commitSource`
3. 各 Block 的 `build()` 保持独立（渲染差异）
4. 消除约 90 行重复样板

**理由**：
- 未来 BlockType：Math / Mermaid / Table / Quote / Image / Callout / AIBlock
- 没有抽象 = 每个新 Block 复制 controller / focus / commit / lifecycle
- 提取后新增 Block 只需实现 `build()` + `_buildInlineSpan`

**风险**：中
- mixin 设计需仔细处理生命周期
- 测试需覆盖 3 个 Block 双态切换行为不变
- 守门测试需新增"mixin 不引入状态泄漏"（TC-ARCH-UI-10）

### 3.3 任务 3.1.A.3：EditorCoordinator 内部 state 拆分（弱化版 R1）

**输出**：`lib/presentation/editor/editor_coordinator.dart`

**改动**：
1. 内部按状态职责拆分 state class（不拆 Notifier）：
   ```dart
   class EditorCoordinator extends ChangeNotifier {
     final DocumentState document;    // 文档级状态（block list / source）
     final FocusState focus;          // 焦点状态（focusedId / render mode）
     final HistoryState history;      // 撤销历史（canUndo / canRedo）
     // ...
   }
   ```
2. 单一 `notifyListeners()` 保留（不拆分）
3. 各 state 内部是不可变数据，外部通过 `coordinator.document.xxx` 访问
4. 新增守门测试 TC-ARCH-UI-11（弱化版）：EditorCoordinator 内部按 state 拆分但 Notifier 不拆

**为什么弱化（不拆 Notifier）**：
- 完整版 R1 是"架构投资"，当前无 500 Block 性能瓶颈数据支撑
- 内部 state 拆分类已经是"半步"重构，给未来 3.1-B 留好路径
- 单一 `notifyListeners()` 仍可能全树重建，但当前 BlockRenderer + chrome 的 3 个 Block 规模无问题

**理由**：
- 为 3.1-B 的 Notifier 拆分铺路（state 拆分是前置条件）
- 内部 state 类明确职责，降低 EditorCoordinator 文件长度（避免 God Object）
- 风险低：仅内部重组，对外 API 不变

**风险**：低
- 仅内部重组，对外 API 不变
- 性能不变（甚至轻微恶化，因多一层 state 间接访问）
- 未来 3.1-B 需重新评估

### 3.4 任务 3.1.A.4：Default Editor Migration

**输出**：`lib/core/router/app_router.dart` + `feature_flag.dart` + 旧路由保留

**改动**：
1. `kEnableNewEditor` 改为 `true`（新 UI 默认）
2. `/editor` 路由指向 `EditorPage`（生产 UI）
3. 新增 `/editor-legacy` 路由指向 `EditorScreen`（fallback，迁移期）
4. 移除 `/editor3` 路由（合并到 `/editor`）
5. 移除 `previewModeProvider`（不再需要"编辑/预览"切换）
6. 旧 `lib/presentation/screens/editor_screen.dart` **保留**（不 archive）
7. EditorAppBar 添加"切换到旧版"入口（仅在设置中可见，方便用户回退）

**为什么改名"Default Editor Migration"（而不是"移除 previewMode"）**：
- v1.0 叫"移除 previewModeProvider"过于激进（隐含删除旧 UI）
- 真实情况：保留 fallback 一个 release 周期，收集用户反馈
- 产品迁移 = 用户习惯迁移 + 功能对齐 + 反馈收集，三者都需时间
- 旧 `EditorScreen` 不是"坏代码"——它的某些功能（如多视图模式、特殊 Markdown 行为）新 UI 尚未实现

**理由**：
- ROADMAP Phase 3.1 主任务："范式切换"（不是"代码删除"）
- 满足用户："编辑/预览"模式消失的范式体验
- 保留 fallback = 降低产品迁移风险

**风险**：中
- 移除 `previewModeProvider` 影响部分使用旧模式的用户
- 旧 UI 路由 `/editor-legacy` 需隐藏入口（避免普通用户发现）
- 必做手动验证：所有原 EditorScreen 关键功能在新 EditorPage 中可用

### 3.5 任务 3.1.A.5：R5 - BlockId 迁移通知机制（备用）

**输出**：`lib/presentation/editor/in_memory_document_editor.dart`

**改动**：
1. `replaceBlock` 不再悄悄改 BlockId（保持原 BlockId）
2. 引入 `replaceBlockKeepId` 显式方法（保持 BlockId）
3. 引入 `replaceBlockWithMigration` 方法（接受 `BlockIdMigration` 回调）

**理由**：
- 当前 `replaceBlock` 分配新 BlockId，调用方若持有旧 BlockId 会导致 BlockViewState / focus / UI 控制器失联
- 当前无调用路径（Phase 3.0 修改走 `updateBlockContent` 保持 BlockId 不变）
- 提前准备好，未来 BlockType 转换场景直接可用

**风险**：低
- 当前无调用路径，改动不影响现有行为
- 提供两个 API 让调用方显式选择

---

## 4. 验证计划

### 4.1 自动验证（CI 门禁）

按 [AGENTS.md §8 CI 与质量门禁](../../AGENTS.md)：

| 验证 | 命令 | 通过标准 |
|------|------|---------|
| 依赖 | `flutter pub get` | exit 0 |
| 静态分析 | `flutter analyze --no-fatal-infos --fatal-warnings` | exit 0（0 warning） |
| 单元测试 | `flutter test` | 0 failed（目标 925+ passed，新增 3+ 守门测试） |
| Android 构建 | `flutter build apk --debug` | exit 0 |
| Web 构建 | `flutter build web` | exit 0 |

### 4.2 架构守门测试（新增 3 项）

| 测试 ID | 守门内容 | 文件 |
|---------|---------|------|
| TC-ARCH-UI-9 | `EditorCommand` 必须 sealed + 子类必须 final | `test/architecture/ui_command_sealed_test.dart` |
| TC-ARCH-UI-10 | `BlockEditing` mixin 不引入状态泄漏 | `test/architecture/ui_mixin_isolation_test.dart` |
| TC-ARCH-UI-11（弱化） | EditorCoordinator 内部按 state 拆分但 Notifier 不拆 | `test/architecture/ui_state_split_test.dart` |
| TC-ARCH-UI-14 | 旧 `editor_screen.dart` 仍存在（保留为 fallback） | `test/architecture/ui_editor_legacy_fallback_test.dart` |

**对比 v1.0**：
- v1.0 计划 5 项新守门测试（TC-ARCH-UI-9 ~ 13）
- v2.0 减少为 4 项（移除 TC-ARCH-UI-12 "previewModeProvider 已移除"——因为是合法业务，改为 TC-ARCH-UI-14 "fallback 保留"）
- v2.0 弱化 TC-ARCH-UI-11（不要求 Notifier 拆分）

### 4.3 功能等价性测试

| 测试 | 文件 | 覆盖 |
|------|------|------|
| ParagraphBlock 双态切换 | `test/ui/paragraph_block_dual_state_test.dart` | R4 mixin 提取后行为不变 |
| HeadingBlock 双态切换 | `test/ui/heading_block_dual_state_test.dart` | R4 mixin 提取后行为不变 |
| CodeBlock 双态切换 | `test/ui/code_block_dual_state_test.dart` | R4 mixin 提取后行为不变 |
| EditorPage 路由 + legacy fallback 路由 | `test/router/editor_route_split_test.dart` | 3.1.A.4 范式切换 |
| CommandHandler sealed exhaustive | `test/commands/command_sealed_dispatch_test.dart` | R6 强类型 |

### 4.4 性能基线测试（不强制）

| 测试 | 阈值 | 状态 |
|------|------|------|
| 3 Block 文档按键 rebuild | 记录基线，**不设阈值** | 信息性（为 3.1-B 准备） |
| 500 Block 文档按键 rebuild | 记录基线，**不设阈值** | 信息性（为 3.1-B 准备） |

**理由**：v2.0 删除了 v1.0 强制的 "500 Block < 16ms" 性能基线，因为无数据支撑时强制性能阈值会扭曲设计方向。改为"信息性记录"作为 3.1-B 触发条件的数据基础。

### 4.5 手动验证（Exit Gate）

| # | 验证项 | 通过标准 |
|---|--------|---------|
| 1 | `flutter run` 默认进入新 EditorPage | 不再走旧 EditorScreen |
| 2 | 3 种 Block 双态切换正常 | 行为不变 |
| 3 | Undo / Redo 单步正确 | 行为不变（R2 多步已知限制保留注释） |
| 4 | 旧 EditorScreen 通过 `/editor-legacy` 可访问 | fallback 工作 |
| 5 | 用户不再需要切换"编辑/预览"模式 | `previewModeProvider` 移除后无回归 |

---

## 5. Hard Rules 守门测试矩阵（13 项）

| 测试 ID | 守门内容 | Phase |
|---------|---------|-------|
| TC-ARCH-UI-1 | UI 不直接 import BlockOperations / DocumentEditor | 3.0 |
| TC-ARCH-UI-2 | UI 不直接 import TransactionBuilder / EditOperation | 3.0 |
| TC-ARCH-UI-3 | State 类不持有 AST 字段 | 3.0 |
| TC-ARCH-UI-4 | EditorCoordinator ≤ 200 行 + 不持有 Theme/File/Route | 3.0 |
| TC-ARCH-UI-5 | blocks/ 不 import editor/（除 coordinator）/ panels/ / chrome/ | 3.0 |
| TC-ARCH-UI-6 | editor/ 不 import panels/ | 3.0 |
| TC-ARCH-UI-7 | chrome/ 不 import blocks/ / panels/ | 3.0 |
| TC-ARCH-UI-8 | BlockRenderer 必须 exhaustive switch + 不允许 _ => fallback | 3.0 |
| **TC-ARCH-UI-9** | EditorCommand 必须 sealed + 子类必须 final | **3.1-A 新增** |
| **TC-ARCH-UI-10** | BlockEditing mixin 不引入状态泄漏 | **3.1-A 新增** |
| **TC-ARCH-UI-11（弱化）** | EditorCoordinator 内部按 state 拆分但 Notifier 不拆 | **3.1-A 新增** |
| **TC-ARCH-UI-14** | 旧 editor_screen.dart 仍存在（fallback 保留） | **3.1-A 新增** |

**未包含项**（v1.0 移出）：
- ~~TC-ARCH-UI-12 previewModeProvider 已移除~~ → 合并到功能测试
- ~~TC-ARCH-UI-13 旧 editor_screen.dart archive~~ → 改为 TC-ARCH-UI-14 "fallback 保留"

---

## 6. Exit Gate（Phase 3.1-A 退出标准）

### 6.1 架构守门（12/12）

- [ ] TC-ARCH-UI-1 ~ 8（Phase 3.0 沿用）全 PASS
- [ ] TC-ARCH-UI-9（EditorCommand sealed）PASS
- [ ] TC-ARCH-UI-10（BlockEditing mixin 隔离）PASS
- [ ] TC-ARCH-UI-11（state 拆分弱化版）PASS
- [ ] TC-ARCH-UI-14（fallback 保留）PASS

### 6.2 功能等价性

- [ ] ParagraphBlock / HeadingBlock / CodeBlock 双态切换行为不变
- [ ] EditorPage 默认入口 + EditorScreen fallback 入口
- [ ] CommandHandler sealed exhaustive dispatch

### 6.3 产品价值

- [ ] 用户进入 `/editor` 默认看到 EditorPage（无"编辑/预览"切换）
- [ ] `previewModeProvider` 已移除
- [ ] 旧 UI 通过 `/editor-legacy` 隐藏入口仍可用

### 6.4 CI 门禁

- [ ] `flutter pub get` 成功
- [ ] `flutter analyze --no-fatal-infos --fatal-warnings` exit 0
- [ ] `flutter test` 0 failed（目标 925+ passed）
- [ ] `flutter build apk --debug` 成功
- [ ] `flutter build web` 成功

### 6.5 文档

- [ ] 更新 [ROADMAP.md Phase 3.1+ 退出条件](../ROADMAP.md)
- [ ] 更新 [docs/design/ui-spec.md](../design/ui-spec.md)（标注已实施部分）
- [ ] 完成 [docs/releases/phase3.1-verification-report.md](../releases/phase3.1-verification-report.md)
- [ ] 标注 [docs/phase3.1-review-backlog.md](../phase3.1-review-backlog.md) 中 R1/R2/R3 状态为"延后到 3.1-B/C"

---

## 7. 风险评估

| # | 风险 | 严重性 | 缓解措施 |
|---|------|--------|---------|
| RK-1 | 3.1.A.4 范式切换后部分用户功能丢失 | 中 | 保留 fallback + 隐藏入口 + 收集用户反馈 |
| RK-2 | R4 mixin 提取破坏 Block 双态切换 | 中 | 必须做 3 个 Block 双态切换功能等价性测试 |
| RK-3 | 弱化版 R1（state 拆分）使 EditorCoordinator 文件膨胀 | 低 | 控制文件 ≤ 200 行（守门测试 TC-ARCH-UI-4 兜底） |
| RK-4 | Phase 3.1-A 范围仍可能偏大 | 中 | 5 个任务拆为 2 个 PR（PR #1: R6 + R4 + 弱化 R1；PR #2: 范式切换 + R5） |
| RK-5 | 3.1-B/C 触发条件定义不清 | 中 | 明确触发条件（性能基线 fail / 用户反馈 / Phase 4 需求） |
| RK-6 | 旧 UI 路由 `/editor-legacy` 暴露 | 低 | 隐藏入口（从设置中可启用） |
| RK-7 | R2 多步 undo 限制未修复 | 低（已知） | 代码注释保留 + 明确推迟到 3.1-C |

---

## 8. PR 拆分建议（2 个 PR）

按 [AGENTS.md §6.3「禁止大规模重构与功能改动混在同一 PR」](../../AGENTS.md)：

| PR | 范围 | 任务 | 风险 | 依赖 |
|----|------|------|------|------|
| **PR #1** | 类型强化 + 重构 | 3.1.A.1 (R6) + 3.1.A.2 (R4) + 3.1.A.3 (弱化 R1) | 中 | 无 |
| **PR #2** | 范式切换 | 3.1.A.4 (Default Editor Migration) + 3.1.A.5 (R5) | 中 | PR #1 |

**推荐顺序**：PR #1 → PR #2

**为什么 3.1.A.4 不与 R1/R4/R6 同一 PR**：
- 范式切换是"产品级"改动，独立 PR 便于回滚
- R1/R4/R6 是"工程级"改动，独立 PR 便于 code review
- 若 3.1.A.4 出问题（如 fallback 路由未正确配置），可单独 revert PR #2

每个 PR 必须独立通过 CI + 守门测试。

---

## 9. AI / Human Owner 分工

按 [AGENTS.md §6.4](../../AGENTS.md)：

| 行为 | AI | Human Owner |
|------|----|-------------|
| 起草 Task Contract v2.0 | ✅ 本文件 | — |
| 审批 Task Contract v2.0 | — | ✅ 必填 |
| 创建 branch（feat/phase3.1-*） | ✅ | ✅ |
| 实施 PR #1（R6 + R4 + 弱化 R1） | ✅ | — |
| 实施 PR #2（范式切换 + R5） | ✅ | — |
| Commit（含 Task scope） | ✅ | ✅ |
| Push 到 main | ❌ 禁止 | ✅ |
| Merge PR | ❌ 禁止 | ✅ |
| 启动 3.1-B/C 子阶段 | — | ✅ 决策 |

**Task Contract v2.0 审批流程**：
1. AI 起草 v1.0（已发布，已收到反馈）
2. AI 修订 v2.0（已发布，等待复审）
3. Human Owner 复审 v2.0
4. 审批通过后开始 PR #1 实施
5. PR #1 → PR #2 顺序执行
6. 全部 PR 合并后 Phase 3.1-A 关闭
7. Phase 3.1-B / 3.1-C 待触发条件满足时新建独立 Task Contract

---

## 10. 待 Human Owner 决策项

### 10.1 问题 1：PR 拆分粒度

§8 建议拆 2 个 PR（PR #1 = 类型强化 + 重构，PR #2 = 范式切换 + R5），是否合理？

**倾向**：2 个 PR
- 理由：每个 PR 风险独立可回滚，符合 AGENTS.md §6.3
- 替代方案：合并为 1 个 PR，但风险集中

### 10.2 问题 2：3.1.A.3 弱化版 R1 是否保留

`EditorCoordinator` 内部 state 拆分（不拆 Notifier）是否在 3.1-A 内完成？

**倾向**：保留（弱化版 R1）
- 理由：为 3.1-B 铺路（state 拆分是 Notifier 拆分的前置条件）
- 风险低：仅内部重组，对外 API 不变
- 替代方案：直接删掉，等 3.1-B 触发时一起做

### 10.3 问题 3：3.1.A.5 R5 是否在 3.1-A 完成

R5 当前无调用路径，是否在 3.1-A 完成？

**倾向**：保留
- 理由：仅 API 扩展（提供 `replaceBlockKeepId` 显式方法），不改变现有行为
- 替代方案：推迟到 3.1-B/C

### 10.4 问题 4：旧 UI fallback 保留时间

旧 `editor_screen.dart` 保留一个 release 周期，具体多久？

**倾向**：1 个 release 周期（约 1-2 个月）
- 理由：足够收集用户反馈 + 评估新 UI 功能对齐度
- 替代方案：永久保留（成本：维护负担）

### 10.5 问题 5：3.1-B/C 触发条件是否清晰

§1.3 触发条件是否需更具体？

**倾向**：当前定义足够
- 性能 fail：500 Block 输入 > 16ms（与 v1.0 一致）
- 用户反馈：直接的产品反馈
- 替代方案：增加更多触发条件（如 Phase 3.2+ 必需）

---

## 11. Self Review Checklist

按 [AGENTS.md §9.4](../../AGENTS.md) 自检：

- [x] 读了 AGENTS.md 相关章节（§6.5 Phase 2 UI 冻结、§9 AI 协作工作流、§6.4 提交分工）
- [x] 读了 [phase3.1-review-backlog.md](../phase3.1-review-backlog.md) R1-R6
- [x] 读了 [ROADMAP.md Phase 3.1+](../ROADMAP.md)
- [x] 读了 Phase 3.0 相关代码（editor_coordinator.dart / paragraph_block.dart 等）
- [x] **采纳 Human Owner 反馈**：拆分 3.1-A/B/C + 弱化 R1 + 重设计 R2 + 重命名 3.1.7
- [x] 补入产品价值描述（Before/After 用户体验目标）
- [x] 没有违反任何 Hard Rules（沿用 Phase 3.0 的 9 项 + 新增 Hard Rule 10）
- [x] 改动范围与 Task Contract 描述一致（5 个任务 + 4 个新守门测试）
- [x] 没有夹带未在 Task Contract 中说明的改动
- [x] 测试覆盖完整（12 项守门 + 5 项功能等价 + 2 项信息性性能记录）
- [x] 文档已同步（本文件 + 后续 verification report）
- [x] 没有引入新的依赖（pubspec.yaml 预期不改）
- [x] 没有修改 `lib/core/editing/` 内核 mutation 逻辑
- [x] 没有修改 ADR / AGENTS.md / ROADMAP 等架构决策文件
- [x] 风险评估完整（7 项风险 + 缓解措施）
- [x] PR 拆分合理（2 个 PR，风险独立可回滚）
- [x] **3.1-B / 3.1-C 明确为延后项**，不在 3.1-A 强制完成

---

## 12. v1.0 → v2.0 变更摘要

| 项目 | v1.0 | v2.0 |
|------|------|------|
| 任务数 | 7 | 5（3.1-A 范围） |
| R1 Notifier 拆分 | 强制 | **延后到 3.1-B**，3.1-A 仅做 state 内部拆分 |
| R2 Snapshot | 强制 | **延后到 3.1-C**，3.1-A 复用 Phase 2 Transaction |
| R3 InlineSpan 缓存 | 强制 | **延后到 3.1-B** |
| 3.1.7 移除 previewMode | 强制 | **改为 Default Editor Migration**：保留 legacy fallback |
| 旧 editor_screen.dart | archive | **保留**（fallback） |
| PR 拆分 | 4 个 | 2 个 |
| 性能基线 | 强制阈值 | **信息性记录**（无阈值） |
| 守门测试 | 5 项新 | 4 项新（弱化 TC-ARCH-UI-11） |
| 产品价值描述 | 弱 | **强化**（Before/After 用户体验目标） |

---

**本 Task Contract v2.0 由 AI Agent 起草（基于 v1.0 + Human Owner 反馈），待 Human Owner 复审。**

审批通过后，按 §8 PR 拆分建议开始实施 PR #1（R6 + R4 + 弱化 R1）。
