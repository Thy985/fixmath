# Interaction Model

> **状态**：Proposed（草案，待 Human Owner 审批）
> **版本**：v1.1（采纳 CommandHandler 中间层修订）
> **起草日期**：2026-07-20
> **起草人**：AI Agent（GLM-5.2）
> **关联 ADR**：[ADR-0009](docs/ADR/0009-ui-architecture-design.md)
> **范围**：定义用户操作如何映射到 EditorCommand → CommandHandler → Transaction → AST

## 版本修订记录

- **v1.0**：初版，EditorCommand 直接操作 TransactionBuilder
- **v1.1**（2026-07-20）：采纳 Human Owner 反馈，引入 CommandHandler 中间层
  - EditorCommand 改为纯数据（用户意图，不含 execute 方法）
  - 新增 CommandHandler 类负责意图分发 + 守卫 + Transaction 生命周期
  - 新增 CommandOrigin 枚举区分意图来源（keyboard / ime / ai / voice / menu / gesture）
  - 流变为：`EditorCommand → CommandHandler → TransactionBuilder → Transaction`

---

## 1. 交互事件流

### 1.1 六层映射（v1.1 修订）

```
用户操作（键盘 / 鼠标 / 触摸 / AI / 语音）
        │
        ↓
   UI Event（Widget 层接收）
        │
        ↓
   EditorCommand（用户意图，纯数据，可序列化）
        │
        ↓
   CommandHandler（意图分发 + 守卫 + Transaction 生命周期）  ← v1.1 新增
        │
        ↓
   TransactionBuilder（内核：构造 Transaction）
        │
        ↓
   BlockOperation（内核原语）
        │
        ↓
   DocumentEditor → AST mutation
```

### 1.2 反向流（AST → UI）

```
   AST mutation（通过 BlockOperation）
        │
        ↓
   TransactionBuilder.onChange 回调
        │
        ↓
   EditorHistory.pushTransaction + UI rebuild notification
        │
        ↓
   BlockEditorWidgetState.setState
        │
        ↓
   BlockWidget rebuild（读取新 AST）
```

### 1.3 v1.1 修订要点

| 项 | v1.0 | v1.1 |
|----|------|------|
| EditorCommand 接口 | 含 `execute(BlockEditor, TransactionBuilder)` 方法 | 纯数据，只有 `displayName` + `origin` getter |
| Command 执行者 | EditorCommand.execute 自执行 | CommandHandler.handle 解释执行 |
| 来源标识 | 隐式（TransactionOrigin） | 显式（CommandOrigin 枚举） |
| 可序列化 | 不可以（含方法） | 可以（纯数据，未来 AI / 协同用） |
| 意图来源扩展 | 需改 EditorCommand 接口 | 只新增 CommandOrigin 枚举值 |

---

## 2. EditorCommand + CommandHandler 抽象

### 2.1 EditorCommand 接口（v1.1 修订）

```dart
/// UI 事件 → EditorCommand（用户意图，纯数据）
///
/// **v1.1 关键变更**：
/// - Command 不再直接 execute(TransactionBuilder)
/// - 改为描述意图（payload），由 [CommandHandler] 解释为 BlockOperation
/// - 这样 Command 可序列化、可记录、可重放（用于 AI / 录制回放 / 协同编辑）
///
/// 详见 [ADR-0009 §3](docs/ADR/0009-ui-architecture-design.md)
@immutable
abstract class EditorCommand {
  /// 人类可读的 Command 名称（用于 Undo/Redo 菜单显示）
  ///
  /// 例如："拆分块" / "删除块" / "更新文本"
  String get displayName;

  /// Command 来源（区分 keyboard / ime / ai / voice / menu / gesture）
  ///
  /// 影响 Coalescing 决策（仅 keyboard origin 合并）+ Undo/Redo 显示
  CommandOrigin get origin;
}

/// Command 来源枚举
enum CommandOrigin {
  keyboard,  // 键盘输入（参与 Coalescing）
  ime,       // IME commit（不参与 Coalescing）
  ai,        // AI Agent（未来，不参与 Coalescing）
  voice,     // 语音输入（未来）
  menu,      // 工具栏菜单
  gesture,   // 手势（tap / drag）
}
```

### 2.2 CommandHandler 接口（v1.1 新增）

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
/// 详见 [ADR-0009 §3.3](docs/ADR/0009-ui-architecture-design.md)
class CommandHandler {
  final BlockEditor _editor;

