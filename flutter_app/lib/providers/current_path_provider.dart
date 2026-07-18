import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前编辑器正在编辑的 .md 文件路径（单一桥接状态）。
///
/// 由文件管理器 / 文档列表在打开文档时写入；编辑器据此做防抖自动保存
/// 与手动保存的目标路径。新建且未保存的文档为 `null`。
///
/// 该状态是编辑器与文档列表之间传递"当前打开文件"的唯一通道，
/// 避免使用重复定义的 [Document] 内容副本（见 AGENTS.md §3.2 同名
/// Provider 多文件问题）。
final currentPathProvider = StateProvider<String?>((ref) => null);
