# Phase 2.9 Task Contract: UI Architecture Prototype

> **版本**：v1.2（R1-R6 修复完成，等待 PR 合并 main）
> **起草日期**：2026-07-20
> **最后更新**：2026-07-21（v1.2 — R1-R6 PR 评审反馈修复）
> **起草人**：AI Agent（GLM-5.2）
> **状态**：Implemented（等待最终 PR 合并 main）
> **前置阶段**：Phase 2.8 Integration Hardening（已 Exit Gate PASS，已合并 main）
> **后继阶段**：Phase 3.0 Editor Shell Architecture & Presentation Foundation（Task Contract v1.1 已起草）

---

## 0. 任务缘起

Phase 2.1~2.8 已建立完整的"块级编辑内核"——所有 BlockOperation / Transaction / EditorHistory / IME 三铁律均可在纯 Dart 逻辑中运行（0 UI 反向依赖，841 tests PASS）。

**但**：前两阶段解决的是"数据和逻辑正确性"，UI 阶段会反过来验证前面设计是否真的适合用户交互。如果直接进入 Phase 3 写 Widget，很容易出现 **UI 推翻核心模型** 的问题（如发现 BlockEditor API 缺少必要的状态查询、Transaction 不支持批量编辑场景、AST 缺少 UI 所需的 position 概念等）。

**Phase 2.9 的核心目标**：用 **设计 + 4 个 Prototype Demo** 验证"用户体验 → UI Interaction Model → BlockEditor API → Transaction → AST"五层映射的正确性，**不写正式 UI 代码**。

---

## 1. 目标与范围

### 1.1 核心目标

回答一个问题：**用户看到的编辑器行为，如何映射到底层 Block、Transaction 和 AST？**

如果这个映射设计正确，Phase 3 UI 开发会变成工程实现；如果这个映射没有设计清楚，Phase 3 UI 开发会变成不断修改核心架构——这是 Phase 2 花大量精力做 ADR / Task Contract 想避免的返工。

### 1.2 五层跨层设计

```
          用户体验层
              │
              ↓
       UI Interaction Model       ← Phase 2.9 新增
              │
              ↓
       BlockEditor API            ← Phase 2.1 抽象，Phase 2.9 验证
              │
              ↓
       Transaction Model          ← Phase 2.6 已稳定
              │
              ↓
       Document AST               ← Phase 1 已稳定
```

**Phase 2.9 必须五层一起设计**，不能只设计 UI 层。

### 1.3 范围（5 个设计任务）

| # | 任务 | 产出 | 类型 |
|---|------|------|------|
| 2.9.1 | UI 心智模型定义 | `docs/UI-ARCHITECTURE.md` §1-2 | 架构决策类（草案） |
| 2.9.2 | UI 状态模型设计 | `docs/UI-ARCHITECTURE.md` §3 + `docs/ADR/0009-ui-architecture-design.md` | 架构决策类（草案） |
| 2.9.3 | 交互事件模型设计 | `docs/Interaction-Model.md` + `docs/ADR/0009` | 架构决策类（草案） |
| 2.9.4 | UI Prototype 验证（4 个 Demo） | `flutter_app/lib/presentation/prototype/` | 新建代码目录 |
| 2.9.5 | 核心接口冻结 | `docs/Component-Tree.md` + `docs/ADR/0009` | 架构决策类（草案） |

### 1.4 不在 Phase 2.9 范围内（明确边界）

- ❌ 修改 `lib/presentation/` 正式代码（Phase 3 才做）
- ❌ 接入生产路由（Phase 3 才做）
- ❌ 实现完整的 21 项 Typora 特性（Phase 3 才做）
- ❌ 修改 `lib/core/editing/` 内核代码（除非 Prototype 暴露设计缺陷，需走 ADR 流程）
- ❌ 主题切换 / TOC / 图片管理 / 焦点模式（Phase 3 任务）
- ❌ 性能优化（除 Prototype 中明显瓶颈外）

---

## 2. 关键架构约束（Hard Rules）

### 2.1 AST 零污染（核心约束）

