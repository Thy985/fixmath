/// EditorScope：通过 [InheritedWidget] 注入 [EditorCoordinator]。
///
/// 落地 Phase 3.0 Task Contract §3.2 + ADR-0009 §3.5。
///
/// **职责**：让 Widget 树任意位置都能通过 `EditorScope.of(context)` 获取
/// 当前页面绑定的 [EditorCoordinator]。
///
/// **依赖方向**（Hard Rule 8）：
/// - editor/ 提供 EditorScope（injection）
/// - blocks/ 通过 EditorScope.of(context) 读取 Coordinator（不直接 import editor/）
///   （注：blocks 依赖 EditorCoordinator 类型，但通过 EditorScope 注入，不直接 import editor/）
///
/// **生命周期**：EditorScope 由 [EditorPage] 创建并挂载到 widget 树顶部，
/// Coordinator 在 EditorPage dispose 时一并释放。
library;

import 'package:flutter/widgets.dart';

import 'editor_coordinator.dart';

/// 通过 [InheritedWidget] 注入 [EditorCoordinator]。
///
/// Widget 通过 `EditorScope.of(context)` 获取 Coordinator，调用：
/// - `coordinator.handler.handle(command)` — 处理用户事件
/// - `coordinator.viewStateOf(id)` — 查询 UI 状态
/// - `coordinator.setFocus(id)` / `clearFocus(id)` — 管理焦点
class EditorScope extends InheritedWidget {
  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const EditorScope({
    super.key,
    required this.coordinator,
    required super.child,
  });

  /// 获取最近祖先的 [EditorCoordinator]，未找到时抛 [FlutterError]。
  ///
  /// 若 [listen] 为 true（默认），会监听 Coordinator 变化触发 rebuild。
  /// （Phase 3.0 Coordinator 本身是 mutable，rebuild 触发依赖 [StatefulWidget] 通知）
  ///
  /// **设计决策**：不提供 `maybeOf` 变体。理由：
  /// - Block 永远在 [EditorScope] 内渲染（EditorPage 保证），不需要 null 容错。
  /// - 若未来出现 EditorScope 外的 Block 渲染（如 preview 场景），应通过独立
  ///   的注入路径而非让 Block 自己处理 null，避免状态机复杂化。
  static EditorCoordinator of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<EditorScope>()
        : context.getInheritedWidgetOfExactType<EditorScope>();
    if (scope == null) {
      throw FlutterError(
        'EditorScope.of() called with no EditorScope ancestor.\n'
        'Ensure EditorPage (or EditorScope widget) wraps the widget tree.',
      );
    }
    return scope.coordinator;
  }

  /// 获取最近祖先的 [EditorCoordinator]，未找到时返回 null（不抛错）。
  ///
  /// 用于测试 / 错误恢复场景。生产代码应使用 [EditorScope.of]。
  ///
  /// **Phase 3.1-A 修订**：被 [BaseBlockState] 引用（抽象类不应假设 EditorScope
  /// 一定存在——例如 EditorScope 在 widget tree 之外时）。
  static EditorScope? maybeOf(BuildContext context, {bool listen = false}) {
    if (listen) {
      return context.dependOnInheritedWidgetOfExactType<EditorScope>();
    }
    return context.getInheritedWidgetOfExactType<EditorScope>();
  }

  @override
  bool updateShouldNotify(EditorScope oldWidget) =>
      coordinator != oldWidget.coordinator;
}
