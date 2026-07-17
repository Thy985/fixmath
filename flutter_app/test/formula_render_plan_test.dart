import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/domain/services/exporters/formula_render_plan.dart'
    show sanitizeSvgString;

/// 断言字符串中不存在未配对的 UTF-16 代理（孤立 high 或 low surrogate）。
///
/// 合法 surrogate pair（如 U+1F600 emoji = `\uD83D\uDE00`）的高位
/// surrogate (0xD800-0xDBFF) 是允许的——它必须紧跟一个低位
/// surrogate (0xDC00-0xDFFF)。
void _expectNoUnpairedSurrogates(String s) {
  for (var i = 0; i < s.length; i++) {
    final unit = s.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      // high surrogate — 必须后跟 low surrogate
      if (i + 1 >= s.length) {
        throw StateError('Unpaired high surrogate at end of string: U+${unit.toRadixString(16)}');
      }
      final next = s.codeUnitAt(i + 1);
      if (next < 0xDC00 || next > 0xDFFF) {
        throw StateError(
            'Unpaired high surrogate U+${unit.toRadixString(16)} '
            'not followed by low surrogate (got U+${next.toRadixString(16)})');
      }
      i++; // 跳过配对的 low surrogate
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      throw StateError('Unpaired low surrogate: U+${unit.toRadixString(16)}');
    }
  }
}

void main() {
  group('sanitizeSvgString', () {
    test('空字符串返回空字符串', () {
      expect(sanitizeSvgString(''), '');
    });

    test('纯 ASCII 不变', () {
      const input = '<svg viewBox="0 0 100 50"></svg>';
      expect(sanitizeSvgString(input), input);
    });

    test('合法 UTF-8 多字节字符（数学符号）保留', () {
      const input = '<svg><text>α + β = γ</text></svg>';
      expect(sanitizeSvgString(input), input);
    });

    test('合法 UTF-8 4 字节 emoji 保留', () {
      const input = '<svg><text>🎉</text></svg>';
      expect(sanitizeSvgString(input), input);
    });

    test('未配对 high surrogate (U+D800) 被替换为 U+FFFD', () {
      // 模拟 WebView 桥接时残留的孤立 surrogate
      const input = '<svg><text>hi \uD800</text></svg>';
      final result = sanitizeSvgString(input);
      // 整串应可被 utf8.encode 安全处理
      expect(() => utf8.encode(result), returnsNormally);
      // 孤立 surrogate 必须被替换，不能保留
      _expectNoUnpairedSurrogates(result);
      // 内容大部分保留
      expect(result, contains('hi'));
      expect(result, contains('<svg>'));
    });

    test('未配对 low surrogate (U+DC00) 被替换为 U+FFFD', () {
      const input = '<svg><text>hi \uDC00</text></svg>';
      final result = sanitizeSvgString(input);
      expect(() => utf8.encode(result), returnsNormally);
      _expectNoUnpairedSurrogates(result);
    });

    test('合法的 surrogate pair (U+1F600 😀) 保留', () {
      // Dart String 字面量里 \uD83D\uDE00 是合法 surrogate pair
      const input = '<svg><text>\uD83D\uDE00</text></svg>';
      final result = sanitizeSvgString(input);
      expect(result, input);
      _expectNoUnpairedSurrogates(result);
    });

    test('混合未配对 + 合法 pair 同时出现：正确处理两种', () {
      // \uD800 (未配对) + 空格 + \uD83D\uDE00 (合法 emoji) + 空格 + \uDC00 (未配对)
      const input = '<svg><text>math: \uD800 \uD83D\uDE00 \uDC00</text></svg>';
      final result = sanitizeSvgString(input);
      // 整串可被 utf8.encode 安全处理（这是用户实际遇到错误的根因）
      expect(() => utf8.encode(result), returnsNormally);
      // 不存在未配对 surrogate
      _expectNoUnpairedSurrogates(result);
      // 内容大部分保留
      expect(result, contains('math:'));
      expect(result, contains('<svg>'));
      // 合法 emoji 仍然存在
      expect(result.contains('\uD83D\uDE00'), isTrue);
    });

    test('长 SVG（>1KB）也不抛错', () {
      final input = '<svg>${'x' * 2048}<text>\uD800\uDC00</text></svg>';
      expect(() => sanitizeSvgString(input), returnsNormally);
    });

    /// **关键回归测试**：用户实际遇到的错误
    /// "FormatException: Unexpected extension byte (at offset 1)" 根因。
    ///
    /// 场景：SVG 字符串同时含非 BMP 字符（数学字母数字 𝑀 = U+1D44C）
    /// 和未配对 surrogate（U+D800）。旧实现 fallback 路径用
    /// `String.fromCharCode(r)` 逐字符重建，对 rune > 0xFFFF 截断为低
    /// 16 位 0xD44C（孤立 surrogate），再次触发 utf8.encode 抛
    /// "Unexpected extension byte (at offset 1)"。
    test('非 BMP 字符 + 未配对 surrogate 混合：清洗后必须能 utf8.encode', () {
      // 真实场景模拟：MathJax 输出的 SVG 包含数学符号 + 偶尔的孤立 surrogate
      final input = '<svg viewBox="0 0 200 50">'
          '<text>𝑀</text>' // 𝑀 = U+1D44C (非 BMP，UTF-16: D835 D44C)
          '<text>\uD800</text>' // 孤立 high surrogate
          '<text>end</text>'
          '</svg>';
      final result = sanitizeSvgString(input);
      // 关键断言 1：utf8.encode 必须成功（这是导致 PDF 导出失败的根因）
      expect(() => utf8.encode(result), returnsNormally,
          reason: 'sanitize 后的 SVG 必须能 utf8.encode，否则 pw.SvgImage 会抛错');
      // 关键断言 2：不存在未配对 surrogate
      _expectNoUnpairedSurrogates(result);
      // 关键断言 3：非 BMP 字符 𝑀 仍然存在（说明没被截断）
      expect(result, contains('𝑀'),
          reason: '非 BMP 字符 𝑀 必须被 fromCharCodes 正确编码为合法 surrogate pair');
    });

    test('控制字符 (NUL/BEL/ESC) 被替换为 U+FFFD', () {
      const input = '<svg>\u0000bell\u0007esc\u001B</svg>';
      final result = sanitizeSvgString(input);
      expect(() => utf8.encode(result), returnsNormally);
      _expectNoUnpairedSurrogates(result);
      // 控制字符被替换为 U+FFFD（不止 1 个，因为有 3 个控制字符）
      expect(result.contains('\uFFFD'), isTrue);
    });

    test('Tab/LF/CR 三个合法 XML 控制字符被保留', () {
      const input = '<svg>\n<text>line1</text>\r\n<text>line2\tcol</text>\n</svg>';
      final result = sanitizeSvgString(input);
      expect(result, contains('\n'));
      expect(result, contains('\r\n'));
      expect(result, contains('\t'));
    });
  });
}
