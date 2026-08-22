# PHASE3.11-RUN-006 — target_failure 四态冻结 + PHASE_3_11 5 维状态 + Word/PDF 泛化验证

**日期**: 2026-08-21
**阶段**: Phase 3.11 Capability Hardening Loop / 评审 §5/§6/§7 落地
**范围**: ① target_failure 四态冻结 ② PHASE_3_11 5 维度状态定义 ③ Word/PDF 架构泛化验证
**结论**: ✅ **repair semantics 四态冻结；Phase 3.11 状态 5 维可回答；架构泛化性初步验证（Word env_missing 路径 + PDF 真实 runner 路径零修改复用）**

---

## 1. ① target_failure 四态冻结（评审 §5）

### 问题

```text
旧：unknown → pass = PERSISTENT——但 persistent 前提是「before 已存在 failure
identity」；unknown 无此前提 → 压成 PERSISTENT 会污染 repair semantics
（Agent 学错规则：没有 baseline + after pass = persistent）
```

### 四态冻结

```text
RESOLVED     before 有 failure，after 无
PERSISTENT   before 有 failure，after 仍有
NOT_OBSERVED before 无可确认 target failure，after 通过
INTRODUCED   before 无 target，after 新出现（本次引入）
```

### 单元验证（5 场景全过）

```text
✅ failed→pass  = RESOLVED
✅ failed→fail  = PERSISTENT（formula RenderOverflow 既有失败）
✅ unknown→pass = NOT_OBSERVED（评审 §5 修正点——不再压成 PERSISTENT）
✅ pass→fail    = INTRODUCED
✅ unknown→fail = INTRODUCED
```

## 2. ② PHASE_3_11 5 维度状态定义（评审 §7）

```text
PHASE_3_11_ARCHITECTURE       = FROZEN / VALIDATED      ✅（taxonomy + ontology 冻结）
PHASE_3_11_CAPABILITY_COVERAGE = IN PROGRESS             ⏳（F1 Data ✅，F2/F3/F4 进行中）
PHASE_3_11_RUNTIME_VALIDATION = PARTIALLY VALIDATED      🟡（Formula Synthetic Loop；Real Runtime 待验）
PHASE_3_11_REAL_DEFECT_REPAIR = NOT YET VALIDATED        ❌（Synthetic ≠ Real，登记下一阶段）
PHASE_3_11_E6/E8              = RELEASE-GATE / NOT YET SATISFIED ⏳（真机/视觉环境就绪后）
```

写入：RUN-005 报告 §5.1 + ROADMAP 状态声明段——相比「Defined」信息量大得多，
能明确回答哪部分已证明、哪部分仅设计完成、哪部分需真实 runtime evidence。

## 3. ③ Word/PDF 架构泛化验证（评审 §6 核心验证点）

### 验证目标

> Word/PDF 是否能**在不修改核心语义**下接入 verify → diagnose → repair-verify
> → evidence delta → regression——证明架构非 Formula 特化，是通用
> capability hardening framework。

### Word（consumer 类）——env_missing 路径复用

```text
verify word → status=env_missing / exit=127
  message: wpscli not installed（ENV_MISSING 语义正确——wpscli 缺失 ≠ FAIL）
  evidence stages: [discover, prepare]（execute 前因 wpscli 缺失抛 EnvironmentError）
  → 退出码语义 / evidence 链 / message 契约全部复用（零修改核心语义）
```

### PDF（assets 类）——真实 runner 路径复用

```text
verify pdf → status=pass
  execution: {runner: flutter_test, real_execution: true, production_runtime: false}
  coverage.checks: {tests_executed: true, no_failures: true}
  evidence stages: [discover, prepare, execute, collect]（完整 4 阶段链）
  → 真实执行 / evidence 聚合 / execution 字段全部复用（零修改核心语义）
```

### 结论

```text
Word（consumer 类）+ PDF（assets 类）均自然复用同一套 verify 架构——
  架构泛化性初步验证 ✅（跨 3 类证据：Data markdown/serializer ✅、
  Runtime formula ✅、Consumer word/PDF 🟡 接入验证）
```

## 4. 结论