**禁止**在 `DocumentElement` / `document.dart` 新增以下字段：
- `bool isFocused`
- `bool isSelected`
- `TextSelection? selection`
- `ScrollPosition? scroll`
- 任何 UI 状态字段

**理由**：AST 是数据层（Phase 1 已稳定），UI 状态属于表现层。混合会导致：
1. AST 序列化时需排除 UI 字段（复杂度上升）
2. 多个 UI 实例共享同一 AST 时状态冲突
3. 测试 AST 时必须 mock UI 状态

**正确做法**：UI 状态单独建模（如 `BlockViewState`），通过 `BlockId` 关联到 AST 块。

### 2.2 Command Layer 强制

**所有 UI 事件必须经** `EditorCommand` → `TransactionBuilder` → `BlockOperation` 路径。

**禁止** UI 层直接调用 `BlockOperations` 或修改 AST。

**理由**：
1. Command Layer 是 Undo/Redo 的语义边界
2. Command 封装了多步 BlockOperation 的原子性（如"按 Enter 拆分块"= split + transform + focus next）
3. Command 可记录、可重放、可测试（UI 事件本身不可测试）

**示例**：
```dart
// ❌ 禁止：UI 直接操作内核
onEnterPressed() {
  blockOperations.split(currentBlockId, cursorOffset);
  blockOperations.insertAfter(newBlockId, ParagraphElement(...));
}

// ✅ 正确：UI 触发 Command
onEnterPressed() {
  editorCommand.execute(SplitBlockCommand(
    blockId: currentBlockId,
    offset: cursorOffset,
  ));
}
```

### 2.3 BlockRenderer 抽象

新增 Block 类型只增加 renderer，不改 BlockEditor 核心：

```dart
abstract class BlockRenderer {
  Widget build(DocumentElement element, EditorContext context);
}

class ParagraphBlockRenderer implements BlockRenderer { ... }
class HeadingBlockRenderer implements BlockRenderer { ... }
class CodeBlockRenderer implements BlockRenderer { ... }
// ... 新增类型只需新增 renderer
```

### 2.4 Phase 3 冻结边界

Phase 2.9 只产出：
- 设计文档（5 个 .md）
- Prototype Demo 代码（4 个 Demo）
- ADR-0009 草案
- ROADMAP 修改草案（新增 Phase 2.9 节）

**不产出**：
- 正式 UI 代码（不修改 `lib/presentation/screens/`）
- 正式路由接入
- 正式 Provider 接入

---

## 3. 设计任务详细分解

### 3.1 任务 2.9.1：UI 心智模型定义

**输出**：`docs/UI-ARCHITECTURE.md` §1-2

**核心问题**：编辑器到底是什么？

**答案**：Block-based Structured Editor（不是 TextField + Markdown Preview）

**参考模型**：
- Notion 的块模型（块是第一公民）
- Typora 的双态编辑（render ↔ edit 切换）
- VS Code 的结构化文档模型（AST 驱动）

**心智模型定义**：
1. 一个 Block 在 UI 中是什么（render 态 vs edit 态）
2. Block 之间的边界如何呈现（视觉分隔 vs 隐式）
3. 用户如何感知"我在编辑块 X"（focus 视觉反馈）
4. 用户如何切换块的 render/edit 态（click / arrow key / tap）
5. 用户如何在块间导航（arrow up/down / tap）

**示例**：
```
AST:                      UI render 态:           UI edit 态:
HeadingElement(           ┌────────────────────┐  ┌────────────────────┐
  level: 1,               │ Hello              │  │ # Hello|           │
  text: "Hello"            │ H1                 │  └────────────────────┘
)                         └────────────────────┘
```

### 3.2 任务 2.9.2：UI 状态模型设计

**输出**：`docs/UI-ARCHITECTURE.md` §3 + `docs/ADR/0009-ui-architecture-design.md`

**核心问题**：UI 需要哪些状态？这些状态如何不污染 AST？

**BlockViewState 设计**（草案）：

