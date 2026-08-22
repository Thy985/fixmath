# Dogfood Run #003 — Known-Bad（故意回退 BUG-1，verify 必须 FAIL 不误报）

**日期**: 2026-08-19
**阶段**: Phase 3.10.1D Dogfood ③ Known-Bad（Golden Failure Corpus 首个案例）
**案例**: `tests/verification_cases/markdown/bug_001_hard_break.json`（BUG-001）
**结论**: ✅ **FFX 正确识别故意破坏的能力（FAIL 不误报）+ 修复恢复后 PASS 路径还原**

---

## 1. 操作流程（Golden Failure 验证链）

```text
① 定位 BUG-1 修复：markdown_parser.dart:326（合并段落前 add TextElement('\n')）
② 临时回退：注释该行（保留原文便于恢复）
③ ffx capability verify markdown → 预期 FAIL
④ 恢复修复（取消注释）
⑤ ffx capability verify markdown → 预期 warn（PASS 路径还原）
```

## 2. 验证结果

### ② 回退后（预期 FAIL）

```text
capability: markdown
status: FAIL                          ✅ 预期达成
roundtrip_convergence: 0.9333        （< 0.99 契约阈值）
checks: {parse: False, serialize: True, roundtrip: False, no_parse_error: True}
failed checks: ['parse', 'roundtrip']
metrics: files=15 / parse_ok=14 / roundtrip_converged=14
```

**关键**：BUG-1 回退后 15 文件中 1 个多行段落 round-trip mismatch →
FFX 正确判 FAIL，**没有误报 PASS**（正是 ROADMAP 3.10.1D ③ 的核心断言）。

### ⑤ 恢复后（预期 warn，PASS 路径还原）

```text
capability: markdown
status: warn                          ✅ 预期达成
roundtrip_convergence: 1.0
checks: {parse ✅, serialize ✅, roundtrip ✅, no_parse_error ✅}
metrics: files=15 / parse_ok=15 / roundtrip_converged=15
```

## 3. 本轮验证的 FFX 能力

| 能力 | 验证点 | 结果 |
|------|--------|------|
| **FAIL 识别** | 故意破坏 → status=fail + failed_checks 精确（parse/roundtrip） | ✅ |
| **不误报** | fail 而非 pass（契约阈值 0.99 拦截） | ✅ |
| **恢复验证** | 修复还原 → 回到 warn（s0 边界），convergence 1.0 | ✅ |
| **证据链** | roundtrip_convergence 数字变化贯穿 evidence（execute→collect） | ✅ |
| **真实路径** | 回退/恢复直接作用于生产 parser，非 fixture | ✅ |

## 4. Golden Failure Corpus 资产

```text
tests/verification_cases/markdown/bug_001_hard_break.json（已建）
  case_id: BUG-001
  expected: {status: fail, failure_type: roundtrip_mismatch}
  fix_location: markdown_parser.dart:326
  observed_before_fix / observed_after_fix（本轮实测数据固化）
  diagnostic_expected / repair_expected / regression_expected: true
```

**意义**：本案例成为 FFX 验收基准集首个成员——后续任何 parser 修改，
重跑 `ffx capability verify markdown` 若 BUG-001 场景不再 FAIL（故意回退时），
即视为回归。

## 5. 结论与下一步

```text
Known-Bad PASS：
  FFX 能正确拒绝一个故意破坏的能力（verify markdown → FAIL 不误报），
  修复恢复后 PASS 路径完整还原（warn + convergence 1.0）
  Golden Failure Corpus 首个案例已资产化（bug_001_hard_break.json）

下一步（ROADMAP 3.10.1D）：
  ④ ADI/Consumer 联合：RenderOverflow → verify→diagnose→replay；
     BUG-WORD-001 公式丢失 → pdf2txt ❌ 不误报 PASS
  ⑤ Real Agent Repair：before=fail → patch → after=pass → regression=pass
```
