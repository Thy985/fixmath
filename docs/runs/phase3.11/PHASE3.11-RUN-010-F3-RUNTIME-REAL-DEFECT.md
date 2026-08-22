# PHASE3.11-RUN-010 — F3 Runtime Real Defect Loop（Formula 首个真实渲染缺陷闭环）

**日期**: 2026-08-21
**阶段**: Phase 3.11 收口验证 / F3 Runtime Real Defect Loop（评审冻结顺序第 2 步）
**范围**: formula adapter 真实渲染检测增强 + formula 渲染代码回退（真实缺陷）+
diagnose → 修复 → repair-verify + target_failure 精度修正
**结论**: ✅ **F3 Runtime = Real Defect Loop validated——四个 family 全部有代表性
Golden Loop 证据（Data/Behavior/Runtime/Consumer），Synthetic 与 Real 双 Loop 齐备**

---

## 1. 背景

```text
评审冻结顺序：Contract-Sync ✅ → F3 Runtime Real Defect Loop（本轮）→ Word Full
Loop → E6/E8。

F3 Runtime 此前状态：Synthetic Loop validated（Run-004 注入观察），
Real Defect Loop ❌——最大证据缺口。
本轮目标：真实 Flutter Runtime 缺陷（非注入）完整闭环：
  reproduce → observe → fingerprint → diagnose → code fix → rebuild → rerun
  → evidence delta → regression
```

## 2. 实现

### 2.1 formula adapter 真实渲染检测增强（Runtime evidence）

```text
formula.py execute 增加真实渲染测试执行（此前仅读 .adi 观察）：
  runtime_bridge.run_flutter_tests([formula_extractor_test, formula_render_plan_test])
  → render_test_passed / render_test_failed metrics
  → evidence tool = adi+flutter-test
evaluate 增加 check：no_render_test_failures（渲染测试失败 → fail）
——回退真实渲染产品代码 → 测试失败 → verify formula FAIL（非注入观察）
```

### 2.2 Controlled Real Defect Reproduction（formula 渲染代码回退）

```text
回退点：lib/core/parser/formula_extractor.dart:98
  latex: text.substring(i + 2, end)  →  .substring(0, 1)（截断 latex → 保真丢失）
——真实产品代码缺陷（state→AST→latex 保真链），非注入观察
```

## 3. 执行（完整 Golden Loop）

| 步骤 | 动作 | 结果 |
|------|------|------|
| ① 回退 | formula_extractor.dart latex 截断（真实代码缺陷） | ✅ |
| ② verify | `ffx capability verify formula` | ✅ fail（no_render_test_failures=false，渲染测试真实失败） |
| ③ diagnose | `diagnose art_0041` | ✅ capability=formula、stage=evaluate |
| ④ 修复 | 恢复 formula_extractor.dart（Agent patch 真实产品代码） | ✅ |
| ⑤ repair-verify | `repair-verify art_0041` | ✅ **before=failed / target_failure=RESOLVED / regression=pass / new_failures=[]** |

### repair-verify 关键输出

```json
{
  "before": "failed",
  "after": "fail",
  "target_failure": "RESOLVED",
  "regression": {"status": "pass", "new_failures": []},
  "evidence_delta": {
    "no_render_test_failures": {"before": false, "after": true},
    "no_adi_render_failure": {"before": false, "after": false}
  }
}
```

> **after=fail 是正确语义**：formula 有**既有** ADI RenderOverflow 观察
> （no_adi_render_failure=false，Run-004 起 persistent）——本次缺陷
> （no_render_test_failures）已消除 → target_failure=RESOLVED，
> Repair Success ≠ Capability Clean。

## 4. 过程中发现并修复的问题：target_failure 判定精度

```text
问题：首次 repair-verify 显示 target_failure=PERSISTENT（误报）——
  before 的 failed checks 混合了「既有 ADI 观察（no_adi_render_failure）」
  与「本次缺陷（no_render_test_failures）」；旧判定用 capability 整体
  status（after=fail → PERSISTENT）无法区分

修复（orchestrator.py）：target_failure 基于「本次新增 failed checks 的恢复」——
  historical = 同 capability 历史 failure records 的 failed checks（既有集）
  target_checks = before_failed − historical（本次新增缺陷）
  全部恢复 → RESOLVED；否则 PERSISTENT

验证：repair-verify art_0041 → target_failure=RESOLVED ✅
  （latex 缺陷消除判 RESOLVED，既有 ADI 观察不误报为本次 target）
```

## 5. 意义

```text
✅ F3 Runtime = Real Defect Loop validated（真实渲染缺陷 → verify FAIL →
   diagnose → 修复 → repair-verify 消除，Controlled Real Defect Reproduction）
✅ 四个 family 全部有代表性 Golden Loop 证据：
   Data（Markdown/Serializer）✅ / Behavior（Undo）✅ /
   Runtime（Formula）✅ 本轮 / Consumer（PDF）✅
✅ formula adapter 从「读 ADI 观察」增强为「ADI + 真实渲染测试」
   ——Runtime evidence（Synthetic + Real 双 Loop 齐备）
✅ target_failure 判定精度修正（评审 §5 精确语义：基于本次新增缺陷恢复，
   非 capability 整体 status——既有 baseline 不误报）
```

## 6. Phase 3.11 状态更新

```text
F1 Data      ✅ Golden Loop validated（Markdown/Serializer）
F2 Behavior  ✅ Representative Golden Loop（Undo）
F3 Runtime   ✅ Real Defect Loop validated（Formula，本轮）
F4 Consumer  ✅ Representative Golden Loop（PDF full / Word env+verify）
E6/E8        ⏳ Release Gate（下一阶段）
```

## 7. 下一步（评审冻结顺序）

```text
Word Full Golden Loop（wpscli 环境就绪后：verify → diagnose → Real Defect
  Reproduction → repair → repair-verify → evidence delta → regression）
→ E6 Physical Runtime（Formula 真机/WebView 截图 → 结构 + 像素比对）
→ E8 Visual Fidelity（视觉回归 → release gate）
→ PHASE_3_11_EXIT
```

## 8. 复跑命令

```bash
ffx capability verify formula     # ADI 观察 + 真实渲染测试（Runtime evidence）
ffx capability diagnose <id>
ffx capability repair-verify <id> # target_failure 基于本次新增缺陷恢复判定
```