```text
Run-006 达成：
  ① target_failure 四态冻结（RESOLVED/PERSISTENT/NOT_OBSERVED/INTRODUCED——
     unknown→pass 不再压成 PERSISTENT，repair semantics 干净）
  ② PHASE_3_11 5 维度状态定义（ARCHITECTURE/CAPABILITY_COVERAGE/
     RUNTIME_VALIDATION/REAL_DEFECT_REPAIR/E6-E8）
  ③ Word/PDF 核心 verify 架构泛化验证（env_missing 路径 + 真实 runner 路径）

⚠️ 措辞修正（评审 §4，2026-08-21）：架构泛化 ≠ Golden Loop 泛化——
  Word/PDF 已证明【核心 verify / environment semantics（ENV_MISSING≠FAIL）/
  real execution / evidence aggregation】无修改复用；
  但【完整 Consumer Golden Loop（diagnose → repair-verify → evidence delta
  → regression）】对 Word/PDF 尚待验证（3.11.6，wpscli 环境就绪后）。
  不把「架构泛化初步实证」误报为「Golden Loop 泛化已证明」。
```

## 4.1 Evidence Strength 冻结（评审 §7，2026-08-21）

```text
Evidence Strength 枚举（严格递增）：
  synthetic < test_runtime < production_runtime < physical_runtime < visual < human_confirmed

规则：什么证据支持什么级别 PASS——
  artifact 存在 ≠ runtime render ≠ physical render ≠ visual fidelity
  real_execution=true 不意味着 production_runtime=true
  （flutter_test 真跑了 ≠ 用户真实环境真跑了）

各能力 achieved（contracts evidence_strength 字段）：
  markdown/serializer: [synthetic, test_runtime, production_runtime]  ✅ 最高
  word: [synthetic, production_runtime]
  pdf/undo/block/file/ime: [synthetic, test_runtime]
  formula/autosave/theme: [synthetic]

E6/E8 将把 physical_runtime/visual 纳入 release policy——
  Evidence Strength 不再是 roadmap 标签，而是 release gate 判定依据。
```

## 4.2 Phase 3.11 逐项真实位置（评审 §8，2026-08-21）

```text
Architecture          ✅ FROZEN / VALIDATED（taxonomy + ontology 冻结）
Failure Identity      ✅ FROZEN（v2 四层：capability+check+failure_class+evidence_signature）
Repair Semantics      ✅ FROZEN（target_failure 四态：RESOLVED/PERSISTENT/NOT_OBSERVED/INTRODUCED）
Capability Taxonomy   ✅ FROZEN（Quality Layers L1-4 / Families F1-4 / Evidence Dimension E6-E8）
Cross-Family Reuse    ✅ PRELIMINARY VALIDATION（Word env_missing + PDF real runner 零修改接入）
Data Family           ✅ VALIDATED（Markdown + Serializer Golden Loop 完整闭环）
Runtime Family        🟡 SYNTHETIC LOOP VALIDATED（Formula Run-004 注入观察闭环）
                      ❌ REAL DEFECT LOOP NOT YET VALIDATED（登记下一阶段）
Consumer Family       🟡 VERIFY/EVIDENCE PATH VALIDATED（Word env_missing / PDF pass）
                      ❌ FULL GOLDEN LOOP NOT YET VALIDATED（3.11.6，wpscli 环境就绪后）
Behavior Family       ⏳ NOT YET VALIDATED（Undo/IME/Autosave/File/Theme/Block，3.11.7）
E6/E8                 ⏳ RELEASE-GATE / NOT YET SATISFIED（真机/视觉环境就绪后）
```

> 此状态比「Phase 3.11 architecture done」更准确——十项逐条可审计，
> 适合被 CI / dashboard 直接消费。

## 5. 下一步

```text
3.11.5 contract-sync 增强（Meta-Validation Layer：s0/unknown_max 自洽 +
  fingerprint v2 / owner_cross_required_for / evidence profile schema 校验）
3.11.6 Word 完整 Golden Loop（wpscli 环境就绪后：verify→diagnose→repair-verify）
3.11.7 Undo/IME/Autosave/File/Theme/Block（F2 Behavior）
后续：Real Defect Repair Loop + E6/E8 Evidence Dimension
```
