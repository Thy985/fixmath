# Component Tree

> **状态**：Proposed（草案，待 Human Owner 审批）
> **版本**：v1.1（采纳 4 项决议 + 新增 CommandHandler）
> **起草日期**：2026-07-20
> **起草人**：AI Agent（GLM-5.2）
> **关联 ADR**：[ADR-0009](docs/ADR/0009-ui-architecture-design.md)
> **范围**：冻结 UI 层组件树结构 + 核心接口

## 版本修订记录

- **v1.0**：初版，EditorCommand 含 execute 方法
- **v1.1**（2026-07-20）：采纳 Human Owner 4 项决议 + 新增 CommandHandler
  - EditorCommand 改为纯数据（含 origin 字段）
  - 新增 CommandHandler 类负责执行（位于 `lib/presentation/commands/command_handler.dart`）
  - 文件位置最终确定（commands / states / renderers 三层目录）

---

## 1. 组件树总览

### 1.1 顶层结构（v1.1 修订）

```
BlockEditorWidget
  │
  ├── BlockEditorWidgetState（持有 _viewStates / _focusedBlockId / _editingBlockId）
  │   ├── BlockEditor（封装 editor + history + operations + composing + handler）
  │   │   └── CommandHandler（v1.1 新增：意图分发 + 守卫 + Transaction 生命周期）
  │   ├── BlockFocusManager（块间导航）
  │   ├── BlockSelectionManager（多块选中，Phase 3 后期）
  │   └── BlockRendererRegistry（renderer 解析）
  │
  ├── BlockListWidget（虚拟列表）
  │     └── BlockWidget × N（按 BlockId 渲染）
  │           ├── RenderModeWidget（render 态，由 BlockRenderer 决定）
  │           └── EditModeWidget（edit 态，TextField + Markdown source）
  │
  ├── BlockEditorToolbar（可选，Phase 3 后期）
  └── BlockEditorStatusBar（可选，显示当前块类型 / 字数等）
```

### 1.2 组件位置（v1.1 确认）

| 组件 | 文件路径 | 类型 |
|------|---------|------|
| `BlockEditorWidget` | `lib/presentation/widgets/block_editor/block_editor_widget.dart` | StatefulWidget |
| `BlockListWidget` | `lib/presentation/widgets/block_editor/block_list_widget.dart` | StatelessWidget |
| `BlockWidget` | `lib/presentation/widgets/block_editor/block_widget.dart` | StatefulWidget |
| `RenderModeWidget` | `lib/presentation/widgets/block_editor/render_mode_widget.dart` | StatelessWidget |
| `EditModeWidget` | `lib/presentation/widgets/block_editor/edit_mode_widget.dart` | StatefulWidget |
| `BlockFocusManager` | `lib/presentation/states/block_focus_manager.dart` | 业务类（非 Widget） |
| `BlockSelectionManager` | `lib/presentation/states/block_selection_manager.dart` | 业务类（非 Widget） |
| `BlockViewState` | `lib/presentation/states/block_view_state.dart` | @immutable 数据类 |
| `BlockRenderer`（abstract） | `lib/presentation/renderers/block_renderer.dart` | 抽象类 |
| `BlockRendererRegistry` | `lib/presentation/renderers/block_renderer_registry.dart` | 注册表 |
| `ParagraphBlockRenderer` | `lib/presentation/renderers/paragraph_block_renderer.dart` | BlockRenderer 实现 |
| `HeadingBlockRenderer` | `lib/presentation/renderers/heading_block_renderer.dart` | BlockRenderer 实现 |
| ... | ... | ... |
| `EditorCommand`（abstract） | `lib/presentation/commands/editor_command.dart` | 抽象类（纯数据） |
| `CommandOrigin`（enum） | `lib/presentation/commands/editor_command.dart` | 同文件 |
| `CommandHandler` | `lib/presentation/commands/command_handler.dart` | 业务类（v1.1 新增） |
| `SplitBlockCommand` | `lib/presentation/commands/split_block_command.dart` | EditorCommand 实现（纯数据） |
| ... | ... | ... |

