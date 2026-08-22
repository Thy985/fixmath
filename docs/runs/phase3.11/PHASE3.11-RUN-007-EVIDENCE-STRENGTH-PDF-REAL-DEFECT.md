# PHASE3.11-RUN-007 — Evidence Strength 冻结 + PDF 首个 Real Defect Repair Loop

**日期**: 2026-08-21
**阶段**: Phase 3.11 Capability Hardening Loop / 评审 §4/§7/§8/§9 落地
**范围**: ① Evidence Strength 冻结 ② RUN-006 措辞修正（架构泛化 ≠ Golden Loop 泛化）
③ Phase 3.11 十项真实位置 ④ PDF 首个 Real Defect Repair Loop（跨 family 完整闭环）
**结论**: ✅ **Evidence Strength 成为 release policy 依据；PDF（Consumer/F4）完成首个
真实代码缺陷（非注入）的完整 Golden Loop——Real Defect Repair 状态推进**

---

## 1. ① Evidence Strength 冻结（评审 §7）

```text
枚举（严格递增）：synthetic < test_runtime < production_runtime <
                  physical_runtime < visual < human_confirmed

规则：什么证据支持什么级别 PASS——
  artifact 存在 ≠ runtime render ≠ physical render ≠ visual fidelity
  real_execution=true 不意味着 production_runtime=true

各能力 achieved（contracts evidence_strength 字段，11 个已落）：
  markdown/serializer: [synthetic, test_runtime, production_runtime]  ✅ 最高
  word: [synthetic, production_runtime]
  pdf/undo/block/file/ime: [synthetic, test_runtime]
  formula/autosave/theme: [synthetic]
  → E6/E8 将把 physical_runtime/visual 纳入 release policy
```

## 2. ② RUN-006 措辞修正（评审 §4 严格区分）

```text
架构泛化 ≠ Golden Loop 泛化：
  Word/PDF 已验证：核心 verify / environment semantics（ENV_MISSING≠FAIL）/
    real execution / evidence aggregation 无修改复用
  Word/PDF 尚待验证：完整 Consumer Golden Loop（diagnose → repair-verify
    → evidence delta → regression）——3.11.6（wpscli 环境就绪后）
  不把「架构泛化初步实证」误报为「Golden Loop 泛化已证明」
```

## 3. ③ Phase 3.11 逐项真实位置（评审 §8）

```text
Architecture        ✅ FROZEN / VALIDATED
Failure Identity    ✅ FROZEN（v2 四层）
Repair Semantics    ✅ FROZEN（target_failure 四态）
Capability Taxonomy ✅ FROZEN（Layers/Families/Evidence Dimension）
Cross-Family Reuse  ✅ PRELIMINARY VALIDATION
Data Family         ✅ VALIDATED
Runtime Family      🟡 Synthetic ✅ / Real Defect ❌（→ 本轮 PDF 推进了 Real 维度）
Consumer Family     🟡 REPRESENTATIVE_GOLDEN_LOOP_VALIDATED（PDF=full loop ✅ / Word=env+verify only）
Behavior Family     ⏳ NOT YET VALIDATED
E6/E8               ⏳ RELEASE-GATE
```

> 本轮后 Consumer Family 获得 **代表性** Full Golden Loop 验证（由 PDF 达成，
> 评审 §4 精确化）：PDF=FULL_GOLDEN_LOOP_VALIDATED；Word=ENVIRONMENT/VERIFY
> VALIDATED（FULL_GOLDEN_LOOP PENDING，wpscli 环境就绪后）——
> 不推导为「所有 Consumer capabilities 都已完成 Full Golden Loop」。

## 4. ④ PDF 首个 Real Defect Repair Loop（评审 §9 精神）

### 为什么是「真实缺陷」而非「注入观察」

```text
之前（Formula Run-004）= Synthetic Failure Loop：注入观察 → 移除
本轮（PDF）= Real Defect Repair Loop：回退真实产品代码
  （formula_render_plan.dart sanitizeSvgString 空输入分支
  `return input` → `return 'x'`）——真实代码缺陷，非注入
```

> **术语（评审 §3，2026-08-21）**：本轮方法更准确的概念是
> **Controlled Real Defect Reproduction**——在真实产品代码中制造一个
> 确定性的、可回滚的 defect state（非传统 fault injection）：
> 真实代码 → 确定性失败 → 可回滚（Agent patch 恢复）→ 重新验证。
> 此术语后续用于区分 Synthetic Loop（验证验证基础设施）与
> Real Defect Loop（验证真实工程闭环）。

### 执行（完整 Golden Loop，不修改核心语义）

| 步骤 | 动作 | 结果 |
|------|------|------|
| ① 回退 | sanitizeSvgString 空输入返回 'x'（真实代码缺陷） | ✅ |
| ② verify | `ffx capability verify pdf` | ✅ fail（no_failures=False，真实测试失败 1 项） |
| ③ diagnose | `diagnose art_0034` | ✅ capability=pdf、stage=evaluate |
| ④ 修复 | 恢复空输入分支（Agent patch 真实产品代码） | ✅ |
| ⑤ repair-verify | `repair-verify art_0034` | ✅ **before=failed / after=pass / target_failure=RESOLVED / regression=pass / new_failures=[]** |

### 中间发现（Dart 行为探测）

```text
首次尝试回退「孤立 surrogate 替换」→ verify 仍 pass——
  Dart 的 utf8.encode 对孤立 surrogate 宽容编码为 U+FFFD（不抛异常）！
  探测：utf8.encode('\uD800') = [239,191,189]（U+FFFD）
→ 换确定性回退点（空输入分支）成功制造真实失败
```

### 意义

```text
✅ 首个 Real Defect Repair Loop（真实代码缺陷 → 修复 → 重新验证 → 回归）
✅ PDF（Consumer/F4 family）完整 Golden Loop 闭环——不修改核心语义
  （Failure Identity v2 / target_failure 四态 / evidence model / diagnose /
   repair-verify / regression 全部复用）
✅ Consumer Family 状态推进：Full Golden Loop ✅（3.11.6 的完整验证提前由 PDF 达成）
```

## 5. 结论

```text
Run-007 达成：
  ① Evidence Strength 冻结（枚举 + release policy 规则 + 11 contracts 字段）
  ② RUN-006 措辞修正（架构泛化 ≠ Golden Loop 泛化——诚实边界）
  ③ Phase 3.11 十项真实位置（逐条可审计）
  ④ PDF 首个 Real Defect Repair Loop（跨 family 完整闭环）

关键进展：Formula 和 PDF（两个不同 family：Runtime/Consumer）都能使用
  同一套 Capability Hardening Loop——「通用 framework」从架构推论变为实证结论。
```

## 6. 下一步

```text
3.11.5 contract-sync 增强（Meta-Validation Layer：s0/unknown_max 自洽 +
  fingerprint v2 / owner_cross_required_for / evidence_profile / evidence_strength schema 校验）
3.11.7 Undo/IME/Autosave/File/Theme/Block（F2 Behavior——最后一个 family）
后续：Word 完整 Golden Loop（wpscli 环境）+ E6/E8 Evidence Dimension + Real LLM agent
```

## 7. 复跑命令

```bash
ffx capability verify pdf          # 真实 flutter test 执行
ffx capability diagnose <id>
ffx capability repair-verify <id>  # target_failure 四态 + evidence delta + regression
```