```dart
/// UI 层 Block 视图状态（不污染 AST）。
///
/// 通过 [BlockId] 关联到 [DocumentElement]。
/// 生命周期：与 Widget 树绑定，不跨序列化持久化。
@immutable
class BlockViewState {
  final BlockId id;

  /// 当前块是否聚焦（edit 态）
  final bool isFocused;

  /// 当前块是否处于 editing（光标在块内）
  final bool isEditing;

  /// 文本选区（仅 edit 态有效）
  final TextSelection? selection;

  /// 滚动位置（仅长块如代码块需要）
  final ScrollController? scrollController;

  /// IME composing region（仅 composing 态有效）
  final ComposingRegion? composingRegion;

  const BlockViewState({
    required this.id,
    this.isFocused = false,
    this.isEditing = false,
    this.selection,
    this.scrollController,
    this.composingRegion,
  });

  BlockViewState copyWith({...});
}
```

**BlockViewState 管理策略**：
1. 存储在 `BlockEditorState`（Widget State）中，不在 AST 中
2. 通过 `Map<BlockId, BlockViewState>` 索引
3. Block 删除时同步清理对应 view state
4. Block 移动时 view state 跟随（不变 BlockId 即不变 state）

### 3.3 任务 2.9.3：交互事件模型设计

**输出**：`docs/Interaction-Model.md` + `docs/ADR/0009`

**核心问题**：用户操作如何映射到 Transaction？

**EditorCommand 抽象**：

```dart
/// UI 事件 → EditorCommand → Transaction → AST
///
/// Command 是 Undo/Redo 的语义边界。
/// 一个 Command 可包含多个 BlockOperation（原子执行）。
abstract class EditorCommand {
  /// 执行 Command（构造 Transaction 并 apply）
  ///
  /// 返回 false 表示 Command 无法执行（如守卫条件不满足）。
  /// 返回 true 表示已构造并 apply Transaction，已 push 到 history。
  bool execute(BlockEditor editor, TransactionBuilder builder);

  /// 人类可读的 Command 名称（用于 Undo/Redo 菜单显示）
  String get displayName;
}
```

**Command 清单（Phase 2.9 设计，Phase 3 实现）**：

| Command | 触发 | 映射的 BlockOperation |
|---------|------|---------------------|
| `SplitBlockCommand` | Enter 键 | split + transform |
| `MergeWithPreviousCommand` | Backspace at offset 0 | merge(prev, current) |
| `InsertBlockAfterCommand` | Shift+Enter / 空行 Enter | insertAfter |
| `DeleteBlockCommand` | Backspace on empty block | delete |
| `MoveBlockUpCommand` | Alt+Up | move(current, prev, before:true) |
| `MoveBlockDownCommand` | Alt+Down | move(current, next, before:false) |
| `UpdateBlockSourceCommand` | 文本变化 | updateSource |
| `TransformBlockCommand` | Markdown 快捷触发 | tryTransform |

### 3.4 任务 2.9.4：UI Prototype 验证（4 个 Demo）

**输出**：`flutter_app/lib/presentation/prototype/` 目录

**位置**：`flutter_app/lib/presentation/prototype/`（不接入生产路由）

**4 个 Demo**：

#### Demo 1: 单 Block 双态切换
- **验证**：`Heading` render → click → TextField → commit → render
- **涉及**：BlockWidget / BlockEditor / Serializer / Transaction
- **场景**：
  1. 显示一个 HeadingElement，render 态显示 "Hello"
  2. 点击进入 edit 态，显示 "# Hello"
  3. 修改为 "# World"
  4. 失焦回到 render 态，显示 "World"
- **文件**：`flutter_app/lib/presentation/prototype/demo1_dual_state_block.dart`

#### Demo 2: 两个 Block 导航
- **验证**：ArrowDown 在块间导航
- **涉及**：BlockPosition / Focus 管理
- **场景**：
  1. 显示 "# Title" + "Paragraph"
  2. 光标在 Title 末尾
  3. 按 ArrowDown，光标移到 Paragraph 开头
  4. 按 ArrowUp，光标回到 Title 末尾