### 1.3 分层归属

| 层 | 目录 | 职责 |
|----|------|------|
| `presentation/widgets/` | Widget 组件 | UI 渲染 + 用户交互 |
| `presentation/states/` | UI 状态模型 | BlockViewState / Focus / Selection |
| `presentation/renderers/` | Block 渲染器 | 每种 Block 类型的 render 态渲染 |
| `presentation/commands/` | EditorCommand | UI 事件 → Transaction 的映射 |
| `presentation/screens/` | 屏幕 | Phase 3 重写（如 EditorScreen） |

---

## 2. 核心接口冻结

### 2.1 BlockEditorWidget（顶层 Widget）

```dart
/// 块编辑器顶层 Widget
///
/// 持有 [BlockEditor]（editor + history + operations）+ [BlockViewState] 索引
class BlockEditorWidget extends StatefulWidget {
  /// 初始文档 AST
  final Document initialDocument;

  /// 文档变化回调（用于持久化等）
  final ValueChanged<Document>? onDocumentChanged;

  const BlockEditorWidget({
    super.key,
    required this.initialDocument,
    this.onDocumentChanged,
  });

  @override
  State<BlockEditorWidget> createState() => BlockEditorWidgetState();
}

class BlockEditorWidgetState extends State<BlockEditorWidget> {
  late final BlockEditor _editor;
  final Map<BlockId, BlockViewState> _viewStates = {};
  BlockId? _focusedBlockId;
  BlockId? _editingBlockId;
  late final BlockFocusManager _focusManager;

  @override
  void initState() {
    super.initState();
    _editor = BlockEditor.fromDocument(widget.initialDocument);
    _focusManager = BlockFocusManager(_editor, _viewStates);
    // 初始化所有块的 view state
    for (final id in _editor.editor.allIds) {
      _viewStates[id] = BlockViewState(id: id);
    }
  }

  /// 执行 [command]（UI 层调用入口，v1.1 改为通过 handler）
  bool executeCommand(EditorCommand command) {
    return _editor.handler.handle(command);
  }

  /// 请求 focus [blockId]
  void requestFocus(BlockId blockId) {
    setState(() {
      if (_focusedBlockId != null) {
        _viewStates[_focusedBlockId!] =
            _viewStates[_focusedBlockId!]!.copyWith(isFocused: false);
      }
      _focusedBlockId = blockId;
      _viewStates[blockId] =
          _viewStates[blockId]!.copyWith(isFocused: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlockListWidget(
      editor: _editor,
      viewStates: _viewStates,
      onFocusChanged: _onBlockFocusChanged,
    );
  }

  void _onBlockFocusChanged(BlockId blockId, bool focused) {
    // ... 处理块 focus 变化
  }
}
```

### 2.2 BlockListWidget

```dart
/// 块列表 Widget（虚拟滚动）
class BlockListWidget extends StatelessWidget {
  final BlockEditor editor;
  final Map<BlockId, BlockViewState> viewStates;
  final void Function(BlockId, bool) onFocusChanged;

  const BlockListWidget({
    super.key,
    required this.editor,
    required this.viewStates,
    required this.onFocusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: editor.editor.blockCount,
      itemBuilder: (context, index) {
        final blockId = editor.editor.allIds[index];
        final element = editor.editor.getBlock(blockId)!;
        final viewState = viewStates[blockId]!;
        final renderer = BlockRendererRegistry.resolve(element);

        return BlockWidget(
          key: ValueKey(blockId.value),  // BlockId 作为 key
          blockId: blockId,
          editor: editor,
          renderer: renderer,
          viewState: viewState,
          onFocusChanged: (focused) => onFocusChanged(blockId, focused),
        );
      },
    );
  }
}
```

### 2.3 BlockWidget

