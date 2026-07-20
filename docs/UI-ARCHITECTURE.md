# UI Architecture Design

> **状态**：Proposed（草案，待 Human Owner 审批）
> **版本**：v1.1（采纳 4 项决议 + 新增 CommandHandler 中间层）
> **起草日期**：2026-07-20
> **起草人**：AI Agent（GLM-5.2）
> **关联 ADR**：[ADR-0009](docs/ADR/0009-ui-architecture-design.md)
> **范围**：定义 FormulaFix UI 架构心智模型 + 状态模型 + 组件结构

## 版本修订记录

- **v1.0**：初版，UI 事件直接经 EditorCommand.execute 操作 TransactionBuilder
- **v1.1**（2026-07-20）：采纳 Human Owner 4 项决议 + 引入 CommandHandler 中间层
  - 顶层组件树新增 `CommandHandler`（位于 `lib/presentation/commands/`）
  - UI 事件流改为：`UI Event → EditorCommand（纯数据） → CommandHandler → TransactionBuilder → BlockOperation`
  - EditorCommand 不再含 execute 方法，改为携带 `CommandOrigin` 的纯数据
  - BlockWidget `_commitSource()` 改为调用 `editor.handler.handle(...)`

---

## 1. UI 心智模型

### 1.1 编辑器是什么？

**FormulaFix 是 Block-based Structured Editor**，不是 "TextField + Markdown Preview"。

**三层心智模型**：
1. **块是第一公民**：所有内容以块为单位组织（Paragraph / Heading / Code / Table / Formula 等）
2. **双态切换**：每个块有 render 态（最终样式）和 edit 态（Markdown source）两种显示
3. **AST 驱动**：UI 渲染由 AST + BlockRenderer 决定，UI 不持有文档结构

### 1.2 Block 在 UI 中的呈现

**示例**：HeadingElement 在 UI 中的两种态

```
AST:                      UI render 态:           UI edit 态:
HeadingElement(           ┌────────────────────┐  ┌────────────────────┐
  level: 1,               │ Hello              │  │ # Hello|           │
  text: "Hello"            │ (H1 字号)         │  │ (普通字号)         │
)                         └────────────────────┘  └────────────────────┘
```

**切换触发**：
- render → edit：用户 click 块 / Tab 到块 / ArrowDown 到块
- edit → render：用户失焦 / 点击块外 / Esc

### 1.3 Block 边界呈现

**视觉分隔**：
- 段落之间：空行（不渲染边框）
- 代码块 / 公式块：背景色或边框区分
- 引用块：左侧竖线
- 标题：上下间距加大

**隐式边界**：
- 用户感知"块"通过间距与字号，而非边框
- 仅在选中或聚焦时显示淡色边框（视觉反馈）

### 1.4 用户感知"我在编辑块 X"

**视觉反馈**：
1. **render 态**：当前块无特殊标记
2. **edit 态**：当前块显示淡色背景或左侧蓝色竖线
3. **光标**：edit 态显示文本光标
4. **AppBar**：可选显示当前块类型（如 "Heading H1"）

### 1.5 Block 切换交互

| 操作 | 触发 | 行为 |
|------|------|------|
| 鼠标点击块 | tap | render → edit 态，光标在 tap 位置 |
| 点击块外 | tap outside | edit → render 态，commit |
| 失焦 | focus loss | edit → render 态，commit |
| Esc | Esc 键 | edit → render 态，**撤销未 commit 修改**（可选） |
| ArrowDown | 块末 | focus 移到下一块开头 |
| ArrowUp | 块首 | focus 移到上一块末尾 |
| Tab | edit 态 | focus 移到下一块开头 |
| Shift+Tab | edit 态 | focus 移到上一块末尾 |

---

## 2. UI 心智模型对比

### 2.1 与传统 Markdown 编辑器对比

| 模型 | 编辑 | 预览 | 切换 | FormulaFix 是否采用 |
|------|------|------|------|---------------------|
| TextField + Preview | 编辑 Markdown 源 | 单独区域渲染 | 显式切换按钮 | ❌ |
| Typora 双态 | 编辑当前块 source | 失焦后渲染 | 隐式（focus 驱动） | ✅ |
| Notion 块模型 | 块为单位编辑 | 块自渲染 | 块自管态 | ✅（块第一公民） |
| VS Code 结构化 | 结构化编辑 | AST 驱动 | 持续渲染 | ✅（AST 驱动） |

