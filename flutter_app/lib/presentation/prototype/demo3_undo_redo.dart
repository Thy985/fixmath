/// Demo 3：Undo/Redo 闭环。
///
/// 验证 ADR-0009 §3：Command → Transaction → EditorHistory 闭环。
/// 落地 Phase 2.9 Task Contract §1（4 个 Demo 之三）。
library;

import 'package:flutter/material.dart';

import '../commands/commands.dart';
import '../commands/editor_command.dart';
import '_shared/block_editor_facade.dart';

class Demo3UndoRedo extends StatefulWidget {
  const Demo3UndoRedo({super.key});
  @override
  State<Demo3UndoRedo> createState() => _Demo3UndoRedoState();
}

class _Demo3UndoRedoState extends State<Demo3UndoRedo> {
  late final BlockEditorFacade _facade;
  final List<String> _operationLog = [];

  @override
  void initState() {
    super.initState();
    _facade = BlockEditorFacade.fromContent('Hello');
    _log('初始状态：1 块, source="Hello"');
  }

  void _log(String msg) {
    setState(() {
      _operationLog.insert(
        0,
        '[${DateTime.now().toIso8601String().substring(11, 19)}] $msg',
      );
    });
  }

  void _runThreeOperations() {
    // 操作 1：updateSource 改为 "Hello World"
    final ok1 = _facade.handler.handle(UpdateBlockSourceCommand(
      blockId: _facade.allIds.first,
      newSource: 'Hello World',
      origin: CommandOrigin.keyboard,
    ));
    _log('操作 1: updateSource "Hello" → "Hello World" (success=$ok1)');

    // 操作 2：split at offset 5（"Hello" 与 " World" 之间）
    final ok2 = _facade.handler.handle(SplitBlockCommand(
      blockId: _facade.allIds.first,
      offset: 5,
      origin: CommandOrigin.keyboard,
    ));
    _log('操作 2: split at offset=5 (success=$ok2, blockCount=${_facade.blockCount})');

    // 操作 3：updateSource 第 2 块改为 "World!"
    if (_facade.blockCount >= 2) {
      final ok3 = _facade.handler.handle(UpdateBlockSourceCommand(
        blockId: _facade.allIds[1],
        newSource: 'World!',
        origin: CommandOrigin.keyboard,
      ));
      _log('操作 3: updateSource 第 2 块 → "World!" (success=$ok3)');
    }
    _log('当前状态: blockCount=${_facade.blockCount}, '
        'undoCount=${_facade.history.undoCount}, '
        'redoCount=${_facade.history.redoCount}, '
        'sources=${_facade.allSources}');
  }

  void _undo() {
    final tx = _facade.undo();
    if (tx != null) {
      _log('Undo: "${tx.metadata.label ?? '未知'}" → '
          'blockCount=${_facade.blockCount}, '
          'undoCount=${_facade.history.undoCount}, '
          'redoCount=${_facade.history.redoCount}, '
          'sources=${_facade.allSources}');
    } else {
      _log('Undo: 失败（无历史）');
    }
  }

  void _redo() {
    final tx = _facade.redo();
    if (tx != null) {
      _log('Redo: "${tx.metadata.label ?? '未知'}" → '
          'blockCount=${_facade.blockCount}, '
          'undoCount=${_facade.history.undoCount}, '
          'redoCount=${_facade.history.redoCount}, '
          'sources=${_facade.allSources}');
    } else {
      _log('Redo: 失败（无历史）');
    }
  }

  void _reset() {
    setState(() {
      _facade = BlockEditorFacade.fromContent('Hello');
      _operationLog.clear();
      _log('重置：1 块, source="Hello"');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo 3: Undo/Redo 闭环'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: '重置',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusPanel(),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 16),
            _buildBlocksList(),
            const SizedBox(height: 16),
            const Divider(),
            const Text('操作日志:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: _buildLog()),
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
            Text('blockCount: ${_facade.blockCount}'),
            Text('undoCount: ${_facade.history.undoCount}'),
            Text('redoCount: ${_facade.history.redoCount}'),
            Text('canUndo: ${_facade.canUndo}'),
            Text('canRedo: ${_facade.canRedo}'),
            const SizedBox(height: 8),
            const Text('当前块列表:', style: TextStyle(fontWeight: FontWeight.bold)),
            for (int i = 0; i < _facade.allIds.length; i++)
              Text(
                '  [$i] ${_facade.allIds[i]}: "${_facade.sourceOf(_facade.allIds[i])}"',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 8,
      children: [
        ElevatedButton(
          onPressed: _runThreeOperations,
          child: const Text('运行 3 步操作'),
        ),
        ElevatedButton(
          onPressed: _facade.canUndo ? _undo : null,
          child: const Text('Undo'),
        ),
        ElevatedButton(
          onPressed: _facade.canRedo ? _redo : null,
          child: const Text('Redo'),
        ),
      ],
    );
  }

  Widget _buildBlocksList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _facade.allIds.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '块 $i: ${_facade.sourceOf(_facade.allIds[i])}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLog() {
    return ListView.builder(
      itemCount: _operationLog.length,
      itemBuilder: (context, index) {
        return Text(
          _operationLog[index],
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        );
      },
    );
  }
}