  CommandHandler(this._editor);

  /// 处理 [command]，返回是否成功
  ///
  /// 内部流程：
  /// 1. 守卫检查（composing / 空文档等）
  /// 2. 构造 TransactionBuilder（origin = command.origin 映射）
  /// 3. 分发到对应的 _handle* 方法
  /// 4. 成功 → builder.commit() + history.pushTransaction
  /// 5. 失败 → builder.rollback()
  bool handle(EditorCommand command) {
    // 守卫：composing 态拒绝（IME 三铁律，由 ComposingController 内部守门）
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
  ///
  /// 使用 sealed class + 模式匹配，编译器强制穷举所有 Command 类型
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

  /// CommandOrigin → TransactionOrigin 映射
  ///
  /// 仅 keyboard / ime 有特殊语义（参与 Coalescing），
  /// 其他来源统一映射为 programmatic
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

  // ============ 各 _handle* 方法 ============

  bool _handleSplitBlock(SplitBlockCommand c, TransactionBuilder b) {
    // BlockOperations.split 内部已自动 tryTransform（Phase 2.7）
    return _editor.operations.split(c.blockId, c.offset);
  }

  bool _handleMerge(MergeWithPreviousCommand c, TransactionBuilder b) {
    final currentIndex = _editor.editor.indexOf(c.blockId);
    if (currentIndex <= 0) return false;  // 第一块无法合并
    final prevId = _editor.editor.allIds[currentIndex - 1];
    return _editor.operations.merge(prevId, c.blockId);
  }

  bool _handleInsert(InsertBlockAfterCommand c, TransactionBuilder b) {
    final newId = _editor.operations.insertAfter(c.blockId, c.element);
    return newId != null;
  }

  bool _handleDelete(DeleteBlockCommand c, TransactionBuilder b) {
    return _editor.operations.delete(c.blockId);
  }

  bool _handleMoveUp(MoveBlockUpCommand c, TransactionBuilder b) {
    final currentIndex = _editor.editor.indexOf(c.blockId);
    if (currentIndex <= 0) return false;
    final prevId = _editor.editor.allIds[currentIndex - 1];
    return _editor.operations.move(c.blockId, prevId, before: true);
  }

  bool _handleMoveDown(MoveBlockDownCommand c, TransactionBuilder b) {
    final currentIndex = _editor.editor.indexOf(c.blockId);
    if (currentIndex + 1 >= _editor.editor.blockCount) return false;
    final nextId = _editor.editor.allIds[currentIndex + 1];
    return _editor.operations.move(c.blockId, nextId, before: false);
  }

  bool _handleUpdateSource(UpdateBlockSourceCommand c, TransactionBuilder b) {
    return _editor.operations.updateSource(c.blockId, c.newSource);
  }

  bool _handleTransform(TransformBlockCommand c, TransactionBuilder b) {
    return _editor.operations.tryTransform(c.blockId);
  }
}
```

### 2.3 BlockEditor 封装（v1.1 修订）

```dart
/// BlockEditor：UI 层对编辑内核的封装
///
/// 持有 [DocumentEditor] + [EditorHistory] + [BlockOperations] + [ComposingController]
/// 提供 [handler] 供 UI 层调用 [EditorCommand]
class BlockEditor {
  final DocumentEditor editor;
  final EditorHistory history;
  final BlockOperations operations;
  final ComposingController? composing;

  /// Command 处理器（v1.1 新增）
  late final CommandHandler handler;

  BlockEditor({
    required this.editor,
    required this.history,
    required this.operations,
    this.composing,
  }) {
    handler = CommandHandler(this);
  }

  /// 从初始文档构造
  factory BlockEditor.fromDocument(Document document) {
    final editor = DocumentEditor.fromDocument(document);
    final history = EditorHistory();
    final operations = BlockOperations(editor, _defaultBuilder(history));
    return BlockEditor(editor: editor, history: history, operations: operations);
  }

