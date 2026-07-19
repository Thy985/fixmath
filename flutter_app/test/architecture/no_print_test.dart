/// TC-ARCH-4: 禁止 print()，必须用 debugPrint()
///
/// 对应 AGENTS.md §6.1 #4。
/// 改进：跟踪三引号字符串状态，避免误报字符串内的 "print("。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TC-ARCH-4 lib/ 下无 print() 调用（排除三引号字符串内容）', () {
    final hits = <String>[];
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      fail('lib/ 目录不存在');
    }
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      bool inTripleQuote = false;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 跟踪三引号字符串状态（简易状态机）
        final tripleCount = "'''".allMatches(line).length + '"""'.allMatches(line).length;
        if (inTripleQuote) {
          // 当前在三引号内：检查本行是否结束三引号
          if (tripleCount % 2 == 1) inTripleQuote = false;
          continue; // 跳过字符串内容
        }
        if (tripleCount % 2 == 1) inTripleQuote = true;

        // 单行注释跳过
        final trimmed = line.trim();
        if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*')) {
          continue;
        }
        if (_isRealPrintCall(line)) {
          hits.add('${entity.path}:${i + 1}:${line.trim()}');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason: 'AGENTS.md §6.1 #4 禁止 print()，必须用 debugPrint()。\n'
          '命中：\n${hits.join("\n")}',
    );
  });
}

/// 判断该行是否真的含 `print(` 调用（非 debugPrint / 非注释）。
bool _isRealPrintCall(String line) {
  final pattern = RegExp(r'(?<!debug)print\s*\(');
  return pattern.hasMatch(line);
}