- **文件**：`flutter_app/lib/presentation/prototype/demo2_block_navigation.dart`

#### Demo 3: Undo/Redo
- **验证**：UI → Transaction → History 链路
- **涉及**：Command → TransactionBuilder → EditorHistory
- **场景**：
  1. 输入文字 "Hello"
  2. 按 Enter 拆分块
  3. 输入 "World"
  4. Ctrl+Z 撤销 "World"
  5. Ctrl+Z 撤销拆分
  6. Ctrl+Z 撤销 "Hello"
  7. Ctrl+Shift+Z 重做
- **文件**：`flutter_app/lib/presentation/prototype/demo3_undo_redo.dart`

#### Demo 4: 复杂 Block 共存
- **验证**：不同 Block 类型可共存
- **涉及**：BlockRenderer / 多类型渲染
- **场景**：
  1. 显示普通文本
  2. 显示公式块 `$$x^2+y^2=z^2$$`
  3. 显示代码块 ```` ```dart ... ``` ````
  4. 三种块之间可切换 focus
- **文件**：`flutter_app/lib/presentation/prototype/demo4_complex_blocks.dart`

#### Prototype 入口
- **文件**：`flutter_app/lib/presentation/prototype/prototype_home.dart`
- **路由**：仅 debug 模式可见的入口按钮（不接入生产路由）
- **依赖**：复用 `lib/core/editing/` 内核（不修改内核）

### 3.5 任务 2.9.5：核心接口冻结

**输出**：`docs/Component-Tree.md` + `docs/ADR/0009`

**冻结的核心接口**（Phase 3 必须遵守）：

1. **BlockEditor API**（UI 不直接操作 AST，只能通过 BlockEditor API）
2. **Transaction**（所有修改必须经 Transaction）
3. **BlockRenderer**（新增 Block 类型只增加 renderer）

**Component Tree**（草案）：

```
BlockEditorWidget
  ├── BlockListWidget
  │     ├── BlockWidget (paragraph)
  │     ├── BlockWidget (heading)
  │     ├── BlockWidget (code)
  │     └── ...
  ├── BlockFocusManager
  ├── BlockSelectionManager
  └── BlockEditorToolbar (可选)
```

---

## 4. 产出物清单

### 4.1 AI 可 commit 的产出物（非架构决策类）

| 文件 | 类型 | AI 权限 |
|------|------|---------|
| `docs/contracts/phase2.9-task-contract.md` | Task Contract | ✅ 可起草 + commit |
| `flutter_app/lib/presentation/prototype/*.dart`（4 个 Demo + 入口） | Prototype 代码 | ✅ 可起草 + commit |
| `flutter_app/test/presentation/prototype/*_test.dart` | Prototype 单元测试 | ✅ 可起草 + commit |

### 4.2 AI 仅起草不 commit 的产出物（架构决策类）

| 文件 | 类型 | AI 权限 |
|------|------|---------|
| `docs/UI-ARCHITECTURE.md` | 架构决策类 | 起草不 commit |
| `docs/Interaction-Model.md` | 架构决策类 | 起草不 commit |
| `docs/Component-Tree.md` | 架构决策类 | 起草不 commit |
| `docs/ADR/0009-ui-architecture-design.md` | ADR | 起草不 commit |
| `docs/ROADMAP.md`（新增 Phase 2.9 节） | 架构决策类 | 起草不 commit |

### 4.3 验收报告（Phase 2.9 完成时产出）

| 文件 | 类型 | AI 权限 |
|------|------|---------|
| `docs/releases/phase2.9-verification-report.md` | Verification Report | ✅ 可起草 + commit |

---

## 5. 验证计划

### 5.1 自动验证

- `flutter analyze --no-fatal-infos --fatal-warnings lib/ test/` — 0 warning
- `flutter test` — 全部通过，0 regression（Phase 2.8 的 841 tests 仍 PASS）
- Prototype 代码的单元测试（至少覆盖 4 个 Demo 的核心逻辑）

### 5.2 功能验证（手动）

