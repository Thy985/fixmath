import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/data/models/document.dart';
import 'package:formula_fix/domain/services/exporters/word_ooxml_builder.dart';

void main() {
  group('parseSvgViewBox', () {
    test('解析标准 viewBox', () {
      const svg = '<svg viewBox="0 0 200 100"></svg>';
      final dims = WordOoxmlBuilder.parseSvgViewBox(svg)!;
      expect(dims.width, 200);
      expect(dims.height, 100);
    });

    test('解析逗号分隔 viewBox', () {
      const svg = '<svg viewBox="0,0,300,150"></svg>';
      final dims = WordOoxmlBuilder.parseSvgViewBox(svg)!;
      expect(dims.width, 300);
      expect(dims.height, 150);
    });

    test('viewBox 缺失返回 null', () {
      const svg = '<svg width="100" height="50"></svg>';
      expect(WordOoxmlBuilder.parseSvgViewBox(svg), isNull);
    });

    test('viewBox 字段不全返回 null', () {
      const svg = '<svg viewBox="0 0 200"></svg>';
      expect(WordOoxmlBuilder.parseSvgViewBox(svg), isNull);
    });

    test('viewBox 含小数', () {
      const svg = '<svg viewBox="0 0 100.5 50.25"></svg>';
      final dims = WordOoxmlBuilder.parseSvgViewBox(svg)!;
      expect(dims.width, closeTo(100.5, 0.01));
      expect(dims.height, closeTo(50.25, 0.01));
    });
  });

  group('parseSvgDimensions', () {
    test('解析 width/height 属性', () {
      const svg = '<svg width="200" height="100"></svg>';
      final dims = WordOoxmlBuilder.parseSvgDimensions(svg)!;
      expect(dims.width, 200);
      expect(dims.height, 100);
    });

    test('解析带 px 单位', () {
      const svg = '<svg width="200px" height="100px"></svg>';
      final dims = WordOoxmlBuilder.parseSvgDimensions(svg)!;
      expect(dims.width, 200);
      expect(dims.height, 100);
    });

    test('width 缺失返回 null', () {
      const svg = '<svg height="100"></svg>';
      expect(WordOoxmlBuilder.parseSvgDimensions(svg), isNull);
    });
  });

  group('calcMermaidEmu', () {
    test('标准 2:1 viewBox 输出 6x3 inches', () {
      const svg = '<svg viewBox="0 0 200 100"></svg>';
      final (cx, cy) = WordOoxmlBuilder.calcMermaidEmu(svg);
      // maxWidth = 5486400, ratio = 2.0
      expect(cx, 5486400);
      expect(cy, 2743200);
    });

    test('viewBox 缺失回退 width/height', () {
      const svg = '<svg width="300" height="150"></svg>';
      final (cx, cy) = WordOoxmlBuilder.calcMermaidEmu(svg);
      expect(cx, 5486400);
      expect(cy, 2743200);
    });

    test('两者都缺失使用默认 2:1 比例', () {
      const svg = '<svg></svg>';
      final (cx, cy) = WordOoxmlBuilder.calcMermaidEmu(svg);
      expect(cx, 5486400);
      expect(cy, 2743200);
    });

    test('1:1 比例 (饼图)', () {
      const svg = '<svg viewBox="0 0 100 100"></svg>';
      final (cx, cy) = WordOoxmlBuilder.calcMermaidEmu(svg);
      expect(cx, 5486400);
      expect(cy, 5486400);
    });
  });

  group('parsePngDimensions', () {
    /// 构造一个最小有效 PNG 头（前 24 字节）
    Uint8List buildPngHeader({required int width, required int height, bool withIHDR = true}) {
      final bytes = Uint8List(24);
      // PNG signature
      bytes[0] = 0x89;
      bytes[1] = 0x50;
      bytes[2] = 0x4E;
      bytes[3] = 0x47;
      bytes[4] = 0x0D;
      bytes[5] = 0x0A;
      bytes[6] = 0x1A;
      bytes[7] = 0x0A;
      // IHDR chunk length = 13 (4 bytes BE) at offset 8
      bytes[8] = 0x00;
      bytes[9] = 0x00;
      bytes[10] = 0x00;
      bytes[11] = 0x0D;
      if (withIHDR) {
        bytes[12] = 0x49; // I
        bytes[13] = 0x48; // H
        bytes[14] = 0x44; // D
        bytes[15] = 0x52; // R
      }
      // width at 16-19, height at 20-23
      bytes[16] = (width >> 24) & 0xFF;
      bytes[17] = (width >> 16) & 0xFF;
      bytes[18] = (width >> 8) & 0xFF;
      bytes[19] = width & 0xFF;
      bytes[20] = (height >> 24) & 0xFF;
      bytes[21] = (height >> 16) & 0xFF;
      bytes[22] = (height >> 8) & 0xFF;
      bytes[23] = height & 0xFF;
      return bytes;
    }

    test('解析标准 PNG 头', () {
      final png = buildPngHeader(width: 1920, height: 1080);
      final dims = parsePngDimensions(png)!;
      expect(dims.width, 1920);
      expect(dims.height, 1080);
    });

    test('长度不足返回 null', () {
      final png = Uint8List(20);
      expect(parsePngDimensions(png), isNull);
    });

    test('非 PNG signature 返回 null', () {
      final bytes = Uint8List(24);
      bytes[0] = 0xFF; // 错误的 magic
      expect(parsePngDimensions(bytes), isNull);
    });

    test('PNG signature 不完整 (CRLF 错误) 返回 null', () {
      final bytes = buildPngHeader(width: 100, height: 100);
      bytes[4] = 0x00; // 错误
      expect(parsePngDimensions(bytes), isNull);
    });

    test('第一个 chunk 不是 IHDR 返回 null', () {
      final png = buildPngHeader(width: 100, height: 100, withIHDR: false);
      expect(parsePngDimensions(png), isNull);
    });

    test('width=0 返回 null', () {
      final png = buildPngHeader(width: 0, height: 100);
      expect(parsePngDimensions(png), isNull);
    });

    test('height=0 返回 null', () {
      final png = buildPngHeader(width: 100, height: 0);
      expect(parsePngDimensions(png), isNull);
    });

    test('大尺寸 32-bit 整数正确解析', () {
      // 0x7FFFFFFF (INT32_MAX)
      final png = buildPngHeader(width: 0x7FFFFFFF, height: 0x7FFFFFFF);
      final dims = parsePngDimensions(png)!;
      expect(dims.width, 0x7FFFFFFF);
      expect(dims.height, 0x7FFFFFFF);
    });

    test('超过 0x7FFFFFFF 视为非法', () {
      final png = buildPngHeader(width: 0x80000000, height: 100);
      expect(parsePngDimensions(png), isNull);
    });
  });

  group('buildDocumentXml 公式 fallback 行为', () {
    /// 关键回归测试：数学试卷导出时，公式 PNG 渲染失败不应让 docx
    /// 文档里留下断链的 rIdImageN —— 应当走 _formulaFallback 文本回退。
    test('formulaRels 中值为 null 时，文档中显示 LaTeX 文本而不是空', () {
      final elements = <DocumentElement>[
        const ParagraphElement(children: <InlineElement>[
          TextElement('二次方程 '),
          FormulaElement(latex: 'x^2 + bx + c = 0'),
          TextElement(' 的解。'),
        ]),
      ];
      final formulaRels = <String, FormulaImageInfo?>{
        'x^2 + bx + c = 0': null,
      };
      final mermaidRels = <String, MermaidImageInfo>{};

      final xml = WordOoxmlBuilder.buildDocumentXml(
        elements,
        'Test',
        formulaRels,
        mermaidRels,
      );

      // 关键断言：文档中应当有 fallback 公式的 LaTeX 文本（被 _esc 转义后）
      expect(xml, contains('Cambria Math'));
      // 关键断言：不能出现 rIdImageN 引用（公式 PNG 缺失就不会写图片 rel）
      expect(xml, isNot(contains('rIdImage')));
      // 关键断言：XML 必须能成功 utf8.encode（不能含未配对 surrogate）
      final bytes = utf8.encode(xml);
      expect(bytes, isNotEmpty);
    });

    test('公式 PNG 失败时，document.xml.rels 不写 Relationship', () {
      final formulaRels = <String, FormulaImageInfo?>{
        // 渲染失败的公式
        'a^2 + b^2 = c^2': null,
        // 同时有正常渲染成功的公式，确保不被误跳过
        'x + y': const FormulaImageInfo(
          relId: 'rIdImage1',
          widthEmu: 1200000,
          heightEmu: 360000,
        ),
      };
      final mermaidRels = <String, MermaidImageInfo>{};

      final relsXml = WordOoxmlBuilder.buildImageRelsXml(
        formulaRels,
        mermaidRels,
      );

      // 关键：失败的公式 'a^2 + b^2 = c^2'（如果有 rIdImage1 是给 'x + y' 用的）
      // rels 中只能有 1 个 rIdImage1（对应成功的公式）
      final matches = RegExp(r'rIdImage').allMatches(relsXml).length;
      expect(matches, 1,
          reason: 'rels 文件应只包含 1 个 rIdImage（成功公式的）');
      // 成功的公式应有 Relationship
      expect(relsXml, contains('rIdImage1'));
      expect(relsXml, contains('formula_1.png'));
    });
  });

  group('buildDocumentXml Unicode / Surrogate 处理', () {
    test('标题含 emoji 不产生未配对 surrogate（utf8.encode 成功）', () {
      final elements = <DocumentElement>[
        const ParagraphElement(children: <InlineElement>[
          TextElement('标题里的 emoji 😄 应正确编码'),
        ]),
      ];
      final formulaRels = <String, FormulaImageInfo?>{};
      final mermaidRels = <String, MermaidImageInfo>{};

      final xml = WordOoxmlBuilder.buildDocumentXml(
        elements,
        'Test 🚀 Title',
        formulaRels,
        mermaidRels,
      );

      // 关键：XML 必须能 utf8.encode → 写入 docx zip
      final bytes = utf8.encode(xml);
      expect(bytes, isNotEmpty);
      // 解码回来应当保留 emoji（不是被截断为 U+FFFD）
      final decoded = utf8.decode(bytes);
      expect(decoded, contains('😄'));
      expect(decoded, contains('🚀'));
    });

    test('正文含数学字母数字符号 U+1D400 不被截断', () {
      const input = '变量 𝑀 表示质量'; // 𝑀 = U+1D44C
      final elements = <DocumentElement>[
        const ParagraphElement(children: <InlineElement>[
          TextElement(input),
        ]),
      ];
      final formulaRels = <String, FormulaImageInfo?>{};
      final mermaidRels = <String, MermaidImageInfo>{};

      final xml = WordOoxmlBuilder.buildDocumentXml(
        elements,
        null,
        formulaRels,
        mermaidRels,
      );
      final bytes = utf8.encode(xml);
      final decoded = utf8.decode(bytes);
      // 关键：U+1D44C 在 UTF-8 中是 4 字节，fromCharCodes 应当生成合法 surrogate pair
      expect(decoded, contains('𝑀'));
    });

    test('输入含未配对 high surrogate 时被替换为 U+FFFD', () {
      // 构造一个含未配对 high surrogate 的字符串（直接构造 String 绕过字面量检查）
      // 'A' + high surrogate + 'B' = 0x41 0xD800 0x42
      final s = String.fromCharCodes([0x41, 0xD800, 0x42]);
      final elements = <DocumentElement>[
        ParagraphElement(children: [TextElement(s)]),
      ];
      final formulaRels = <String, FormulaImageInfo?>{};
      final mermaidRels = <String, MermaidImageInfo>{};

      final xml = WordOoxmlBuilder.buildDocumentXml(
        elements,
        null,
        formulaRels,
        mermaidRels,
      );
      // 关键：utf8.encode 不能抛错（surrogate 已被替换为 U+FFFD）
      final bytes = utf8.encode(xml);
      final decoded = utf8.decode(bytes);
      expect(decoded, contains('A'));
      expect(decoded, contains('B'));
      expect(decoded, contains('\uFFFD')); // 替换字符
    });
  });
}
