/// TC-EDIT-4: BlockTypeDetector 单元测试。
///
/// 对应 ADR-0007 §4.3（Markdown 快捷映射规则表）+ §Phase 2.3。
///
/// 7 条规则（taskListItem 先于 listItem）：
/// 1. heading: `^#{1,6}\s`
/// 2. taskListItem: `^\s*[-*+]\s\[(?: |x|X)\]\s`
/// 3. listItem unordered: `^\s*[-*+]\s`
/// 4. listItem ordered: `^\s*\d+\.\s`
/// 5. code: `^```+\S*`
/// 6. blockquote: `^>\s`
/// 7. horizontalRule: `^\s*(-{3,}|\*{3,}|_{3,})\s*$`
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_type_detector.dart';
import 'package:formula_fix/core/editing/block_types.dart';

void main() {
  group('TC-EDIT-4.1 规则正样本', () {
    test('heading: `# Title`', () {
      expect(detectBlockType('# Title'), equals(BlockType.heading));
    });

    test('heading: `###### Deep`（level 6 上限）', () {
      expect(detectBlockType('###### Deep'), equals(BlockType.heading));
    });

    test('taskListItem unchecked', () {
      expect(detectBlockType('- [ ] todo'), equals(BlockType.taskListItem));
    });

    test('taskListItem checked lowercase x', () {
      expect(detectBlockType('- [x] done'), equals(BlockType.taskListItem));
    });

    test('taskListItem checked uppercase X', () {
      expect(detectBlockType('- [X] done'), equals(BlockType.taskListItem));
    });

    test('taskListItem with `*` marker', () {
      expect(detectBlockType('* [ ] todo'), equals(BlockType.taskListItem));
    });

    test('taskListItem with `+` marker', () {
      expect(detectBlockType('+ [x] done'), equals(BlockType.taskListItem));
    });

    test('listItem unordered `- `', () {
      expect(detectBlockType('- item'), equals(BlockType.listItem));
    });

    test('listItem unordered `* `', () {
      expect(detectBlockType('* item'), equals(BlockType.listItem));
    });

    test('listItem unordered `+ `', () {
      expect(detectBlockType('+ item'), equals(BlockType.listItem));
    });

    test('listItem ordered `1. `', () {
      expect(detectBlockType('1. first'), equals(BlockType.listItem));
    });

    test('listItem ordered `99. `', () {
      expect(detectBlockType('99. item'), equals(BlockType.listItem));
    });

    test('listItem with indent', () {
      expect(detectBlockType('  - nested'), equals(BlockType.listItem));
    });

    test('code with language', () {
      expect(detectBlockType('```dart\ncode\n```'), equals(BlockType.code));
    });

    test('code without language', () {
      expect(detectBlockType('```\ncode\n```'), equals(BlockType.code));
    });

    test('code with multiple backticks', () {
      expect(detectBlockType('````\ncode\n````'), equals(BlockType.code));
    });

    test('blockquote', () {
      expect(detectBlockType('> quote'), equals(BlockType.blockquote));
    });

    test('horizontalRule `---`', () {
      expect(detectBlockType('---'), equals(BlockType.horizontalRule));
    });

    test('horizontalRule `***`', () {
      expect(detectBlockType('***'), equals(BlockType.horizontalRule));
    });

    test('horizontalRule `___`', () {
      expect(detectBlockType('___'), equals(BlockType.horizontalRule));
    });

    test('horizontalRule 4+ dashes', () {
      expect(detectBlockType('----'), equals(BlockType.horizontalRule));
    });

    test('horizontalRule with leading whitespace', () {
      expect(detectBlockType('  ---'), equals(BlockType.horizontalRule));
    });
  });

  group('TC-EDIT-4.2 规则负样本（返回 paragraph）', () {
    test('纯文本', () {
      expect(detectBlockType('hello world'), equals(BlockType.paragraph));
    });

    test('空字符串', () {
      expect(detectBlockType(''), equals(BlockType.paragraph));
    });

    test('无 `# ` 空格的 heading', () {
      // `#Title` 没有 space，不算 heading
      expect(detectBlockType('#Title'), equals(BlockType.paragraph));
    });

    test('7 个 `#` 超出 level 6 上限', () {
      // `#######` 不算 heading（7 个 #）
      expect(detectBlockType('####### too deep'), equals(BlockType.paragraph));
    });

    test('incomplete taskListItem', () {
      // `- [ ]` 后无内容，无匹配规则，但仍是 taskListItem 前缀
      // 实际：`- [ ]` 无 `\s+` 后缀，不匹配 taskListItem 规则，但匹配 listItem
      expect(detectBlockType('- [ ]'), equals(BlockType.listItem));
    });

    test('`-` 无空格', () {
      // `-item` 不匹配 `- ` 规则
      expect(detectBlockType('-item'), equals(BlockType.paragraph));
    });

    test('`1.` 无空格', () {
      // `1.item` 不匹配 `1. ` 规则
      expect(detectBlockType('1.item'), equals(BlockType.paragraph));
    });

    test('单 `>` 无空格', () {
      // `>quote` 不匹配 `> ` 规则
      expect(detectBlockType('>quote'), equals(BlockType.paragraph));
    });

    test('2 个 dashes', () {
      // `--` 不匹配 `-{3,}` 规则
      expect(detectBlockType('--'), equals(BlockType.paragraph));
    });

    test('backtick 单个', () {
      // 单 backtick 不匹配 ``` 规则
      expect(detectBlockType('`not code`'), equals(BlockType.paragraph));
    });
  });

  group('TC-EDIT-4.3 优先级与边界', () {
    test('taskListItem 优先于 listItem（`- [ ]` 不被误判为普通 list item）', () {
      // 必须返回 taskListItem 而非 listItem
      expect(detectBlockType('- [ ] task'), equals(BlockType.taskListItem));
      expect(detectBlockType('- [x] done'), equals(BlockType.taskListItem));
    });

    test('`- [xy]` 非法 taskListItem → listItem', () {
      // `[xy]` 非单字符 `[ x]`，不匹配 taskListItem 规则
      // 但 `- ` 仍匹配 listItem 规则
      expect(detectBlockType('- [xy] invalid'), equals(BlockType.listItem));
    });

    test('mermaid code fence 仍判定为 code（mermaid 区分在 toElement 内部）', () {
      // detector 不区分 mermaid 与 code，统一返回 code
      expect(detectBlockType('```mermaid\ngraph\n```'), equals(BlockType.code));
    });

    test('heading 优先于 paragraph（含 `#` 但有其他 inline）', () {
      // `# Hello **world**` 仍判为 heading
      expect(detectBlockType('# Hello **world**'), equals(BlockType.heading));
    });

    test('返回类型为 BlockType（非 BlockType?）', () {
      // detectBlockType 永不返回 null
      final result = detectBlockType('anything');
      expect(result, isA<BlockType>());
    });

    test('永远不会返回 null（编译期保证）', () {
      // 此测试验证 detectBlockType 返回类型为 BlockType 而非 BlockType?
      // 若改为 BlockType? 则此行编译错误
      // ignore: unused_local_variable
      final BlockType ignored1 = detectBlockType('');
      // ignore: unused_local_variable
      final BlockType ignored2 = detectBlockType('random text');
      expect(ignored1, isA<BlockType>());
      expect(ignored2, isA<BlockType>());
    });
  });
}