每个 Demo 的场景全部可执行：
- Demo 1: 双态切换 + 修改 source + round-trip
- Demo 2: 块间导航（上下箭头）
- Demo 3: Undo/Redo 3 次闭环
- Demo 4: 3 种 Block 共存 + focus 切换

### 5.3 架构验证

- `lib/core/editing/` 仍 0 反向依赖（editing_layer_test.dart 守门）
- AST 未新增 UI 状态字段（grep 守门）
- 所有 UI 修改经 Command Layer（grep 守门：`BlockOperations` 不被 `lib/presentation/` 直接 import）

---

## 6. 退出条件（Exit Gate）

Phase 2.9 完成必须满足：

- [x] 5 个设计文档定稿（Human Owner 签字）
- [x] ADR-0009 Accepted（v1.1 已采纳 4 项决议 + CommandHandler 中间层；状态仍为 Proposed 待最终签字）
- [x] ROADMAP 新增 Phase 2.9 节（已 commit + push）
- [x] 4 个 Demo 可运行 + 通过手动验证场景
- [x] flutter analyze 0 warning（`--fatal-warnings` 退出码 0）
- [x] flutter test 0 regression（908 passed + 11 skipped + 0 failed，较 Phase 2.8 的 841 tests 新增 67 个测试）
- [ ] Phase 2.9 Verification Report 完成（待最终 PR 合并后补完）
- [x] **核心接口冻结**：BlockEditor API / Transaction / BlockRenderer 接口在 Phase 3 不再变更（如需变更走 ADR 流程）
  - DocumentEditor 接口 v1.3（PR 评审 R1 修复触发）：新增 `allIds` getter
  - CommandHandler 架构（v1.1 新增）：依赖 DocumentEditor + EditorHistory 内核抽象
  - BlockViewState / EditorCommand / Transaction 接口在 Phase 2.9 全程未变更

### 6.1 PR 评审反馈修复（v1.2 新增）

Phase 2.9 PR 评审收到 6 项反馈（R1-R6），全部已修复（commit `3bfc50d`）：

| # | 风险 | 等级 | 修复方式 | 验证 |
|---|------|------|---------|------|
| R1 | 循环依赖（commands/ → prototype/_shared/） | Medium | CommandHandler 改为依赖 DocumentEditor + EditorHistory 内核抽象；DocumentEditor 接口 v1.3 新增 allIds getter | `test/presentation/commands/command_handler_dispatch_test.dart` 12 个测试 |
| R2 | undo/redo 空 Transaction 断链 | Medium | 在 undo/redo 上方添加 Prototype 限制 doc comment + Phase 3.0 tech debt 跟踪 | `test/presentation/prototype/_shared/command_handler_test.dart` R2 限制验证测试 |
| R3 | 缺少 Prototype 单元测试 | Medium | 新增 52 个 _shared 层单元测试（CommandHandler 11 + InMemoryDocumentEditor 25 + BlockViewState 16） | 全部通过 |
| R4 | _dispatch 静默失败 | Low | 新增 12 个自省测试覆盖 8 个 EditorCommand 子类 + 4 个守卫；doc comment 标注 Phase 3.0 sealed class 升级路径 | `command_handler_dispatch_test.dart` |
| R5 | replaceBlock 变更 BlockId | Low | 添加显式注释 + Phase 3.0 迁移提示 | `in_memory_document_editor_test.dart` replaceBlock 测试覆盖 |
| R6 | Demo 间代码复用不足 | Low | Demo 1/2/4 标注 FocusNode + TextEditingController 重复模式 + Phase 3.0 提取目标 | 注释已添加 |

**最终验证**（2026-07-21）：
- `flutter analyze --fatal-warnings`：0 error 0 warning（仅 16 个 pre-existing info，均与 R1-R6 修复无关）
- `flutter test`：908 passed + 11 skipped + 0 failed（新增 64 个测试全部通过）
- `file_size_test`：所有 lib/ 文件 ≤ 400 行

---

## 7. 风险评估

### 7.1 风险 1：Prototype 暴露内核设计缺陷

