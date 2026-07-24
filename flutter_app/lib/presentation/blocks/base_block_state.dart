/// BaseBlockState 抽象基类：Block 组件双态切换共享样板。
///
/// 落地 Phase 3.1-A Task Contract §3.1.A.2（R4 评审反馈）。
/// 落地 Phase 3.2 Task Contract §3.0 方案 A（基类统一调度）：
/// - `build()` 由基类统一按 `currentMode` 分发到 `buildRenderContent` / `buildEditField`
/// - 子类只实现 `buildRenderContent`（render 态差异）+ 可选 `editFieldDecoration` / `editFieldStyle`
/// - 不再重写 `build()`（消除 40 行/Block 的分发样板）
///
/// **背景**：Phase 3.0 时 3 个 Block 组件（paragraph / heading / code）各自重复实现：
/// - `late final TextEditingController _textController`
/// - `late final FocusNode _focusNode`
/// - `initState` / `dispose` 中的 controller / focus 初始化与销毁
/// - `_onFocusChange` listener + `_commitSource` 共享逻辑
/// - `build()` 中的 `if (currentMode == RenderMode.editing) return _buildEditing();` 分发
///
/// **R4 抽象**（Phase 3.1-A）：把 controller / focus / commit 样板抽到基类。
/// **§3.0 方案 A**（Phase 3.2）：把 build() 分发也抽到基类,子类职责更聚焦。
///
/// **未来 BlockType 复用**（Math / Mermaid / Table / Quote / Image / Link）
/// 只需：
/// 1. `class MermaidBlock extends StatefulWidget`
/// 2. `class _MermaidBlockState extends BaseBlockState<MermaidBlock>`
/// 3. `@override Widget buildRenderContent(...)` 实现 render 差异
/// 4. 无需重复 controller / focus / commit / build 分发样板
///
/// **实现选择**：Flutter [State] 是 class，mixin-on-class 约束较多，
/// 因此选择抽象类继承而非 mixin 模式。
library;

import 'package:flutter/material.dart';

import '../../core/editing/block_types.dart';
import '../commands/commands.dart';
import '../editor/editor_coordinator.dart';
import '../editor/editor_scope.dart';
import '../states/block_view_state.dart';

/// Block 组件状态抽象基类。
///
/// **职责**：
/// - 管理 [TextEditingController] / [FocusNode] 生命周期
/// - 监听 [FocusNode] 变化，触发 [UpdateBlockSourceCommand]
/// - 双态切换（render ↔ edit）通过基类 `build()` 统一分发
/// - 提供 [buildRenderContent] 抽象让子类实现 render 差异
///
/// **继承约束**：
/// - 子类必须实现 [buildRenderContent]（render 差异）
/// - 子类可选覆盖 [editFieldStyle] / [editFieldDecoration] / [editFieldMaxLines]
///   / [editFieldInputAction]（edit 态 TextField 配置）
/// - 子类可选覆盖 [onModeChanged]（监听模式变化）
/// - 子类**不应**重写 `build()`（已由基类统一调度）
abstract class BaseBlockState<T extends StatefulWidget> extends State<T> {
  /// Markdown 源文本控制器（共享样板）。
  late final TextEditingController textController;

  /// 焦点监听器（共享样板）。
  late final FocusNode focusNode;

  /// 当前 Block 所属的 [EditorCoordinator]（缓存，避免事件回调中调用 of(context)）。
  late EditorCoordinator _coordinator;

  /// 上次同步到 controller 的 source（R1 修复：检测外部 source 变化）。
  late String _lastSyncedSource;

