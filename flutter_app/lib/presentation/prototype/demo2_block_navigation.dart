/// Demo 2：块间导航。
///
/// 验证 ADR-0009 §3：多块 focus 切换 + BlockViewState 管理。
/// 落地 Phase 2.9 Task Contract §1（4 个 Demo 之二）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';
import '../commands/commands.dart';
import '../commands/editor_command.dart';
import '../states/block_view_state.dart';
import '_shared/block_editor_facade.dart';

/// Demo 2：3 个段落块，ArrowDown / Up 在块间移动 focus。
class Demo2BlockNavigation extends StatefulWidget {
  const Demo2BlockNavigation({super.key});

  @override
  State<Demo2BlockNavigation> createState() => _Demo2BlockNavigationState();
}

class _Demo2BlockNavigationState extends State<Demo2BlockNavigation> {
  late final BlockEditorFacade _facade;
  late final Map<BlockId, BlockViewState> _states;
  late final Map<BlockId, TextEditingController> _controllers;
  late final Map<BlockId, FocusNode> _focusNodes;
  BlockId? _focusedId;

  @override
  void initState() {
    super.initState();
    _facade = BlockEditorFacade.fromContent('第一块内容\n第二块内容\n第三块内容');
    _states = {};
    _controllers = {};
    _focusNodes = {};
    for (final id in _facade.allIds) {
      _states[id] = BlockViewState(id: id);
      _controllers[id] = TextEditingController(text: _facade.sourceOf(id));
      _focusNodes[id] = FocusNode(
        onKeyEvent: (node, event) => _onKeyEvent(id, node, event),
      );
      _focusNodes[id]!.addListener(() => _onFocusChange(id));
    }
    // 初始聚焦第一块（post-frame，确保 FocusNode 已挂载到 widget 树）
    final firstId = _facade.allIds.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusBlock(firstId));
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// 聚焦指定块，并把旧块切回渲染态。
  void _focusBlock(BlockId id) {
    // 先提交旧块的 source（若它在编辑态），避免 setState 后 _onFocusChange 跳过提交
    final oldId = _focusedId;
    if (oldId != null &&
        oldId != id &&
        _states[oldId]?.mode == RenderMode.editing) {
      _commitSource(oldId);
    }
    setState(() {
      if (oldId != null && oldId != id) {
        _states[oldId] = _states[oldId]!.copyWith(
          isFocused: false,
          mode: RenderMode.rendered,
        );
      }
      _states[id] = _states[id]!.copyWith(
        isFocused: true,
        mode: RenderMode.editing,
      );
      // 同步 controller 文本（可能被 undo/redo 修改过）
      _controllers[id]!.text = _facade.sourceOf(id);
      _focusedId = id;
    });
    _focusNodes[id]!.requestFocus();
  }

  /// FocusNode listener：失焦时提交并切回渲染态。
  void _onFocusChange(BlockId id) {
    final node = _focusNodes[id]!;
    if (!node.hasFocus && _states[id]?.mode == RenderMode.editing) {
      _commitSource(id);
      setState(() {
        _states[id] = _states[id]!.copyWith(
          isFocused: false,
          mode: RenderMode.rendered,
        );
      });
      if (_focusedId == id) {
        _focusedId = null;
      }
    }
  }

  void _commitSource(BlockId id) {
    _facade.handler.handle(UpdateBlockSourceCommand(
      blockId: id,
      newSource: _controllers[id]!.text,
      origin: CommandOrigin.keyboard,
    ));
  }

  /// ArrowDown 在末尾 → 聚焦下一块；末块则不移动。
  void _navigateDown(BlockId currentId) {
    final index = _facade.editor.indexOf(currentId);
    if (index + 1 < _facade.blockCount) {
      _focusBlock(_facade.allIds[index + 1]);
    } else {
      debugPrint('navigateDown: 已是末块，不移动');
    }
  }

  /// ArrowUp 在开头 → 聚焦上一块；首块则不移动。
  void _navigateUp(BlockId currentId) {
    final index = _facade.editor.indexOf(currentId);
    if (index > 0) {
      _focusBlock(_facade.allIds[index - 1]);
    } else {
      debugPrint('navigateUp: 已是首块，不移动');
    }
  }

  /// 键盘事件处理：仅当光标在边界（末尾/开头）时拦截 ArrowDown/Up。
  KeyEventResult _onKeyEvent(BlockId id, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowDown &&
        event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final controller = _controllers[id]!;
    final selection = controller.selection;
    final text = controller.text;
    // selection 未初始化（offset = -1）时不拦截
    if (!selection.isValid || selection.baseOffset < 0) {
      return KeyEventResult.ignored;
    }
    final isAtEnd =
        selection.isCollapsed && selection.baseOffset == text.length;
    final isAtStart =
        selection.isCollapsed && selection.baseOffset == 0;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown && isAtEnd) {
      _navigateDown(id);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && isAtStart) {
      _navigateUp(id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo 2: 块间导航')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusPanel(),
            const SizedBox(height: 16),
            Expanded(child: _buildBlockList()),
            const Divider(),
            _buildHelpText(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总块数: ${_facade.blockCount}'),
            Text('当前聚焦: $_focusedId'),
            const SizedBox(height: 8),
            const Text('各块 source:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (final id in _facade.allIds)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  '[$id] "${_facade.sourceOf(id)}"',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockList() {
    return ListView(
      children: [
        for (final id in _facade.allIds) _buildBlockItem(id),
      ],
    );
  }

  Widget _buildBlockItem(BlockId id) {
    final state = _states[id]!;
    final element = _facade.getBlock(id);
    final isFocused = state.isFocused;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isFocused ? Colors.blue : Colors.grey.shade300,
            width: isFocused ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(8),
        child: state.mode == RenderMode.editing
            ? TextField(
                controller: _controllers[id],
                focusNode: _focusNodes[id],
                maxLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _focusNodes[id]!.unfocus(),
              )
            : GestureDetector(
                onTap: () => _focusBlock(id),
                child: _buildRenderedContent(id, element),
              ),
      ),
    );
  }

  Widget _buildRenderedContent(BlockId id, DocumentElement? element) {
    if (element == null) {
      return const Text('（空）', style: TextStyle(fontSize: 16));
    }
    return switch (element) {
      ParagraphElement(:final children) => Text(
          children.map((e) => e is TextElement ? e.text : '').join(),
          style: const TextStyle(fontSize: 16),
        ),
      HeadingElement(:final level, :final text) => Text(
          text,
          style: TextStyle(
            fontSize: 28 - (level - 1) * 4.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      _ => Text(
          _facade.sourceOf(id),
          style: const TextStyle(fontSize: 16),
        ),
    };
  }

  Widget _buildHelpText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('操作指南：', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('• 点击块 → 聚焦并进入编辑态'),
        Text('• ArrowDown（光标在末尾）→ 聚焦下一块'),
        Text('• ArrowUp（光标在开头）→ 聚焦上一块'),
        Text('• 失焦 → 提交 source + 切换到渲染态'),
      ],
    );
  }
}