  static TransactionBuilder _defaultBuilder(EditorHistory history) {
    return TransactionBuilder(
      origin: TransactionOrigin.keyboard,
      onChange: (tx) => history.pushTransaction(tx),
    );
  }
}
```

### 2.4 UI 层调用入口（v1.1 修订）

```dart
// BlockEditorWidgetState 内部
void _onEnterPressed(BlockId blockId, int offset) {
  // v1.1：通过 handler.handle 处理 Command
  final command = SplitBlockCommand(
    blockId: blockId,
    offset: offset,
    origin: CommandOrigin.keyboard,
  );
  final success = _editor.handler.handle(command);
  if (!success) {
    // 提示用户（如震动 / Toast）
  }
}
```

---

## 3. Command 清单

### 3.1 核心 Command（8 个）

| Command | 触发 | 映射的 BlockOperation | Undo 行为 |
|---------|------|---------------------|-----------|
| `SplitBlockCommand` | Enter 键 | split + tryTransform | 撤销拆分，合并两块 |
| `MergeWithPreviousCommand` | Backspace at offset 0 | merge(prev, current) | 撤销合并，拆分回两块 |
| `InsertBlockAfterCommand` | Shift+Enter / 空行 Enter | insertAfter | 撤销插入，删除新块 |
| `DeleteBlockCommand` | Backspace on empty block | delete | 撤销删除，恢复块 |
| `MoveBlockUpCommand` | Alt+Up | move(current, prev, before:true) | 撤销移动，移回原位 |
| `MoveBlockDownCommand` | Alt+Down | move(current, next, before:false) | 撤销移动，移回原位 |
| `UpdateBlockSourceCommand` | 文本变化（debounce） | updateSource | 撤销文本修改 |
| `TransformBlockCommand` | Markdown 快捷触发 | tryTransform | 撤销类型转换 |

### 3.2 Command 详细设计（v1.1 修订）

> **v1.1 关键变更**：Command 改为纯数据（不含 execute 方法），执行逻辑由 CommandHandler._handle* 承担。详见 [§2.2](#22-commandhandler-接口v11-新增)。

#### SplitBlockCommand（纯数据）

```dart
/// 拆分块 Command（Enter 键触发，纯数据）
///
/// 携带意图参数（blockId + offset），执行由 [CommandHandler._handleSplitBlock] 完成
@immutable
class SplitBlockCommand implements EditorCommand {
  final BlockId blockId;
  final int offset;
  @override
  final CommandOrigin origin;

