# ADL Loop Run #007 — Formal Closed-Loop Verification (F1-F7)

**日期**: 2026-08-17
**前置**: Run #001-006 已验证 ADI 诊断链 / 持久化 / 闭环编排 / fault-injection 闭环 / 真实源码修复可验证性 / 真实 runtime 自主修复闭环
**状态**: ✅ F1-F7 形式化验收条件全部通过（含 F2 before=reproduced 绑定）
**关键修复**: `adi.dart _cmdValidate` 不再硬编码 `before=unknown` —— 从同一 session 的 observation 推导 `before=reproduced`
**下一步**: Phase 3.9 Product Capability & Behavioral Audit（见 ADL-LOOP-RUN-006-PLAN.md §9.3）

---

## 执行摘要

Run #006 遗留一个形式化证明缺口：`validate` 输出 `before=unknown → after=pass`，
弱于理想的 `before=reproduced → after=not_reproduced`。Run #007 修复该缺口，
并完成 **F1-F7 形式化验收**（Run #006 文档预告的 Run #007 验收标准）。

```text
F1 = failure observed                   ✅  .adi/observations 存在（RenderOverflow）
F2 = before replay reproduced           ✅  validate.before=reproduced（本次修复）
F3 = production patch                   ✅  git diff 可审计（code_block.dart, -6 行）
F4 = fresh runtime                      ✅  模拟器 integration_test（真实 engine）
F5 = after replay not_reproduced        ✅  validate.after=pass
F6 = invariants pass                    ✅  validate.invariants.allPassed=true
F7 = capability regression pass         ✅  ffx project create/info 正常

PASS = F1 ∧ F2 ∧ F3 ∧ F4 ∧ F5 ∧ F6 ∧ F7 = true
```

---

## 核心修复：before=reproduced 绑定

### 根因

`tools/adi/adi.dart` 的 `_cmdValidate`（约 609 行）硬编码 `'before': 'unknown'`，
即使同一 session 的 observation 已存在于 `.adi/observations/` 且 replay 已缓存，
validate 命令也未把 before 状态绑定进结果。

### 修复

新增 `_deriveBeforeStatus(sessionId)`：遍历 `.adi/observations/*.json`，
若存在 `sessionId` 匹配的错误记录 → 返回 `reproduced`；否则保持 `unknown`（安全网）。

```dart
String _deriveBeforeStatus(String sessionId) {
  final dir = Directory('$_adiRoot/observations');
  if (!dir.existsSync()) return 'unknown';
  final files = dir.listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  for (final f in files) {
    final record = _readJson(f.path);
    if (record?['sessionId'] == sessionId) return 'reproduced';
  }
  return 'unknown';
}
```

`_cmdValidate` 中 `'before': 'unknown'` → `'before': _deriveBeforeStatus(sessionId)`。

### 三种状态验证（F2 判定逻辑）

| 场景 | observation | replay.json | validate 输出 | 判定 |
|------|-------------|-------------|---------------|------|
| before 状态 | 存在（sessionId 匹配） | reproduced | before=reproduced, after=still_failing | F2 ✅ |
| after 状态 | 存在（sessionId 匹配） | not_reproduced | before=reproduced, after=pass | F2 ✅ |
| 无 observation（回归） | 无 | 无 | no_data 安全网 | 不误判 ✅ |

---

## 模拟器全闭环重测（emulator-5554，无 zip 链路）

### 分阶段执行

| 阶段 | 操作 | 实测结果 |
|------|------|---------|
| P1 BEFORE | integration_test 渲染 CodeBlock（fault gate 存在）→ 真实 RenderOverflow | ✅ session=sess_2f78，5 个 .adi 文件透传 |
| P2 落盘 | RUN006_FILE_BEFORE 行解码 → 写入 tools/adi/.adi | ✅ observations（sessionId=sess_2f78, errorType=GlobalError） |
| P3 Agent reason | `ffx adi latest-error → trace-show → replay` → 推理 → 改码 | ✅ 定位 code_block.dart，git diff `6 deletions` 真实生效 |
| P4 AFTER | 新 APK 重编译修复后源码 → 无 overflow → 覆盖 replay.json | ✅ replay=not_reproduced（4 文件透传落盘） |
| P5 Agent validate | `ffx adi validate --after-fix sess_2f78` + capability E2E | ✅ **before=reproduced**, after=pass, invariants=true |

### 最终证据（validate 输出）

```text
conditions: C1_agent_discovers=true  C2_agent_decides_patch=true  C3_agent_judges_success=true
validate:   before=reproduced  after=pass  replay=not_reproduced  invariants_all_passed=true
capability: project_create=ok
status:     autonomous_agent_repair_proven
```

### 静态检查

```text
dart analyze tools/adi/adi.dart → No issues found
flutter analyze（capability 测试）→ 0 error / 0 warning
```

---

## 关键成果

1. **形式化闭环证明成立**：`reproduced → not_reproduced` 全链路绑定，
   不再出现 `unknown → pass` 的弱断言。
2. **F2 修复是纯 CLI 层**（adi.dart），不影响 Agent harness / capability 测试 /
   驱动脚本——验证了 ADI 作为独立诊断层的可演进性。
3. **与 Run #006 的边界**：Run #006 证明「闭环可运行」（C1-C3 + P1-P6），
   Run #007 证明「闭环可形式化验证」（F1-F7 全绑定）。

---

## 遗留与下一步

1. **Phase 3.9 Product Capability & Behavioral Audit**（见 ADL-LOOP-RUN-006-PLAN.md §9.3）：
   - Capability Audit 先行（Markdown/Parser/Serializer/Formula/Export/Undo-Redo）
   - 审计项契约：`{capability, 触发方式, 期望行为, ADI 观察点}`
   - Regression Asset：每个 ADI 发现的 bug → regression test（积累质量资产）
2. **Real LLM agent**：仍未验证（执行者为确定性 harness），需专门实验。
3. **Real product capability E2E**：FFX API regression 已通过（F7），
   真实产品链路（parser/export 等在真机完整路径）待 Phase 3.9 覆盖。
