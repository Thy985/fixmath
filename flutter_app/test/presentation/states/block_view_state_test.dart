/// R3 BlockViewState 不变性单元测试。
///
/// 落地 PR 评审 R3（Phase 2.9 PR review）+ Phase 2.9 Task Contract §5.1。
///
/// **覆盖范围**：
/// - [BlockViewState.copyWith] 默认值（不传参保持原值）
/// - [BlockViewState.copyWith] 显式传 null（_sentinel 模式区分"未传"和"传 null"）
/// - [BlockViewState.clearComposing] 清空 composing region 不影响其他字段
/// - [BlockViewState] 是 @immutable（运行时验证）
/// - [RenderMode] 默认值 + 切换
library;

import 'package:flutter/painting.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/presentation/states/block_view_state.dart';

void main() {
  group('R3 BlockViewState copyWith 不变性', () {
    test('默认构造：isFocused=false, mode=rendered, selection=null, composing=null', () {
      const state = BlockViewState(id: BlockId(1));
      expect(state.id, equals(const BlockId(1)));
      expect(state.isFocused, isFalse);
      expect(state.mode, equals(RenderMode.rendered));
      expect(state.selection, isNull);
      expect(state.composingRegion, isNull);
      expect(state.isEditing, isFalse,
          reason: 'rendered 模式下 isEditing 应为 false');
    });

    test('copyWith 不传任何参数：返回等价实例（仅 id 一致）', () {
      const original = BlockViewState(
        id: BlockId(1),
        isFocused: true,
        mode: RenderMode.editing,
      );
      final copied = original.copyWith();
      expect(copied.id, equals(const BlockId(1)));
      expect(copied.isFocused, isTrue);
      expect(copied.mode, equals(RenderMode.editing));
    });

    test('copyWith 部分更新：仅传 isFocused', () {
      const original = BlockViewState(id: BlockId(1));
      final updated = original.copyWith(isFocused: true);
      expect(updated.isFocused, isTrue);
      expect(updated.mode, equals(RenderMode.rendered),
          reason: '未传 mode 应保持原值');
    });

    test('copyWith 部分更新：仅传 mode', () {
      const original = BlockViewState(id: BlockId(1));
      final updated = original.copyWith(mode: RenderMode.editing);
      expect(updated.mode, equals(RenderMode.editing));
      expect(updated.isFocused, isFalse,
          reason: '未传 isFocused 应保持原值');
      expect(updated.isEditing, isTrue);
    });

    test('copyWith 显式传 composingRegion: null（清除 composing）', () {
      // 先设置 composingRegion 为非 null
      const composing = ComposingRegion(start: 0, end: 3);
      const original = BlockViewState(
        id: BlockId(1),
        composingRegion: composing,
      );
      expect(original.composingRegion, isNotNull);

      // 显式传 null 应清除 composing
      final updated = original.copyWith(composingRegion: null);
      expect(updated.composingRegion, isNull,
          reason: '显式传 null 应清除 composingRegion（_sentinel 模式）');
    });

    test('copyWith 不传 composingRegion：保持原值（_sentinel 区分）', () {
      const composing = ComposingRegion(start: 0, end: 3);
      const original = BlockViewState(
        id: BlockId(1),
        composingRegion: composing,
      );

      // 调用 copyWith 不传 composingRegion
      final updated = original.copyWith(isFocused: true);
      expect(updated.composingRegion, equals(composing),
          reason: '未传 composingRegion 应保持原值（_sentinel 模式关键）');
    });

    test('copyWith 显式传 composingRegion: null 后再 copyWith 不传保持 null', () {
      const original = BlockViewState(
        id: BlockId(1),
        composingRegion: ComposingRegion(start: 0, end: 3),
      );
      // 第一次：显式传 null
      final cleared = original.copyWith(composingRegion: null);
      expect(cleared.composingRegion, isNull);
      // 第二次：不传 composingRegion，应保持 null（不是恢复原值）
      final updated = cleared.copyWith(isFocused: true);
      expect(updated.composingRegion, isNull,
          reason: '_sentinel 读取的是当前对象的 composingRegion（已为 null）');
    });

    test('copyWith 传 selection', () {
      const original = BlockViewState(id: BlockId(1));
      const selection = TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      final updated = original.copyWith(selection: selection);
      expect(updated.selection, equals(selection));
    });

    test('原实例不被 copyWith 修改（immutable）', () {
      const original = BlockViewState(
        id: BlockId(1),
        isFocused: false,
        mode: RenderMode.rendered,
      );
      // 多次 copyWith 不影响原对象
      original.copyWith(isFocused: true);
      original.copyWith(mode: RenderMode.editing);
      original.copyWith(composingRegion: null);

      expect(original.isFocused, isFalse,
          reason: 'immutable：原对象不应被修改');
      expect(original.mode, equals(RenderMode.rendered));
      expect(original.composingRegion, isNull);
    });
  });

  group('R3 BlockViewState clearComposing', () {
    test('clearComposing 清空 composingRegion', () {
      const original = BlockViewState(
        id: BlockId(1),
        composingRegion: ComposingRegion(start: 0, end: 3),
      );
      expect(original.composingRegion, isNotNull);

      final cleared = original.clearComposing();
      expect(cleared.composingRegion, isNull,
          reason: 'clearComposing 后 composingRegion 应为 null');
    });

    test('clearComposing 不影响其他字段（isFocused / mode / selection）', () {
      const selection = TextSelection(baseOffset: 1, extentOffset: 4);
      const original = BlockViewState(
        id: BlockId(42),
        isFocused: true,
        mode: RenderMode.editing,
        selection: selection,
        composingRegion: ComposingRegion(start: 0, end: 2),
      );

      final cleared = original.clearComposing();
      expect(cleared.id, equals(const BlockId(42)));
      expect(cleared.isFocused, isTrue);
      expect(cleared.mode, equals(RenderMode.editing));
      expect(cleared.selection, equals(selection));
      expect(cleared.composingRegion, isNull);
    });

    test('clearComposing 在已是 null 时保持 null', () {
      const original = BlockViewState(id: BlockId(1));
      expect(original.composingRegion, isNull);

      final cleared = original.clearComposing();
      expect(cleared.composingRegion, isNull);
    });
  });

  group('R3 BlockViewState immutable 标注', () {
    test('BlockViewState 类被 @immutable 标注', () {
      // 静态验证：检查类声明上有 @immutable 元数据
      // 通过 SMirror 无法直接获取 annotation，改为通过类行为验证：
      // immutable 类的字段必须 final（已由编译期保证），并通过 toString 验证状态完整
      const state = BlockViewState(id: BlockId(1));
      expect(state.toString(), contains('BlockViewState'));
      expect(state.toString(), contains('id=BlockId(1)'));
      expect(state.toString(), contains('isFocused=false'));
      expect(state.toString(), contains('mode=RenderMode.rendered'));
    });

    test('BlockViewState 多次 copyWith 链式调用保持 immutable 语义', () {
      const original = BlockViewState(id: BlockId(1));
      // 链式 copyWith 应返回新实例，不修改原对象
      final chained = original
          .copyWith(isFocused: true)
          .copyWith(mode: RenderMode.editing)
          .copyWith(selection: const TextSelection(baseOffset: 0, extentOffset: 3));

      expect(original.isFocused, isFalse,
          reason: '原对象不应被链式 copyWith 修改');
      expect(original.mode, equals(RenderMode.rendered));
      expect(original.selection, isNull);

      expect(chained.isFocused, isTrue);
      expect(chained.mode, equals(RenderMode.editing));
      expect(chained.selection, isNotNull);
    });
  });

  group('R3 RenderMode 枚举', () {
    test('RenderMode.rendered 与 .editing 是两个不同值', () {
      expect(RenderMode.rendered, isNot(equals(RenderMode.editing)));
      expect(RenderMode.values.length, equals(2));
    });

    test('BlockViewState.isEditing getter 与 mode 联动', () {
      const rendered = BlockViewState(id: BlockId(1), mode: RenderMode.rendered);
      const editing = BlockViewState(id: BlockId(1), mode: RenderMode.editing);
      expect(rendered.isEditing, isFalse);
      expect(editing.isEditing, isTrue);
    });
  });
}
