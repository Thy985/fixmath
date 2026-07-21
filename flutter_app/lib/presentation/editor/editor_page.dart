/// EditorPage：Phase 3.0 production 路径的顶层编辑器页面（Route 入口）。
///
/// 落地 Phase 3.0 Task Contract §3.2 + §2.5（旧 UI 并存）。
///
/// **职责**：
/// - 创建 [EditorCoordinator]（注入 InMemoryDocumentEditor + EditorHistory）
/// - 通过 [EditorScope] 把 Coordinator 注入到 widget 树
/// - 挂载 [EditorShell]（布局壳）
/// - dispose 时释放 Coordinator（[InMemoryDocumentEditor] / [EditorHistory]）
///
/// **Feature Flag**（§2.5 旧 UI 并存）：
/// - Phase 3.0 期间 `kEnableNewEditor` 默认 false（旧 UI 为主入口）
/// - Phase 3.1 完成后改为 true
/// - Phase 3.17 完成后删除旧 UI 代码
library;

import 'package:flutter/material.dart';

import '../../core/editing/editor_history.dart';
import 'editor_coordinator.dart';
import 'editor_scope.dart';
import 'editor_shell.dart';
import 'in_memory_document_editor.dart';
import 'seed_documents.dart';

/// Phase 3.0 顶层编辑器页面（Route 入口）。
///
/// 通过 [seedSelector] 选择种子文档（0/1/2 对应 demo1/demo2/demo3）。
class EditorPage extends StatefulWidget {
  /// 选择种子文档（0 = demo1, 1 = demo2, 2 = demo3）。
  ///
  /// 默认 0。Phase 3.1+ 接入真实 .md 文件时，此参数替换为文件路径。
  final int seedSelector;

  const EditorPage({
    super.key,
    this.seedSelector = 0,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final EditorCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    final editor = _buildSeedEditor(widget.seedSelector);
    final history = EditorHistory(maxHistorySize: 200);
    _coordinator = EditorCoordinator(editor: editor, history: history);
  }

  /// 根据 [selector] 构造种子 [InMemoryDocumentEditor]。
  InMemoryDocumentEditor _buildSeedEditor(int selector) {
    switch (selector) {
      case 0:
        return SeedDocuments.createDemo1();
      case 1:
        return SeedDocuments.createDemo2();
      case 2:
        return SeedDocuments.createDemo3();
      default:
        return SeedDocuments.createDemo1();
    }
  }

  @override
  void dispose() {
    // Phase 3.0：InMemoryDocumentEditor / EditorHistory 持有的是纯内存数据，
    // 无需显式释放。Phase 3.1+ 接入真实 .md 文件时需补充资源清理。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 用 AnimatedBuilder 监听 ChangeNotifier（_coordinator）变化，
    // 当 coordinator.handle / setFocus / clearFocus / undo / redo 调用
    // notifyListeners() 时，触发 EditorShell 重建。
    return EditorScope(
      coordinator: _coordinator,
      child: AnimatedBuilder(
        animation: _coordinator,
        builder: (context, _) => EditorShell(coordinator: _coordinator),
      ),
    );
  }
}
