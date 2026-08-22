# Dogfood Run #005 — Real Agent Repair（repair-verify 重新证明）

**日期**: 2026-08-19
**阶段**: Phase 3.10.1D Dogfood ⑤ Real Agent Repair（五轮收官）
**命令**: `ffx capability verify markdown` → `ffx capability repair-verify art_0004`
**结论**: ✅ **REPAIR path 验证通过（before=failed → after=warn，evidence_delta 实证修复）**

---

## 1. 标准流程（ROADMAP §八）

```text
Known Bug（BUG-1）
 ↓
verify → FAIL（before 状态落盘 art_0004）
 ↓
diagnose（聚合失败上下文）
 ↓
Agent patch（恢复 BUG-1 修复——本轮模拟 Agent 修改动作）
 ↓
repair-verify art_0004（重新证明，read-only 不修码）
 ↓
before=failed / after=warn / evidence_delta 实证修复
```

## 2. 执行明细

### ① Known-Bad 构造（before）

```text
临时回退 markdown_parser.dart:326（hard-break 补丁）
ffx capability verify markdown → status: fail
  roundtrip_convergence: 0.9333（< 0.99 契约阈值）
  failed checks: ['parse', 'roundtrip']
  parse_ok=14/15（1 个多行段落 round-trip mismatch）
  failure record 落盘：.ffx/failures/art_0004.json（before=failed）
```

### ② Agent patch

```text
恢复 BUG-1 修复（取消注释，markdown_parser.dart:326）
——模拟 Agent 根据 diagnose 定位后执行修复
```

### ③ repair-verify art_0004（after）

```text
before: failed
after: warn                    ← 修复后回到 s0 边界状态（PASS 路径）
evidence_delta（2 项实证）：
  checks: {parse False→True, roundtrip False→True, ...}   ← 4 checks 全 True
  roundtrip_convergence: 0.9333 → 1.0                      ← 收敛达标
evidence_graph_delta: before_count=5 / after_count=5（evidence 链完整）
regression: n/a（detail: only 1 capability in registry (P0.1)）
```

## 3. 本轮验证的 REPAIR path

| 能力 | 验证点 | 结果 |
|------|--------|------|
| verify FAIL | 故意回退 → status=fail + failed_checks 精确 | ✅ |
| failure record | before 状态落盘（art_0004.json）可被 repair-verify 读取 | ✅ |
| diagnose 聚合 | 失败上下文（stage/tool/summary/before）可消费 | ✅ |
| repair-verify | read-only 重新证明（不修码）：before=failed → after=warn | ✅ |
| evidence_delta | checks 翻转（False→True）+ convergence 0.9333→1.0 实证 | ✅ |
| regression | n/a（单 capability 限制，P0.1 设计） | ⚠️ 登记 |

## 4. 缺口登记（本轮新增）

```text
D5（repair-verify regression）：当前 registry 仅 markdown 单 capability，
  regression 输出 "only 1 capability in registry (P0.1)"——跨能力回归对比
  需 ≥2 个 capability 后才能真实验证（对应 ROADMAP 3.10.3 consumer
  adapter 扩展后）
```

## 5. Dogfood 五轮收官总结

```text
① Smoke        real_runtime_path=true ✅
② Known-Good   verify markdown vs Matrix 一致 ✅
③ Known-Bad    故意回退 BUG-1 → FAIL 不误报 ✅（Golden case 资产化）
④ ADI/Consumer docx_qa 公式保真检测修复 + ADI 链路验证 ✅
⑤ Real Repair  repair-verify：before=failed → after=warn + evidence_delta ✅

5 条证据链状态：
  PASS path      ✅（② Known-Good）
  FAIL path      ✅（③ Known-Bad）
  DIAGNOSE path  ✅（③/⑤ failure record + diagnose 聚合）
  REPAIR path    ✅（⑤ repair-verify 重新证明）
  REGRESSION path ⚠️ 登记 D5（需 ≥2 capability，3.10.3 后补）
```

## 6. 结论

```text
⑤ Real Agent Repair 验证通过：
  FFX 能正确识别 Known-Bad（verify FAIL）→ 记录 before →
  Agent patch 后 repair-verify 重新证明（before=failed → after=warn，
  evidence_delta 实证 checks 翻转 + convergence 达标）
  repair-verify 职责边界确认：read-only 重新证明，不自己修码 ✅

Phase 3.10.1D Dogfood 五轮全部执行完毕（①-⑤），
5 条证据链中 4 条完整（PASS/FAIL/DIAGNOSE/REPAIR），
REGRESSION 待 ≥2 capability（D5，3.10.3）
```
