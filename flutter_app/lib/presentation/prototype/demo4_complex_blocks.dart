/// Demo 4：复杂 Block 共存。
///
/// 验证 ADR-0009 §3：多 BlockType 共存 + BlockRenderer 抽象。
/// 落地 Phase 2.9 Task Contract §1（4 个 Demo 之四）。
library;

import 'package:flutter/material.dart';

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';
import '../commands/commands.dart';
import '../commands/editor_command.dart';
import '../states/block_view_state.dart';
import '_shared/block_editor_facade.dart';

/// Demo 4 入口 Widget。
///
/// 4 个不同 BlockType 的块共存：段落 / 段落（公式文本）/ 代码 / 标题。
/// 验证 focus 在块间切换、BlockType 标签渲染、以及编辑代码块后自动
/// transform 仍为 code 但 language 会随 source 变化。
class Demo4ComplexBlocks extends StatefulWidget {
  const Demo4ComplexBlocks({super.key});

  @override
  State<Demo4ComplexBlocks> createState() => _Demo4ComplexBlocksState();
}

class _Demo4ComplexBlocksState extends State<Demo4ComplexBlocks> {
  late final BlockEditorFacade _facade;
  late final Map<BlockId, BlockViewState> _states;
  late final Map<BlockId, TextEditingController> _controllers;
  late final Map<BlockId, FocusNode> _focusNodes;
  BlockId? _focusedId;