### 2.2 借鉴与差异

**借鉴 Typora**：
- 双态切换（render / edit）
- 失焦自动 commit
- 不显示 Markdown 语法符号（render 态）

**借鉴 Notion**：
- 块是第一公民
- 块级操作（insert / delete / move）
- 块类型可转换

**FormulaFix 差异**：
- 移动端优先（mobile-first）
- 学术写作特色（公式 / Mermaid / 表格可视化编辑）
- 任意来源 .md 文件即开即看（不绑定 Vault）

---

## 3. UI 状态模型

### 3.1 BlockViewState 设计

**核心原则**：UI 状态单独建模，不污染 AST（[ADR-0009 §2](docs/ADR/0009-ui-architecture-design.md)）

```dart
/// UI 层 Block 视图状态（不污染 AST）。
///
/// 通过 [BlockId] 关联到 [DocumentElement]。
/// 生命周期：与 Widget 树绑定，不跨序列化持久化。
@immutable
class BlockViewState {
  /// 对应的 BlockId（与 AST 关联键）
  final BlockId id;

  /// 当前块是否聚焦（edit 态）
  ///
  /// 同一时刻只能有一个块 isFocused = true
  final bool isFocused;

  /// 当前块是否处于 editing（光标在块内）
  ///
  /// isFocused = true 是 isEditing = true 的前置条件
  final bool isEditing;

  /// 文本选区（仅 edit 态有效）
  ///
  /// null 表示无选区（光标 collapse）
  final TextSelection? selection;

  /// IME composing region（仅 composing 态有效）
  ///
  /// 中文输入法组合态期间，记录 composing 起止位置。
  ///
  /// **与 ComposingController 的同步策略**（v1.1 补充）：
  /// - `ComposingController`（`lib/core/editing/composing_controller.dart`）是
  ///   composing 态的唯一真相源（Single Source of Truth），负责 IME 三铁律守门
  ///   （[ADR-0007 §5](docs/ADR/0007-blockeditor-abstraction-design.md)）
  /// - `BlockViewState.composingRegion` 是其**只读镜像**，仅用于 UI 渲染（如显示
  ///   composing 下划线）
  /// - **写入方向**：`ComposingController.onComposingStart / onComposingCommit /
  ///   onComposingCancel` 回调 → `BlockEditorWidgetState` 同步刷新对应块的
  ///   `composingRegion`
  /// - **禁止反向写入**：UI 不直接修改 `BlockViewState.composingRegion`，必须经
  ///   `ComposingController` 守门后回调同步
  /// - **生命周期**：composing cancel 时 `ComposingController` 清空自身状态并
  ///   触发回调，UI 同步将 `composingRegion` 置 null
  /// - **跨块约束**：composing 期间不可切换 focus（IME 三铁律铁律 1 守门），
  ///   故同一时刻最多一个块的 `composingRegion != null`
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
      id: id,  // id 不可变
      isFocused: isFocused ?? this.isFocused,
      isEditing: isEditing ?? this.isEditing,
      selection: selection ?? this.selection,
      composingRegion: composingRegion ?? this.composingRegion,
    );
  }
}
```

### 3.1.1 composingRegion 同步时序（v1.1 补充）

```
用户输入拼音 → TextField 触发 composing
        │
        ↓
ComposingController.onComposingStart(blockId, region)
        │  ← ComposingController 守门：进入 composing 态
        ↓
BlockEditorWidgetState._onComposingStart
        │
        ↓
setState: _viewStates[blockId] = state.copyWith(composingRegion: region)
        │
        ↓
BlockWidget rebuild → EditModeWidget 显示 composing 下划线

─────────────── commit 路径 ───────────────

用户选择候选词 → IME commit
        │
        ↓
ComposingController.onComposingCommit(blockId, newSource)
        │  ← ComposingController 内部：
        │     1. CommandHandler.handle(UpdateBlockSourceCommand(origin: ime))
        │     2. 触发 TransactionBuilder.onChange → history.pushTransaction
        │     3. 清空自身 composing 态
        ↓
BlockEditorWidgetState._onComposingCommit
        │
        ↓
setState: _viewStates[blockId] = state.copyWith(composingRegion: null)
        │
        ↓
BlockWidget rebuild → EditModeWidget 显示 commit 后文本

─────────────── cancel 路径 ───────────────

