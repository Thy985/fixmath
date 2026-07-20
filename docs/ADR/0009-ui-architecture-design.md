# ADR-0009: UI Architecture Design

> **状态**：Proposed（草案，待 Human Owner 审批）
> **版本**：v1.1（采纳 4 项决议 + 新增 CommandHandler 中间层）
> **起草日期**：2026-07-20
> **起草人**：AI Agent（GLM-5.2）
> **关联文档**：[ADR-0007](docs/ADR/0007-blockeditor-abstraction-design.md) / [ADR-0008](docs/ADR/0008-editor-transaction-model.md) / [Phase 2.9 Task Contract](docs/contracts/phase2.9-task-contract.md)

## 版本修订记录

- **v1.0**（2026-07-20）：初版草案，5 条决策（UI 心智模型 / BlockViewState / Command Layer / BlockRenderer / 接口冻结）
- **v1.1**（2026-07-20）：采纳 Human Owner 4 项决议 + 新增 CommandHandler 中间层
  1. EditorCommand 位置确定为 `lib/presentation/commands/`（原草案已倾向，现确认）
  2. BlockViewState 位置确定为 `lib/presentation/states/`（原草案已倾向，现确认）
  3. Prototype CI 策略确定：analyze 进 CI，test 用 `--tags prototype` 隔离
  4. ADR 编号确定：ADR-0009（UI Architecture），ADR-0010 留给 TransactionExecutor
  5. **新增 §3 CommandHandler 中间层**：EditorCommand 不直接操作 TransactionBuilder，引入 CommandHandler 解耦"用户意图"与"执行机制"

---

## 背景

### 当前状态

FormulaFix 已完成 Phase 2.1~2.8 块级编辑内核建设：
- AST（Phase 1）：`DocumentElement` 9 种块类型稳定
- Transaction Model（Phase 2.6）：`BlockOperation` 6 原语 + `EditorHistory` + Coalescing
- IME 三铁律（Phase 2.5）：composing 态守门 + commit 入栈 + cancel 不入栈
- Markdown 快捷（Phase 2.7）：12 类规则自动 transform
- Integration Hardening（Phase 2.8）：841 tests / 0 regression / per-block 0.0752ms

内核可在纯 Dart 逻辑中独立运行，0 UI 反向依赖。

### 待决问题

Phase 3 即将进入 UI 实现，但若直接写 Widget，可能出现：
1. **AST 污染风险**：UI 状态（focus / selection / scroll）被错误地塞进 `DocumentElement`
2. **内核绕过风险**：UI 直接调 `BlockOperations`，破坏 Undo/Redo 语义
3. **接口不稳风险**：BlockEditor API / BlockRenderer 缺乏冻结契约，Phase 3 实施中频繁变更
4. **架构返工风险**：UI 实施暴露内核设计缺陷（如缺少 `BlockPosition` 抽象），被迫回头改内核

### 现有约束

- [ADR-0003](docs/ADR/0003-storage-single-source-md-files.md)：单一真相源（.md 文件），UI 状态不持久化
- [ADR-0007](docs/ADR/0007-blockeditor-abstraction-design.md) §1.3：Block 是 AST 的编辑态视图（Wrapping 而非 Flattening）
- [ADR-0008](docs/ADR/0008-editor-transaction-model.md) §9：BlockId 是 in-memory identity，不跨序列化持久化
- [ADR-0008](docs/ADR/0008-editor-transaction-model.md) §10：TransactionExecutor 是 Phase 2.8+ 候选（tech debt）
- [AGENTS.md §6.5](AGENTS.md)：Phase 2 期间 UI 行为冻结，Phase 2.9 仍属 Phase 2 范畴

### 触发本 ADR 的事件

Phase 2.8 Integration Hardening 完成后，Human Owner 提出：Phase 3 开始前应先做 UI Architecture Prototype（Phase 2.9），避免直接编码 UI 导致架构返工。

---

## 决策

### 1. UI 心智模型：Block-based Structured Editor

**决策**：FormulaFix 是 Block-based Structured Editor，不是 "TextField + Markdown Preview"。

**三层心智模型**：
1. **块是第一公民**：所有内容以块为单位组织（Paragraph / Heading / Code / Table / Formula 等）
2. **双态切换**：每个块有 render 态（最终样式）和 edit 态（Markdown source）两种显示
3. **AST 驱动**：UI 渲染由 AST + BlockRenderer 决定，UI 不持有文档结构

