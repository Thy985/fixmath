# PHASE3.11-RUN-005 — taxonomy 冻结 + Synthetic/Real Loop 区分 + 优先级调整 + repair result 语义

**日期**: 2026-08-20
**阶段**: Phase 3.11 Capability Hardening Loop / 评审 §3/§4/§6/§8 落地
**范围**: ① Layer/Family taxonomy 两维度冻结 ② Synthetic vs Real Defect Loop 区分
③ contract-sync 优先级提前 ④ repair result 语义（Repair Success ≠ Capability Clean）
**结论**: ✅ **Phase 3.11 Architecture 基本冻结（Evidence-driven Capability Verification
Runtime 成型）——4 项评审修正全部落地**

---

## 1. ① taxonomy 修正（评审 §4，结构性）

### 问题

```text
旧：四层质量闭环（L1 Data/L2 Behavior/L3 Runtime/L4 Consumer）
  vs N=4 families（Data/Runtime/Consumer/Physical-Visual）
  ——Behavior 消失、Physical/Visual 取代 Behavior——两个「四层」不是同一 taxonomy
  → 到 3.11.7 Undo/IME 时会出现「Undo 属于 Behavior 还是 Runtime？」歧义
```

### 修正（两个正交维度冻结）

```text
Quality Layers（验证质量层级，L1-L4）：
  L1 Data / L2 Behavior / L3 Runtime / L4 Consumer-Experience

Capability Families（能力族，N=4）：
  F1 Data → Markdown ✅ / Serializer ✅
  F2 Behavior → Undo / IME / Autosave / File / Theme / Block（3.11.7）
  F3 Runtime → Formula（🟡 Run-004）
  F4 Consumer → Word / PDF（3.11.6）

Evidence Dimension（证据维度，非能力族）：
  E6 Physical Runtime / E8 Visual Fidelity —— release-gate
  （Physical/Visual 不是第 5 个 family）
```

## 2. ② Synthetic vs Real Defect Loop 区分（评审 §6）

```text
Run-004 标注为 Synthetic Failure Loop：
  注入观察（err_svgparse）→ 移除 → 证明「系统识别并清除新 failure identity」
  （Evidence → Fingerprint → Diagnose → Repair → Evidence Delta → Regression）

尚不证明 Real Defect Repair Loop（Agent 修复真实 SVG parser/render pipeline
产品缺陷）——登记下一阶段：
  reproduce → observe → fingerprint → agent diagnose → code fix → rebuild
  → rerun → evidence delta → regression

formula contract note + RUN-004 报告均已注明。
```

## 3. ③ 优先级调整（评审 §8）

```text
旧：3.11.5 Word/PDF / 3.11.6 Undo-IME / 3.11.7 contract-sync
新：3.11.5 contract-sync（P0 提前）/ 3.11.6 Word-PDF（F4 Consumer）/ 3.11.7 Undo-IME（F2 Behavior）

理由：schema 快速演化期（fingerprint v2 / owner_cross_required_for / evidence
profile 刚冻结）——先冻结「系统如何描述验证结果」，再扩大验证对象。
否则 3.11.5/3.11.6 新增字段会回头改 3.11 核心 contract。
```

## 4. ④ repair result 语义（评审 §3）

```text
repair-verify 输出补充：
  target_failure: RESOLVED / PERSISTENT
    （before fail → after pass = RESOLVED；after 仍 fail = PERSISTENT——可能为既有 baseline）
  persistent_baseline_count: N
  已有：new_failures / resolved_failures / persistent_failures / regression

单元级验证（三场景）：
  Markdown 修复（failed→pass）= RESOLVED ✅
  Formula 既有失败（failed→fail）= PERSISTENT ✅
  未知场景（unknown→pass）= PERSISTENT ✅

核心语义：Repair Success ≠ Capability Clean——
  repair result：target failure RESOLVED + persistent baseline N + new failures 0
  + regression PASS（formula 修复后仍有 RenderOverflow 是正确语义，非假阳性）
```

## 5. 结论

```text
Run-005 达成（Phase 3.11 Architecture 基本冻结）：
  ① taxonomy 两维度冻结（Quality Layers L1-4 独立于 Capability Families F1-4，
     Physical/Visual 归 Evidence Dimension E6/E8）——消除 Undo 归属歧义
  ② Synthetic vs Real Defect Loop 显式区分（Run-004 诚实标注 + 下一阶段登记）
  ③ contract-sync 提前至 3.11.5（先冻结验证结果描述，再扩大验证对象）
  ④ repair result 语义（target_failure RESOLVED/PERSISTENT——Repair Success
     ≠ Capability Clean）

Evidence-driven Capability Verification Runtime 成型：
  Capability → Quality Layer → Evidence Profile → Failure Identity
  → Regression Corpus Ownership → Diagnosis → Repair-Verify
  → Evidence Delta → Regression Decision
```

## 5.1 PHASE_3_11 状态定义（评审 §7，5 维度）

```text
PHASE_3_11_ARCHITECTURE       = FROZEN / VALIDATED      ✅（taxonomy + ontology 冻结）
PHASE_3_11_CAPABILITY_COVERAGE = IN PROGRESS             ⏳（F1 Data ✅，F2/F3/F4 进行中）
PHASE_3_11_RUNTIME_VALIDATION = PARTIALLY VALIDATED      🟡（Formula Synthetic Loop；Real Runtime 待验）
PHASE_3_11_REAL_DEFECT_REPAIR = NOT YET VALIDATED        ❌（Synthetic ≠ Real，登记下一阶段）
PHASE_3_11_E6/E8              = RELEASE-GATE / NOT YET SATISFIED ⏳（真机/视觉环境就绪后）
```

> 相比「Phase 3.11 = Defined」信息量大得多——能明确回答哪部分已证明、
> 哪部分只是设计完成、哪部分需真实 runtime evidence。

## 6. 下一步

```text
3.11.5 contract-sync 增强（s0/unknown_max 自洽 + fingerprint v2/owner schema 校验）
3.11.6 Word/PDF 加固（F4 Consumer：WPS/OfficeCLI/pdf2txt/ADI）
3.11.7 Undo/IME/Autosave/File/Theme/Block 加固（F2 Behavior）
后续：Real Defect Repair Loop（formula 真实渲染缺陷）→ E6/E8 Evidence Dimension
```
