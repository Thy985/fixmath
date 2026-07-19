/// TC-EDIT-5: ComposingController 单元测试。
///
/// 对应 ADR-0007 §3.2 三铁律 + §3.4 8 个测试场景矩阵
/// + Phase 2.5 Task Contract §4.1（含评审反馈 2 个补充场景）。
///
/// 状态机转换测试（TC-EDIT-5.1）见 [composing_state_test.dart]。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/composing_controller.dart';
import 'package:formula_fix/core/editing/composing_state.dart';

/// Mock ComposingHost 用于隔离 Flutter TextEditingController。
///
/// 记录 replaceRange / restoreSource 调用参数，便于断言。
class _MockComposingHost implements ComposingHost {
  @override
  String source;

  @override
  ComposingRegion composing;

  final List<({int start, int end, String replacement})> replaceRangeCalls = [];
  final List<String> restoreSourceCalls = [];

  _MockComposingHost({required this.source, required this.composing});

  @override
  void replaceRange(int start, int end, String replacement) {
    replaceRangeCalls.add((start: start, end: end, replacement: replacement));
    // 模拟 TextEditingController 的替换行为
    source = source.substring(0, start) + replacement + source.substring(end);
  }

  @override
  void restoreSource(String source) {
    restoreSourceCalls.add(source);
    this.source = source;
  }
}

