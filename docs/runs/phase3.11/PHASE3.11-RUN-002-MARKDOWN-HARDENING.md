# PHASE3.11-RUN-002 — 3.11.2 Markdown Hardening Loop（Golden Loop 首轮）

**日期**: 2026-08-20
**阶段**: Phase 3.11 Capability Hardening Loop / 3.11.2（P0）
**范围**: Markdown 能力加固闭环（Golden Loop 首轮——完整跑通
verify → FAIL → diagnose → 修复 → repair-verify → regression asset）
**结论**: ✅ **Golden Loop 首轮闭环达成：before=failed / after=pass / regression=pass**

---

## 1. 背景

```text
3.11.1（Run #001）完成 Evidence Execution Level 升级后，3.11.2 用
Markdown（最成熟、最能完整跑通闭环的能力）执行 Golden Loop 首轮——
第一次证明 FFX Orchestrator 不只是「能跑测试」，而是能驱动
「发现 → 诊断 → 修复 → 回归资产化」完整工程闭环。
```

## 2. Golden Loop 执行明细

| 步骤 | 动作 | 结果 |
|------|------|------|
| ① 基线 | `ffx capability verify markdown` | ✅ pass（roundtrip 1.0，execution.production_runtime=true） |
| ② 故意回退 | 注释 markdown_parser.dart:326（hard-break 补丁） | ✅ |
| ③ FAIL | `ffx capability verify markdown` | ✅ fail（roundtrip 0.875，parse/roundtrip check False）→ art_0015 落盘 |
| ④ diagnose | `ffx capability diagnose art_0015` | ✅ stage=evaluate、checks failed、root_cause 分类 |
| ⑤ 修复 | 恢复 BUG-1 补丁（Agent patch） | ✅ |
| ⑥ repair-verify | `ffx capability repair-verify art_0015` | ✅ **before=failed / after=pass / regression=pass** |
| ⑦ 资产确认 | bug_001_hard_break.json + corpus（files=16） | ✅ 已挂载 |

### repair-verify 关键输出

```json
{
  "before": "failed",
  "after": "pass",
  "regression": {
    "status": "pass",
    "pre_existing_failures": ["formula"],
    "results": {"autosave": "warn", "block": "pass", "file": "pass",
                "formula": "fail", "ime": "pass", "pdf": "pass",
                "serializer": "pass", "theme": "warn", "undo": "pass",
                "word": "env_missing"}
  },
  "evidence_delta": {"roundtrip_convergence": {"before": 0.875, "after": 1.0}}
}
```

## 3. 过程中发现并修复的问题（3 个）

### ① `--json` 管道被 runtime_bridge print 污染
```text
症状：verify/repair-verify --json 输出被 `[runtime-bridge] runner ok...` 前缀污染
根因：R9 可观测 print 走 stdout
修复：print → stderr（run_markdown + run_flutter_tests 两处），--json 管道纯净
```

### ② regression 语义误判（核心）
```text
症状：repair-verify 显示 regression=fail——formula 是 fail
根因：regression 遍历其他 capability，把「既有失败」（formula 的 ADI
      RenderOverflow 观察，Run #004 起已存在）误判为「本次修复引入的回归」
修复：_has_historical_failure(capability) 检查历史 failure record——
      既有失败归入 pre_existing_failures（不判回归），仅新增失败判 regression=fail
结果：regression=pass + pre_existing_failures=['formula']（诚实标注）
```

### ③ `_has_historical_failure` 引用未定义
```text
症状：repair-verify Error: name '_has_historical_failure' is not defined
根因：regression 修正引用函数但未定义
修复：补定义（基于 failure.py list_failures + load_failure 检查 capability）
```

## 4. Evidence Profile 落地（评审 §4）

```text
11 个 contracts 全部增加 evidence_profile（E2/E3/E5/E6 级别）：
  markdown/serializer/undo/block: E2/E3 required, E5 recommended, E6 conditional
  file: E2/E3/E5 required, E6 conditional
  pdf/ime/theme/word/formula: E6 release-gate（视觉/真机/Word Desktop）
  autosave: E2/E3/E5/E6 全 required（需 runtime E2E）
意义：ffx verify 知道「151 tests passed ≠ Block COMPLETE」——Completion
      需 Evidence Profile 全维度验收
```

## 5. execution 证据字段（评审 §1/§3）

```text
adapter evaluate 返回值新增 execution 字段（orchestrator 透传）：
  markdown/serializer/word/formula: {runner: capability_runner/docx_qa/adi,
    real_execution: true, production_runtime: true}
  assets 型（undo/block/file/pdf/ime）: {runner: flutter_test,
    real_execution: true, production_runtime: false}  ← 测试层证据明示
防证据层级偷换：flutter test 真实执行 ≠ 产品功能真实运行
```

## 6. 7 能力状态（Runner vs 功能完成度分离，评审 §3）

| 能力 | Runner 状态 | 证据意义 | 功能完成度（未变） |
|------|------------|---------|------------------|
| Undo | ✅ real flutter test | 测试层证据 | conditional |
| Block | ✅ real flutter test | 测试层证据 | incomplete |
| File | ✅ real flutter test | 文件服务逻辑证据 | conditional |
| PDF | ✅ real flutter test | 导出逻辑证据 | conditional |
| IME | ✅ real flutter test（TestTextInput） | composing 模型证据 | unproven（真机软键盘未验） |
| Autosave | ⚠️ no runnable unit layer | 需 runtime E2E | unproven |
| Theme | ⚠️ golden/environment blocked | 需视觉基线 | unproven |

## 7. 结论

```text
3.11.2 Markdown Hardening Loop 首轮达成：
  verify 基线 PASS → 故意回退 BUG-1 → FAIL（0.875）→ diagnose →
  修复 → repair-verify：before=failed / after=pass / regression=pass
  + regression asset（bug_001 corpus 挂载 files=16）确认

Golden Loop 在 Markdown 上稳定跑通——3.11 的 Capability Hardening
Golden Loop 模板成立，可复制到 3.11.3-3.11.6 各能力。

本轮同时落地评审要求：
  - Evidence Execution Level 边界（RUN-001 措辞修正）
  - Evidence Profile（11 contracts）
  - execution 字段（production_runtime 区分）
  - regression 语义修正（既有失败 ≠ 回归）
```

## 8. 下一步

```text
3.11.3 Serializer 加固（复制 Golden Loop 模板）
3.11.4 Formula 加固（E6 physical visual fidelity）
3.11.5 Word/PDF 加固（全链路）
3.11.6 Undo/IME/Theme/File/Autosave/Block 加固
3.11.7 contract-sync 增强（s0 vs unknown_max 自洽）
```