  /// 标记当前是否正在本地 commit（R1 修复：区分本地输入与外部命令）。
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _coordinator = EditorScope.of(context, listen: false);
    textController = TextEditingController(text: _initialSource());
    _lastSyncedSource = textController.text;
    focusNode = FocusNode();
    focusNode.addListener(_onFocusChange);
    textController.addListener(_onSelectionChanged);
  }

  // ============ Phase 3.3 PR #2B §2.7: selection 同步（节流）============

  /// 帧内节流标记（同一帧内多次 selection 变化只同步一次）。
  bool _selectionSyncScheduled = false;

  /// selection 变化回调：仅 focused 时同步,帧内节流。
  ///
  /// **节流策略**（§2.7）：
  /// 1. 仅 focused 时同步（非聚焦块的 selection 变化不进入全局状态）
  /// 2. 帧内节流：同一帧内多次 selection 变化只同步一次,
  ///    通过 [WidgetsBinding.instance.addPostFrameCallback] 合并
  void _onSelectionChanged() {
    if (!mounted || !isFocused) return; // 仅 focused 时同步
    if (_selectionSyncScheduled) return; // 帧内已调度,跳过
    _selectionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionSyncScheduled = false;
      if (!mounted) return;
      final sel = textController.selection;
      final current = _coordinator.viewStateOf(blockId)?.selection;
      if (sel != current) {
        final state =
            _coordinator.viewStateOf(blockId) ?? BlockViewState(id: blockId);
        _coordinator.updateViewState(blockId, state.copyWith(selection: sel));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 用 listen: true 注册依赖,响应 EditorScope.coordinator 实例替换
    _coordinator = EditorScope.of(context);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检测 mode 变化（RenderMode 切换时同步 controller 文本 + 焦点）
    if (currentMode != previousMode(oldWidget)) {
      textController.text = _initialSource();
      _lastSyncedSource = textController.text;
      _syncSelectionFromViewState();
      if (currentMode == RenderMode.editing) {
        focusNode.requestFocus();
      }
      onModeChanged(previousMode(oldWidget));
    } else if (!_isCommitting) {
      // R1 修复：检测外部 source 变化（如 toolbar 命令修改了 Document）
      final newSource = _initialSource();
      if (newSource != _lastSyncedSource) {
        textController.text = newSource;
        _lastSyncedSource = newSource;
        // R2 修复：同步 selection（cursor 位置由 Coordinator 计算）
        _syncSelectionFromViewState();
      }
    }
    _isCommitting = false;
  }

  /// 从 [BlockViewState] 同步 selection 到 controller（R2 修复）。
  ///
  /// Coordinator 在 handle InsertText/WrapSelection 后会更新 viewState.selection,
  /// 此方法将其同步到 [TextEditingController.selection]。
  void _syncSelectionFromViewState() {
    final sel = _coordinator.viewStateOf(blockId)?.selection;
    if (sel != null) {
      textController.selection = sel;
    }
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    textController.removeListener(_onSelectionChanged);
    textController.dispose();
    super.dispose();
  }

  /// **§3.0 方案 A 基类统一调度**：
  /// 按 [currentMode] 分发到 [buildRenderContent]（render 态）或
  /// [buildEditField]（edit 态）。子类不应重写此方法。
  @override
  Widget build(BuildContext context) {
    if (currentMode == RenderMode.editing) {
      return buildEditField(
        style: editFieldStyle,
        decoration: editFieldDecoration,
        maxLines: editFieldMaxLines,
        inputAction: editFieldInputAction,
      );
    }
    return buildRenderContent(context);
  }

  /// 焦点变化回调：edit → render 时 commit 修改。
  ///
  /// **R4 共享逻辑**：当 focusNode 失焦且当前处于 editing 模式,
  /// commit 当前 textController 文本并清除 focus。
  void _onFocusChange() {
    if (!focusNode.hasFocus && currentMode == RenderMode.editing) {
      _commitSource();
      _coordinator.clearFocus(blockId);
    }
  }

  /// commit 当前 textController 文本到 [EditorCoordinator]。
  ///
  /// **R1 修复**：设置 [_isCommitting] 标志,防止 didUpdateWidget 把
  /// 本地输入误判为外部命令而反向同步 controller（导致光标跳位）。
  void _commitSource() {
    _isCommitting = true;
    _lastSyncedSource = textController.text;
    _coordinator.handle(UpdateBlockSourceCommand(
      blockId: blockId,
      newSource: textController.text,
    ));
  }

  /// 当前 Block 所属的 [EditorCoordinator]（缓存,避免 of(context) 热点）。
  ///
  /// **修复 PR #1 review 反馈**：原实现每次调用都执行
  /// `EditorScope.of(context)`,在事件回调（[_onFocusChange] / [_commitSource]）
  /// 中会注册 InheritedWidget 依赖（Flutter 反模式）。
  /// 现改为返回 [_coordinator] 缓存值,由 [didChangeDependencies] 维护。
  EditorCoordinator get coordinator => _coordinator;

  /// 当前 Block 是否处于聚焦态（editing 模式）。
  ///
  /// 用于 [_onSelectionChanged] 节流判断：仅聚焦块同步 selection 到
  /// [CoordinatorState]（§2.7）。非聚焦块的 selection 变化不进入全局状态。
  bool get isFocused => currentMode == RenderMode.editing;

  /// 当前 Block 的 [BlockId]（子类必须实现，从 widget 拿）。
  BlockId get blockId;

  /// 当前 Block 的渲染模式（从 [BlockViewState] 拿，子类必须实现）。
  RenderMode get currentMode;

  /// 从 [oldWidget] 拿前一次的模式。
  ///
  /// **强制抽象**：子类必须实现，通常为 `previousMode(oldWidget) => oldWidget.state.mode`。
  /// 此为抽象方法以避免静默不生效（若默认返回 [currentMode]，模式切换检测
  /// `currentMode != previousMode(oldWidget)` 始终为 false，controller 同步 + 焦点
  /// 请求将无法触发）。
  @protected
  RenderMode previousMode(T oldWidget);

  /// 初始 source（默认从 coordinator 拿当前块 source）。
  String _initialSource() {
    return coordinator.sourceOf(blockId);
  }

  /// Block 点击处理：进入 editing 模式（子类可复用）。
  void onBlockTap() {
    coordinator.setFocus(blockId);
  }

  /// 模式变化回调（子类可覆盖，默认空实现）。
  ///
  /// 用于在 render ↔ editing 切换时执行额外逻辑（如 scroll to focus）。
  @protected
  void onModeChanged(RenderMode oldMode) {}

  /// 子类实现的 render 内容（render 态显示内容）。
  ///
  /// **§3.0 方案 A 后**：此方法由基类 `build()` 在 `RenderMode.rendered` 时调用,
  /// 子类只需实现 render 态的视觉差异（如富文本 / 标题样式 / 代码块样式）,
  /// 不再需要自己判断 mode 也不用调用 `buildEditField`。
  @protected
  Widget buildRenderContent(BuildContext context);

  // ============ edit 态 TextField 配置（子类可覆盖） ============

  /// edit 态 [TextField] 的文本样式（子类可覆盖）。
  ///
  /// 默认 `null`（跟随 Theme.of(context).textTheme.bodyMedium）。
  @protected
  TextStyle? get editFieldStyle => null;

  /// edit 态 [TextField] 的 [InputDecoration]（子类可覆盖）。
  ///
  /// 默认带 `OutlineInputBorder` + 水平 12 / 垂直 8 内边距。
  @protected
  InputDecoration get editFieldDecoration => const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  /// edit 态 [TextField] 的 maxLines（子类可覆盖）。
  ///
  /// - 默认 `null`（多行,适合段落 / 代码块）
  /// - 标题块可覆盖为 `1`（单行）
  @protected
  int? get editFieldMaxLines => null;

  /// edit 态 [TextField] 的 [TextInputAction]（子类可覆盖）。
  ///
  /// - 默认 [TextInputAction.done]：触发 [TextField.onSubmitted] → 失焦 → commit
  /// - 代码块可覆盖为 [TextInputAction.newline]：不触发 onSubmitted,
  ///   插入换行符;失焦通过点击其他区域触发 [_onFocusChange]
  @protected
  TextInputAction get editFieldInputAction => TextInputAction.done;

  /// 构造标准 TextField（edit 态显示）。
  ///
  /// 由基类 `build()` 在 `RenderMode.editing` 时调用,
  /// 子类通常不需要直接调用此方法。
  ///
  /// **onSubmitted 触发条件**：仅在 [editFieldInputAction] 为
  /// [TextInputAction.done]（默认）时触发。覆盖为 [TextInputAction.newline]
  /// 的子类（如 CodeBlock）不会触发 onSubmitted,改由 [_onFocusChange]
  /// 在失焦时 commit。
  @protected
  Widget buildEditField({
    required TextStyle? style,
    required InputDecoration decoration,
    required int? maxLines,
    required TextInputAction inputAction,
  }) {
    return TextField(
      controller: textController,
      focusNode: focusNode,
      style: style,
      maxLines: maxLines,
      textInputAction: inputAction,
      decoration: decoration,
      onSubmitted: (_) => focusNode.unfocus(),
    );
  }
}
