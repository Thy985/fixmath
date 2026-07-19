/// BlockType 规则检测器。
///
/// 纯函数 [detectBlockType]：给定 Markdown source 文本，返回最匹配的 [BlockType]。
///
/// 7 条规则（按优先级排列，taskListItem 先于 listItem 避免误判）：
/// 1. `^#{1,6}\s` → heading
/// 2. `^\s*[-*+]\s\[(?: |x|X)\]\s` → taskListItem
/// 3. `^\s*[-*+]\s` → listItem
/// 4. `^\s*\d+\.\s` → listItem（ordered）
/// 5. `^```+\S*` → code（含 mermaid，区分发生在 toElement 内部）
/// 6. `^>\s` → blockquote
/// 7. `^\s*(-{3,}|\*{3,}|_{3,})\s*$` → horizontalRule
///
/// **永不返回 null**：无匹配时返回 [BlockType.paragraph]（减少调用方分支）。
///
/// 详见 ADR-0007 §4.3。
library;

import 'block_types.dart';

/// 检测 [source] 文本的 [BlockType]。
///
/// 永不返回 null。无匹配规则时返回 [BlockType.paragraph]。
BlockType detectBlockType(String source) {
  if (source.isEmpty) return BlockType.paragraph;

  // 1. heading
  if (RegExp(r'^#{1,6}\s').hasMatch(source)) {
    return BlockType.heading;
  }

  // 2. taskListItem（先于 listItem，避免 `- [ ]` 被误判为普通 list item）
  if (RegExp(r'^\s*[-*+]\s\[( |x|X)\]\s').hasMatch(source)) {
    return BlockType.taskListItem;
  }

  // 3. listItem（unordered）
  if (RegExp(r'^\s*[-*+]\s').hasMatch(source)) {
    return BlockType.listItem;
  }

  // 4. listItem（ordered）
  if (RegExp(r'^\s*\d+\.\s').hasMatch(source)) {
    return BlockType.listItem;
  }

  // 5. code（含 mermaid，区分发生在 toElement 内部）
  if (RegExp(r'^```+\S*').hasMatch(source)) {
    return BlockType.code;
  }

  // 6. blockquote
  if (RegExp(r'^>\s').hasMatch(source)) {
    return BlockType.blockquote;
  }

  // 7. horizontalRule
  if (RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(source)) {
    return BlockType.horizontalRule;
  }

  // 默认：paragraph
  return BlockType.paragraph;
}