**对比**：
| 模型 | 代表 | FormulaFix 是否采用 |
|------|------|---------------------|
| TextField + Preview | 传统 Markdown 编辑器 | ❌ |
| Block-based（Notion）| Notion / Obsidian | ✅ 部分借鉴 |
| 双态切换（Typora）| Typora | ✅ 部分借鉴 |
| 结构化文档（VS Code）| VS Code / Monaco | ✅ AST 驱动部分 |

### 2. UI 状态模型：BlockViewState 与 AST 零污染

**决策**：UI 状态单独建模为 `BlockViewState`，通过 `BlockId` 关联到 AST，**禁止**在 `DocumentElement` 新增任何 UI 状态字段。

**BlockViewState 草案**：
```dart
@immutable
class BlockViewState {
  final BlockId id;
  final bool isFocused;          // 当前块是否聚焦（edit 态）
  final bool isEditing;          // 光标是否在块内
  final TextSelection? selection; // 文本选区（仅 edit 态）
  final ComposingRegion? composingRegion; // IME composing（仅 composing 态）
  // 注：ScrollController 不放入 state（widget 自管）
}
```

**管理策略**：
1. 存储在 `BlockEditorWidgetState`（Widget State）中，不在 AST 中
2. 通过 `Map<BlockId, BlockViewState>` 索引
3. Block 删除时同步清理对应 view state
4. Block 移动时 view state 跟随（不变 BlockId 即不变 state）
5. 不跨序列化持久化（与 BlockId 一致，[ADR-0008 §9](docs/ADR/0008-editor-transaction-model.md)）

**禁止**（Hard Rule）：
- ❌ 在 `DocumentElement` 新增 `isFocused` / `isSelected` / `selection` / `scrollPosition` 等 UI 字段
- ❌ 在 `document.dart` 新增 `focusedBlockId` / `currentSelection` 等 UI 状态
- ❌ 在 `DocumentEditor` 新增 `focusBlock(BlockId)` 等 UI 操作方法

### 3. 交互事件模型：Command Layer + CommandHandler

**决策**（v1.1 修订）：所有 UI 事件必须经 `EditorCommand → CommandHandler → TransactionBuilder → Transaction` 路径，**EditorCommand 不直接操作 TransactionBuilder**。

> **注**：`TransactionExecutor` 是未来 ADR-0010 候选（接管 Transaction 生命周期 / notification / concurrency），当前 v1.1 由 `CommandHandler` 隐式承担执行职责。详见 §3.6。

**核心原则**：
- **Command 是用户意图**：来自键盘 / AI / 语音 / 菜单 / 手势，描述"用户想做什么"
- **Handler 是意图分发器**：解释 Command 为 BlockOperation 序列，并管理 TransactionBuilder 生命周期
- **Executor 是未来扩展位**：当前 CommandHandler 隐式承担，未来 ADR-0010 接管
- **二者职责分离**：Command 不感知执行细节，Handler 不感知意图来源

#### 3.1 五层执行流（v1.1 当前）

```
Keyboard / AI / Voice / Menu / Gesture
        │
        ↓
   EditorCommand（用户意图，纯数据）
        │
        ↓
   CommandHandler（意图分发 + 守卫 + TransactionBuilder 生命周期 + history push）
        │
        ↓
   TransactionBuilder（内核：构造 Transaction）
        │
        ↓
   Transaction（一组 BlockOperation 容器）
        │
        ↓
   DocumentEditor → AST mutation
```

> **未来 ADR-0010 启用后**：在 `CommandHandler` 与 `TransactionBuilder` 之间插入 `TransactionExecutor` 层（接管 notification / concurrency / batch apply）。当前 v1.1 不引入此层，避免 Phase 2.9 过度设计。详见 §3.6。

#### 3.2 EditorCommand 接口（v1.1 修订）

```dart
/// UI 事件 → EditorCommand（用户意图，纯数据）
///
/// **v1.1 关键变更**：
/// - Command 不再直接 execute(TransactionBuilder)
/// - 改为描述意图（payload），由 CommandHandler 解释为 BlockOperation
/// - 这样 Command 可序列化、可记录、可重放（用于 AI / 录制回放 / 协同编辑）
///
/// 详见 [ADR-0009 §3](docs/ADR/0009-ui-architecture-design.md)
@immutable
abstract class EditorCommand {
  /// 人类可读的 Command 名称（用于 Undo/Redo 菜单显示）
  String get displayName;

  /// Command 来源（keyboard / ime / ai / voice / menu / gesture）
  CommandOrigin get origin;
}

/// Command 来源枚举
enum CommandOrigin {
  keyboard,  // 键盘输入
  ime,       // IME commit
  ai,        // AI Agent（未来）
  voice,     // 语音输入（未来）
  menu,      // 工具栏菜单
  gesture,   // 手势（tap / drag）
}
```