```dart
/// 单块 Widget
///
/// 根据 [BlockViewState.isFocused] 切换 render / edit 态
class BlockWidget extends StatefulWidget {
  final BlockId blockId;
  final BlockEditor editor;
  final BlockRenderer renderer;
  final BlockViewState viewState;
  final ValueChanged<bool> onFocusChanged;

  const BlockWidget({
    super.key,
    required this.blockId,
    required this.editor,
    required this.renderer,
    required this.viewState,
    required this.onFocusChanged,
  });

  @override
  State<BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<BlockWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final element = widget.editor.editor.getBlock(widget.blockId)!;
    _controller = TextEditingController(text: fromElement(element));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    widget.onFocusChanged(_focusNode.hasFocus);
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      // v1.1：通过 handler.handle 执行 Command
      widget.editor.handler.handle(UpdateBlockSourceCommand(
        blockId: widget.blockId,
        newSource: _controller.text,
        origin: CommandOrigin.keyboard,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.editor.editor.getBlock(widget.blockId)!;
    if (widget.viewState.isFocused) {
      return EditModeWidget(
        controller: _controller,
        focusNode: _focusNode,
      );
    }
    return RenderModeWidget(
      element: element,
      renderer: widget.renderer,
      viewState: widget.viewState,
      onTap: () => _focusNode.requestFocus(),
    );
  }
}
```

### 2.4 RenderModeWidget / EditModeWidget

```dart
/// render 态显示 Widget
class RenderModeWidget extends StatelessWidget {
  final DocumentElement element;
  final BlockRenderer renderer;
  final BlockViewState viewState;
  final VoidCallback onTap;

  const RenderModeWidget({
    super.key,
    required this.element,
    required this.renderer,
    required this.viewState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: renderer.build(element, BlockRendererContext(
        isFocused: false,
        selection: null,
        composingRegion: null,
      )),
    );
  }
}

/// edit 态显示 Widget（TextField）
class EditModeWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const EditModeWidget({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      // ... 其他配置
    );
  }
}
```

---

## 3. BlockViewState 接口冻结

```dart
/// UI 层 Block 视图状态（不污染 AST）
///
/// 详见 [ADR-0009 §2](docs/ADR/0009-ui-architecture-design.md)
@immutable
class BlockViewState {
  final BlockId id;
  final bool isFocused;
  final bool isEditing;
  final TextSelection? selection;
  final ComposingRegion? composingRegion;

  const BlockViewState({
    required this.id,
    this.isFocused = false,
    this.isEditing = false,
    this.selection,
    this.composingRegion,
  });

  BlockViewState copyWith({
    bool? isFocused,
    bool? isEditing,
    TextSelection? selection,
    ComposingRegion? composingRegion,
  }) {
    return BlockViewState(
      id: id,
      isFocused: isFocused ?? this.isFocused,
      isEditing: isEditing ?? this.isEditing,
      selection: selection ?? this.selection,
      composingRegion: composingRegion ?? this.composingRegion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockViewState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isFocused == other.isFocused &&
          isEditing == other.isEditing &&
          selection == other.selection &&
          composingRegion == other.composingRegion;

  @override
  int get hashCode => Object.hash(id, isFocused, isEditing, selection, composingRegion);
}
```

---

## 4. BlockRenderer 接口冻结

```dart
/// Block 渲染器抽象
///
/// 新增 Block 类型只需新增 [BlockRenderer] 实现，不改 BlockEditor 核心
///
/// 详见 [ADR-0009 §4](docs/ADR/0009-ui-architecture-design.md)
abstract class BlockRenderer {
  /// 构建块的 render 态 Widget（最终样式）
  ///
  /// [context] 包含 UI 状态（focus / selection / composing）
  Widget build(DocumentElement element, BlockRendererContext context);

  /// 该 renderer 是否处理 [element] 类型
  bool matches(DocumentElement element);
}

/// BlockRenderer 上下文（UI 状态传递）
@immutable
class BlockRendererContext {
  final bool isFocused;
  final TextSelection? selection;
  final ComposingRegion? composingRegion;

  const BlockRendererContext({
    required this.isFocused,
    this.selection,
    this.composingRegion,
  });
}
```

