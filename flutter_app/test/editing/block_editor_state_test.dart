/// TC-EDIT-2: BlockEditor 状态机单元测试
///
/// 对应 ADR-0007 §1.4（双态切换）+ §1.6（error 态处理）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_editor_state.dart';

void main() {
  group('TC-EDIT-2.1 合法转换路径', () {
    test('blurred + focus → focusing', () {
      expect(
        transitionBlockEditorState(
          current: BlockEditorState.blurred,
          event: BlockEditorEvent.focus,
        ),
        equals(BlockEditorState.focusing),
      );
    });

    test('focusing + focusComplete → focused', () {
      expect(
        transitionBlockEditorState(
          current: BlockEditorState.focusing,
          event: BlockEditorEvent.focusComplete,
        ),
        equals(BlockEditorState.focused),
      );
    });

    test('focused + blur → blurring', () {
      expect(
        transitionBlockEditorState(
          current: BlockEditorState.focused,
          event: BlockEditorEvent.blur,
        ),
        equals(BlockEditorState.blurring),
      );
    });

    test('blurring + blurComplete → blurred', () {
      expect(
        transitionBlockEditorState(
          current: BlockEditorState.blurring,
          event: BlockEditorEvent.blurComplete,
        ),
        equals(BlockEditorState.blurred),
      );
    });

    test('blurring + blurFailed → error', () {
      expect(
        transitionBlockEditorState(
          current: BlockEditorState.blurring,
          event: BlockEditorEvent.blurFailed,
        ),
        equals(BlockEditorState.error),
      );
    });

    test('error + resumeEditing → focused（保留编辑态）', () {
      expect(
        transitionBlockEditorState(
          current: BlockEditorState.error,
          event: BlockEditorEvent.resumeEditing,
        ),
        equals(BlockEditorState.focused),
      );
    });

    test('error + discardError → blurred（放弃编辑态）', () {
      expect(
        transitionBlockEditorState(
          current: BlockEditorState.error,
          event: BlockEditorEvent.discardError,
        ),
        equals(BlockEditorState.blurred),
      );
    });
  });

  group('TC-EDIT-2.2 完整生命周期（Happy path）', () {
    test('blurred → focusing → focused → blurring → blurred', () {
      var state = BlockEditorState.blurred;
      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.focus,
      );
      expect(state, equals(BlockEditorState.focusing));

      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.focusComplete,
      );
      expect(state, equals(BlockEditorState.focused));

      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.blur,
      );
      expect(state, equals(BlockEditorState.blurring));

      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.blurComplete,
      );
      expect(state, equals(BlockEditorState.blurred));
    });
  });

  group('TC-EDIT-2.3 error 态生命周期', () {
    test('focused → blurring → error → focused（用户继续编辑）', () {
      var state = BlockEditorState.focused;
      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.blur,
      );
      expect(state, equals(BlockEditorState.blurring));

      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.blurFailed,
      );
      expect(state, equals(BlockEditorState.error));

      // 用户继续编辑，回到 focused
      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.resumeEditing,
      );
      expect(state, equals(BlockEditorState.focused));
    });

    test('focused → blurring → error → blurred（用户放弃）', () {
      var state = BlockEditorState.focused;
      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.blur,
      );
      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.blurFailed,
      );
      expect(state, equals(BlockEditorState.error));

      // 用户放弃，回到 blurred
      state = transitionBlockEditorState(
        current: state,
        event: BlockEditorEvent.discardError,
      );
      expect(state, equals(BlockEditorState.blurred));
    });
  });

  group('TC-EDIT-2.4 非法转换被拒绝', () {
    test('blurred + focusComplete 非法', () {
      expect(
        () => transitionBlockEditorState(
          current: BlockEditorState.blurred,
          event: BlockEditorEvent.focusComplete,
        ),
        throwsStateError,
      );
    });

    test('blurred + blur 非法（已在 blurred）', () {
      expect(
        () => transitionBlockEditorState(
          current: BlockEditorState.blurred,
          event: BlockEditorEvent.blur,
        ),
        throwsStateError,
      );
    });

    test('blurred + blurFailed 非法', () {
      expect(
        () => transitionBlockEditorState(
          current: BlockEditorState.blurred,
          event: BlockEditorEvent.blurFailed,
        ),
        throwsStateError,
      );
    });

    test('focused + focus 非法（已在 focused）', () {
      expect(
        () => transitionBlockEditorState(
          current: BlockEditorState.focused,
          event: BlockEditorEvent.focus,
        ),
        throwsStateError,
      );
    });

    test('focused + blurComplete 非法（必须先 blur → blurring）', () {
      expect(
        () => transitionBlockEditorState(
          current: BlockEditorState.focused,
          event: BlockEditorEvent.blurComplete,
        ),
        throwsStateError,
      );
    });

    test('error + focus 非法（必须用 resumeEditing 或 discardError）', () {
      expect(
        () => transitionBlockEditorState(
          current: BlockEditorState.error,
          event: BlockEditorEvent.focus,
        ),
        throwsStateError,
      );
    });

    test('error + blur 非法（已在 error，不能直接 blur）', () {
      expect(
        () => transitionBlockEditorState(
          current: BlockEditorState.error,
          event: BlockEditorEvent.blur,
        ),
        throwsStateError,
      );
    });
  });

  group('TC-EDIT-2.5 isValidTransition 守门', () {
    test('合法转换返回 true', () {
      expect(
        isValidTransition(
          current: BlockEditorState.blurred,
          event: BlockEditorEvent.focus,
        ),
        isTrue,
      );
    });

    test('非法转换返回 false', () {
      expect(
        isValidTransition(
          current: BlockEditorState.blurred,
          event: BlockEditorEvent.focusComplete,
        ),
        isFalse,
      );
    });

    test('全部合法转换枚举', () {
      final legalTransitions = <(BlockEditorState, BlockEditorEvent)>[
        (BlockEditorState.blurred, BlockEditorEvent.focus),
        (BlockEditorState.focusing, BlockEditorEvent.focusComplete),
        (BlockEditorState.focused, BlockEditorEvent.blur),
        (BlockEditorState.blurring, BlockEditorEvent.blurComplete),
        (BlockEditorState.blurring, BlockEditorEvent.blurFailed),
        (BlockEditorState.error, BlockEditorEvent.resumeEditing),
        (BlockEditorState.error, BlockEditorEvent.discardError),
      ];
      for (final (state, event) in legalTransitions) {
        expect(
          isValidTransition(current: state, event: event),
          isTrue,
          reason: '$state + $event should be legal',
        );
      }
    });

    test('全部非法转换枚举（7 个事件 × 5 个状态 - 7 个合法 = 28 个非法）', () {
      const allStates = BlockEditorState.values;
      const allEvents = BlockEditorEvent.values;
      final legalTransitions = <(BlockEditorState, BlockEditorEvent)>{
        (BlockEditorState.blurred, BlockEditorEvent.focus),
        (BlockEditorState.focusing, BlockEditorEvent.focusComplete),
        (BlockEditorState.focused, BlockEditorEvent.blur),
        (BlockEditorState.blurring, BlockEditorEvent.blurComplete),
        (BlockEditorState.blurring, BlockEditorEvent.blurFailed),
        (BlockEditorState.error, BlockEditorEvent.resumeEditing),
        (BlockEditorState.error, BlockEditorEvent.discardError),
      };
      var illegalCount = 0;
      for (final state in allStates) {
        for (final event in allEvents) {
          if (!legalTransitions.contains((state, event))) {
            expect(
              isValidTransition(current: state, event: event),
              isFalse,
              reason: '$state + $event should be illegal',
            );
            illegalCount++;
          }
        }
      }
      expect(illegalCount, equals(28)); // 5 * 7 - 7 = 28
    });
  });
}
