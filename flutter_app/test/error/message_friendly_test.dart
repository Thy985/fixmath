/// TC-1.7.x: 错误消息用户友好性测试
///
/// 对应 docs/PHASE1_TEST_PLAN.md §8 错误消息测试。
/// 验证 [classifyError] 输出的 [ExportFailureInfo] 符合
/// AGENTS.md §4.4 错误传播规范：
///   - 不含 stack trace / 源文件路径
///   - 不含 LaTeX 源码
///   - 用户消息长度合理
///   - 含行动建议
///   - 不同根因消息不同
///   - 走 ExportFailure 枚举（i18n-ready）
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/domain/services/export_service.dart';

void main() {
  // 被测函数：classifyError。它把任意异常映射为 ExportFailureInfo。
  ExportFailureInfo classify(Object e) => classifyError(e);

  group('TC-1.7.1 不含 stack trace', () {
    test('FormatException 不暴露 stack', () {
      final info = classify(FormatException('bad data'));
      expect(info.userMessage.contains('stack'), isFalse,
          reason: '用户消息不应含 "stack"');
      expect(info.userMessage.contains('.dart'), isFalse,
          reason: '用户消息不应含 .dart 文件后缀');
    });

    test('TimeoutException 不暴露 stack', () {
      final info = classify(TimeoutException('10s'));
      expect(info.userMessage.contains('stack'), isFalse);
      expect(info.userMessage.contains('at '), isFalse,
          reason: '用户消息不应含 "at " (stack frame 前缀)');
    });

    test('ExportException 不暴露 stack', () {
      final info = classify(ExportException('render fail'));
      expect(info.userMessage.contains('stack'), isFalse);
      expect(info.userMessage.contains('at '), isFalse);
    });

    test('未知错误兜底不暴露 stack', () {
      final info = classify(StateError('unknown error'));
      expect(info.userMessage.contains('stack'), isFalse);
      expect(info.userMessage.contains('at '), isFalse);
    });
  });

  group('TC-1.7.2 不含源文件路径', () {
    test('userMessage 不含绝对路径', () {
      final cases = <Object>[
        FormatException('bad'),
        TimeoutException('t'),
        ExportException('fail'),
        StateError('err'),
        ArgumentError('bad arg'),
      ];
      for (final e in cases) {
        final info = classify(e);
        expect(info.userMessage.contains('d:/'), isFalse,
            reason: '不应含 Windows 路径: ${info.userMessage}');
        expect(info.userMessage.contains('/Users/'), isFalse,
            reason: '不应含 macOS 路径: ${info.userMessage}');
        expect(info.userMessage.contains('/home/'), isFalse,
            reason: '不应含 Linux 路径: ${info.userMessage}');
      }
    });

    test('userMessage 不含 .dart 后缀', () {
      final cases = <Object>[
        FormatException('bad'),
        TimeoutException('t'),
        ExportException('fail'),
        StateError('err'),
      ];
      for (final e in cases) {
        final info = classify(e);
        expect(info.userMessage.contains('.dart'), isFalse,
            reason: '不应含 .dart 后缀: ${info.userMessage}');
      }
    });
  });

  group('TC-1.7.3 不含 LaTeX 源', () {
    test('userMessage 不含 \\frac / \\sum 等 LaTeX 命令', () {
      final cases = <Object>[
        FormatException(r'\frac{1}{2} invalid'),
        ArgumentError(r'\sum_{i=1}^\infty'),
        ExportException(r'cannot render \int_0^1 x dx'),
      ];
      for (final e in cases) {
        final info = classify(e);
        expect(info.userMessage.contains(r'\frac'), isFalse,
            reason: '不应向用户暴露 LaTeX 命令: ${info.userMessage}');
        expect(info.userMessage.contains(r'\sum'), isFalse);
        expect(info.userMessage.contains(r'\int'), isFalse);
      }
    });

    // 注意：detail 允许包含 LaTeX 源（用于开发者排查），但 userMessage 不允许。
    test('userMessage 不含 \$E=mc^2\$ 等公式片段', () {
      final info = classify(FormatException(r'E=mc^2 malformed'));
      expect(info.userMessage.contains(r'$E=mc^2$'), isFalse);
      expect(info.userMessage.contains('mc^2'), isFalse,
          reason: '不应向用户暴露公式片段: ${info.userMessage}');
    });
  });

  group('TC-1.7.4 消息长度 < 60 字符', () {
    test('所有用户消息长度合理', () {
      final cases = <Object>[
        FormatException('bad'),
        TimeoutException('t'),
        ExportException('render fail'),
        StateError('err'),
        ArgumentError('bad arg'),
        ExportException('empty document'),
        ExportException('encode failure'),
        ExportException('zip archive error'),
      ];
      for (final e in cases) {
        final info = classify(e);
        // 中文字符按 1 字符算，但允许稍宽（< 60 chars）。
        expect(info.userMessage.length, lessThan(60),
            reason: '消息过长: "${info.userMessage}" (${info.userMessage.length} chars)');
      }
    });
  });

  group('TC-1.7.5 含行动建议', () {
    test('timeout 消息含行动建议', () {
      final info = classify(TimeoutException('timeout'));
      expect(info.userMessage.contains('重试'), isTrue,
          reason: '超时错误应建议重试: ${info.userMessage}');
    });

    test('offline 消息含行动建议', () {
      final info = classify(SocketException('connection refused'));
      expect(info.userMessage.contains('网络'), isTrue,
          reason: '网络错误应建议检查网络: ${info.userMessage}');
    });

    test('writeError 消息含行动建议', () {
      final info = classify(FileSystemException('disk full', '/tmp/x'));
      expect(info.userMessage.contains('保存'), isTrue,
          reason: '写盘错误应包含保存相关字眼: ${info.userMessage}');
    });

    test('parseError 消息含说明', () {
      final info = classify(FormatException('bad'));
      expect(info.userMessage.contains('公式') || info.userMessage.contains('识别'),
          isTrue,
          reason: '解析错误应说明问题: ${info.userMessage}');
    });
  });

  group('TC-1.7.6 根因区分', () {
    test('emptyDocument 与 renderError 消息不同', () {
      final emptyInfo = classify(ExportException('empty document'));
      final renderInfo = classify(ExportException('render fail'));
      expect(emptyInfo.userMessage, isNot(equals(renderInfo.userMessage)),
          reason: '不同根因应有不同消息');
      expect(emptyInfo.kind, isNot(equals(renderInfo.kind)));
    });

    test('timeout 与 offline 消息不同', () {
      final timeoutInfo = classify(TimeoutException('10s'));
      final offlineInfo = classify(SocketException('refused'));
      expect(timeoutInfo.userMessage, isNot(equals(offlineInfo.userMessage)));
      expect(timeoutInfo.kind, ExportFailure.timeout);
      expect(offlineInfo.kind, ExportFailure.offline);
    });

    test('writeError 与 parseError 消息不同', () {
      final writeInfo = classify(FileSystemException('disk full'));
      final parseInfo = classify(FormatException('bad'));
      expect(writeInfo.userMessage, isNot(equals(parseInfo.userMessage)));
      expect(writeInfo.kind, ExportFailure.writeError);
      expect(parseInfo.kind, ExportFailure.parseError);
    });

    test('parseError 与 unknown 消息不同', () {
      final parseInfo = classify(FormatException('bad'));
      final unknownInfo = classify(Exception('random error'));
      expect(parseInfo.userMessage, isNot(equals(unknownInfo.userMessage)));
      expect(parseInfo.kind, ExportFailure.parseError);
      expect(unknownInfo.kind, ExportFailure.unknown);
    });
  });

  group('TC-1.7.7 i18n-ready', () {
    test('所有错误都归类到 ExportFailure 枚举', () {
      // i18n-ready 的核心要求：UI 可以基于 ExportFailure.kind 决定本地化 key，
      // 而不是基于消息字符串做字符串匹配。
      final cases = <Object>[
        FormatException('bad'),
        TimeoutException('t'),
        ExportException('render fail'),
        ExportException('empty'),
        ExportException('encode'),
        StateError('err'),
        ArgumentError('arg'),
        SocketException('refused'),
        FileSystemException('disk'),
        Exception('random'),
      ];
      for (final e in cases) {
        final info = classify(e);
        expect(info.kind, isA<ExportFailure>(),
            reason: '所有错误必须归类到 ExportFailure 枚举: $e');
      }
    });

    test('ExportFailure 枚举覆盖关键失败场景', () {
      // 列举用户可能遇到的所有失败场景，确保枚举覆盖
      const expectedKinds = <ExportFailure>[
        ExportFailure.emptyDocument,
        ExportFailure.offline,
        ExportFailure.parseError,
        ExportFailure.renderError,
        ExportFailure.writeError,
        ExportFailure.timeout,
        ExportFailure.unknown,
      ];
      for (final kind in expectedKinds) {
        expect(kind.name, isNotEmpty,
            reason: 'ExportFailure.$kind 应有非空 name');
      }
    });
  });

  group('TC-1.7.8 日志与 UI 分离', () {
    test('ExportFailureInfo 有 detail 字段用于开发者排查', () {
      // detail 可空但应存在；userMessage 给用户看，detail 给开发者看
      final info = classify(FormatException('bad data'));
      expect(info.userMessage, isNotEmpty);
      // detail 可能含开发信息（如 source/offset），但不应该出现在 userMessage
      expect(info.cause, isNotNull,
          reason: '原始异常应保留在 cause 中供开发者使用');
    });

    test('ExportFailureException 透传 info', () {
      const originalInfo = (
        kind: ExportFailure.unknown,
        userMessage: '测试消息',
        detail: 'detail for dev',
        cause: null,
      );
      final ex = ExportFailureException(originalInfo);
      expect(ex.info, same(originalInfo));
      expect(ex.message, '测试消息');
    });

    test('classifyError 透传 ExportFailureException', () {
      const originalInfo = (
        kind: ExportFailure.timeout,
        userMessage: '已分类的消息',
        detail: null,
        cause: null,
      );
      final ex = ExportFailureException(originalInfo);
      final info = classify(ex);
      expect(info, same(originalInfo),
          reason: 'ExportFailureException 应被透传，不重新分类');
    });
  });
}
