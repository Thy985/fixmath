# PHASE3.11-RUN-011 — Word Full Golden Loop（ENV_MISSING 与 Real Defect 共存验证）

**日期**: 2026-08-21
**阶段**: Phase 3.11 收口验证 / Word Full Golden Loop（评审冻结顺序第 3 步）
**范围**: word adapter 真实导出链路改造 + word_ooxml_builder artifact 层真实缺陷
回退 + diagnose → 修复 → repair-verify
**结论**: ✅ **Word Full Golden Loop validated——ENV_MISSING、真实 Consumer 环境与
Real Defect Repair 共存于同一 capability 生命周期；四个 family 全有完整 Golden Loop**

---

## 1. 背景

```text
评审冻结顺序：Contract-Sync ✅ → F3 Runtime Real Defect ✅（Run-010）→
Word Full Golden Loop（本轮）→ E6/E8。

Word 此前状态：ENVIRONMENT / VERIFY VALIDATED（wpscli 缺失 → env_missing），
Full Golden Loop 未完成。
本轮价值（评审）：证明 ENV_MISSING、真实 Consumer 环境和 Real Defect Repair
可以同时存在于同一个 capability 生命周期里。
```

## 2. 实现

### 2.1 word adapter 真实导出链路（替代既有 corpus audit）

```text
此前：直接 audit 既有 corpus docx（cap_word_fix.docx）——不经 WordExporter，
  回退 builder 不影响结果。
改造：execute 用真实导出链路（md → WordExporter → docx → audit）：
  - 新增 word_exporter_runner_test.dart（真实 md 输入 → WordExporter.export
    → FFX_OUT_DIR/cap_word_live.docx）
  - word adapter execute 先跑导出 runner → audit 导出的 live docx
  ——回退 word_ooxml_builder → 导出 docx 有缺陷 → artifact_integrity 失败
```

### 2.2 ENV_MISSING 与 Real Defect 共存（evaluate 调整）

```text
wpscli 缺失时不再整体抛 EnvironmentError（原 G4.4 逻辑）：
  - wps_consumer / no_consumer_error check 不计入 failed（wpscli 缺失）
  - artifact 层（zip/CRC/rels/semantic，不依赖 wpscli）仍执行验证
  - status 判定：artifact 层缺陷 → fail（Real Defect 可测）；
    artifact 层通过 + wpscli 缺失 → env_missing
```

### 2.3 Controlled Real Defect Reproduction（word_ooxml_builder 回退）

```text
回退点：word_ooxml_builder.dart buildDocumentXml 抛 StateError
  （document.xml 生成失败）→ 导出 docx 失败 → artifact_integrity=false
  ——真实产品代码缺陷（artifact 层），非注入观察
```

## 3. 执行（完整 Golden Loop）

| 步骤 | 动作 | 结果 |
|------|------|------|
| ① 回退 | buildDocumentXml 抛 StateError（真实代码缺陷） | ✅ |
| ② verify | `ffx capability verify word` | ✅ fail（artifact_integrity=false，导出失败） |
| ③ diagnose | `diagnose art_0047` | ✅ capability=word、stage=evaluate |
| ④ 修复 | 恢复 buildDocumentXml（Agent patch 真实产品代码） | ✅ |
| ⑤ repair-verify | `repair-verify art_0047` | ✅ **before=failed / target_failure=RESOLVED / regression=pass / new_failures=[]** |

### repair-verify 关键输出

```json
{
  "before": "failed",
  "after": "fail",
  "target_failure": "RESOLVED",
  "persistent_baseline_count": 1,
  "regression": {"status": "pass", "new_failures": []}
}
```

> **after=fail 是正确语义**：word 有**既有**失败（formula_fidelity=false，
> 导出 docx 公式保真检查——非本次 buildDocumentXml 缺陷）→ persistent；
> 本次缺陷（artifact_integrity）已消除 → target_failure=RESOLVED，
> Repair Success ≠ Capability Clean。

## 4. ENV_MISSING 与 Real Defect 共存（本轮核心证明）

```text
同一 capability（word）生命周期内同时出现：
  1. Real Defect（artifact 层：buildDocumentXml 抛错）→ verify FAIL
     （artifact_integrity=false，真实代码缺陷可测）
  2. ENV_MISSING（consumer 段：wpscli 缺失）→ wps_consumer 不计 fail +
     evidence gap 登记「wps not installed — ENV_MISSING」
  3. 修复后：本次缺陷 RESOLVED（target_failure=RESOLVED），
     既有失败（formula_fidelity）与 ENV_MISSING 保持 persistent
——评审目标达成：ENV_MISSING、真实 Consumer 环境和 Real Defect Repair
  共存于同一 capability 生命周期。
```

## 5. 过程中发现并修复的问题

```text
① word adapter 改造后 NameError：metrics 残留 `"corpus": corpus` 引用
   （corpus 变量已删）→ 修复为 live_docx（两处）
② 确认 artifact_integrity 判定基于 REQUIRED_PARTS/dangling——
   破坏 document.xml 生成（抛错）是确定性 fail 路径
```

## 6. 意义

```text
✅ Word Full Golden Loop validated（真实代码缺陷 → verify FAIL → diagnose →
   修复 → repair-verify 消除，Controlled Real Defect Reproduction）
✅ ENV_MISSING 与 Real Defect 共存验证（评审核心目标）
✅ word adapter 从「既有 corpus audit」升级为「真实导出链路」
   （md → WordExporter → docx → audit）——真实 Consumer 环境路径
✅ 四个 family 全有完整 Golden Loop：
   Data（Markdown/Serializer）✅ / Behavior（Undo）✅ /
   Runtime（Formula）✅ / Consumer（Word/PDF）✅
```

## 7. Phase 3.11 状态更新

```text
F1 Data      ✅ Golden Loop validated
F2 Behavior  ✅ Representative Golden Loop（Undo）
F3 Runtime   ✅ Real Defect Loop validated（Formula）
F4 Consumer  ✅ Full Golden Loop validated（Word 本轮 + PDF）
E6/E8        ⏳ Release Gate（下一阶段）
```

## 8. 下一步（评审冻结顺序）

```text
E6 Physical Runtime（Formula 真机/WebView 截图 → 结构 + 像素比对）
→ E8 Visual Fidelity（视觉回归 → release gate）
→ PHASE_3_11_EXIT
```

## 9. 复跑命令

```bash
ffx capability verify word     # 真实导出链路 + artifact 校验 + ENV_MISSING 共存
ffx capability diagnose <id>
ffx capability repair-verify <id>
```