#### 3.3 CommandHandler 接口（v1.1 新增）

```dart
/// CommandHandler：解释 EditorCommand 为 BlockOperation 序列
///
/// 职责：
/// 1. 接收 [EditorCommand]（用户意图）
/// 2. 守卫检查（如 composing 态拒绝、空文档守卫等）
/// 3. 构造 [TransactionBuilder]（含正确的 origin / coalescing 标记）
/// 4. 调用 [BlockOperations] 执行 BlockOperation
/// 5. commit Transaction 并 push 到 [EditorHistory]
/// 6. 触发 onChange notification
///
/// **不持有 UI 状态**：CommandHandler 是纯逻辑层，由 BlockEditorWidgetState 持有
///
/// 详见 [Interaction-Model.md §2](docs/Interaction-Model.md)
class CommandHandler {
  final BlockEditor _editor;

  CommandHandler(this._editor);

  /// 处理 [command]，返回是否成功
  ///
  /// 内部流程：
  /// 1. 守卫检查（composing / 空文档等）
  /// 2. 构造 TransactionBuilder（origin = command.origin）
  /// 3. 分发到对应的 _handle* 方法
  /// 4. 成功 → builder.commit() + history.pushTransaction
  /// 5. 失败 → builder.rollback()
  bool handle(EditorCommand command) {
    // 守卫：composing 态拒绝（IME 三铁律）
    if (_editor.composing?.isActive == true) return false;

    final builder = TransactionBuilder(
      origin: _toTransactionOrigin(command.origin),
      onChange: (tx) => _editor.history.pushTransaction(tx),
    );

    final success = _dispatch(command, builder);
    if (success) {
      builder.commit();
    } else {
      builder.rollback();
    }
    return success;
  }

  /// 分发 [command] 到对应处理方法
  bool _dispatch(EditorCommand command, TransactionBuilder builder) {
    return switch (command) {
      SplitBlockCommand c => _handleSplitBlock(c, builder),
      MergeWithPreviousCommand c => _handleMerge(c, builder),
      InsertBlockAfterCommand c => _handleInsert(c, builder),
      DeleteBlockCommand c => _handleDelete(c, builder),
      MoveBlockUpCommand c => _handleMoveUp(c, builder),
      MoveBlockDownCommand c => _handleMoveDown(c, builder),
      UpdateBlockSourceCommand c => _handleUpdateSource(c, builder),
      TransformBlockCommand c => _handleTransform(c, builder),
    };
  }

  TransactionOrigin _toTransactionOrigin(CommandOrigin origin) {
    return switch (origin) {
      CommandOrigin.keyboard => TransactionOrigin.keyboard,
      CommandOrigin.ime => TransactionOrigin.ime,
      CommandOrigin.ai => TransactionOrigin.programmatic,
      CommandOrigin.voice => TransactionOrigin.programmatic,
      CommandOrigin.menu => TransactionOrigin.programmatic,
      CommandOrigin.gesture => TransactionOrigin.programmatic,
    };
  }

  // 各 _handle* 方法调用 _editor.operations.* 执行 BlockOperation
  bool _handleSplitBlock(SplitBlockCommand c, TransactionBuilder b) {
    return _editor.operations.split(c.blockId, c.offset);
  }
  // ... 其他 _handle* 方法
}
```

#### 3.4 Command 清单（v1.1 修订）

| Command | 触发 | 映射的 BlockOperation | CommandHandler 分发 |
|---------|------|---------------------|--------------------|
| `SplitBlockCommand` | Enter 键 | split + tryTransform | `_handleSplitBlock` |
| `MergeWithPreviousCommand` | Backspace at offset 0 | merge(prev, current) | `_handleMerge` |
| `InsertBlockAfterCommand` | Shift+Enter | insertAfter | `_handleInsert` |
| `DeleteBlockCommand` | Backspace on empty block | delete | `_handleDelete` |
| `MoveBlockUpCommand` | Alt+Up | move(current, prev, before:true) | `_handleMoveUp` |
| `MoveBlockDownCommand` | Alt+Down | move(current, next, before:false) | `_handleMoveDown` |
| `UpdateBlockSourceCommand` | 文本变化（debounce） | updateSource | `_handleUpdateSource` |
| `TransformBlockCommand` | Markdown 快捷触发 | tryTransform | `_handleTransform` |