### 4.1 Renderer 实现示例（ParagraphBlockRenderer）

```dart
class ParagraphBlockRenderer implements BlockRenderer {
  @override
  bool matches(DocumentElement element) => element is ParagraphElement;

  @override
  Widget build(DocumentElement element, BlockRendererContext context) {
    final paragraph = element as ParagraphElement;
    // 渲染 ParagraphElement.children（TextElement / BoldElement / ...）
    return RichText(
      text: _buildInlineSpans(paragraph.children),
    );
  }

  InlineSpan _buildInlineSpans(List<InlineElement> children) {
    // ... 渲染行内元素
    return TextSpan(text: '...');
  }
}
```

### 4.2 Renderer 注册表

```dart
class BlockRendererRegistry {
  static final List<BlockRenderer> _renderers = [
    HeadingBlockRenderer(),
    ParagraphBlockRenderer(),
    CodeBlockRenderer(),
    TableBlockRenderer(),
    FormulaBlockRenderer(),
    MermaidBlockRenderer(),
    ListBlockRenderer(),
    TaskListItemBlockRenderer(),
    BlockquoteBlockRenderer(),
    HorizontalRuleBlockRenderer(),
  ];

  /// 解析 [element] 对应的 renderer
  ///
  /// 找不到匹配的 renderer 时返回 [ParagraphBlockRenderer]（fallback）
  static BlockRenderer resolve(DocumentElement element) {
    return _renderers.firstWhere(
      (r) => r.matches(element),
      orElse: () => ParagraphBlockRenderer(),
    );
  }
}
```

---

## 5. EditorCommand + CommandHandler 接口冻结（v1.1 修订）

> **v1.1 关键变更**：EditorCommand 改为纯数据（不含 execute 方法），执行逻辑由 [CommandHandler] 承担。
> 详见 [Interaction-Model.md §2](docs/Interaction-Model.md) + [ADR-0009 §3](docs/ADR/0009-ui-architecture-design.md)

### 5.1 EditorCommand 抽象（纯数据）

```dart
/// UI 事件 → EditorCommand（用户意图，纯数据） → CommandHandler → Transaction → AST
///
/// **v1.1 关键变更**：
/// - Command 不再含 execute 方法
/// - 改为描述意图（payload + origin），由 [CommandHandler] 解释为 BlockOperation
/// - 这样 Command 可序列化、可记录、可重放（用于 AI / 录制回放 / 协同编辑）
///
/// Command 是 Undo/Redo 的语义边界
///
/// 详见 [Interaction-Model.md §2.1](docs/Interaction-Model.md)
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

/// Command 来源枚举（v1.1 新增）
enum CommandOrigin {
  keyboard,  // 键盘输入（参与 Coalescing）
  ime,       // IME commit（不参与 Coalescing）
  ai,        // AI Agent（未来，不参与 Coalescing）
  voice,     // 语音输入（未来）
  menu,      // 工具栏菜单
  gesture,   // 手势（tap / drag）
}
```

### 5.2 CommandHandler 接口（v1.1 新增）

```dart
/// CommandHandler：解释 EditorCommand 为 BlockOperation 序列
///
/// 职责：
/// 1. 接收 [EditorCommand]（用户意图）
/// 2. 守卫检查（如 composing 态拒绝、空文档守卫等）
/// 3. 构造 [TransactionBuilder]（含正确的 origin / coalescing 标记）
/// 4. 分发到对应的 _handle* 方法（调用 [BlockOperations]）
/// 5. commit Transaction 并 push 到 [EditorHistory]
/// 6. 触发 onChange notification
///
/// **不持有 UI 状态**：CommandHandler 是纯逻辑层，由 BlockEditor 持有
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
  bool handle(EditorCommand command);

  /// 分发 [command] 到对应处理方法
  ///
  /// 使用 sealed class + 模式匹配，编译器强制穷举所有 Command 类型
  bool _dispatch(EditorCommand command, TransactionBuilder builder);

  /// CommandOrigin → TransactionOrigin 映射
  ///
  /// 仅 keyboard / ime 有特殊语义（参与 Coalescing），
  /// 其他来源统一映射为 programmatic
  TransactionOrigin _toTransactionOrigin(CommandOrigin origin);
}
```

