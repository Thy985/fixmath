/// Phase 2.9 Prototype 入口：4 个 Demo 切换器。
///
/// 落地 Phase 2.9 Task Contract §1：4 个 Prototype Demo 验证 ADR-0009 设计。
/// 本文件不进入生产路由（Phase 3 才正式接入 UI），仅供手动启动验证。
///
/// 启动方式：
/// ```
/// flutter run -t lib/presentation/prototype/prototype_main.dart
/// ```
library;

import 'package:flutter/material.dart';

import 'demo1_dual_state_block.dart';
import 'demo2_block_navigation.dart';
import 'demo3_undo_redo.dart';
import 'demo4_complex_blocks.dart';

/// Prototype 入口 Widget。
class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FormulaFix Prototype',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const PrototypeHome(),
    );
  }
}

/// Prototype 主页：4 个 Demo 入口。
class PrototypeHome extends StatelessWidget {
  const PrototypeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 2.9 Prototype')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDemoCard(
            context,
            title: 'Demo 1: 单块双态切换',
            description: '验证 EditorCommand → CommandHandler → Transaction → AST 闭环。\n'
                '点击块 → 编辑态；失焦 → 渲染态；修改 source → UpdateBlockSourceCommand。',
            target: const Demo1DualStateBlock(),
          ),
          _buildDemoCard(
            context,
            title: 'Demo 2: 块间导航',
            description: '验证多块 focus 切换 + BlockViewState 管理。\n'
                'ArrowDown/Up 在块间移动 focus（光标在边界时）。',
            target: const Demo2BlockNavigation(),
          ),
          _buildDemoCard(
            context,
            title: 'Demo 3: Undo/Redo 闭环',
            description: '验证 Command → Transaction → EditorHistory 闭环。\n'
                '3 步操作 + 3 次 undo + 3 次 redo，状态完全恢复。',
            target: const Demo3UndoRedo(),
          ),
          _buildDemoCard(
            context,
            title: 'Demo 4: 复杂 Block 共存',
            description: '验证多 BlockType 共存 + BlockRenderer 抽象。\n'
                'Paragraph + 公式 + 代码块 + 标题，focus 切换 + 类型转换。',
            target: const Demo4ComplexBlocks(),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCard(
    BuildContext context, {
    required String title,
    required String description,
    required Widget target,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => target),
                  );
                },
                child: const Text('启动'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prototype main 入口（独立运行用）。
void main() {
  runApp(const PrototypeApp());
}