#### 3.5 文件位置（v1.1 确认）

| 组件 | 位置 | 说明 |
|------|------|------|
| `EditorCommand`（abstract） | `lib/presentation/commands/editor_command.dart` | UI 层意图抽象 |
| `CommandOrigin`（enum） | `lib/presentation/commands/editor_command.dart` | 同文件 |
| 8 个 Command 实现 | `lib/presentation/commands/*_command.dart` | 每个文件一个 Command |
| `CommandHandler` | `lib/presentation/commands/command_handler.dart` | 意图分发 + 守卫 + Transaction 生命周期 |

#### 3.6 与未来 TransactionExecutor（ADR-0010）的边界

**当前 v1.1**：CommandHandler 是隐式执行器（构造 TransactionBuilder + commit + push history）

**未来 ADR-0010 TransactionExecutor 启动后**：
- `CommandHandler` 职责缩小为"意图分发 + 守卫"
- `TransactionExecutor` 接管"Transaction 生命周期 + notification + concurrency"
- 流变为：`EditorCommand → CommandHandler → TransactionExecutor → TransactionBuilder → Transaction`

**当前 v1.1 不引入 TransactionExecutor**：
- 避免 Phase 2.9 过度设计（CommandHandler 已足够）
- 待 Phase 3 UI 接入后，若发现 CommandHandler 性能瓶颈 / 并发需求，再启动 ADR-0010

**理由**：
1. Command 是 Undo/Redo 的语义边界（一个用户操作 = 一个 Transaction）
2. Command + Handler 封装了多步 BlockOperation 的原子性（如 Enter = split + transform + focus next）
3. Command 可序列化、可记录、可重放（未来 AI / 协同编辑用）
4. Handler 隔离了意图（Command）与执行（Executor），未来扩展不破坏 Command 接口

### 4. BlockRenderer 抽象

**决策**：新增 Block 类型只增加 renderer，不改 BlockEditor 核心。

**BlockRenderer 接口**：
```dart
/// Block 渲染器抽象。
///
/// 新增 Block 类型只需新增 [BlockRenderer] 实现，不改 BlockEditor 核心。
abstract class BlockRenderer {
  /// 构建块的 render 态 Widget（最终样式）
  Widget build(DocumentElement element, BlockRendererContext context);

  /// 该 renderer 是否处理 [element] 类型
  bool matches(DocumentElement element);
}

class BlockRendererContext {
  final bool isFocused;
  final TextSelection? selection;
  final ComposingRegion? composingRegion;
  // ... 其他 UI 状态
}
```

**Renderer 注册表**（Phase 2.9 设计，Phase 3 实现）：
```dart
class BlockRendererRegistry {
  final List<BlockRenderer> _renderers = [
    ParagraphBlockRenderer(),
    HeadingBlockRenderer(),
    CodeBlockRenderer(),
    TableBlockRenderer(),
    FormulaBlockRenderer(),
    MermaidBlockRenderer(),
    ListBlockRenderer(),
    BlockquoteBlockRenderer(),
    HorizontalRuleBlockRenderer(),
  ];

  BlockRenderer resolve(DocumentElement element) {
    return _renderers.firstWhere(
      (r) => r.matches(element),
      orElse: () => ParagraphBlockRenderer(),  // fallback
    );
  }
}
```

### 5. 核心接口冻结

**决策**：以下接口在 Phase 3 实施时不再变更（如需变更走 ADR 流程）：

| 接口 | 当前位置 | 冻结内容 |
|------|---------|---------|
| `BlockEditor` API | [ADR-0007 §1.1](docs/ADR/0007-blockeditor-abstraction-design.md) | 接口签名 |
| `Transaction` / `TransactionBuilder` | [ADR-0008 §1-3](docs/ADR/0008-editor-transaction-model.md) | commit / rollback / 嵌套 |
| `BlockOperations` 五原语 + transform | [block_operations.dart](flutter_app/lib/core/editing/block_operations.dart) | 6 个方法签名 |
| `EditorHistory` coalescing | [editor_history.dart](flutter_app/lib/core/editing/editor_history.dart) | 7 触发条件 |
| `ComposingController` 三铁律 | [composing_controller.dart](flutter_app/lib/core/editing/composing_controller.dart) | 3 条铁律 |