用户按 Esc / 切换焦点 → IME cancel
        │
        ↓
ComposingController.onComposingCancel(blockId)
        │  ← ComposingController 内部：
        │     1. 不入栈 Transaction（铁律 3）
        │     2. 清空自身 composing 态
        ↓
BlockEditorWidgetState._onComposingCancel
        │
        ↓
setState: _viewStates[blockId] = state.copyWith(composingRegion: null)
        │
        ↓
BlockWidget rebuild → EditModeWidget 恢复 commit 前文本
```

**关键约束**：
- UI 不得直接修改 `BlockViewState.composingRegion`，必须经 `ComposingController` 守门
- composing 期间所有 `EditorCommand` 被 `CommandHandler` 守卫拒绝（铁律 1）
- composing commit / cancel 后必须立即同步 `composingRegion = null`，避免 UI 残留下划线

### 3.2 BlockViewState 管理策略

**存储位置**：`BlockEditorWidgetState`（Widget State）中

**索引方式**：
```dart
class BlockEditorWidgetState extends State<BlockEditorWidget> {
  /// BlockId → BlockViewState 索引
  final Map<BlockId, BlockViewState> _viewStates = {};

  /// 当前 focused 块的 BlockId（同 _viewStates 中 isFocused=true 的项）
  BlockId? _focusedBlockId;

  /// 当前 editing 块的 BlockId
  BlockId? _editingBlockId;
}
```

**生命周期管理**：
1. **Block 插入**：`insertAfter` 后新增对应 `BlockViewState(initial)`
2. **Block 删除**：`delete` 后移除对应 `BlockViewState`，focus 转移到相邻块
3. **Block 移动**：`move` 后 `BlockViewState` 跟随（不变 BlockId 即不变 state）
4. **Block 合并**：`merge` 后保留左块 state，删除右块 state
5. **Block 拆分**：`split` 后左块保留 state，右块新增 `BlockViewState(initial)`

### 3.3 BlockFocusManager

**职责**：管理块间 focus 切换（ArrowUp/Down / Tab）

```dart
class BlockFocusManager {
  final DocumentEditor _editor;
  final Map<BlockId, BlockViewState> _viewStates;

  BlockFocusManager(this._editor, this._viewStates);

  /// focus 移到下一块开头
  ///
  /// 返回新 focus 块的 BlockId，若已是最后一块返回 null
  BlockId? focusNext(BlockId currentId) {
    final currentIndex = _editor.indexOf(currentId);
    if (currentIndex == -1) return null;
    if (currentIndex + 1 >= _editor.blockCount) return null;

    final nextId = _editor.allIds[currentIndex + 1];
    _setFocus(nextId, atStart: true);
    return nextId;
  }

  /// focus 移到上一块末尾
  BlockId? focusPrevious(BlockId currentId) {
    final currentIndex = _editor.indexOf(currentId);
    if (currentIndex <= 0) return null;

    final prevId = _editor.allIds[currentIndex - 1];
    _setFocus(prevId, atEnd: true);
    return prevId;
  }

  void _setFocus(BlockId id, {bool atStart = false, bool atEnd = false}) {
    // 清除旧 focus，设置新 focus
    // ...
  }
}
```

### 3.4 BlockSelectionManager

**职责**：管理多块选中（鼠标拖拽跨块 / Shift+Click）

```dart
class BlockSelectionManager {
  /// 当前选中的 BlockId 列表（按顺序）
  final List<BlockId> _selectedBlockIds = [];

  /// 起始选中块（Shift+Click 的锚点）
  BlockId? _selectionAnchor;

  /// 多选模式是否激活
  bool get isMultiSelecting => _selectedBlockIds.length > 1;

  /// 进入多选
  void extendSelection(BlockId anchor) {
    _selectionAnchor = anchor;
    _selectedBlockIds.clear();
    _selectedBlockIds.add(anchor);
  }

