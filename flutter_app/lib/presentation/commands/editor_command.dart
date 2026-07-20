/// EditorCommand 抽象接口（用户意图，纯数据）。
///
/// 落地 ADR-0009 §3.2（v1.1 修订）：Command 是用户意图的纯数据描述，
/// 不含 execute 方法，由 [CommandHandler] 解释为 BlockOperation 序列。
///
/// 设计原则：
/// - **纯数据**：可序列化、可记录、可重放（用于 AI / 录制回放 / 协同编辑）
/// - **来源显式**：[origin] 区分意图来源（keyboard / ime / ai / voice / menu / gesture）
/// - **不感知执行**：Command 不持有 TransactionBuilder 引用，不感知执行细节
library;

import 'package:flutter/foundation.dart';

/// Command 来源枚举。
///
/// 影响 Coalescing 决策：仅 [keyboard] / [ime] 在 Transaction 层可能合并；
/// 其他来源统一映射为 [TransactionOrigin.programmatic]。
enum CommandOrigin {
  /// 键盘输入（参与 Coalescing）。
  keyboard,

  /// IME commit（中文 / 日文输入 commit）。
  ime,

  /// AI Agent（未来扩展）。
  ai,

  /// 语音输入（未来扩展）。
  voice,

  /// 工具栏菜单点击。
  menu,

  /// 手势（tap / drag / long press）。
  gesture,
}

/// EditorCommand 抽象接口（用户意图，纯数据）。
///
/// 所有 UI 事件必须先构造 [EditorCommand] 子类，再交由 [CommandHandler] 处理。
/// 禁止 UI 直接调用 [BlockOperations]（ADR-0009 Hard Rule 2）。
@immutable
abstract class EditorCommand {
  /// 人类可读的 Command 名称（用于 Undo / Redo 菜单显示）。
  ///
  /// 例如："拆分块" / "删除块" / "更新文本"。
  String get displayName;

  /// Command 来源（区分 keyboard / ime / ai / voice / menu / gesture）。
  ///
  /// 影响 Coalescing 决策（仅 keyboard origin 合并）+ Undo / Redo 显示。
  CommandOrigin get origin;
}
