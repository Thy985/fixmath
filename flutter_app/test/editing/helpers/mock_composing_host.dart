/// ComposingHost 的 mock 实现（测试专用）。
///
/// 用于 BlockOperations 守门测试：构造 [ComposingController] 进入 composing 态，
/// 验证铁律 1（不切块）被强制执行。
library;

import 'package:formula_fix/core/editing/block_types.dart';
import 'package:formula_fix/core/editing/composing_controller.dart';

/// 用于单测的 [ComposingHost] mock 实现。
///
/// 记录 replaceRange / restoreSource 调用参数，便于断言。
/// 与 [composing_controller_test.dart] 中的 _MockComposingHost 同结构，
/// 但提取为可复用 helper（避免重复）。
class MockComposingHost implements ComposingHost {
  @override
  String source;

  @override
  ComposingRegion composing;

  final List<({int start, int end, String replacement})> replaceRangeCalls = [];
  final List<String> restoreSourceCalls = [];

  MockComposingHost({required this.source, required this.composing});

  @override
  void replaceRange(int start, int end, String replacement) {
    replaceRangeCalls.add((start: start, end: end, replacement: replacement));
    source = source.substring(0, start) + replacement + source.substring(end);
  }

  @override
  void restoreSource(String s) {
    restoreSourceCalls.add(s);
    source = s;
  }
}
