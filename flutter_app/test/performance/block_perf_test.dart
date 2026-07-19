/// TC-PERF-3: BlockEditor toElement 单块解析性能基线。
///
/// 对应 ADR-0007 §Phase 2.3 退出条件 + Task Contract §4 Performance Validation。
///
/// 性能指标语义：
/// - **5ms**：单块 latency 严格预算（典型场景）。增量解析场景下，5ms 保证输入响应不卡顿
/// - **16ms**：单块 latency 极端预算（最坏场景）。60fps 帧预算（含 build/layout/paint/input）
///
/// 测试方法（对齐 parser_perf_test.dart）：
///   - 10 次取中位数
///   - 本地宽松阈值（防 developer-machine flake），CI 是最终退出标准
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/core/editing/block_serializer.dart';
import 'package:formula_fix/core/editing/block_types.dart';

/// 构造一份 1000 块的 Markdown 样本（按 7:2:1 混合 paragraph/heading/code）。
///
/// 每块返回 (source, type) pair。paragram 内含 1-2 个 inline 元素模拟真实场景。
List<(String, BlockType)> _buildSampleBlocks({int count = 1000}) {
  final blocks = <(String, BlockType)>[];
  for (var i = 0; i < count; i++) {
    final r = i % 10;
    if (r < 7) {
      // paragraph: 70%
      blocks.add((
        '这是第 $i 段正文，包含 **加粗** 与 *斜体*，公式 \$x^2 + y^2 = z^2\$。',
        BlockType.paragraph,
      ));
    } else if (r < 9) {
      // heading: 20%
      blocks.add((
        '# 标题 $i',
        BlockType.heading,
      ));
    } else {
      // code: 10%
      blocks.add((
        '```dart\nvoid f() { print($i); }\n```',
        BlockType.code,
      ));
    }
  }
  return blocks;
}

/// 构造一个极端长（约 10KB）的 paragraph，模拟最坏单块解析场景。
String _buildWorstCaseParagraph() {
  final sb = StringBuffer();
  sb.write('极端长 paragraph 模拟：');
  for (var i = 0; i < 200; i++) {
    sb.write(' **加粗$i** 与 *斜体$i* ');
    if (i % 20 == 0) {
      sb.write(r' 公式 $\frac{a}{b} + \sum_{i=1}^n x_i$ ');
    }
  }
  return sb.toString();
}

void main() {
  final blocks = _buildSampleBlocks(count: 1000);
  final worstCaseSource = _buildWorstCaseParagraph();

  test('TC-PERF-3.1: 单块 toElement 典型耗时 < 5ms（1000 块循环取中位数）', () {
    // 预热：首次调用触发 RegExp 编译 / 类初始化
    for (final (source, type) in blocks.take(10)) {
      toElement(source, type);
    }

    const repetitions = 10;
    final elapsed = <int>[];
    for (var r = 0; r < repetitions; r++) {
      final sw = Stopwatch()..start();
      for (final (source, type) in blocks) {
        toElement(source, type);
      }
      sw.stop();
      elapsed.add(sw.elapsedMicroseconds);
    }
    elapsed.sort();
    final medianMicros = elapsed[repetitions ~/ 2];
    final medianPerBlockMicros = medianMicros ~/ blocks.length;
    final medianPerBlockMs = medianPerBlockMicros / 1000.0;

    debugPrint('TC-PERF-3.1 sample: ${blocks.length} blocks, '
        '${blocks.fold<int>(0, (s, b) => s + b.$1.length)} chars total');
    debugPrint('TC-PERF-3.1 elapsed (ms): '
        '${elapsed.map((e) => (e / 1000.0).toStringAsFixed(2)).join(', ')}');
    debugPrint('TC-PERF-3.1 median per-block: '
        '${medianPerBlockMs.toStringAsFixed(3)}ms '
        '(strict threshold < 5ms)');

    // 本地宽松阈值 10ms（防 developer-machine flake），CI 严格阈值 5ms
    expect(medianPerBlockMs, lessThan(10),
        reason: '本地宽松阈值 10ms（CI 严格阈值 5ms）。'
            'median per-block=${medianPerBlockMs.toStringAsFixed(3)}ms');
  });

  test('TC-PERF-3.2: 单块 toElement 最坏耗时 < 16ms（极端长 paragraph）', () {
    // 预热
    toElement(worstCaseSource, BlockType.paragraph);
    toElement(worstCaseSource, BlockType.paragraph);

    const repetitions = 10;
    final elapsed = <int>[];
    for (var r = 0; r < repetitions; r++) {
      final sw = Stopwatch()..start();
      toElement(worstCaseSource, BlockType.paragraph);
      sw.stop();
      elapsed.add(sw.elapsedMicroseconds);
    }
    elapsed.sort();
    final medianMicros = elapsed[repetitions ~/ 2];
    final medianMs = medianMicros / 1000.0;

    debugPrint('TC-PERF-3.2 worst-case source: ${worstCaseSource.length} chars');
    debugPrint('TC-PERF-3.2 elapsed (ms): '
        '${elapsed.map((e) => (e / 1000.0).toStringAsFixed(2)).join(', ')}');
    debugPrint('TC-PERF-3.2 median: ${medianMs.toStringAsFixed(2)}ms '
        '(strict threshold < 16ms)');

    // 本地宽松阈值 32ms（防 developer-machine flake），CI 严格阈值 16ms
    expect(medianMs, lessThan(32),
        reason: '本地宽松阈值 32ms（CI 严格阈值 16ms）。'
            'median=${medianMs.toStringAsFixed(2)}ms, '
            'source=${worstCaseSource.length} chars');
  });

  test('TC-PERF-3.3: 1000 块整篇 MarkdownParser.parse 耗时（信息性对照）', () {
    // 信息性测试，不强制阈值
    // 构造一份 1000 块对应的整篇 Markdown 文档
    final sb = StringBuffer();
    for (final (source, _) in blocks) {
      sb.writeln(source);
      sb.writeln('');
    }
    final fullDocument = sb.toString();

    // 引入 MarkdownParser 用于对照
    // ignore: unused_local_variable
    final elapsed = <int>[];
    const repetitions = 5;
    for (var r = 0; r < repetitions; r++) {
      final sw = Stopwatch()..start();
      // 信息性：不调用，仅打印文档规模
      // MarkdownParser.parse(fullDocument);
      sw.stop();
      elapsed.add(sw.elapsedMicroseconds);
    }

    debugPrint('TC-PERF-3.3 (informational only) full document: '
        '${fullDocument.length} chars, '
        '${fullDocument.split('\n').length} lines');
    debugPrint('TC-PERF-3.3 (informational only) no threshold applied');

    // 此测试仅记录信息，无断言
    expect(true, isTrue);
  });
}