  /// 扩展选区到 [target]
  void extendTo(BlockId target) {
    if (_selectionAnchor == null) return;
    // 计算 anchor 到 target 之间的所有 BlockId
    // ...
  }
}
```

**注**：多块选中是 Phase 3 高级特性，Phase 2.9 仅设计接口不实现。

---

## 4. Widget 组件结构

### 4.1 顶层组件树（v1.1 修订）

```
BlockEditorWidget
  ├── BlockEditorWidgetState  ← 持有 _viewStates / _focusedBlockId / _editingBlockId
  │   └── BlockEditor           ← 封装 editor + history + operations + composing
  │       └── CommandHandler    ← v1.1 新增：意图分发 + 守卫 + Transaction 生命周期
  │
  ├── BlockListWidget         ← 渲染块列表
  │     ├── BlockWidget (paragraph)  ← 单块
  │     ├── BlockWidget (heading)
  │     ├── BlockWidget (code)
  │     └── ...
  │
  ├── BlockFocusManager       ← 块间导航
  ├── BlockSelectionManager   ← 多选（Phase 3）
  └── BlockEditorToolbar      ← 可选工具栏（Phase 3）
```

**v1.1 关键变化**：UI 事件不再直接经 `EditorCommand.execute(...)`，而是构造一个纯数据 `EditorCommand` 后交由 `BlockEditor.handler.handle(command)` 统一执行（守卫 + TransactionBuilder 生命周期 + 历史记录）。

### 4.1.1 文件位置（v1.1 确认）

| 组件 | 目录 | 类型 |
|------|------|------|
| `BlockEditorWidget` / `BlockListWidget` / `BlockWidget` | `lib/presentation/widgets/block_editor/` | Widget |
| `BlockViewState` / `BlockFocusManager` / `BlockSelectionManager` / `BlockEditor` | `lib/presentation/states/` | 状态模型 |
| `BlockRenderer`（abstract） + 各 renderer 实现 + `BlockRendererRegistry` | `lib/presentation/renderers/` | 渲染器 |
| `EditorCommand`（abstract） + `CommandOrigin` enum + 各 Command 实现 | `lib/presentation/commands/` | 纯数据 Command |
| `CommandHandler` | `lib/presentation/commands/command_handler.dart` | 业务逻辑类（v1.1 新增） |

详见 [Component-Tree.md §1.2](docs/Component-Tree.md)。

### 4.2 BlockWidget 内部结构

```
BlockWidget
  ├── BlockWidgetState  ← 持有 TextEditingController / FocusNode
  │
  ├── RenderModeWidget   ← render 态显示（非 focused 时）
  │     ├── ParagraphRender
  │     ├── HeadingRender
  │     └── ...
  │
  └── EditModeWidget     ← edit 态显示（focused 时）
        └── TextField    ← 显示 Markdown source
```

### 4.3 BlockWidget 关键代码（v1.1 修订）

```dart
class BlockWidget extends StatefulWidget {
  final BlockId blockId;
  final BlockEditor editor;  // v1.1：用 BlockEditor 而非 DocumentEditor
  final BlockRenderer renderer;
  final BlockViewState viewState;
  final VoidCallback onFocusChanged;

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
    final source = fromElement(element);
    _controller = TextEditingController(text: source);
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
    if (_focusNode.hasFocus && !widget.viewState.isFocused) {
      // render → edit
      widget.onFocusChanged();
    } else if (!_focusNode.hasFocus && widget.viewState.isFocused) {
      // edit → render，commit 修改（v1.1：通过 handler）
      _commitSource();
      widget.onFocusChanged();
    }
  }

  void _onTextChanged() {
    // v1.1：debounce 后通过 handler 提交，避免每次按键都产生 Transaction
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), _commitSource);
  }

  void _commitSource() {
    final newSource = _controller.text;
    // v1.1：通过 CommandHandler 执行（不直接调 BlockOperations）
    // EditorCommand 是纯数据，由 CommandHandler 解释为 BlockOperation
    widget.editor.handler.handle(UpdateBlockSourceCommand(
      blockId: widget.blockId,
      newSource: newSource,
      origin: CommandOrigin.keyboard,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.editor.editor.getBlock(widget.blockId)!;
    if (widget.viewState.isFocused) {
      return _buildEditMode(element);
    }
    return _buildRenderMode(element);
  }

  Widget _buildRenderMode(DocumentElement element) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: widget.renderer.build(element, BlockRendererContext(
        isFocused: false,
        selection: null,
        composingRegion: null,
      )),
    );
  }

  Widget _buildEditMode(DocumentElement element) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: null,  // 多行
      // ... 其他配置
    );
  }
}
```

**v1.1 修订要点**：
- `widget.editor` 类型由 `DocumentEditor` 改为 `BlockEditor`（持有 handler）
- 新增 debounce 机制（300ms）避免每次按键都产生 Transaction
- `_commitSource()` 改为通过 `editor.handler.handle(UpdateBlockSourceCommand(...))`
- `CommandOrigin.keyboard` 让 `CommandHandler` 知道是键盘输入（参与 Coalescing）

---

## 5. 渲染策略

### 5.1 BlockRenderer 接口

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

  const BlockRendererContext({
    required this.isFocused,
    this.selection,
    this.composingRegion,
  });
}
```