**新增接口**（Phase 2.9 设计，Phase 3 实现）：
- `EditorCommand`（abstract class）
- `BlockViewState`（@immutable class）
- `BlockRenderer`（abstract class）
- `BlockRendererRegistry`
- `BlockFocusManager`
- `BlockSelectionManager`

---

## 动机

### 1. 为什么禁止 AST 污染？

**反例**（如果允许 AST 污染）：
```dart
// ❌ 错误：AST 持有 UI 状态
class HeadingElement extends DocumentElement {
  final int level;
  final String text;
  final bool isFocused;  // UI 状态污染
  final TextSelection? selection;  // UI 状态污染
}
```

**问题**：
1. **序列化复杂度**：`toElement` / `fromElement` 必须排除 UI 字段（易出 bug）
2. **多视图冲突**：同一 AST 被多个 UI 实例（如预览 + 编辑）共享时，UI 状态冲突
3. **测试复杂度**：AST 单元测试必须 mock UI 状态
4. **架构倒退**：违反六层架构（[AGENTS.md §1.1](AGENTS.md)），`data/` 层反向持有 `presentation/` 概念

**正例**（BlockViewState 与 AST 解耦）：
```dart
// ✅ 正确：AST 保持纯净
class HeadingElement extends DocumentElement {
  final int level;
  final String text;
}

// UI 状态单独建模
class BlockViewState {
  final BlockId id;
  final bool isFocused;
  final TextSelection? selection;
}
```

### 2. 为什么强制 Command Layer？

**反例**（如果允许 UI 直接调 BlockOperations）：
```dart
// ❌ 错误：UI 直接操作内核
onEnterPressed() {
  blockOperations.split(currentBlockId, cursorOffset);
  blockOperations.insertAfter(newBlockId, ParagraphElement(...));
}
```

**问题**：
1. **Undo/Redo 语义破坏**：两步操作产生两个 Transaction，Undo 只能撤销一步
2. **原子性丧失**：split 成功但 insertAfter 失败时，状态不一致
3. **不可测试**：UI 事件本身无法单测（需 Widget 测试）

**正例**（Command 封装原子性）：
```dart
// ✅ 正确：UI 触发 Command
onEnterPressed() {
  editor.execute(SplitBlockCommand(
    blockId: currentBlockId,
    offset: cursorOffset,
  ));
}

class SplitBlockCommand implements EditorCommand {
  bool execute(BlockEditor editor, TransactionBuilder builder) {
    // 一个 Command = 一个 Transaction（含多 op，原子保证）
    final newId = editor.operations.split(blockId, offset);
    if (newId != null) {
      editor.operations.tryTransform(newId);  // 同 Transaction
    }
    return newId != null;
  }
}
```

### 3. 为什么 BlockRenderer 抽象？

**理由**：
1. **开闭原则**：新增 Block 类型（如未来 Admonition / Callout）不改 BlockEditor 核心
2. **测试隔离**：每个 renderer 独立测试
3. **主题切换**：不同主题可注册不同 renderer 集合（Phase 4）

---

## 后果

### 正面后果

1. **Phase 3 UI 开发变为工程实现**：接口冻结后，UI 开发无架构决策，只写代码
2. **内核稳定性提升**：AST / Transaction / BlockOperations 不再受 UI 需求干扰
3. **测试覆盖清晰**：UI 单测（Command / BlockViewState / Renderer）+ 内核单测分离
4. **多视图可行性**：未来可支持同一 AST 多 UI 实例（编辑 + 预览 + 大纲）

### 负面后果

1. **Command Layer 增加代码量**：每个用户操作需定义 Command 类（约 8 个核心 Command）
2. **BlockViewState 管理复杂度**：需手动维护 state 生命周期（与 Widget 树同步）
3. **Command 与 BlockOperations 边界**：需明确哪些操作属于 Command 哪些属于 BlockOperations（如 focus 切换不进 Command）

### 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| Prototype 暴露内核设计缺陷 | 走 ADR-0010 流程修订内核（不破坏向后兼容） |
| BlockViewState 设计错误 | Phase 2.9 Prototype 验证后冻结 |
| Command Layer 过度设计 | 8 个核心 Command 即上限，不预先抽象 base class |

---

## 替代方案

### 替代方案 A：UI 直接操作内核（无 Command Layer）

**方案**：UI 直接调 `BlockOperations`，Transaction 由 UI 构造。

