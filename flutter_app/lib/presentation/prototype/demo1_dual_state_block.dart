/// Demo 1：单 Block 双态切换。
///
/// 验证 ADR-0009 §3：EditorCommand → CommandHandler → Transaction → AST 闭环。
/// 落地 Phase 2.9 Task Contract §1（4 个 Demo 之一）。
library;

import 'package:flutter/material.dart';

import '../../core/editing/block_types.dart';
import '../../data/models/document.dart';
import '../commands/commands.dart';
import '../commands/editor_command.dart';
import '../states/block_view_state.dart';
import '_shared/block_editor_facade.dart';

/// Demo 1 入口 Widget。
///
/// 单块文档：点击进入编辑态（TextField 显示 source），失焦回到渲染态
/// （Text 显示最终样式）。修改 source 通过 [UpdateBlockSourceCommand]
/// 提交，验证 round-trip：source → Command → AST → 渲染。
class Demo1DualStateBlock extends StatefulWidget {
  const Demo1DualStateBlock({super.key});

  @override
  State<Demo1DualStateBlock> createState() => _Demo1DualStateBlockState();
}

class _Demo1DualStateBlockState extends State<Demo1DualStateBlock> {
  late final BlockEditorFacade _facade;
  late final BlockId _blockId;
  late BlockViewState _state;
  // NOTE（PR 评审 R6）：FocusNode + TextEditingController + _onFocusChange +
  // _commitSource 模式在 Demo 1/2/4 中重复。Phase 3.0 应提取到 BlockEditController
  // 公共组件（lib/presentation/blocks/block_edit_controller.dart）。
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _facade = BlockEditorFacade.fromContent('Hello World');
    _blockId = _facade.allIds.first;
    _state = BlockViewState(id: _blockId);
    _textController = TextEditingController(text: _facade.sourceOf(_blockId));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // 失焦时：提交 source + 切换到 rendered mode
    if (!_focusNode.hasFocus && _state.mode == RenderMode.editing) {
      _commitSource();
      setState(() {
        _state = _state.copyWith(
          isFocused: false,
          mode: RenderMode.rendered,
        );
      });
    }
  }

  void _onBlockTap() {
    // 点击块：切换到 editing mode，刷新 controller 与最新 source
    setState(() {
      _state = _state.copyWith(
        isFocused: true,
        mode: RenderMode.editing,
      );
      _textController.text = _facade.sourceOf(_blockId);
    });
    _focusNode.requestFocus();
  }

  void _commitSource() {
    final newSource = _textController.text;
    final success = _facade.handler.handle(UpdateBlockSourceCommand(
      blockId: _blockId,
      newSource: newSource,
      origin: CommandOrigin.keyboard,
    ));
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败')),
      );
    }
  }

  void _undo() {
    setState(() {
      _facade.undo();
      _textController.text = _facade.sourceOf(_blockId);
      _state = _state.copyWith(mode: RenderMode.rendered);
    });
  }

  void _redo() {
    setState(() {
      _facade.redo();
      _textController.text = _facade.sourceOf(_blockId);
      _state = _state.copyWith(mode: RenderMode.rendered);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo 1: 双态切换'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _facade.canUndo ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _facade.canRedo ? _redo : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusPanel(),
            const SizedBox(height: 24),
            Expanded(child: _buildBlockWidget()),
            const Divider(),
            _buildHelpText(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    final element = _facade.getBlock(_blockId);
    final blockType = element != null ? BlockType.fromElement(element) : null;
    final theme = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BlockId: $_blockId', style: theme),
            Text('BlockType: $blockType', style: theme),
            Text('RenderMode: ${_state.mode}', style: theme),
            Text('Source: "${_facade.sourceOf(_blockId)}"', style: theme),
            Text(
              'canUndo: ${_facade.canUndo} / canRedo: ${_facade.canRedo}',
              style: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockWidget() {
    final element = _facade.getBlock(_blockId);
    if (element == null) {
      return const Center(child: Text('Block not found'));
    }

    if (_state.mode == RenderMode.editing) {
      return TextField(
        controller: _textController,
        focusNode: _focusNode,
        maxLines: null,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: '编辑 Markdown source',
        ),
        onSubmitted: (_) => _focusNode.unfocus(),
      );
    }

    return GestureDetector(
      onTap: _onBlockTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _buildRenderedElement(element),
      ),
    );
  }

  Widget _buildRenderedElement(DocumentElement element) {
    return switch (element) {
      HeadingElement(:final level, :final text) => Text(
          text,
          style: TextStyle(
            fontSize: 28 - (level - 1) * 4.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ParagraphElement(:final children) => Text(
          _serializeInline(children),
          style: const TextStyle(fontSize: 16),
        ),
      CodeElement(:final code) => Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(8),
          child: Text(
            code,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),
      BlockquoteElement(:final text) => Container(
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
      HorizontalRuleElement() => const Divider(thickness: 2),
      ListElement(:final children) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(_serializeInline(children),
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      TaskListItemElement(:final children, :final checked) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_serializeInline(children),
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      TableElement(:final headers, :final rows) => Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          children: [
            TableRow(
              children: headers
                  .map((h) => Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(h,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...rows.map((r) => TableRow(
                  children: r
                      .map((c) => Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(c),
                          ))
                      .toList(),
                )),
          ],
        ),
      MermaidElement(:final code) => Container(
          color: Colors.purple.shade50,
          padding: const EdgeInsets.all(8),
          child: Text(
            'mermaid:\n$code',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      EmptyLineElement() => const SizedBox(height: 16),
    };
  }

  String _serializeInline(List<InlineElement> children) {
    // 简化实现：仅提取文本，不还原 Markdown 语法。
    // 正式版应使用 InlineSerializer.serialize（顶层函数）。
    return children.map((e) {
      if (e is TextElement) return e.text;
      if (e is InlineCodeElement) return e.code;
      if (e is FormulaElement) return e.latex;
      if (e is LinkElement) return e.text;
      if (e is BoldElement) return _serializeInline(e.children);
      if (e is ItalicElement) return _serializeInline(e.children);
      if (e is StrikethroughElement) return _serializeInline(e.children);
      return '';
    }).join();
  }

  Widget _buildHelpText() {
    const style = TextStyle(fontSize: 13);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('操作指南：', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('• 点击块 → 进入编辑态（TextField 显示 source）', style: style),
        Text('• 编辑文本 → 点击外部或按键盘 Done → 提交（UpdateBlockSourceCommand）',
            style: style),
        Text('• 输入 `# ` 开头 → 自动 transform 为 heading', style: style),
        Text('• 按 Undo / Redo 按钮 → 验证历史栈', style: style),
      ],
    );
  }
}