  @override
  void initState() {
    super.initState();
    _facade = BlockEditorFacade.empty();
    // 块 1：段落 "Hello World"
    _facade.editor.addParagraph('Hello World');
    // 块 2：段落（含公式）—— 简化：公式作为段落文本（Prototype 不实现公式渲染）
    _facade.editor.addParagraph(r'$$E = mc^2$$');
    // 块 3：代码块（Python 函数定义）
    _facade.editor.addBlock('```\ndef greet():\n    return "hi"\n```', BlockType.code);
    // 块 4：标题
    _facade.editor.addBlock('# Demo 4', BlockType.heading);

    _states = {};
    _controllers = {};
    _focusNodes = {};
    for (final id in _facade.allIds) {
      _states[id] = BlockViewState(id: id);
      _controllers[id] = TextEditingController(text: _facade.sourceOf(id));
      final node = FocusNode();
      _focusNodes[id] = node;
      node.addListener(() => _onFocusChange(id));
    }
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

  /// FocusNode listener：失焦时提交 source 并切回渲染态。
  void _onFocusChange(BlockId id) {
    final node = _focusNodes[id];
    final state = _states[id];
    if (node == null || state == null) return;
    if (!node.hasFocus && state.mode == RenderMode.editing) {
      _commitSource(id);
      setState(() {
        _states[id] = state.copyWith(
          isFocused: false,
          mode: RenderMode.rendered,
        );
      });
      if (_focusedId == id) {
        _focusedId = null;
      }
    }
  }

  /// 聚焦指定块，先把旧块切回渲染态（含提交 source）。
  void _focusBlock(BlockId id) {
    final oldId = _focusedId;
    if (oldId != null &&
        oldId != id &&
        _states[oldId]?.mode == RenderMode.editing) {
      _commitSource(oldId);
    }
    setState(() {
      if (oldId != null && oldId != id) {
        final oldState = _states[oldId];
        if (oldState != null) {
          _states[oldId] = oldState.copyWith(
            isFocused: false,
            mode: RenderMode.rendered,
          );
        }
      }
      final curState = _states[id];
      if (curState != null) {
        _states[id] = curState.copyWith(
          isFocused: true,
          mode: RenderMode.editing,
        );
      }
      final controller = _controllers[id];
      if (controller != null) {
        controller.text = _facade.sourceOf(id);
      }
      _focusedId = id;
    });
    _focusNodes[id]?.requestFocus();
  }

  void _commitSource(BlockId id) {
    final controller = _controllers[id];
    if (controller == null) return;
    final ok = _facade.handler.handle(UpdateBlockSourceCommand(
      blockId: id,
      newSource: controller.text,
      origin: CommandOrigin.keyboard,
    ));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo 4: 复杂 Block 共存')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummary(),
            const SizedBox(height: 16),
            Expanded(child: _buildBlockList()),
            const Divider(),
            _buildHelpText(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总块数: ${_facade.blockCount}'),
            Text('聚焦块: $_focusedId'),
            const SizedBox(height: 8),
            const Text('块类型列表:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (int i = 0; i < _facade.allIds.length; i++)
              Text(
                '  [$i] ${_facade.allIds[i]}: ${_getBlockTypeLabel(_facade.allIds[i])}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  String _getBlockTypeLabel(BlockId id) {
    final element = _facade.getBlock(id);
    if (element == null) return 'unknown';
    return BlockType.fromElement(element).name;
  }

  Widget _buildBlockList() {
    return ListView(
      children: [for (final id in _facade.allIds) _buildBlockItem(id)],
    );
  }

  Widget _buildBlockItem(BlockId id) {
    final state = _states[id];
    final element = _facade.getBlock(id);
    final blockType = element != null ? BlockType.fromElement(element) : null;
    if (state == null) return const SizedBox.shrink();
    final isEditing = state.mode == RenderMode.editing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: state.isFocused ? Colors.blue : Colors.grey.shade300,
            width: state.isFocused ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BlockType 标签
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(blockType),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                blockType?.name ?? 'unknown',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            const SizedBox(height: 4),
            // 内容
            if (isEditing)
              TextField(
                controller: _controllers[id],
                focusNode: _focusNodes[id],
                maxLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _focusNodes[id]?.unfocus(),
              )
            else
              GestureDetector(
                onTap: () => _focusBlock(id),
                child: _buildRenderedContent(id, element),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderedContent(BlockId id, DocumentElement? element) {
    if (element == null) {
      return const Text('（空）', style: TextStyle(fontSize: 16));
    }
    return switch (element) {
      HeadingElement(:final level, :final text) => Text(
          text,
          style: TextStyle(
            fontSize: 28 - (level - 1) * 4.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ParagraphElement(:final children) => Text.rich(
          TextSpan(children: _buildInlineSpans(children)),
          style: const TextStyle(fontSize: 16),
        ),
      CodeElement(:final code, :final language) => Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (language != null)
                Text(
                  language,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              if (language != null) const SizedBox(height: 4),
              Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      BlockquoteElement(:final text) => Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey.shade400, width: 3),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      // 其他类型 fallback：直接显示 source
      _ => Text(
          _facade.sourceOf(id),
          style: const TextStyle(fontSize: 16),
        ),
    };
  }

  List<InlineSpan> _buildInlineSpans(List<InlineElement> children) {
    return children.map(_buildInlineSpan).toList();
  }

  InlineSpan _buildInlineSpan(InlineElement e) {
    return switch (e) {
      TextElement(:final text) => TextSpan(text: text),
      FormulaElement(:final latex, :final displayMode) => TextSpan(
          text: displayMode ? '\$\$$latex\$\$' : '\$$latex\$',
          style: TextStyle(
            color: Colors.blue.shade700,
            fontFamily: 'monospace',
          ),
        ),
      BoldElement(:final children) => TextSpan(
          children: _buildInlineSpans(children),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ItalicElement(:final children) => TextSpan(
          children: _buildInlineSpans(children),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      StrikethroughElement(:final children) => TextSpan(
          children: _buildInlineSpans(children),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
      InlineCodeElement(:final code) => TextSpan(
          text: code,
          style: TextStyle(
            backgroundColor: Colors.grey.shade200,
            fontFamily: 'monospace',
          ),
        ),
      LinkElement(:final text) => TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.blue.shade700,
            decoration: TextDecoration.underline,
          ),
        ),
      ImageElement(:final alt) => TextSpan(
          text: '[image: $alt]',
          style: const TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
    };
  }

  Color _getTypeColor(BlockType? type) {
    return switch (type) {
      BlockType.heading => Colors.red,
      BlockType.paragraph => Colors.blue,
      BlockType.code => Colors.green,
      BlockType.blockquote => Colors.orange,
      BlockType.listItem => Colors.purple,
      BlockType.taskListItem => Colors.teal,
      BlockType.table => Colors.brown,
      BlockType.mermaid => Colors.indigo,
      BlockType.horizontalRule => Colors.grey,
      null => Colors.grey,
    };
  }

  Widget _buildHelpText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('操作指南：', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('• 4 个块：段落 / 段落（公式文本）/ 代码 / 标题'),
        Text('• 每个块根据 BlockType 显示不同颜色标签 + 渲染样式'),
        Text('• 点击任意块 → 进入编辑态（TextField 显示 source）'),
        Text('• 点击其他块 → 自动切换 focus（旧块提交 + 渲染）'),
        Text('• 失焦 → 提交 source + 切换到渲染态'),
        Text('• 验证：编辑代码块为 ```dart\\nvoid main() {}\\n``` → '
            '仍为 code（language=dart）'),
      ],
    );
  }
}