**否决理由**：
1. Undo/Redo 语义破坏（一个用户操作 = 多 Transaction）
2. 原子性丧失（多步操作中间失败无回滚）
3. UI 不可测试

### 替代方案 B：Command Layer 放入内核（`lib/core/editing/commands/`）

**方案**：把 EditorCommand 放入 `lib/core/editing/commands/`。

**否决理由**：
1. Command 是 UI 层概念（与 Focus / Selection / Keyboard 强耦合）
2. 放入内核会让内核反向依赖 UI 概念（如 TextSelection）
3. 违反 [AGENTS.md §1.1](AGENTS.md) 六层架构（core 不允许 import presentation）

### 替代方案 C：BlockViewState 与 Widget State 合并

**方案**：不显式建模 BlockViewState，每个 BlockWidget 自管 state。

**否决理由**：
1. 块间导航需要外部 state（如 BlockFocusManager 知道下一个 focus 块）
2. Undo/Redo 后需重建 state（若 state 散落在 widget，重建困难）
3. 多 widget 共享 state 困难（如 toolbar 需读当前 focus 块类型）

---

## 设计意图

### 1. 五层映射的工程价值

```
          用户体验层           ← 用户感知
              │
              ↓
       UI Interaction Model     ← Phase 2.9 新增（Command + BlockViewState + BlockRenderer）
              │
              ↓
       BlockEditor API          ← Phase 2.1 抽象（接口冻结）
              │
              ↓
       Transaction Model        ← Phase 2.6 稳定（不改）
              │
              ↓
       Document AST             ← Phase 1 稳定（不改）
```

**核心价值**：每一层职责单一、接口冻结、可独立测试。

### 2. 与 ADR-0007 / ADR-0008 的关系

- **ADR-0007**（BlockEditor 抽象）：定义 `BlockEditor` 接口 + 块类型 + 双态切换机制
- **ADR-0008**（Transaction Model）：定义 Transaction + History + Coalescing + IME 三铁律
- **ADR-0009**（本 ADR）：定义 UI 如何使用 ADR-0007/0008 的内核——UI 状态模型 + Command Layer + Renderer 抽象

**ADR-0009 不修改 ADR-0007/0008 的内核设计**，只定义 UI 层如何对接。

---

## 未来扩展边界

### 1. Phase 3 实施时允许的变更

- 新增 `EditorCommand` 实现类（不修改抽象接口）
- 新增 `BlockRenderer` 实现类（不修改抽象接口）
- 新增 `BlockViewState` 字段（向后兼容，不删除现有字段）

### 2. Phase 3 实施时不允许的变更（需走 ADR 流程）

- 修改 `EditorCommand` 抽象接口签名
- 修改 `BlockRenderer` 抽象接口签名
- 修改 `BlockOperations` 6 个原语签名
- 修改 `EditorHistory` coalescing 7 触发条件
- 在 `DocumentElement` 新增 UI 状态字段

### 3. 与协同编辑（Phase 4+）的兼容性

- `BlockViewState` 与协同编辑无关（仅本地 UI）
- `EditorCommand` 可作为协同编辑的操作单元（CRDT 操作映射到 Command）
- `BlockRenderer` 可扩展为协同感知渲染（显示其他用户光标）

---

## 验证计划

### 1. 自动验证

- `flutter analyze` 守门：`lib/presentation/` 不得直接 import `BlockOperations` / `TransactionBuilder`
- grep 守门：`document.dart` 不得出现 `isFocused` / `isSelected` / `selection` 字段
- editing_layer_test.dart 守门：`lib/core/editing/` 0 反向依赖

### 2. 功能验证（4 个 Demo）

详见 [Phase 2.9 Task Contract §3.4](docs/contracts/phase2.9-task-contract.md)

### 3. 架构验证

- BlockEditor API / Transaction / BlockRenderer 接口在 Phase 3 实施中无变更
- 若需变更，走 ADR-0010+ 流程

---

## 参考文档

- [Phase 2.9 Task Contract](docs/contracts/phase2.9-task-contract.md)
- [ADR-0007 BlockEditor 抽象设计](docs/ADR/0007-blockeditor-abstraction-design.md)
- [ADR-0008 Transaction Model](docs/ADR/0008-editor-transaction-model.md)
- [AGENTS.md §1.1 六层架构](AGENTS.md)
- [ROADMAP Phase 2.9](docs/ROADMAP.md)（待新增）

---

**本 ADR 由 AI Agent 起草，v1.0 草案，待 Human Owner 审批后 Accepted。**
