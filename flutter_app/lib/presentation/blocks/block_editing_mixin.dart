/// BaseBlockState 抽象基类：Block 组件双态切换共享样板。
///
/// 落地 Phase 3.1-A Task Contract §3.1.A.2（R4 评审反馈）。
///
/// **背景**：Phase 3.0 时 3 个 Block 组件（paragraph / heading / code）各自重复实现：
/// - `late final TextEditingController _textController`
/// - `late final FocusNode _focusNode`
/// - `initState` / `dispose` 中的 controller / focus 初始化与销毁
/// - `_onFocusChange` listener + `_commitSource` 共享逻辑
///
/// **R4 抽象**：把上述 4 项样板抽到 [BaseBlockState] 抽象基类，
/// 3 个 Block 子类只需：
/// 1. `class XBlockState extends BaseBlockState<XBlock>`（继承样板）
/// 2. `@override Widget buildRenderContent(...)`（实现 render 差异）
/// 3. `@override void onModeChanged(RenderMode oldMode)`（可选：监听模式变化）
///
/// **未来 BlockType 复用**（Math / Mermaid / Table / Quote / Image / Callout / AIBlock）
/// 只需：
/// 1. `class MermaidBlock extends StatefulWidget`
/// 2. `class _MermaidBlockState extends BaseBlockState<MermaidBlock>`
/// 3. `@override Widget buildRenderContent(...)` 实现 render 差异
/// 4. 无需重复 controller / focus / commit 样板（约 40 行/Block）
library;

import 'package:flutter/material.dart';

import '../commands/commands.dart';
import '../editor/editor_coordinator.dart';
import '../editor/editor_scope.dart';
import '../states/block_view_state.dart';

/// Block 组件状态抽象基类。
///
/// **职责**：
/// - 管理 [TextEditingController] / [FocusNode] 生命周期
/// - 监听 [FocusNode] 变化，触发 [UpdateBlockSourceCommand]
/// - 双态切换（render ↔ edit）通过 [EditorCoordinator] 协调
/// - 提供 [buildRenderContent] 抽象让子类实现 render 差异
///
/// **继承约束**：
/// - 子类必须实现 [buildRenderContent]（render 差异）
/// - 子类可选覆盖 [onModeChanged]（监听模式变化）
abstract class BaseBlockState<T extends StatefulWidget> extends State<T> {
  /// Markdown 源文本控制器（共享样板）。
  late final TextEditingController textController;

  /// 焦点监听器（共享样板）。
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: _initialSource());
    focusNode = FocusNode();
    focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检测 mode 变化（RenderMode 切换时同步 controller 文本 + 焦点）
    if (currentMode != previousMode(oldWidget)) {
      textController.text = _initialSource();
      if (currentMode == RenderMode.editing) {
        focusNode.requestFocus();
      }
      onModeChanged(previousMode(oldWidget));
    }
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  /// 焦点变化回调：edit → render 时 commit 修改。
  ///
  /// **R4 共享逻辑**：当 focusNode 失焦且当前处于 editing 模式，
  /// commit 当前 textController 文本并清除 focus。
  void _onFocusChange() {
    if (!focusNode.hasFocus && currentMode == RenderMode.editing) {
      _commitSource();
      coordinator.clearFocus(blockId);
    }
  }

  /// commit 当前 textController 文本到 [EditorCoordinator]。
  void _commitSource() {
    coordinator.handle(UpdateBlockSourceCommand(
      blockId: blockId,
      newSource: textController.text,
    ));
  }

  /// 当前 Block 所属的 [EditorCoordinator]（从 [EditorScope] 拿）。
  EditorCoordinator get coordinator {
    final scope = EditorScope.of(context);
    return scope.coordinator;
  }

  /// 当前 Block 的 [BlockId]（子类必须实现，从 widget 拿）。
  BlockId get blockId;

  /// 当前 Block 的渲染模式（从 [BlockViewState] 拿，子类必须实现）。
  RenderMode get currentMode;

  /// 从 [oldWidget] 拿前一次的模式（默认取 [currentMode]，子类可覆盖）。
  RenderMode previousMode(T oldWidget) => currentMode;

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

  /// 子类实现的 render 内容（render 态显示内容 / edit 态显示 TextField）。
  ///
  /// 调用 [buildRenderContent] 时应区分当前 [RenderMode]：
  /// - [RenderMode.rendered]：显示最终样式（如富文本 / 标题样式 / 代码块样式）
  /// - [RenderMode.editing]：显示 [TextField] + Markdown source
  @protected
  Widget buildRenderContent(BuildContext context);

  /// 构造标准 TextField（edit 态显示）。
  ///
  /// 子类在 [buildRenderContent] 中检测到 editing mode 时调用。
  @protected
  Widget buildEditField({required TextStyle? style}) {
    return TextField(
      controller: textController,
      focusNode: focusNode,
      style: style,
      maxLines: null,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
