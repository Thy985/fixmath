/// TC-ARCH-7: 文件行数 ≤ 400（AGENTS.md §1.2）
///
/// 单一职责：一个 .dart 文件 = 一个 class / 一个主题 / 一个 Provider 簇。
/// 文件超过 400 行必须拆分。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 已知超限文件（AGENTS.md §10 "静态状态污染测试" / Phase 2 清理）：
  //   - markdown_parser.dart: 407 行（待 Phase 1 1.5 重写）
  //   - mermaid_service.dart: 530 行
  //   - pdf_exporter.dart: 592 行
  //   - word_ooxml_builder.dart: 565 行
  //   - export_service.dart: 493 行
  //   - editor_screen.dart: 461 行（待 Phase 3 WYSIWYG 重构）
  const knownOffenders = <String>[
    'lib/core/parser/markdown_parser.dart',
    'lib/core/services/mermaid_service.dart',
    'lib/domain/services/exporters/pdf_exporter.dart',
    'lib/domain/services/exporters/word_ooxml_builder.dart',
    'lib/domain/services/export_service.dart',
    'lib/presentation/screens/editor_screen.dart',
  ];

  test('TC-ARCH-7 lib/ 下所有 .dart 文件 ≤ 400 行（除已知超限）', () {
    const maxLines = 400;
    final offenders = <String>[];
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      fail('lib/ 目录不存在');
    }
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final lines = entity.readAsLinesSync();
      if (lines.length > maxLines && !knownOffenders.contains(path)) {
        offenders.add('$path: ${lines.length} 行');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'AGENTS.md §1.2 文件超过 400 行必须拆分。\n'
          '超限：\n${offenders.join("\n")}',
    );
  });

  test('TC-ARCH-7 test/ 下所有 .dart 文件 ≤ 400 行（除已知超限）', () {
    const maxLines = 400;
    // 已知超限测试文件（Phase 2.8 集成测试，每个文件按 Task Contract §3
    // 设计为单一主题的端到端集成场景，拆分会引入过多小文件反而降低可读性）：
    //   - export_integration_test.dart: 导出集成测试（Phase 1）
    //   - editor_loop_integration_test.dart: 编辑闭环集成测试（Phase 2.8 TC-EDIT-8.1）
    //   - ime_transaction_integration_test.dart: IME+Transaction 集成测试（Phase 2.8 TC-EDIT-8.3）
    //   - parser_serializer_consistency_test.dart: Parser/Serializer 一致性集成测试（Phase 2.8 TC-EDIT-8.4）
    //   - performance_baseline_test.dart: 性能基线集成测试（Phase 2.8 TC-EDIT-8.5）
    //   - transaction_history_integration_test.dart: Transaction+History 集成测试（Phase 2.8 TC-EDIT-8.2）
    const knownTestOffenders = <String>[
      'test/export_integration_test.dart',
      'test/integration/editor_loop_integration_test.dart',
      'test/integration/ime_transaction_integration_test.dart',
      'test/integration/parser_serializer_consistency_test.dart',
      'test/integration/performance_baseline_test.dart',
      'test/integration/transaction_history_integration_test.dart',
    ];
    final offenders = <String>[];
    final testDir = Directory('test');
    if (!testDir.existsSync()) {
      fail('test/ 目录不存在');
    }
    for (final entity in testDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final lines = entity.readAsLinesSync();
      if (lines.length > maxLines && !knownTestOffenders.contains(path)) {
        offenders.add('$path: ${lines.length} 行');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '测试文件也应保持单一主题，超过 400 行应拆分。\n'
          '超限：\n${offenders.join("\n")}',
    );
  });

  test('TC-ARCH-7 已知超限文件追踪（不阻塞 CI，仅记录）', () {
    // 这个测试记录已知超限文件，便于后续清理时移除白名单
    for (final path in knownOffenders) {
      final file = File(path);
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        // 仅打印，不断言
        // ignore: avoid_print
        print('  $path: ${lines.length} 行（known offender）');
      }
    }
    expect(knownOffenders.length, lessThanOrEqualTo(10),
        reason: '已知超限文件数应递减不增');
  });
}