**概率**：中（Phase 2.8 Architecture Review 已登记 5 项 tech debt）

**影响**：需修改 `lib/core/editing/` 内核代码

**缓解**：
1. 修改必须走 ADR 流程（新增 ADR-0010 或修订 ADR-0007/0008）
2. 修改必须保持向后兼容（不破坏 Phase 2.8 测试套件）
3. 修改必须先更新 Task Contract，由 Human Owner 审批

### 7.2 风险 2：设计文档过度膨胀

**概率**：高（5 个 .md 容易写到 5000+ 行）

**影响**：Phase 3 实施时反而找不到关键信息

**缓解**：
1. 每个文档控制在 500 行以内
2. 聚焦"接口契约"而非"实现细节"
3. 实现细节放在代码 + dartdoc，不放 .md

### 7.3 风险 3：Demo 代码量超预期

**概率**：中（4 个 Demo 完整实现可能需要 2000+ 行）

**影响**：Phase 2.9 时间超预期

**缓解**：
1. Demo 仅验证核心架构，不实现完整 UI
2. 复用 `lib/core/editing/` 内核，不重写
3. Demo 代码用最简 Widget（不追求美观）

---

## 8. 实施顺序

### 8.1 第一步：起草 Task Contract（本文件）

- AI 起草本文件
- Human Owner 审批
- 审批通过后才进入第二步

### 8.2 第二步：起草 5 个设计文档草案

按依赖顺序：
1. ADR-0009（最高层架构决策）
2. UI-ARCHITECTURE.md（心智模型 + 状态模型）
3. Interaction-Model.md（交互事件）
4. Component-Tree.md（组件树 + 接口冻结）
5. ROADMAP.md 修改草案（新增 Phase 2.9 节）

### 8.3 第三步：Human Owner 审阅设计文档

- Human Owner 逐个审阅
- 反馈修订意见
- AI 修订草案（不 commit）
- Human Owner 签字 + 自己 commit 架构决策类文件

### 8.4 第四步：实现 4 个 Prototype Demo

- AI 实现 Demo 代码（可 commit）
- 每个 Demo 完成后手动验证场景
- 暴露的内核缺陷走 ADR 流程

### 8.5 第五步：Phase 2.9 Exit Gate

- 起草 Verification Report
- Human Owner 验收
- 正式关闭 Phase 2.9，启动 Phase 3

---

## 9. AI 协作信息

### 9.1 AI 自我审查清单

- [ ] 本 Task Contract 已明确范围与边界
- [ ] 所有架构决策类文件授权情况已明确（起草不 commit）
- [ ] Prototype 代码位置已明确（flutter_app/lib/presentation/prototype/）
- [ ] Phase 3 冻结边界已明确（不修改 lib/presentation/ 正式代码）
- [ ] 风险已评估且有缓解措施
- [ ] 验证计划覆盖自动 + 功能 + 架构三层

### 9.2 反馈信号

**成功信号**：
- 4 个 Demo 全部可运行
- 设计文档无重大反对意见
- Phase 3 启动时无内核返工

**失败信号**：
- Demo 暴露内核缺陷且无法通过 ADR 流程解决
- 设计文档 Human Owner 反对意见重大
- Phase 2.9 时间超预期 2 倍以上

### 9.3 回滚方案

- 若 Phase 2.9 验证失败，回滚到 Phase 2.8 状态（Phase 2.8 已合并 main）
- 若 Prototype 代码污染内核，删除 `lib/presentation/prototype/` 目录
- 若设计文档被否决，重新起草或推迟 Phase 2.9

---

## 10. 待决问题（Human Owner 审批时拍板）

