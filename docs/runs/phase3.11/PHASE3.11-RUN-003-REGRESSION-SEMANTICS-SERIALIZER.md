# PHASE3.11-RUN-003 — regression 语义升级 + Serializer Golden Loop + PHASE_3_11_EXIT

**日期**: 2026-08-20
**阶段**: Phase 3.11 Capability Hardening Loop / 3.11.3 + 评审 §1/§4/§6 落地
**范围**: ① regression 语义升级（fingerprint diff）② support_policy 显式化
③ 3.11.3 Serializer Golden Loop ④ PHASE_3_11_EXIT 退出条件定义
**结论**: ✅ **Golden Loop 模板跨能力稳定（Markdown + Serializer 两轮闭环）；
regression 判定升级为 baseline failure set + fingerprint diff；退出条件定义完成**

---

## 1. ① regression 语义升级（评审 §1，最关键）

### 旧实现的问题

```text
_has_historical_failure(capability) —— 只按 capability 判断
  问题：formula 历史上失败过 → 任何 formula 失败都被标 pre_existing
  → 一个月后 BUG-B 使 formula 再失败，会被错误吞掉（掩盖真实回归）
```

### 新实现（fingerprint diff）

```text
Failure Identity（指纹）= capability + 失败 checks 组合
  'formula:no_adi_render_failure' ≠ 'formula:render_observable'（同能力不同 bug 可区分）

_baseline_failure_set(exclude_capability) → F1（failures 目录历史指纹，排除修复目标）
repair-verify 遍历 others → F2（当前失败指纹）
  new      = F2 - F1   （真回归 → regression=fail）
  resolved = F1 - F2   （已修复）
  persistent = F1 ∩ F2 （既有失败，不判回归）
```

### 验证（repair-verify art_0015）

```json
{
  "before": "failed", "after": "pass",
  "regression": {
    "status": "pass",
    "before_failures": ["formula:no_adi_render_failure"],
    "after_failures": ["formula:no_adi_render_failure"],
    "new_failures": [],
    "resolved_failures": [],
    "persistent_failures": ["formula:no_adi_render_failure"]
  }
}
```

**formula 既有失败正确归为 persistent（非回归）——同一 fingerprint 匹配，非
capability 粗粒度判断。将来 formula 出现新失败（不同指纹）→ new_failures → 拦截。**

## 2. ② support_policy 显式化（评审 §4）

```text
11 个 contracts 增加 support_policy：
  {required: [...], optional: [], unsupported: <s0 显式化>}
  - markdown: required=[parse,serialize,roundtrip,no_parse_error], unsupported=5 项
  - word: required=[artifact_integrity,wps_consumer,formula_fidelity], unsupported=[microsoft_word_desktop]
  - formula: required=[render_observable,no_adi_render_failure], unsupported=2 项
  ...
语义清晰化：Unsupported（s0 声明）≠ Unknown（证据缺口）≠ Failure（checks 失败）
contract-sync 验证：status=ok 无漂移
```

## 3. ③ 3.11.3 Serializer Golden Loop（评审 §5 第一优先）

### 执行（Golden Loop 模板复制，仅替换 Capability/Failure/Repair）

| 步骤 | 动作 | 结果 |
|------|------|------|
| ① 基线 | `ffx capability verify serializer` | ✅ pass（roundtrip 1.0） |
| ② 回退 | markdown_serializer.dart `separator='\n'` → `''`（块间分隔丢失） | ✅ |
| ③ FAIL | `ffx capability verify serializer` | ✅ fail（roundtrip 0.9375，roundtrip check False）→ art_0024 |
| ④ diagnose | `ffx capability diagnose art_0024` | ✅ capability=serializer |
| ⑤ 修复 | 恢复 separator='\n'（Agent patch） | ✅ |
| ⑥ repair-verify | `ffx capability repair-verify art_0024` | ✅ **before=failed / after=pass / regression=pass** |
| ⑦ 资产 | regression corpus（bug_001 共享 runner，files=16 覆盖） | ✅ |

### Golden Loop 模板稳定

```text
Markdown（RUN-002）+ Serializer（RUN-003）两轮闭环：
  同一个模板（verify → FAIL → diagnose → 修复 → repair-verify → regression asset），
  仅替换 Capability / Failure Case / Repair——模板跨能力成立 ✅
```

## 4. ④ PHASE_3_11_EXIT 退出条件定义（评审 §6）

```text
PHASE_3_11_EXIT =
    GoldenLoopTemplateStable        ✅（Markdown + Serializer 两轮）
    ∧ N capabilities hardened       ⏳（1 parser/data ✅ + 1 runtime ⏳ + 1 consumer/export ⏳ + 1 physical/visual ⏳）
    ∧ every bug → regression asset ⏳
    ∧ no false-positive regression ✅（fingerprint diff 落地）
    ∧ completion status updated    ⏳
```

ROADMAP 退出条件已更新为此定义（3.11.2/3.11.3 ✅，3.11.4 Formula 🟡 待启动）。

## 5. 结论

```text
Run-003 达成：
  ① regression 语义升级：baseline failure set + fingerprint diff
     （评审 §1：新回归/已解决/既有失败精确区分，防「回归被历史记录吞掉」）
  ② support_policy 显式化（评审 §4：Unsupported ≠ Unknown ≠ Failure）
  ③ Serializer Golden Loop 闭环（评审 §5：Golden Loop 模板跨能力稳定）
  ④ PHASE_3_11_EXIT 定义（评审 §6）

Phase 3.11 已从「把测试接进 FFX」进入「用 FFX 持续改进 FormulaFix」：
  Golden Loop 模板成立，可复制到 Formula（E6/E8 高等级证据突破）→ Word/PDF
  → Undo/IME/Autosave/File/Theme/Block。
```

## 6. 下一步

```text
3.11.4 Formula 加固（评审 §5 第二优先）：首次解决 E6 physical runtime /
  E8 visual fidelity 高等级证据缺口——FormulaFix 核心差异化能力
3.11.5 Word/PDF 加固（基础设施最强：WPSCLI/OfficeCLI/pdfinfo/pdf2txt/ADI）
3.11.6 Undo/IME/Autosave/File/Theme/Block
3.11.7 contract-sync 增强
```