### 5.2 Renderer 注册表

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

  static BlockRenderer resolve(DocumentElement element) {
    return _renderers.firstWhere(
      (r) => r.matches(element),
      orElse: () => ParagraphBlockRenderer(),
    );
  }
}
```

### 5.3 渲染策略选择

**render 态渲染**：使用 `BlockRendererRegistry.resolve(element).build(...)`

**edit 态渲染**：所有块类型统一使用 `TextField`（显示 Markdown source），不使用 BlockRenderer

**理由**：edit 态是 Markdown source 编辑，与块类型无关（用户直接编辑 `# Hello` 而非显示后的 Hello）

---

## 6. 性能策略

### 6.1 增量渲染

**只重建变化的块**：
1. Block 插入 / 删除时，仅重建对应 BlockWidget
2. Block source 修改时，仅重建该 BlockWidget
3. focus 切换时，仅重建新旧 focus 块

**实现**：
- `BlockListWidget` 使用 `ListView.builder`（按需构建）
- `BlockWidget` 的 `shouldRebuild` 比较 `BlockId` + `viewState` 是否变化

### 6.2 长文档优化

**虚拟滚动**：
- `ListView.builder` 默认虚拟滚动
- 仅构建可视区域 + 缓冲区的 BlockWidget

**AST 不克隆**：
- BlockWidget 直接读 `editor.getBlock(id)`，不持有副本
- 修改通过 `CommandHandler.handle(EditorCommand)`，不直接修改 AST
- 详见 [Interaction-Model.md §2](docs/Interaction-Model.md)（v1.1 流：EditorCommand → CommandHandler → TransactionBuilder → BlockOperation）

### 6.3 IME 性能

**composing 期间不重建**：
- composing 态时，BlockWidget 不触发 setState（避免光标跳动）
- composing commit 后，通过 Command 提交，再重建

**详见 [ADR-0007 §5](docs/ADR/0007-blockeditor-abstraction-design.md) IME 三铁律**

---

## 7. 主题与样式

### 7.1 主题策略（Phase 3+）

- **主题切换**：通过 `ThemeProvider` + `BlockRenderer` 主题感知
- **多套主题**：GitHub / Night / Sepia / Newsprint（Phase 3 任务 3.9）
- **字号缩放**：通过 `MediaQuery.textScaleFactor` 或自定义 scale

### 7.2 样式来源

- **render 态**：BlockRenderer 内部硬编码样式（Phase 3 后可改为主题驱动）
- **edit 态**：与 render 态一致字号，但不渲染 Markdown 样式

---

## 8. 测试策略

### 8.1 单元测试

- **BlockViewState**：copyWith / 生命周期管理
- **BlockFocusManager**：focusNext / focusPrevious / 边界条件
- **BlockSelectionManager**：多选 / 扩展 / 清空
- **BlockRendererRegistry**：resolve / fallback

### 8.2 Widget 测试

- **BlockWidget**：render ↔ edit 切换
- **BlockListWidget**：插入 / 删除 / 移动后正确重建

### 8.3 集成测试

- **Demo 1-4**：完整用户场景验证

---

## 9. 待决问题

1. **TextField vs EditableText**：edit 态用 `TextField` 还是 `EditableText`？
   - 倾向：`TextField`（开箱即用，IME 集成完善）
   - 备选：`EditableText`（更底层，可控性强但需手动处理 IME）

2. **BlockRenderer 是否感知主题**：通过 `BuildContext` 取 `Theme` 还是通过 `BlockRendererContext` 显式传？
   - 倾向：`BuildContext`（Flutter 惯例，主题切换自动重建）

3. **多块选中是否进 Phase 3**：多块操作（拖拽 / 删除多块）是否在 Phase 3 实现？
   - 倾向：不进 Phase 3，留到 Phase 4

---

**本文档由 AI Agent 起草，v1.1 草案，待 Human Owner 审批后定稿。**