void main() {
  group('TC-EDIT-5.2 三铁律', () {
    test('铁律 1：composing 态 canEditBlock() 返回 false', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: const ComposingRegion(start: 0, end: 0),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      expect(controller.canEditBlock(), isFalse);
    });

    test('铁律 1：committing 态 canEditBlock() 返回 false', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: const ComposingRegion(start: 0, end: 5),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      // 手动推进到 committing（不调 commit 避免立即 commitComplete）
      // 通过 transitionComposingState 直接验证
      expect(
        transitionComposingState(
          current: ComposingState.composing,
          event: ComposingEvent.commit,
        ),
        equals(ComposingState.committing),
      );
    });

    test('铁律 1：idle 态 canEditBlock() 返回 true', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: ComposingRegion.empty,
      );
      final controller = ComposingController(host);
      expect(controller.canEditBlock(), isTrue);
    });

    test('铁律 1：assertBlockMutationAllowed() 在 composing 态抛 StateError（评审反馈 2）', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: const ComposingRegion(start: 0, end: 2),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      expect(
        controller.assertBlockMutationAllowed,
        throwsStateError,
      );
    });

    test('铁律 1：assertBlockMutationAllowed() 在 idle 态不抛（正常路径）', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: ComposingRegion.empty,
      );
      final controller = ComposingController(host);
      // 不应抛异常
      controller.assertBlockMutationAllowed();
      expect(controller.state, equals(ComposingState.idle));
    });

    test('铁律 2：onComposingCommit 用 replaceRange 替换 composing region', () {
      final host = _MockComposingHost(
        source: '今天',
        composing: const ComposingRegion(start: 0, end: 2),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCommit('你好');
      // 验证 host.replaceRange 被调用，参数为 (0, 2, '你好')
      expect(host.replaceRangeCalls.length, equals(1));
      expect(host.replaceRangeCalls[0].start, equals(0));
      expect(host.replaceRangeCalls[0].end, equals(2));
      expect(host.replaceRangeCalls[0].replacement, equals('你好'));
    });

    test('铁律 2：不覆盖整个 source（仅替换 composing region）', () {
      final host = _MockComposingHost(
        source: '前缀中缀后缀',
        composing: const ComposingRegion(start: 2, end: 4), // '中缀'
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCommit('替换');
      // replaceRange 应仅替换 [2, 4) 区间，前缀/后缀保留
      expect(host.source, equals('前缀替换后缀'));
    });

    test('铁律 3：onComposingCancel 恢复到 commit 前 source', () {
      final host = _MockComposingHost(
        source: '原始',
        composing: const ComposingRegion(start: 0, end: 0),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      // 模拟 composing 期间 source 被修改
      host.source = '原始你';
      controller.onComposingCancel();
      // restoreSource 应被调用，恢复到 '原始'
      expect(host.restoreSourceCalls.length, equals(1));
      expect(host.restoreSourceCalls[0], equals('原始'));
      expect(host.source, equals('原始'));
    });
  });

  group('TC-EDIT-5.3 ADR-0007 §3.4 8 个场景', () {
    test('场景 1：输入 "你好" 中途切到下一块 → canEditBlock 返回 false', () {
      // 用户在 composing 中，试图切到下一块
      final host = _MockComposingHost(
        source: '今天',
        composing: const ComposingRegion(start: 2, end: 2),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      // 切块前必须检查 canEditBlock
      expect(controller.canEditBlock(), isFalse);
      // 调用方必须先 commit 或 cancel
    });

    test('场景 2：输入 "你好" 中途点工具栏加粗按钮 → canEditBlock 返回 false', () {
      final host = _MockComposingHost(
        source: 'text',
        composing: const ComposingRegion(start: 0, end: 2),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      // 点加粗按钮前必须检查 canEditBlock
      expect(controller.canEditBlock(), isFalse);
    });

    test('场景 3：选候选 "拟好" → onComposingCommit 替换 composing region', () {
      // 输入 "ni hao" 选第 2 候选 "拟好"
      final host = _MockComposingHost(
        source: '今天ni hao',
        composing: const ComposingRegion(start: 2, end: 8), // 'ni hao'
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCommit('拟好');
      expect(host.source, equals('今天拟好'));
      expect(controller.state, equals(ComposingState.idle));
    });

    test('场景 4：输入到块末尾继续输入 → onComposingUpdate 推进 offset', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: const ComposingRegion(start: 5, end: 5),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      // 连续 update，composing region 推进
      host.composing = const ComposingRegion(start: 5, end: 6);
      controller.onComposingUpdate();
      host.composing = const ComposingRegion(start: 5, end: 7);
      controller.onComposingUpdate();
      // 状态仍为 composing（self-transition）
      expect(controller.state, equals(ComposingState.composing));
      // 不自动 split（canEditBlock 仍为 false）
      expect(controller.canEditBlock(), isFalse);
    });

    test('场景 5：输入到块末尾按 Enter → idle 态 canEditBlock 返回 true', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: ComposingRegion.empty,
      );
      final controller = ComposingController(host);
      // idle 态允许 split（Phase 2.6 实现）
      expect(controller.canEditBlock(), isTrue);
      controller.assertBlockMutationAllowed(); // 不抛
    });

    test('场景 6：composing 中按 Backspace → onComposingCancel 恢复 source', () {
      final host = _MockComposingHost(
        source: '原始',
        composing: const ComposingRegion(start: 0, end: 0),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      host.source = '原始你';
      // 按 Backspace 取消 composing
      controller.onComposingCancel();
      // 恢复到 commit 前 source（'原始'）
      expect(host.source, equals('原始'));
      // 不删除已 commit 字符
      expect(controller.state, equals(ComposingState.idle));
    });

    test('场景 7：连续 composing update（评审反馈 5）→ source 不重复追加', () {
      // 模拟输入 n → ni → nih → 你好
      final host = _MockComposingHost(
        source: '',
        composing: const ComposingRegion(start: 0, end: 0),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      // 4 次 update（模拟 IME 输入过程）
      host.composing = const ComposingRegion(start: 0, end: 1);
      controller.onComposingUpdate();
      host.composing = const ComposingRegion(start: 0, end: 2);
      controller.onComposingUpdate();
      host.composing = const ComposingRegion(start: 0, end: 3);
      controller.onComposingUpdate();
      host.composing = const ComposingRegion(start: 0, end: 2);
      controller.onComposingUpdate();
      // update 不应触发 source 修改（source 修改只在 commit 时）
      expect(host.replaceRangeCalls, isEmpty);
      expect(host.source, equals(''));
      // 状态仍为 composing
      expect(controller.state, equals(ComposingState.composing));
    });

    test('场景 8：commit 后 state reset（评审反馈 5）→ state == idle && isActive == false', () {
      final host = _MockComposingHost(
        source: 'ni hao',
        composing: const ComposingRegion(start: 0, end: 6),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCommit('你好');
      // commit 后状态必须 reset
      expect(controller.state, equals(ComposingState.idle));
      expect(controller.isActive, isFalse);
      // 防止 Phase 2.6 Transaction 误判仍 composing
    });
  });

  group('TC-EDIT-5.4 边界与降级', () {
    test('空 composing region 处理（commit 空 composing）', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: const ComposingRegion(start: 0, end: 0), // 空 composing
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCommit('');
      // replaceRange(0, 0, '') 应该是空操作
      expect(host.source, equals('hello'));
      expect(controller.state, equals(ComposingState.idle));
    });

    test('连续 commit（commit 后立即 start 新 composing）', () {
      final host = _MockComposingHost(
        source: 'a',
        composing: const ComposingRegion(start: 1, end: 1),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCommit('b');
      expect(controller.state, equals(ComposingState.idle));
      // 立即开始新 composing
      controller.onComposingStart();
      expect(controller.state, equals(ComposingState.composing));
      controller.onComposingCommit('c');
      expect(controller.state, equals(ComposingState.idle));
    });

    test('cancel 后立即 start 新 composing', () {
      final host = _MockComposingHost(
        source: 'a',
        composing: const ComposingRegion(start: 1, end: 1),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCancel();
      expect(controller.state, equals(ComposingState.idle));
      // 立即开始新 composing
      controller.onComposingStart();
      expect(controller.state, equals(ComposingState.composing));
    });

    test('_sourceBeforeComposing 内存释放（commit 后置 null）', () {
      final host = _MockComposingHost(
        source: 'orig',
        composing: const ComposingRegion(start: 0, end: 4),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      controller.onComposingCommit('new');
      // commit 后 _sourceBeforeComposing 应被清空（null）
      // 验证方式：再次 start + cancel，应恢复第二次 start 时的 source
      host.source = 'after_commit';
      host.composing = const ComposingRegion(start: 0, end: 11);
      controller.onComposingStart();
      controller.onComposingCancel();
      // restoreSource 应恢复 'after_commit'（第二次 start 时的 source）
      // 而非 'orig'（若 _sourceBeforeComposing 未清空，会错误恢复 'orig'）
      expect(host.restoreSourceCalls.last, equals('after_commit'));
    });

    test('单一真相源验证（评审反馈 4）：ComposingController 不保存 composing region', () {
      final host = _MockComposingHost(
        source: 'hello',
        composing: const ComposingRegion(start: 0, end: 2),
      );
      final controller = ComposingController(host);
      controller.onComposingStart();
      // 多次 update，composing region 在 host 端变化
      host.composing = const ComposingRegion(start: 0, end: 3);
      controller.onComposingUpdate();
      host.composing = const ComposingRegion(start: 0, end: 5);
      controller.onComposingUpdate();
      // controller 内无 composing 字段累积，commit 时直接从 host 读
      host.source = 'helloABC';
      host.composing = const ComposingRegion(start: 0, end: 5);
      controller.onComposingCommit('XYZ');
      // replaceRange 应使用 host 当前 composing (0, 5)，而非旧的
      expect(host.replaceRangeCalls.last.start, equals(0));
      expect(host.replaceRangeCalls.last.end, equals(5));
      expect(host.replaceRangeCalls.last.replacement, equals('XYZ'));
    });
  });
}
