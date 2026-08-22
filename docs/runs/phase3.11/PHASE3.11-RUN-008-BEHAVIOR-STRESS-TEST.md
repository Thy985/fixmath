# PHASE3.11-RUN-008 — 4 项精度修正 + Behavior Family 压力测试（Undo Golden Loop）

**日期**: 2026-08-21
**阶段**: Phase 3.11 Capability Hardening Loop / 评审 §1/§2/§3/§4 + 3.11.7 Behavior
**范围**: ① Defect Attribution ② Evidence Strength policy-defined ordering +
minimum_required ③ Controlled Real Defect Reproduction 术语 ④ Consumer Family
状态精确化 ⑤ Undo Behavior 压力测试
**结论**: ✅ **Behavior Family（F2）完成首个 Real Defect Golden Loop——四个 family 中
三个（Data/Consumer/Behavior）已有代表性子验证；4 项精度修正全部落地**

---

## 1. ① Defect Attribution（评审 §1）

```text
问题：PDF Real Defect 修改点（formula_render_plan.dart）属共享渲染基础设施，
  不能统计为「PDF 自有缺陷修复能力」——防反向污染（PDF 修好共享 renderer
  被误记为 PDF 自有缺陷修复）

落地：tests/verification_cases/pdf/bug_pdf_001_sanitize_empty.json
  defect_attribution：
    owner = shared_infrastructure/formula_rendering
    owner_capability = formula
    affected_capabilities = [pdf, formula, word]
    cross_capabilities = [pdf]
    evidence_owner = pdf（检测/验证方）
    repair_target = formula_render_plan.dart sanitizeSvgString 空输入分支
  ——从「测试归属」升级到「真实缺陷归属」
```

## 2. ② Evidence Strength policy-defined ordering + minimum_required（评审 §2）

```text
问题：visual < human_confirmed 不是普适全序（自动视觉比较器 vs 人工确认
  各有权衡）——是 release policy 定义的最低证明能力阶梯

落地：11 contracts evidence_strength 加 minimum_required（release gate 要求）：
  formula: physical_runtime（E6/E8 视觉为 release gate → 要求最高）
  pdf/undo/block/file/ime/autosave/theme: test_runtime
  markdown/serializer/word: production_runtime
  ——achieved（实际获得）与 minimum_required（release gate 要求）分离
```

## 3. ③ Controlled Real Defect Reproduction 术语（评审 §3）

```text
RUN-007 报告补术语：本轮方法 = Controlled Real Defect Reproduction——
  在真实产品代码中制造确定性、可回滚的 defect state（非传统 fault injection）
  真实代码 → 确定性失败 → 可回滚（Agent patch 恢复）→ 重新验证
  用于区分 Synthetic Loop（验证验证基础设施）与 Real Defect Loop（真实工程闭环）
```

## 4. ④ Consumer Family 状态精确化（评审 §4）

```text
Consumer Family = REPRESENTATIVE_GOLDEN_LOOP_VALIDATED（非「所有 Consumer 完成」）：
  PDF   = FULL_GOLDEN_LOOP_VALIDATED
  Word  = ENVIRONMENT/VERIFY VALIDATED（FULL_GOLDEN_LOOP PENDING，wpscli 就绪后）
——RUN-007 报告 + ROADMAP 已同步
```

## 5. ⑤ Behavior Family 压力测试：Undo Golden Loop（3.11.7）

### 为什么 Behavior 是更强的压力测试

```text
Data/PDF 是 input→output 型；Behavior（Undo）是
  state → action → transition → observable behavior → persistent state
  型——验证「状态机语义」能力是否也能不改核心 Golden Loop
```

### 执行（Controlled Real Defect Reproduction）

| 步骤 | 动作 | 结果 |
|------|------|------|
| ① 回退 | editor_history.dart `EditorHistory.undo` 返回 null（真实代码缺陷） | ✅ |
| ② verify | `ffx capability verify undo` | ✅ fail（20/21 passed，真实测试失败 21 项） |
| ③ diagnose | `diagnose art_0036` | ✅ capability=undo、stage=evaluate |
| ④ 修复 | 恢复 EditorHistory.undo（Agent patch 真实产品代码） | ✅ |
| ⑤ repair-verify | `repair-verify art_0036` | ✅ **before=failed / after=pass / target_failure=RESOLVED / regression=pass / new_failures=[]** |

### 意义

```text
✅ Behavior（state→action→transition 型）不改核心语义完成完整 Golden Loop
  ——Failure Identity v2 / target_failure 四态 / evidence model / diagnose /
   repair-verify / regression 全部复用
✅ 四个 family 中三个（Data/Consumer/Behavior）已有代表性子验证
  （Runtime 为 Synthetic；Real Defect Loop 待验）
```

## 6. Phase 3.11 状态更新

```text
Architecture        ✅ FROZEN
Failure Identity v2 ✅ FROZEN
Repair Semantics    ✅ FROZEN
Evidence Policy     ✅ FROZEN（含 minimum_required）
Data Family         ✅ Golden Loop validated
Runtime Family      🟡 Synthetic validated / Real Defect pending
Consumer Family     🟡 REPRESENTATIVE_GOLDEN_LOOP_VALIDATED（PDF=full / Word=env+verify）
Behavior Family     ✅ REPRESENTATIVE_GOLDEN_LOOP_VALIDATED（Undo=full loop，本轮达成）
E6/E8               ⏳ Release Gate
```

## 7. 下一步

```text
3.11.5 contract-sync 增强（Meta-Validation Layer：s0/unknown_max 自洽 +
  fingerprint v2 / owner_cross_required_for / evidence_profile /
  evidence_strength.minimum_required / defect_attribution schema 校验）
后续：Word 完整 Golden Loop（wpscli 环境）+ Runtime Real Defect Loop + E6/E8
```