  const SplitBlockCommand({
    required this.blockId,
    required this.offset,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '拆分块';
}
```

#### MergeWithPreviousCommand（纯数据）

```dart
/// 合并到上一块 Command（Backspace at offset 0 触发，纯数据）
@immutable
class MergeWithPreviousCommand implements EditorCommand {
  final BlockId blockId;
  @override
  final CommandOrigin origin;

  const MergeWithPreviousCommand({
    required this.blockId,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '合并到上一块';
}
```

#### InsertBlockAfterCommand（纯数据）

```dart
/// 在当前块后插入新块 Command（Shift+Enter / 空行 Enter 触发，纯数据）
@immutable
class InsertBlockAfterCommand implements EditorCommand {
  final BlockId blockId;
  final DocumentElement element;
  @override
  final CommandOrigin origin;

  InsertBlockAfterCommand({
    required this.blockId,
    DocumentElement? element,
    this.origin = CommandOrigin.keyboard,
  }) : element = element ?? ParagraphElement(children: [TextElement('')]);

  @override
  String get displayName => '插入新块';
}
```

#### DeleteBlockCommand（纯数据）

```dart
/// 删除块 Command（空块 Backspace 触发，纯数据）
///
/// 守卫：若 editor.blockCount <= 1，[CommandHandler._handleDelete] 返回 false
@immutable
class DeleteBlockCommand implements EditorCommand {
  final BlockId blockId;
  @override
  final CommandOrigin origin;

  const DeleteBlockCommand({
    required this.blockId,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '删除块';
}
```

#### UpdateBlockSourceCommand（纯数据）

```dart
/// 更新块 source Command（文本变化触发，纯数据）
///
/// **重要**：UI 文本变化必须 debounce（如 300ms），避免每次按键都产生 Transaction。
///
/// 注：[BlockOperations.updateSource] 已封装 transform + TextOperation 逻辑，
/// CommandHandler._handleUpdateSource 仅作 wrapper。
@immutable
class UpdateBlockSourceCommand implements EditorCommand {
  final BlockId blockId;
  final String newSource;
  @override
  final CommandOrigin origin;

  const UpdateBlockSourceCommand({
    required this.blockId,
    required this.newSource,
    this.origin = CommandOrigin.keyboard,
  });

  @override
  String get displayName => '更新文本';
}
```

### 3.3 Coalescing 与 Command 的关系

**关键问题**：一个 Command 产生一个 Transaction，但用户连续输入字符时，多个 `UpdateBlockSourceCommand` 会产生多个 Transaction，导致 Undo 时一次只撤销一个字符。

**解决方案**：
1. **UI 层 debounce**：300ms 内多次文本变化合并为一次 `UpdateBlockSourceCommand`
2. **Coalescing 自动合并**：[EditorHistory](flutter_app/lib/core/editing/editor_history.dart) 的 coalescing 7 触发条件会自动合并连续 keyboard TextOperation（< 500ms）

**Coalescing 与 Command 的边界**：
- Coalescing 在 Transaction 层（内核）
- Command 在 UI 层，每个 Command 仍产生独立 Transaction
- Coalescing 把多个 Command 的 Transaction 合并为一个（Undo 时一次撤销多步）

---

## 4. 键盘事件映射

### 4.1 键盘事件 → Command 映射

| 键盘事件 | 当前光标位置 | 触发 Command |
|---------|------------|--------------|
| Enter | 任意位置 | `SplitBlockCommand` |
| Shift+Enter | 任意位置 | `InsertBlockAfterCommand` |
| Backspace | offset == 0 且块非空 | `MergeWithPreviousCommand` |
| Backspace | 块为空且非最后一块 | `DeleteBlockCommand` |
| Alt+Up | 任意 | `MoveBlockUpCommand` |
| Alt+Down | 任意 | `MoveBlockDownCommand` |
| ArrowDown | offset == source.length | `FocusNextBlockCommand`（注：不进 Transaction） |
| ArrowUp | offset == 0 | `FocusPreviousBlockCommand`（注：不进 Transaction） |
| 字符输入 | 任意 | 不直接触发 Command（TextField 处理，debounce 后触发 `UpdateBlockSourceCommand`） |

### 4.2 特殊键处理

| 键 | 行为 |
|----|------|
| Esc | edit → render 态，**撤销未 commit 修改**（可选，Phase 3 决定） |
| Tab | edit 态：focus 下一块；render 态：进入 edit 态 |
| Shift+Tab | edit 态：focus 上一块 |

### 4.3 IME 组合态守门

**核心约束**（[ADR-0007 §5](docs/ADR/0007-blockeditor-abstraction-design.md) IME 三铁律）：

1. **铁律 1**：composing 态下，所有 BlockOperation 被拒绝
2. **铁律 2**：composing commit 时，入栈 Transaction（origin = ime）
3. **铁律 3**：composing cancel 时，不入栈

**对 Command 的影响**：
- composing 态下，所有 Command 执行失败（`BlockOperation` 守门）
- UI 层应在 composing 态下禁用键盘快捷键（如 Alt+Up / Shift+Enter）
- composing commit 自动触发 `UpdateBlockSourceCommand`（通过 [ComposingController.onComposingCommit](flutter_app/lib/core/editing/composing_controller.dart)）

---

## 5. 鼠标 / 触摸事件映射

### 5.1 鼠标事件

| 事件 | 行为 |
|------|------|
| 点击块（render 态）| render → edit 态，光标在 tap 位置 |
| 点击块（edit 态）| 光标移动到 tap 位置（TextField 默认行为） |
| 点击块外 | edit → render 态，commit 修改 |
| 双击块 | 选中单词（TextField 默认行为） |
| 三击块 | 选中整行（TextField 默认行为） |
| 拖拽 | 选中跨块文本（Phase 4，多块选中） |

### 5.2 触摸事件（移动端）

| 事件 | 行为 |
|------|------|
| 单指点击 | render → edit 态，光标在 tap 位置 |
| 长按 | 显示选择菜单（TextField 默认行为） |
| 双指缩放 | 字号缩放（Phase 3 任务 3.10） |
| 滑动 | 滚动（默认行为） |

---

## 6. Command 与 Undo/Redo

### 6.1 Undo 行为

**核心原则**：一次 Undo = 撤销一个 Command（而非一个 BlockOperation）

**实现**：
- 每个 Command 产生一个 Transaction
- Undo 时撤销一个 Transaction（[EditorHistory.undo](flutter_app/lib/core/editing/editor_history.dart)）
- Coalescing 合并的多个 Transaction 在 Undo 时一次撤销

### 6.2 Redo 行为

**核心原则**：一次 Redo = 重做一个 Command

**实现**：
- [EditorHistory.redo](flutter_app/lib/core/editing/editor_history.dart)
- Redo 后 UI 需重建对应 BlockWidget

### 6.3 Undo/Redo 时的 UI 同步

**关键问题**：Undo 后 AST 变化，UI 如何同步？

**策略**：
1. `TransactionBuilder.onChange` 回调触发 UI rebuild
2. `BlockEditorWidgetState.setState` 重建所有 BlockWidget
3. `BlockWidget.shouldRebuild` 比较 BlockId + viewState 决定是否真重建

**focus 同步**：
- Undo 删除块后，focus 移到相邻块
- Undo 插入块后，focus 移到恢复的块
- focus 同步逻辑由 UI 层在 onChange 回调中处理

---

## 7. 防抖与节流

### 7.1 文本输入防抖

**问题**：用户每次按键都触发 `UpdateBlockSourceCommand` 会导致：
1. 大量小 Transaction 污染 history
2. Undo 时一次只撤销一个字符

**解决方案**：
- **UI 层 debounce**：300ms 内多次文本变化合并为一次 `UpdateBlockSourceCommand`
- **Coalescing 自动合并**：[EditorHistory](flutter_app/lib/core/editing/editor_history.dart) 的 coalescing 7 触发条件会自动合并连续 keyboard TextOperation

**实现**：
```dart
class _BlockWidgetState extends State<BlockWidget> {
  Timer? _debounceTimer;

  void _onTextChanged(String newSource) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      widget.editor.execute(UpdateBlockSourceCommand(
        blockId: widget.blockId,
        newSource: newSource,
      ));
    });
  }
}
```

### 7.2 Markdown 快捷触发节流

**问题**：用户输入 `# ` 时，每次按键都触发 `tryTransform` 检测

**解决方案**：
- `tryTransform` 检测在 `BlockOperations.updateSource` 内部自动调用（Phase 2.7）
- 无需额外节流（detectBlockType 性能 < 1ms，1000 块 < 16ms）

### 7.3 滚动节流

**问题**：长文档滚动时频繁 rebuild BlockWidget

**解决方案**：
- `ListView.builder` 默认虚拟滚动，仅构建可视区域块
- 滚动期间不触发 `setState`（滚动停止后才同步）

---

## 8. 异常处理

### 8.1 Command 执行失败

**策略**：
- Command 返回 false 时，不产生 Transaction
- UI 层显示错误反馈（如震动 / Toast）
- AST 保持不变

### 8.2 内核异常

**策略**：
- `BlockOperation.apply` 失败时，op 不加入 TransactionBuilder
- 已 apply 的 op 需调用方逆序 revert（[transaction_rollback_atomicity_test.dart](flutter_app/test/editing/transaction_rollback_atomicity_test.dart) 的 rollback helper）
- UI 层在 Command 内捕获异常并返回 false

### 8.3 不显示 detail 给用户

**核心约束**（[AGENTS.md §6.1.3](AGENTS.md)）：
- 禁止把异常 `detail` / `stack` 直接显示给用户
- Command 返回 false 时，UI 显示友好提示（如 "操作无法完成"）

---

## 9. 测试策略

### 9.1 Command 单元测试

每个 Command 至少测试：
- 正常路径（execute 返回 true，AST 正确变化）
- 守卫条件（execute 返回 false，AST 不变）
- 边界条件（第一块 / 最后一块 / 空文档）

### 9.2 集成测试

- Demo 1-4 验证 Command 链路
- Undo/Redo 3 次闭环

### 9.3 性能测试

- 1000 次 Command 执行 < 100ms
- 1000 次 Undo < 200ms

---

## 10. 待决问题

1. **Command 是否记录参数**：用于协同编辑 / 录制回放？
   - 倾向：Phase 2.9 不记录，Phase 4 协同编辑时考虑

2. **Command 与 IME 的交互细节**：composing commit 时是否产生 Command？
   - 倾向：不产生，直接通过 `BlockOperations.updateSource`（origin = ime，与 keyboard 区分）

3. **多块选中后的批量 Command**：如多块删除 / 移动
   - 倾向：Phase 4，Phase 2.9 仅设计单块 Command

4. **Command history 显示**：是否在 UI 显示 Command history（如 VS Code 的 Command Palette）？
   - 倾向：不显示，Undo/Redo 按钮即可

---

**本文档由 AI Agent 起草，v1.0 草案，待 Human Owner 审批后定稿。**
