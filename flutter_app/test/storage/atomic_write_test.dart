/// TC-1.2.8: 原子写无 .tmp 残留
///
/// 对应 ADR-0003、AGENTS.md §4.1。
/// 业务价值：进程崩溃 / 写入中断时不能留下半截 .md。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/services/file_repository.dart';

void main() {
  group('TC-1.2.8 原子写无 .tmp 残留', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atomic_write_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('正常写入：写入完成后无 .tmp 残留', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.md');
      await atomicWrite(file, '# 测试\n\n内容');
      expect(await file.exists(), isTrue);
      expect(await File('${file.path}.tmp').exists(), isFalse,
          reason: '正常写入后 .tmp 必须已被 rename');
    });

    test('100 次连续写入：无 .tmp 残留', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}stress.md');
      for (var i = 0; i < 100; i++) {
        await atomicWrite(file, '版本 $i\n');
      }
      expect(await file.exists(), isTrue);
      expect(await File('${file.path}.tmp').exists(), isFalse);
    });

    test('覆盖写入：旧内容被替换，无 .tmp 残留', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}overwrite.md');
      await atomicWrite(file, '版本 1');
      await atomicWrite(file, '版本 2');
      expect(await file.readAsString(), '版本 2');
      expect(await File('${file.path}.tmp').exists(), isFalse);
    });

    test('目录不存在时自动创建', () async {
      final nested = '${tempDir.path}${Platform.pathSeparator}nested${Platform.pathSeparator}deep';
      final file = File('$nested${Platform.pathSeparator}doc.md');
      await atomicWrite(file, '内容');
      expect(await file.exists(), isTrue);
    });
  });
}
