/// Block 编辑内核数据类。
///
/// 定义 BlockEditor 抽象所需的核心数据类型：
/// - [BlockId]：块唯一标识（内存标识，非持久化）
/// - [BlockType]：块类型枚举，1:1 映射 [DocumentElement] 子类
/// - [BlockSelection]：块内选区
/// - [BlockPosition]：光标位置（块间 + 块内）
/// - [ComposingRegion]：IME 组合态区间
///
/// 详见 ADR-0007 §1（抽象结构）+ §2（光标模型）+ §3（IME 兼容）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextAffinity;

import '../../data/models/document.dart';

/// 块唯一标识。
///
/// 同一 Document 内稳定，用于光标定位与 Undo/Redo。
/// 仅内存标识，非持久化存储（[ADR-0003] §边界约束 5：不引入派生缓存）。
@immutable
class BlockId {
  /// 内部值。使用 int 自增，未来可扩展为 String UUID。
  final int value;

  const BlockId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BlockId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BlockId($value)';
}

/// 块类型枚举。1:1 映射 [DocumentElement] 子类。
///
/// 例外：[EmptyLineElement] 不在 BlockEditor 范围（空行是块间分隔符，不编辑）。
/// 详见 ADR-0007 §1.2。
enum BlockType {
  heading,
  paragraph,
  listItem,
  taskListItem,
  code,
  table,
  blockquote,
  mermaid,
  horizontalRule;

  /// 从 [DocumentElement] 子类映射到 [BlockType]。
  ///
  /// 1:1 映射，遗漏子类将导致编译错误（exhaustive switch）。
  static BlockType fromElement(DocumentElement element) {
    return switch (element) {
      HeadingElement() => heading,
      ParagraphElement() => paragraph,
      ListElement() => listItem,
      TaskListItemElement() => taskListItem,
      CodeElement() => code,
      TableElement() => table,
      BlockquoteElement() => blockquote,
      MermaidElement() => mermaid,
      HorizontalRuleElement() => horizontalRule,
      // EmptyLineElement 不映射：空行非可编辑块
      EmptyLineElement() => throw ArgumentError(
          'EmptyLineElement is not an editable BlockType',
        ),
    };
  }
}

/// 块内选区。
///
/// 表示用户在块内选中的文本区间 [start, end)。
/// 不重新发明 Flutter TextField 的选区，仅作 BlockEditor 内部表示。
///
/// 语义对齐 Flutter `TextSelection`（UTF-16 code unit offset）。
/// 详见 ADR-0007 §2.1 offset 语义。
@immutable
class BlockSelection {
  /// 选区起点 offset（包含）。必须 >= 0。
  final int start;

  /// 选区终点 offset（不包含）。必须 >= start。
  final int end;

  /// 文本方向（中文混排、RTL 文本用）。
  final TextAffinity affinity;

  const BlockSelection({
    required this.start,
    required this.end,
    this.affinity = TextAffinity.downstream,
  })  : assert(start >= 0, 'BlockSelection.start must be >= 0'),
        assert(end >= start, 'BlockSelection.end must be >= start');

  /// 选区长度。
  int get length => end - start;

  /// 是否为空选区（光标点，非范围）。
  bool get isCollapsed => length == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockSelection &&
          other.start == start &&
          other.end == end &&
          other.affinity == affinity);

  @override
  int get hashCode => Object.hash(start, end, affinity);

  @override
  String toString() =>
      'BlockSelection(start=$start, end=$end, affinity=$affinity)';

  BlockSelection copyWith({
    int? start,
    int? end,
    TextAffinity? affinity,
  }) {
    return BlockSelection(
      start: start ?? this.start,
      end: end ?? this.end,
      affinity: affinity ?? this.affinity,
    );
  }
}

/// 光标位置。块间 + 块内双层定位。
///
/// 详见 ADR-0007 §2.1。
/// - [blockId]：哪个块
/// - [offset]：块内字符 offset（UTF-16 code unit，0..source.length）
/// - [selection]：选区（null=单光标点）
@immutable
class BlockPosition {
  final BlockId blockId;

  /// 块内 offset。语义为 UTF-16 code unit，对齐 Flutter TextEditingValue。
  final int offset;

  final BlockSelection? selection;

  const BlockPosition({
    required this.blockId,
    required this.offset,
    this.selection,
  }) : assert(offset >= 0, 'BlockPosition.offset must be >= 0');

  /// 是否为单光标点（无选区）。
  bool get isCursor => selection == null || selection!.isCollapsed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockPosition &&
          other.blockId == blockId &&
          other.offset == offset &&
          other.selection == selection);

  @override
  int get hashCode => Object.hash(blockId, offset, selection);

  @override
  String toString() =>
      'BlockPosition(blockId=$blockId, offset=$offset, selection=$selection)';

  BlockPosition copyWith({
    BlockId? blockId,
    int? offset,
    Object? selection = _sentinel,
  }) {
    return BlockPosition(
      blockId: blockId ?? this.blockId,
      offset: offset ?? this.offset,
      selection: identical(selection, _sentinel)
          ? this.selection
          : selection as BlockSelection?,
    );
  }
}

const Object _sentinel = Object();

/// IME 组合态区间。
///
/// 中文 / 日文输入未 commit 时，[start, end) 区间不可分割。
/// 详见 ADR-0007 §3.1。
///
/// 三条铁律（ADR-0007 §3.2）：
/// 1. 组合态中间不切块（composing.isActive 时禁止 onBlur/split/merge）
/// 2. commit 时不丢字（onSourceChanged 在 commit 阶段触发，替换 composing region）
/// 3. cancel 时回滚（onComposingCancelled 恢复 commit 前 source）
@immutable
class ComposingRegion {
  /// 组合态起点 offset（包含）。-1 表示无组合态。
  final int start;

  /// 组合态终点 offset（不包含）。
  final int end;

  const ComposingRegion({required this.start, required this.end});

  /// 常量：无组合态。
  static const ComposingRegion empty = ComposingRegion(start: -1, end: -1);

  /// 是否处于组合态。
  ///
  /// - start >= 0
  /// - end > start
  bool get isActive => start >= 0 && end > start;

  /// 组合态长度。
  int get length => isActive ? end - start : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComposingRegion && other.start == start && other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ComposingRegion(start=$start, end=$end)';
}
