# Dogfood Run #007 — Consumer Adapter 扩展（word/formula capability，D3/D4 闭环）

**日期**: 2026-08-20
**阶段**: Phase 3.10.3 consumer adapter 扩展（D3：word 公式保真 / D4：formula ADI 衔接）
**命令**: `ffx capability verify word` + `ffx capability verify formula`
**结论**: ✅ **word/formula 双 capability 建立，D3/D4 闭环——registry 四能力**

---

## 1. 背景（D3/D4 登记于 Run #004）

```text
D3（④ Consumer）：BUG-WORD-001 完整检测需 word capability contract +
   输入期望模型——docx_qa 单产物检测无法覆盖「docx 内部公式消失」
D4（④ ADI）：render/formula capability contract + adapter 缺失——
   verify formula 无法衔接 ADI 证据链
本轮：建 word + formula 双 capability，D3/D4 闭环
```

## 2. 建立内容

### 2.1 word capability（D3）

```text
contracts/word_export.json（新建）
  capability: word / id: FEAT-WORD-EXPORT
  required_checks: [artifact_integrity, wps_consumer, formula_fidelity, no_consumer_error]
  completion_policy: wps_consumer_required=true / formula_fidelity_required=true
  s0_unsupported: [microsoft_word_desktop]（Level C Release Gate 边界）

tools/ffx-cli/.../harness/adapters/word.py（新建，195 行）
  WordAdapter：复用 docx_qa.audit_docx（ffx analyze audit 核心）作为
  metrics 来源——artifact_integrity / wps_compatibility /
  wps_semantic_text.formula_fidelity（DOGFOOD-RUN-004 修复字段）/
  officecli_issues
  corpus：既有真实导出产物（D:/Temp/word_consumer/cap_word_fix.docx）
```

### 2.2 formula capability（D4）

```text
contracts/formula.json（新建）
  capability: formula / id: FEAT-FORMULA
  required_checks: [no_adi_render_failure, render_observable]
  completion_policy: render_error_max=0 / adi_binding_required=true
  s0_unsupported: [mermaid_renderer_headless, real_llm_agent]

tools/ffx-cli/.../harness/adapters/formula.py（新建，175 行）
  FormulaAdapter：读 .adi/observations/err_*.json 最新观察，
  收集 RenderOverflow/RenderFlex 失败 → 衔接 ADI 证据链
  （latest-error → trace-show → replay）
```

### 2.3 registry（四能力）

```text
adapters/__init__.py：markdown / serializer / word / formula
```

## 3. 验证结果

### 3.1 verify word（D3：公式保真）

```text
capability: word
status: warn                        ← s0 边界（microsoft_word_desktop）
wps_compatibility: pass             ← WPS consumer 验证通过
formula_fidelity: ok（cap_word_fix.docx 含 E=mc² fallback）
exit=2（WARN 码）
→ word 能力可自动 verify（含公式内容保真检查，BUG-WORD-001 检测点就绪）
```

### 3.2 verify formula（D4：ADI 衔接）

```text
capability: formula
status: FAIL                        ← ✅ 预期（ADI 存在未解决渲染观察）
render_failure_count: 1
adi_latest_observation: err_20260816160407（RenderOverflow）
failed checks: ['no_adi_render_failure']
exit=1（FAIL 码）
next_actions: adi trace-show / replay 诊断
→ formula 能力正确把产品失败连接到 ADI 证据链，不误报 PASS
```

**关键**：verify formula=fail 是**正确行为**——`.adi/` 中存在 RenderOverflow
观察（Run #006 采集），FFX 检测到未解决渲染失败 → fail + 指引 ADI 诊断。
这验证了 D4 核心目标：FFX 不是测试 runner，而是能把产品失败连接到 ADI。

## 4. 意义

```text
✅ word capability（D3）：BUG-WORD-001 公式丢失可自动 verify
  （docx_qa consumer 检查 + formula_fidelity 字段）
✅ formula capability（D4）：RenderOverflow 可 verify + 衔接 ADI
  证据链（latest-error → trace-show → replay）
✅ registry 四能力（markdown/serializer/word/formula）——跨能力回归
  对比对象更丰富
⚠️ 完整链路边界（3.10.3 后续轮）：word 需「输入 md → 导出 → 消费端」
  全链路 runner；formula 需真实渲染 corpus（headless 渲染器为 S0）
```

## 5. 资产

```text
contracts/word_export.json（新建）/ contracts/formula.json（新建）
adapters/word.py（新建，195 行）/ adapters/formula.py（新建，175 行）
adapters/__init__.py（四能力注册）
复跑：ffx capability verify word / ffx capability verify formula
```
