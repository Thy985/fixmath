/// TC-ARCH-UI-9 ~ 11: Phase 3.1-A 架构守门测试。
///
/// 落地 Phase 3.1-A Task Contract §5.2（自动验证）+ §6（Exit Gate）。
///
/// 守门内容：
/// - **TC-ARCH-UI-9**：EditorCommand 是 sealed class，8 个子类在同文件（library 限定）
/// - **TC-ARCH-UI-10**：3 个 Block（paragraph/heading/code）都 extends BaseBlockState
///   且不重复实现 controller / focus / commit 样板
/// - **TC-ARCH-UI-11（弱化版 R1）**：EditorCoordinator 持有 CoordinatorState
///   不可变单字段，外部不直接暴露 _viewStates / _focusedId
///
/// 背景：Phase 3.1-A 完成 3 项架构强化，3.1-B / 3.1-C 留待触发。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-ARCH-UI-9 EditorCommand sealed class 守门 ============

  group('TC-ARCH-UI-9 EditorCommand sealed class 守门', () {
    test('editor_command.dart 中 EditorCommand 声明为 sealed class', () {
      final file = File('lib/presentation/commands/editor_command.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // 检查 sealed 修饰符
      expect(
        RegExp(r'sealed\s+class\s+EditorCommand').hasMatch(content),
        isTrue,
        reason: 'EditorCommand 必须声明为 sealed class（Phase 3.1-A R6）',
      );

      // 检查 8 个子类都在同一文件（Dart sealed library 限定）
      const expectedSubclasses = [
        'SplitBlockCommand',
        'MergeWithPreviousCommand',
        'InsertBlockAfterCommand',
        'DeleteBlockCommand',
        'MoveBlockUpCommand',
        'MoveBlockDownCommand',
        'UpdateBlockSourceCommand',
        'TransformBlockCommand',
      ];
      for (final name in expectedSubclasses) {
        final pattern = RegExp('(?:final\\s+)?class\\s+$name\\s+extends\\s+EditorCommand');
        expect(
          pattern.hasMatch(content),
          isTrue,
          reason: 'EditorCommand 子类 $name 必须在 editor_command.dart '
              '中 extends EditorCommand（sealed library 限定）',
        );
      }
    });

    test('commands.dart 是 re-export 桥，不重复声明 sealed class', () {
      final file = File('lib/presentation/commands/commands.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // commands.dart 应有 export
      expect(
        RegExp(r"export\s+'editor_command\.dart'").hasMatch(content),
        isTrue,
        reason: 'commands.dart 必须 export editor_command.dart（让外部 import 不变）',
      );

      // commands.dart 不应重新声明 sealed class EditorCommand
      expect(
        RegExp(r'sealed\s+class\s+EditorCommand').hasMatch(content),
        isFalse,
        reason: 'sealed class EditorCommand 只能在 editor_command.dart 中声明一次',
      );
    });
  });

  // ============ TC-ARCH-UI-10 BaseBlockState 共享样板守门 ============

  group('TC-ARCH-UI-10 BaseBlockState 共享样板守门', () {
    test('paragraph / heading / code 3 个 Block 都 extends BaseBlockState', () {
      const blockFiles = [
        'paragraph_block.dart',
        'heading_block.dart',
        'code_block.dart',
      ];
      final hits = <String>[];
      for (final name in blockFiles) {
        final file = File('lib/presentation/blocks/$name');
        expect(file.existsSync(), isTrue, reason: '$name 必须存在');
        final content = file.readAsStringSync();
        if (!RegExp(r'extends\s+BaseBlockState<').hasMatch(content)) {
          hits.add(name);
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'Phase 3.1-A R4 反馈：3 个 Block 必须 extends BaseBlockState '
            '共享 controller / focus / commit 样板。\n'
            '未改造：\n${hits.join('\n')}',
      );
    });

    test('paragraph / heading / code 3 个 Block 不重复声明 _textController 字段', () {
      // R4 抽取后，_textController 应只存在于 BaseBlockState，
      // 3 个 Block 子类不应再各自声明。
      const blockFiles = [
        'paragraph_block.dart',
        'heading_block.dart',
        'code_block.dart',
      ];
      final hits = <String>[];
      for (final name in blockFiles) {
        final file = File('lib/presentation/blocks/$name');
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains(RegExp(r'(?:late\s+final|final)\s+TextEditingController\s+_\w*Controller'))) {
            hits.add('$name:${i + 1}:${line.trim()}');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'R4 抽取后 _textController 字段应继承自 BaseBlockState，'
            '3 个 Block 子类不应再各自声明。\n'
            '命中：\n${hits.join('\n')}',
      );
    });

    test('BaseBlockState 是 abstract 类', () {
      final file = File('lib/presentation/blocks/base_block_state.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        RegExp(r'abstract\s+class\s+BaseBlockState').hasMatch(content),
        isTrue,
        reason: 'BaseBlockState 必须是 abstract 类（R4 设计）',
      );
    });
  });

  // ============ TC-ARCH-UI-11 弱化版 R1：EditorCoordinator 内部 state 拆分守门 ============

  group('TC-ARCH-UI-11（弱化版 R1）EditorCoordinator 内部 state 拆分守门', () {
    test('EditorCoordinator 不再持有 _viewStates Map 字段', () {
      final file = File('lib/presentation/editor/editor_coordinator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // 弱化 R1 后 _viewStates 字段应被 CoordinatorState 替代
      // 允许：注释 / 字符串字面量中出现 "_viewStates"
      // 禁止：字段声明 `Map<BlockId, BlockViewState> _viewStates = {};`
      expect(
        RegExp(r'Map<BlockId,\s*BlockViewState>\s+_viewStates\s*=').hasMatch(content),
        isFalse,
        reason: 'Phase 3.1-A R1 弱化版：_viewStates Map 字段必须被 CoordinatorState '
            '不可变单字段替代，禁止直接持有可变 Map。',
      );
    });

    test('EditorCoordinator 持有 CoordinatorState _state 字段', () {
      final file = File('lib/presentation/editor/editor_coordinator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(
        RegExp(r'CoordinatorState\s+_state\s*;').hasMatch(content),
        isTrue,
        reason: 'Phase 3.1-A R1 弱化版：EditorCoordinator 必须持有 '
            'CoordinatorState _state 不可变单字段。',
      );

      // 应有 import
      expect(
        RegExp("import\\s+['\"].*coordinator_state\\.dart['\"]").hasMatch(content),
        isTrue,
        reason: 'editor_coordinator.dart 必须 import coordinator_state.dart',
      );
    });

    test('CoordinatorState 是不可变（@immutable + 不可变更新方法）', () {
      final file = File('lib/presentation/states/coordinator_state.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(
        RegExp(r'@immutable\s*\n\s*class\s+CoordinatorState').hasMatch(content),
        isTrue,
        reason: 'CoordinatorState 必须标 @immutable（不可变状态）',
      );

      // 不可变更新方法必须返回 CoordinatorState（新副本）
      const updateMethods = [
        'updateViewState',
        'focusOn',
        'clearFocusOf',
        'syncViewStates',
      ];
      for (final method in updateMethods) {
        final pattern = RegExp('CoordinatorState\\s+$method\\(');
        expect(
          pattern.hasMatch(content),
          isTrue,
          reason: 'CoordinatorState 必须提供不可变更新方法 $method（返回新副本）',
        );
      }
    });
  });
}
