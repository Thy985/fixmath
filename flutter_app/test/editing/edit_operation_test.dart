/// TC-EDIT-6.1 EditOperation apply/revert 幂等性测试 - TextOperation 部分。
///
/// 验证 TextOperation：
/// - apply + revert → editor 状态恢复
/// - 幂等性：apply-revert-apply-revert 循环
/// - 边界：空 source / emoji UTF-16 offset / 非法 BlockId
///
/// 详见 Phase 2.6 Task Contract §4.1 TC-EDIT-6.1。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/edit_operation.dart';

import 'helpers/mock_document_editor.dart';

void main() {
  group('TC-EDIT-6.1 TextOperation apply/revert 幂等性', () {
    group('基本 apply + revert', () {
      test('纯插入：offset=0, deleted="", inserted="hello"', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('');

        final op = TextOperation(
          blockId: id,
          offset: 0,
          deleted: '',
          inserted: 'hello',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('hello'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals(''));
      });

      test('纯删除：offset=0, deleted="hello", inserted=""', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 0,
          deleted: 'hello',
          inserted: '',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals(''));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('替换：offset=0, deleted="abc", inserted="xyz"', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('abcdef');

        final op = TextOperation(
          blockId: id,
          offset: 0,
          deleted: 'abc',
          inserted: 'xyz',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('xyzdef'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('abcdef'));
      });

      test('中间插入：offset=3, deleted="", inserted="-"', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 3,
          deleted: '',
          inserted: '-',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('hel-lo'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('中间删除：offset=2, deleted="ll", inserted=""', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 2,
          deleted: 'll',
          inserted: '',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('heo'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('中间替换：offset=2, deleted="ll", inserted="LL"', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 2,
          deleted: 'll',
          inserted: 'LL',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('heLLo'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('hello'));
      });
    });

    group('幂等性：apply-revert-apply-revert 循环', () {
      test('2 轮循环状态一致', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('abc');

        final op = TextOperation(
          blockId: id,
          offset: 3,
          deleted: '',
          inserted: 'def',
        );

        // 第 1 轮
        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('abcdef'));
        op.revert(editor);
        expect(editor.sourceOf(id), equals('abc'));

        // 第 2 轮
        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('abcdef'));
        op.revert(editor);
        expect(editor.sourceOf(id), equals('abc'));
      });

      test('5 轮循环状态一致', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('');

        final op = TextOperation(
          blockId: id,
          offset: 0,
          deleted: '',
          inserted: 'x',
        );

        for (var i = 0; i < 5; i++) {
          expect(op.apply(editor), isTrue);
          expect(editor.sourceOf(id), equals('x'));
          op.revert(editor);
          expect(editor.sourceOf(id), equals(''));
        }
      });
    });

    group('边界与错误处理', () {
      test('空 deleted + 空 inserted = 空操作', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 2,
          deleted: '',
          inserted: '',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('hello'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('hello'));
      });

      test('含 UTF-8 emoji（1 字符 = 1 UTF-16 code unit 之内）', () {
        // 注：UTF-16 code unit 是 Dart String 长度单位
        // "你好" 在 Dart String.length == 2（每个汉字 1 UTF-16 code unit）
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('你好');

        final op = TextOperation(
          blockId: id,
          offset: 1,
          deleted: '好',
          inserted: '吗',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('你吗'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('你好'));
      });

      test('含 surrogate pair emoji（4 字节 UTF-16）', () {
        // "😀" 在 Dart String.length == 2（surrogate pair）
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('😀😀');

        final op = TextOperation(
          blockId: id,
          offset: 2,  // 第 1 个 emoji 后（length=2）
          deleted: '😀',
          inserted: '😂',
        );

        expect(op.apply(editor), isTrue);
        expect(editor.sourceOf(id), equals('😀😂'));

        op.revert(editor);
        expect(editor.sourceOf(id), equals('😀😀'));
      });

      test('非法 BlockId → apply 返回 false', () {
        final editor = MockDocumentEditor();

        final op = TextOperation(
          blockId: BlockId(999),
          offset: 0,
          inserted: 'x',
        );

        expect(op.apply(editor), isFalse);
      });

      test('offset 越界 → apply 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 100,  // 越界
          deleted: '',
          inserted: 'x',
        );

        expect(op.apply(editor), isFalse);
      });

      test('deleted.length 越界 → apply 返回 false', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 0,
          deleted: 'hello world',  // 超出 source 长度
          inserted: 'x',
        );

        expect(op.apply(editor), isFalse);
      });
    });

    group('cachedIndex 优化', () {
      test('apply 后 cachedIndex 被填充', () {
        final editor = MockDocumentEditor();
        final id = editor.addParagraph('hello');

        final op = TextOperation(
          blockId: id,
          offset: 0,
          inserted: 'x',
        );

        expect(op.cachedIndex, isNull);
        op.apply(editor);
        expect(op.cachedIndex, isNotNull);
        expect(op.cachedIndex, equals(0));
      });

      test('revert 不依赖 cachedIndex（通过 BlockId 定位）', () {
        final editor = MockDocumentEditor();
        final id1 = editor.addParagraph('a');
        final id2 = editor.addParagraph('b');
        final id3 = editor.addParagraph('c');

        // 在 id2 上 apply
        final op = TextOperation(
          blockId: id2,
          offset: 1,
          inserted: 'X',
        );
        op.apply(editor);
        expect(editor.sourceOf(id2), equals('bX'));

        // 删除 id1（cachedIndex 会失效，但 revert 仍应正确工作）
        editor.removeBlock(id1);

        // revert id2 的 op（cachedIndex=1 现在已失效）
        op.revert(editor);
        expect(editor.sourceOf(id2), equals('b'));

        // id3 不受影响
        expect(editor.sourceOf(id3), equals('c'));
      });
    });
  });
}
