import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/services/file_service.dart';

void main() {
  group('decodeBytesAuto', () {
    test('空字节流返回空字符串', () {
      expect(decodeBytesAuto(const []), '');
    });

    test('纯 ASCII 走 UTF-8 严格路径', () {
      const input = 'Hello, world!';
      expect(decodeBytesAuto(utf8.encode(input)), input);
    });

    test('带 UTF-8 BOM 的纯中文正常解析', () {
      const input = '你好世界';
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(input)];
      expect(decodeBytesAuto(bytes), input);
    });

    test('合法 UTF-8 多字节序列', () {
      const input = '数学公式: α + β = γ'; // α β γ 是 2 字节 UTF-8
      expect(decodeBytesAuto(utf8.encode(input)), input);
    });

    test('合法 UTF-8 4 字节 emoji', () {
      const input = '🎉 导出成功';
      expect(decodeBytesAuto(utf8.encode(input)), input);
    });

    test('GBK 编码（中文 Windows 记事本默认）走 GBK 回退', () {
      const input = '这是GBK编码的中文';
      final gbk = Encoding.getByName('gb18030') ?? Encoding.getByName('gbk');
      if (gbk == null) {
        // 极端情况：当前平台连 gb18030/gbk 都不提供——跳过此用例。
        return;
      }
      final bytes = gbk.encode(input);
      // 严格 UTF-8 会失败，gb18030 应该成功
      expect(decodeBytesAuto(bytes), input);
    });

    test('单字节 Latin-1 走 latin1 兜底', () {
      final bytes = [0x48, 0x65, 0x6C, 0x6C, 0x6F, 0xA9, 0x20, 0x57, 0x6F, 0x72, 0x6C, 0x64]; // "Hello© World"
      // 0xA9 在严格 UTF-8 中是孤立 continuation byte
      final result = decodeBytesAuto(bytes);
      expect(result, contains('Hello'));
      expect(result, contains('World'));
    });

    test('孤立 continuation byte（0x80 单独）不抛错', () {
      final bytes = [0x48, 0x69, 0x80, 0x21]; // "Hi\x80!"
      // 严格 UTF-8 抛 FormatException，必须由容错模式或 latin1 兜底
      final result = decodeBytesAuto(bytes);
      expect(result, contains('Hi'));
      expect(result, contains('!'));
    });

    test('混合 GBK + UTF-8 字节不抛错', () {
      // 这是用户实际场景：用 UTF-8 编辑器打开 GBK 文件时部分内容会是乱码
      // 我们的目标是不抛错、保留可读部分
      final bytes = [0x68, 0x69, 0x20, 0xC4, 0xE3, 0xBA, 0xC3, 0x21]; // "hi 你好!" 用 GBK 编码的"你好"
      final result = decodeBytesAuto(bytes);
      expect(result, contains('hi'));
      expect(result, contains('!'));
    });
  });
}
