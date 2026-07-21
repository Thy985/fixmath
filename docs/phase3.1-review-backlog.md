# Phase 3.1 评审待办 backlog

> **来源**：PR #44（feat(ui): Phase 3.0 Editor Shell 架构 + Typora 化设计同步）代码评审
> **整理日期**：2026-07-21
> **状态**：待 Phase 3.1 启动时纳入任务规划
> **原则**：PR #44 已是 Phase 3.0 功能落地，按 AGENTS.md §6.3「禁止大规模重构与功能改动混在同一 PR」，以下项不在 #44 内修复，统一归入 Phase 3.1。

---

## 评审项清单

### R1. 变更通知粒度（性能）— Phase 3.1-A 弱化版已落地

- **严重性**：⚠️ 中（Phase 3.0 无感，Phase 3.1 实时编辑必现）
- **现状**：Phase 3.1-A 已落地弱化版 R1：`EditorCoordinator` 内部 `_viewStates` + `_focusedId` 合并为不可变 `CoordinatorState` 单字段，每次修改产生新副本。但 Notifier 拆分（FocusNotifier / ContentNotifier / UndoNotifier）留到 Phase 3.1-B 触发制。
- **代码位置**：
  - `lib/presentation/states/coordinator_state.dart`（新增不可变聚合）
  - `lib/presentation/editor/editor_coordinator.dart`（持有 `_state` 单字段）
- **触发条件**：3 个种子 Block 无感；500+ Block 真实文档会卡顿
- **建议方案（3.1-B）**：拆分细粒度通知通道
  - `FocusNotifier` → 仅 block 级 Widget 订阅
  - `ContentNotifier` → EditorViewport + StatusBar
  - `UndoNotifier` → StatusBar 的 undo/redo 按钮
- **归属**：Phase 3.1-A（弱化版已落地，见 PR #45）→ 3.1-B（完整 Notifier 拆分）

### R2. undo/redo 空 currentState（已知限制，已注释）

- **严重性**：⚠️ 中（影响 redo→undo 链第 2 步状态记录）
- **现状**：`undo()` / `redo()` 用 `_emptyCurrentState()` 构造空 Transaction 作为 currentState
- **代码位置**：`lib/presentation/editor/editor_coordinator.dart:126-127,141-142,154-159`
- **现状管控**：代码已标注「PR 评审 R2」注释，说明 Phase 3.0+ 需 state snapshot
- **建议方案**：Phase 3.1 引入 DocumentState snapshot（基于 .md source 或 AST 哈希）
- **归属**：Phase 3.1

### R3. InlineSpan 构建器性能（性能）

- **严重性**：⚠️ 低（Phase 3.0 双态切换无实时编辑）/ Phase 3.1 高（每次按键重建）
- **现状**：`ParagraphBlock._buildInlineSpan` 每次 build 递归构造 InlineSpan 树
- **代码位置**：`lib/presentation/blocks/paragraph_block.dart:148-208`
- **触发条件**：Phase 3.1 Typora 风格实时编辑，每次按键触发 rebuild
- **建议方案**：对 InlineSpan 树缓存，仅当元素哈希变化时重建
- **归属**：Phase 3.1（依赖 R1 通知通道细化后才有效）

### R4. 三种 Block 重复样板代码（重构）

- **严重性**：⚠️ 低（不影响行为）/ Phase 3.1 中（新增 6 种 BlockType 时重复 ×9）
- **现状**：paragraph / heading / code 三个 Block 各自有 ~50 行相同的 controller/focus/commit 样板（initState / didUpdateWidget / dispose / _onFocusChange / _commitSource）
- **代码位置**：
  - `lib/presentation/blocks/paragraph_block.dart:50-101`
  - `lib/presentation/blocks/heading_block.dart`（同构）
  - `lib/presentation/blocks/code_block.dart`（同构）
- **重复量**：约 30 行 × 3 = 90 行
- **建议方案（Phase 3.1-A 已落地）**：提取 `BaseBlockState<T extends StatefulWidget>` 抽象类（而非 mixin，因为 Flutter State 是 class，mixin-on-class 约束更多）
  ```dart
  abstract class BaseBlockState<T extends StatefulWidget> extends State<T> {
    late final TextEditingController textController;
    late final FocusNode focusNode;
    // ... shared focus/commit logic
  }
  ```
  各 Block 的 `build()` 保持独立（渲染差异），消除 controller/focus 样板。
  实现文件：`flutter_app/lib/presentation/blocks/base_block_state.dart`
- **归属**：Phase 3.1-A（已落地，见 PR #45）

### R5. replaceBlock 悄悄改 BlockId（已知风险，已注释）

- **严重性**：⚠️ 低（当前无调用路径）/ Phase 3.1+ 中（BlockType 转换场景）
- **现状**：`replaceBlock` 分配新 BlockId，调用方若持有旧 BlockId 会导致 BlockViewState / focus / UI 控制器失联
- **代码位置**：`lib/presentation/editor/in_memory_document_editor.dart:81-91`
- **现状管控**：代码第 72-79 行已标注「PR 评审 R5」注释，说明此方法当前无调用路径（Phase 3.0 修改走 `updateBlockContent` 保持 BlockId 不变）
- **建议方案**：Phase 3.1 若需 BlockType 转换，先实现 BlockId 迁移通知机制；或改为 `replaceBlock` 保持原 BlockId
- **归属**：Phase 3.1+（视是否引入 BlockType 转换而定）

### R6. command_handler 非密封 dispatch（类型安全）— 已落地

- **严重性**：⚠️ 低（守门测试已覆盖 exhaustive）
- **现状**：Phase 3.1-A 已落地，`EditorCommand` 改为 sealed class + 8 个 final class 子类，switch dispatch 获得编译期 exhaustive 保证。
- **代码位置**：`lib/presentation/commands/editor_command.dart` + `lib/presentation/commands/command_handler.dart`
- **变更 PR**：#45

---

## Phase 3.1 启动检查

Phase 3.1（WYSIWYG 模式迁移）启动时，任务规划应纳入：

1. **R1 通知粒度** — WYSIWYG 实时编辑的性能前置（Phase 3.1-A 做了弱化版 state 拆分，Notifier 拆分留到 3.1-B）
2. **R3 InlineSpan 缓存** — 依赖 R1
3. **R4 BaseBlockState 抽象基类** ✅ 已落地（PR #45）
4. **R6 sealed dispatch** ✅ 已落地（PR #45）
5. **R2 state snapshot** — undo/redo 正确性（合同推迟到 3.1-C）
6. **R5 BlockId 迁移** — 视 BlockType 转换需求

建议顺序：R6 ✅ → R4 ✅ → R1（3.1-B）→ R3（依赖 R1）→ R2（3.1-C）→ R5。

---

**本文件由 AI Agent 整理，未提交，待 Human Owner 确认后纳入 Phase 3.1 规划。**
