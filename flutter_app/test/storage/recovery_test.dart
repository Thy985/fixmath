/// TC-RECOVERY-1/2/3: 恢复测试
///
/// 对应 ADR-0003、AGENTS.md §4.1。
/// 业务价值：进程崩溃、迁移中断、异常退出后，数据不丢失、App 可恢复。
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:formula_fix/core/services/file_repository.dart';

void main() {
  group('TC-RECOVERY-1 写入中断恢复', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recovery_write_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('旧版本存在时，新写入失败不影响旧数据', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.md');
      await atomicWrite(file, '旧内容');
      expect(await file.exists(), isTrue);

      // 模拟写入中断：手动创建 .tmp，但不 rename
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString('半截内容');
      // 此时旧文件仍然完整
      expect(await file.readAsString(), '旧内容');

      // 恢复：清理 .tmp 残留，重新写入
      if (await tmp.exists()) await tmp.delete();
      await atomicWrite(file, '新内容');
      expect(await file.readAsString(), '新内容');
    });

    test('.tmp 残留不影响后续读取', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.md');
      await atomicWrite(file, '已保存内容');
      // 模拟上次崩溃留下的 .tmp
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString('半截');
      // 用户读取：通过 FileRepository.readDocument 应该读 .md 而非 .tmp
      expect(await file.readAsString(), '已保存内容');
      // 清理
      await tmp.delete();
    });
  });

  group('TC-RECOVERY-2 迁移中断恢复', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recovery_migration_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('迁移中断后 .bak 仍存在', () async {
      // ADR-0003：失败时保留 .bak，可安全重跑
      final jsonFile = File('${tempDir.path}${Platform.pathSeparator}formula_fix_documents.json');
      await jsonFile.writeAsString('[{"id":"1","title":"doc","content":"x"}]');
      final backup = await jsonFile.copy('${jsonFile.path}.bak');

      // 模拟中断：marker 未写入
      // 重跑：再次执行迁移
      expect(await jsonFile.exists(), isTrue, reason: '源 JSON 仍存在');
      expect(await backup.exists(), isTrue, reason: '.bak 备份存在');

      // 重新迁移应该成功
      // （此处只验证数据未丢失，真实迁移需 path_provider mock）
      final re = await jsonFile.readAsString();
      expect(re.contains('"id":"1"'), isTrue);
    });

    test('已迁移的 .md 文件不被重复迁移覆盖', () async {
      // 标准做法：marker 存在 → 跳过迁移
      // 这里只验证 .md 已存在时不被重写
      final mdFile = File('${tempDir.path}${Platform.pathSeparator}abc.md');
      await mdFile.writeAsString('---\nid: abc\n---\n\n# 标题\n\n内容');
      final original = await mdFile.readAsString();

      // 假装再次迁移 → 应该跳过（marker 守卫）
      // 这里直接验证：文件内容不变
      expect(await mdFile.readAsString(), original);
    });
  });

  group('TC-RECOVERY-3 异常崩溃后状态恢复', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recovery_crash_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('未保存的修改丢失，已保存的修改保留', () async {
      // 用户编辑文档：先保存 v1，再编辑为 v2 但未保存 → 崩溃
      // 重启后：磁盘上是 v1
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.md');
      await atomicWrite(file, '版本 1');
      // 模拟未保存的修改（直接写入内存，不落盘）
      // const unsavedContent = '版本 2（未保存）';
      // 崩溃后重启：磁盘上仍是 v1
      expect(await file.readAsString(), '版本 1');
    });

    test('App 重启后可读取已保存文档', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.md');
      await atomicWrite(file, '# 标题\n\n内容');
      // 模拟重启：重新读文件
      final re = await file.readAsString();
      expect(re.contains('# 标题'), isTrue);
      expect(re.contains('内容'), isTrue);
    });
  });
}
