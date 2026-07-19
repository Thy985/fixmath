/// TC-EDIT-3.5 + 3.6: InlineSerializer 单元测试。
///
/// 对应 ADR-0007 §Phase 2.3：BlockEditor.fromElement 内部使用的 InlineSerializer。
/// 覆盖 8 类 InlineElement 序列化 + 嵌套结构。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_serializer.dart';
import 'package:formula_fix/data/models/document.dart';

void main() {
  group('TC-EDIT-3.5 InlineSerializer 8 类', () {
    test('TextElement', () {
      const elements = [TextElement('hello')];
      expect(InlineSerializer.serialize(elements), equals('hello'));
    });

    test('FormulaElement inline', () {
      const elements = [FormulaElement(latex: r'\frac{a}{b}', displayMode: false)];
      expect(InlineSerializer.serialize(elements), equals(r'$\frac{a}{b}$'));
    });

    test('FormulaElement display', () {
      const elements = [FormulaElement(latex: r'\sum', displayMode: true)];
      expect(InlineSerializer.serialize(elements), equals(r'$$\sum$$'));
    });

    test('BoldElement', () {
      const elements = [BoldElement(children: [TextElement('hi')])];
      expect(InlineSerializer.serialize(elements), equals('**hi**'));
    });

    test('ItalicElement', () {
      const elements = [ItalicElement(children: [TextElement('hi')])];
      expect(InlineSerializer.serialize(elements), equals('*hi*'));
    });

    test('StrikethroughElement', () {
      const elements = [StrikethroughElement(children: [TextElement('hi')])];
      expect(InlineSerializer.serialize(elements), equals('~~hi~~'));
    });

    test('InlineCodeElement', () {
      const elements = [InlineCodeElement('code')];
      expect(InlineSerializer.serialize(elements), equals('`code`'));
    });

    test('LinkElement', () {
      const elements = [LinkElement(text: 't', url: 'u')];
      expect(InlineSerializer.serialize(elements), equals('[t](u)'));
    });

    test('ImageElement', () {
      const elements = [ImageElement(alt: 'a', url: 'u')];
      expect(InlineSerializer.serialize(elements), equals('![a](u)'));
    });

    test('Empty list returns empty string', () {
      expect(InlineSerializer.serialize([]), equals(''));
    });
  });

  group('TC-EDIT-3.6 InlineSerializer 嵌套', () {
    test('Bold inside Italic', () {
      const elements = [
        ItalicElement(children: [
          TextElement('a '),
          BoldElement(children: [TextElement('b')]),
        ]),
      ];
      expect(InlineSerializer.serialize(elements), equals('*a **b***'));
    });

    test('Formula inside Bold', () {
      const elements = [
        BoldElement(children: [
          FormulaElement(latex: r'\pi', displayMode: false),
        ]),
      ];
      expect(InlineSerializer.serialize(elements), equals(r'**$\pi$**'));
    });

    test('Multiple inline elements joined', () {
      const elements = [
        TextElement('hello '),
        BoldElement(children: [TextElement('world')]),
        TextElement(' end'),
      ];
      expect(InlineSerializer.serialize(elements), equals('hello **world** end'));
    });
  });
}
