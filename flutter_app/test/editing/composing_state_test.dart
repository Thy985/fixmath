/// TC-EDIT-5.1: ComposingState 状态机转换单元测试。
///
/// 对应 ADR-0007 §3.2 + Phase 2.5 Task Contract §4.1 评审反馈 1
///（composing state self-transition 允许）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/composing_state.dart';

void main() {
  group('TC-EDIT-5.1 状态机转换', () {
    test('idle + start → composing', () {
      expect(
        transitionComposingState(
          current: ComposingState.idle,
          event: ComposingEvent.start,
        ),
        equals(ComposingState.composing),
      );
    });

    test('composing + update → composing（self-transition，评审反馈 1）', () {
      expect(
        transitionComposingState(
          current: ComposingState.composing,
          event: ComposingEvent.update,
        ),
        equals(ComposingState.composing),
      );
    });

    test('composing + commit → committing → idle', () {
      var state = transitionComposingState(
        current: ComposingState.composing,
        event: ComposingEvent.commit,
      );
      expect(state, equals(ComposingState.committing));
      state = transitionComposingState(
        current: state,
        event: ComposingEvent.commitComplete,
      );
      expect(state, equals(ComposingState.idle));
    });

    test('composing + cancel → cancelling → idle', () {
      var state = transitionComposingState(
        current: ComposingState.composing,
        event: ComposingEvent.cancel,
      );
      expect(state, equals(ComposingState.cancelling));
      state = transitionComposingState(
        current: state,
        event: ComposingEvent.cancelComplete,
      );
      expect(state, equals(ComposingState.idle));
    });

    test('committing + commitComplete → idle（合法完成转换）', () {
      expect(
        transitionComposingState(
          current: ComposingState.committing,
          event: ComposingEvent.commitComplete,
        ),
        equals(ComposingState.idle),
      );
    });

    test('cancelling + cancelComplete → idle（合法完成转换）', () {
      expect(
        transitionComposingState(
          current: ComposingState.cancelling,
          event: ComposingEvent.cancelComplete,
        ),
        equals(ComposingState.idle),
      );
    });

    test('非法：idle + update 抛 StateError', () {
      expect(
        () => transitionComposingState(
          current: ComposingState.idle,
          event: ComposingEvent.update,
        ),
        throwsStateError,
      );
    });

    test('非法：idle + commit 抛 StateError', () {
      expect(
        () => transitionComposingState(
          current: ComposingState.idle,
          event: ComposingEvent.commit,
        ),
        throwsStateError,
      );
    });

    test('非法：idle + cancel 抛 StateError', () {
      expect(
        () => transitionComposingState(
          current: ComposingState.idle,
          event: ComposingEvent.cancel,
        ),
        throwsStateError,
      );
    });

    test('非法：composing + commitComplete 抛 StateError', () {
      expect(
        () => transitionComposingState(
          current: ComposingState.composing,
          event: ComposingEvent.commitComplete,
        ),
        throwsStateError,
      );
    });

    test('非法：committing + start 抛 StateError', () {
      expect(
        () => transitionComposingState(
          current: ComposingState.committing,
          event: ComposingEvent.start,
        ),
        throwsStateError,
      );
    });
  });
}