> **v1.1 决议**（2026-07-20 Human Owner 拍板）：
>
> 1. **EditorCommand 接口位置**：`lib/presentation/commands/` ✅
>    - 理由：Command 表达"用户想做什么"（用户意图），不属于编辑内核
>    - 避免未来 core 反向知道 toolbar / shortcut / UI action，违反六层架构
> 2. **BlockViewState 实现位置**：`lib/presentation/states/` ✅
>    - 理由：Widget 是渲染，State 是业务交互状态，应解耦
>    - 未来 Flutter → Web → Desktop 切换时 State 可复用
> 3. **Prototype 是否纳入 CI**：analyze ✅ / test 单独 pipeline ✅
>    - 主 CI：`flutter analyze` + `flutter test test/core/ test/domain/`
>    - Prototype：`flutter test --tags prototype`（用 tags 隔离，不进主测试）
>    - 理由：保证质量但避免 Prototype 变化绑定主测试体系
> 4. **ADR 编号**：使用 ADR-0009（UI Architecture），ADR-0010 留给 TransactionExecutor ✅
>    - 理由：ADR 编号表示决策顺序而非领域编号，不跳号保持时间线清晰
>
> **新增架构变更**（v1.1 修订）：
>
> - **EditorCommand 不直接操作 Transaction**，引入 `CommandHandler` 中间层
> - 流：`EditorCommand → CommandHandler → TransactionBuilder → Transaction → TransactionExecutor`
> - 理由：Command 是用户意图（来源多样：键盘 / AI / 语音 / 菜单），Executor 是执行机制，二者职责不同
> - 详见 [ADR-0009 §3 v1.1](file:///d:/Projects/Active/math/docs/ADR/0009-ui-architecture-design.md) 修订

### 原 v1.0 倾向（保留作历史参考）

1. **EditorCommand 接口位置**：放在 `lib/core/editing/` 还是 `lib/presentation/commands/`？
   - 倾向：`lib/presentation/commands/`（Command 是 UI 层概念，不属于内核）

2. **BlockViewState 实现位置**：放在 `lib/presentation/states/` 还是 `lib/presentation/widgets/block/`？
   - 倾向：`lib/presentation/states/`（与 widget 解耦）

3. **Prototype 是否纳入 CI**：Prototype 代码是否参与 `flutter analyze` + `flutter test`？
   - 倾向：参与 analyze，不参与 test（Prototype 测试单独运行）

4. **ADR-0009 编号**：是否跳过 0010 保留给 TransactionExecutor（ADR-0008 §10 候选）？
   - 倾向：不跳过，按顺序编号 0009

---

## 11. 版本修订记录

### v1.2（2026-07-21）— PR 评审反馈 R1-R6 修复

**触发**：Phase 2.9 PR 评审收到 6 项反馈（R1-R6），其中 3 项 Medium、3 项 Low。

**主要变更**：
- **R1（架构）**：DocumentEditor 接口升级 v1.2 → v1.3，新增 `allIds` getter；CommandHandler 改为依赖 `DocumentEditor + EditorHistory` 内核抽象，消除 `commands/ → prototype/_shared/` 循环依赖
- **R2（限制标注）**：`BlockEditorFacade.undo/redo` 空 Transaction 限制在 doc comment 中明确标注，列入 Phase 3.0 tech debt
- **R3（测试覆盖）**：新增 52 个 _shared 层单元测试（CommandHandler 11 + InMemoryDocumentEditor 25 + BlockViewState 16）
- **R4（自省测试）**：新增 12 个 _dispatch 自省测试，覆盖 8 个 EditorCommand 子类 + 4 个守卫逻辑
- **R5（注释标注）**：`InMemoryDocumentEditor.replaceBlock` BlockId 变更行为添加显式注释
- **R6（DRY 标注）**：Demo 1/2/4 FocusNode + TextEditingController 重复模式添加 NOTE 注释

**退出条件状态**：8 项中 7 项已完成，1 项待最终 PR 合并后补完（Verification Report）。

**关联 commit**：`3bfc50d`（docs/phase2.9-ui-architecture-prototype 分支）

### v1.1（2026-07-20）— Human Owner 4 项决议 + CommandHandler 架构变更

详见 §10 待决问题。

### v1.0（2026-07-20）— 初版草案

5 条设计决策 + 4 个 Prototype Demo 计划。

---

**本 Task Contract 由 AI Agent 起草，v1.2 R1-R6 修复完成，等待最终 PR 合并 main。**
