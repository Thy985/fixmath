import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/parser/markdown_parser.dart';
import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/domain/services/exporters/text_exporter.dart';

void main() {
  group('行内样式解析（ADR-0004 优先级）', () {
    test('解析行内代码 `code`', () {
      final inlines = MarkdownParser.parseInline('这是 `code` 文本');
      expect(inlines.whereType<InlineCodeElement>().length, 1);
      final code = inlines.whereType<InlineCodeElement>().first;
      expect(code.code, 'code');
    });

    test('解析链接 [text](url)', () {
      final inlines = MarkdownParser.parseInline('访问 [Google](https://g.com) 链接');
      final links = inlines.whereType<LinkElement>().toList();
      expect(links.length, 1);
      expect(links.first.text, 'Google');
      expect(links.first.url, 'https://g.com');
    });

    test('解析图片 ![alt](url)', () {
      final inlines = MarkdownParser.parseInline('![alt](http://x/y.png)');
      final imgs = inlines.whereType<ImageElement>().toList();
      expect(imgs.length, 1);
      expect(imgs.first.alt, 'alt');
      expect(imgs.first.url, 'http://x/y.png');
    });

    test('解析星号斜体 *text*', () {
      final inlines = MarkdownParser.parseInline('这是 *斜体* 文本');
      final italics = inlines.whereType<ItalicElement>().toList();
      expect(italics.length, 1);
      final child = italics.first.children.whereType<TextElement>().first;
      expect(child.text, '斜体');
    });

    test('解析下划线斜体 _text_', () {
      final inlines = MarkdownParser.parseInline('这是 _斜体_ 文本');
      final italics = inlines.whereType<ItalicElement>().toList();
      expect(italics.length, 1);
      final child = italics.first.children.whereType<TextElement>().first;
      expect(child.text, '斜体');
    });

    test('解析删除线 ~~text~~', () {
      final inlines = MarkdownParser.parseInline('这是 ~~删除线~~ 文本');
      final strikes = inlines.whereType<StrikethroughElement>().toList();
      expect(strikes.length, 1);
      final child = strikes.first.children.whereType<TextElement>().first;
      expect(child.text, '删除线');
    });

    test('加粗内可嵌套斜体', () {
      final inlines = MarkdownParser.parseInline('**粗 *斜* 体**');
      final bolds = inlines.whereType<BoldElement>().toList();
      expect(bolds.length, 1);
      expect(bolds.first.children.whereType<ItalicElement>().length, 1);
    });

    test('优先级：图片先于链接', () {
      final inlines = MarkdownParser.parseInline('![a](b) 和 [c](d)');
      expect(inlines.first, isA<ImageElement>());
      expect(inlines.whereType<LinkElement>().length, 1);
    });

    test('行内代码内不解析加粗', () {
      final inlines = MarkdownParser.parseInline('`**not bold**`');
      final codes = inlines.whereType<InlineCodeElement>().toList();
      expect(codes.length, 1);
      expect(codes.first.code, '**not bold**');
    });

    test('纯文本回退为单个 TextElement', () {
      final inlines = MarkdownParser.parseInline('普通文本');
      expect(inlines.length, 1);
      expect(inlines.first, isA<TextElement>());
    });
  });

  group('块级扩展解析', () {
    test('解析未勾选任务列表 - [ ]', () {
      final elements = MarkdownParser.parse('- [ ] 待办事项');
      final tasks = elements.whereType<TaskListItemElement>().toList();
      expect(tasks.length, 1);
      expect(tasks.first.checked, false);
      expect(
        tasks.first.children.whereType<TextElement>().first.text,
        '待办事项',
      );
    });

    test('解析已勾选任务列表 - [x]', () {
      final elements = MarkdownParser.parse('- [x] 已完成');
      final tasks = elements.whereType<TaskListItemElement>().toList();
      expect(tasks.length, 1);
      expect(tasks.first.checked, true);
    });

    test('任务列表支持嵌套缩进', () {
      final elements = MarkdownParser.parse('  - [ ] 子任务');
      final tasks = elements.whereType<TaskListItemElement>().toList();
      expect(tasks.length, 1);
      expect(tasks.first.indent, 1);
    });

    test('解析水平分割线 ---', () {
      final elements = MarkdownParser.parse('---');
      expect(elements.whereType<HorizontalRuleElement>().length, 1);
    });

    test('水平线不与无序列表混淆', () {
      final elements = MarkdownParser.parse('- 普通列表项');
      expect(elements.whereType<TaskListItemElement>().isEmpty, true);
      expect(elements.whereType<ListElement>().length, 1);
    });

    test('水平线不与标题混淆', () {
      final elements = MarkdownParser.parse('# 标题');
      expect(elements.whereType<HorizontalRuleElement>().isEmpty, true);
    });
  });

  group('TextExporter 行内/块级一致性', () {
    test('保留行内代码与链接标记', () async {
      final md = '普通 **粗** *斜* `code` [链接](http://x)';
      final bytes = await TextExporter.export(md);
      final txt = utf8.decode(bytes);
      expect(txt, contains('`code`'));
      expect(txt, contains('[链接](http://x)'));
    });

    test('导出任务列表与水平线', () async {
      final md = '- [ ] 待办\n- [x] 完成\n\n---';
      final bytes = await TextExporter.export(md);
      final txt = utf8.decode(bytes);
      expect(txt, contains('- [ ] 待办'));
      expect(txt, contains('- [x] 完成'));
      expect(txt, contains('---'));
    });
  });
}