### 5.3 BlockEditor（CommandHandler 持有者）

```dart
/// BlockEditor：UI 层对编辑内核的封装
///
/// 持有 [DocumentEditor] + [EditorHistory] + [BlockOperations] + [ComposingController]
/// + [CommandHandler]（v1.1 新增）
///
/// UI 层通过 [handler] 调用 [CommandHandler.handle] 执行 [EditorCommand]
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

### 5.4 UI 层调用入口（v1.1 修订）

```dart
// BlockEditorWidgetState 内部
bool executeCommand(EditorCommand command) {
  return _editor.handler.handle(command);
}

void _onEnterPressed(BlockId blockId, int offset) {
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

### 5.5 v1.0 vs v1.1 对比

| 项 | v1.0 | v1.1 |
|----|------|------|
| EditorCommand 接口 | 含 `execute(BlockEditor, TransactionBuilder)` 方法 | 纯数据，只有 `displayName` + `origin` getter |
| Command 执行者 | EditorCommand.execute 自执行 | CommandHandler.handle 解释执行 |
| 来源标识 | 隐式（TransactionOrigin） | 显式（CommandOrigin 枚举） |
| 可序列化 | 不可以（含方法） | 可以（纯数据，未来 AI / 协同用） |
| 意图来源扩展 | 需改 EditorCommand 接口 | 只新增 CommandOrigin 枚举值 |
| BlockEditor 公开方法 | `execute(EditorCommand)` | `handler`（CommandHandler 实例） |

---

## 6. BlockFocusManager 接口冻结

```dart
/// 块间 focus 管理
///
/// 详见 [UI-ARCHITECTURE.md §3.3](docs/UI-ARCHITECTURE.md)
class BlockFocusManager {
  final BlockEditor _editor;
  final Map<BlockId, BlockViewState> _viewStates;

  BlockFocusManager(this._editor, this._viewStates);

  /// focus 移到下一块开头
  ///
  /// 返回新 focus 块的 BlockId，若已是最后一块返回 null
  BlockId? focusNext(BlockId currentId);

  /// focus 移到上一块末尾
  BlockId? focusPrevious(BlockId currentId);

  /// 设置 focus 到 [id]
  void setFocus(BlockId id, {bool atStart = false, bool atEnd = false});

  /// 清除 focus（无块聚焦）
  void clearFocus();

  /// 当前 focused 块的 BlockId
  BlockId? get currentFocused => _viewStates.entries
      .where((e) => e.value.isFocused)
      .map((e) => e.key)
      .firstOrNull;
}
```

---

## 7. 接口冻结清单

### 7.1 Phase 3 不再变更的接口

| 接口 | 文件 | 冻结内容 |
|------|------|---------|
| `BlockEditorWidget` | `lib/presentation/widgets/block_editor/block_editor_widget.dart` | 公开 API（构造参数 + State 公开方法） |
| `BlockListWidget` | `lib/presentation/widgets/block_editor/block_list_widget.dart` | 构造参数 + 行为 |
| `BlockWidget` | `lib/presentation/widgets/block_editor/block_widget.dart` | 构造参数 + 生命周期 |
| `BlockViewState` | `lib/presentation/states/block_view_state.dart` | 字段 + copyWith |
| `BlockRenderer` | `lib/presentation/renderers/block_renderer.dart` | 抽象接口 |
| `BlockRendererRegistry` | `lib/presentation/renderers/block_renderer_registry.dart` | resolve 方法签名 |
| `EditorCommand` | `lib/presentation/commands/editor_command.dart` | 抽象接口（纯数据：displayName + origin） |
| `CommandOrigin` | `lib/presentation/commands/editor_command.dart` | 枚举值集合（v1.1 新增） |
| `CommandHandler` | `lib/presentation/commands/command_handler.dart` | handle 方法签名 + 守卫规则（v1.1 新增） |
| `BlockEditor` | `lib/presentation/states/block_editor.dart` | handler 公开字段 + 构造参数 |
| `BlockFocusManager` | `lib/presentation/states/block_focus_manager.dart` | 公开方法签名 |

### 7.2 Phase 3 允许新增的实现

- 新增 `EditorCommand` 实现类（如 `CopyBlockCommand` / `PasteBlockCommand`）
- 新增 `CommandOrigin` 枚举值（如 `clipboard` / `automation`）
- 新增 `BlockRenderer` 实现类（如 `AdmonitionBlockRenderer`）
- 新增 `BlockViewState` 字段（向后兼容）

### 7.3 Phase 3 不允许的变更（需走 ADR 流程）

- 修改 `EditorCommand` / `CommandHandler` / `BlockRenderer` / `BlockViewState` 抽象接口签名
- 修改 `BlockEditorWidget` / `BlockWidget` 公开 API
- 让 `EditorCommand` 重新带上 execute 方法（违反 v1.1 纯数据原则）
- 在 `DocumentElement` 新增 UI 状态字段（[ADR-0009 §2](docs/ADR/0009-ui-architecture-design.md) Hard Rule）

---

## 8. 文件大小约束

按 [AGENTS.md §1.2](AGENTS.md) 单一职责 + 400 行限制：

| 文件 | 预估行数 | 是否需拆分 |
|------|---------|----------|
| `block_editor_widget.dart` | ~200 | 否 |
| `block_list_widget.dart` | ~80 | 否 |
| `block_widget.dart` | ~250 | 否 |
| `block_view_state.dart` | ~80 | 否 |
| `block_renderer.dart`（abstract） | ~30 | 否 |
| `block_renderer_registry.dart` | ~50 | 否 |
| 各 renderer 实现（如 `paragraph_block_renderer.dart`） | ~150 each | 否 |
| `editor_command.dart`（abstract + CommandOrigin enum） | ~50 | 否 |
| `command_handler.dart`（v1.1 新增） | ~250 | 否 |
| 各 command 实现（如 `split_block_command.dart`） | ~80 each | 否 |
| `block_editor.dart` | ~100 | 否 |
| `block_focus_manager.dart` | ~120 | 否 |

**预估总行数**：~2300 行（含 9 个 renderer + 8 个 command + 1 个 CommandHandler）

---

## 9. 待决问题

1. **BlockEditor 是 class 还是 Provider**：作为全局状态是否需要 Riverpod 包装？
   - 倾向：Phase 2.9 Prototype 不用 Provider，直接 StatefulWidget 持有
   - Phase 3 正式接入时考虑用 `StateNotifierProvider<BlockEditorNotifier>`

2. **Toolbar 是否纳入 Phase 2.9**：是否设计 BlockEditorToolbar？
   - 倾向：不纳入，Phase 3 后期设计

3. **多块选中何时实现**：BlockSelectionManager 是否在 Phase 3 实现？
   - 倾向：不实现，Phase 4 设计

4. **Renderer 是否需要BuildContext**：通过 `BlockRenderer.build` 传 BuildContext 还是 `BlockRendererContext`？
   - 倾向：传 `BlockRendererContext`（避免 renderer 持有 BuildContext 导致主题切换时重建复杂）

---

## 10. Prototype 目录结构（Phase 2.9 Demo）

```
flutter_app/lib/presentation/prototype/
  ├── prototype_home.dart         # Demo 入口
  ├── demo1_dual_state_block.dart # Demo 1: 单块双态切换
  ├── demo2_block_navigation.dart # Demo 2: 块间导航
  ├── demo3_undo_redo.dart        # Demo 3: Undo/Redo
  └── demo4_complex_blocks.dart   # Demo 4: 复杂块共存
```

**注**：Prototype 代码不修改正式 `lib/presentation/screens/` 与 `lib/presentation/widgets/`，独立目录验证架构。

---

**本文档由 AI Agent 起草，v1.0 草案，待 Human Owner 审批后定稿。**
