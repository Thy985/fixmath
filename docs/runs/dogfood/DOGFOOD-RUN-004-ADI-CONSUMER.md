# Dogfood Run #004 — ADI/Consumer 联合

**日期**: 2026-08-19
**阶段**: Phase 3.10.1D Dogfood ④ ADI/Consumer 联合
**命令**: `ffx analyze audit <docx>`（Consumer）+ `ffx adi latest-error / trace-show / replay`（ADI）
**结论**: ✅ **两链路部分验证 + 关键缺口登记（word/render/formula capability 契约缺失）**

---

## 1. Consumer 联合（BUG-WORD-001 公式丢失场景）

### 验证链（同 Run #003 模式，作用于 Word 消费端）

```text
① 临时回退 BUG-WORD-001（word_ooxml_builder.dart:376 widthEmu>0 → info!=null）
② 生成含公式 docx（cap_word_dogfood4.docx，size=3953）
③ ffx analyze audit → wps_semantic_text 文本预览 '公式 结尾'（E=mc² 丢失）
④ 发现：consumer 检查误报（status=pass，公式丢了但文本非空）
⑤ 修复 docx_qa：增加公式内容保真检测（_extract_formula_signals +
   formula_fidelity 字段）——docx 内部 latex 特征片段必须出现在消费端文本
⑥ 恢复 BUG-WORD-001 生产代码
```

### 结果

| 项 | 修复前 | 修复后 |
|----|--------|--------|
| 正常产物（cap_word_fix.docx，含公式 fallback） | — | ✅ formula_fidelity ok=true / missing=[] / status=pass |
| 回退产物（cap_word_dogfood4.docx，公式走图片引用） | 误报 pass | ⚠️ signals=[] / missing=[]（docx 内部无公式文本信号） |

### 关键结论（「产物成功 ≠ 功能正确」验证）

```text
✅ 发现并修复了 docx_qa 的 consumer 误报：公式内容保真检测已加入
  （docx 内部有 latex fallback → 消费端必须含），正常产物验证通过
⚠️ 边界登记 D3：BUG-WORD-001 回退后 docx 内部即无公式文本信号
  （公式走空图片引用），docx_qa 单产物检测提取不到 signals →
  完整检测需 word capability contract + 输入期望模型（registry 当前无）
```

## 2. ADI 联合（RenderOverflow 场景）

### 验证链（latest-error → trace-show → replay）

```text
ffx adi latest-error
  → RenderOverflow（session sess_2f78 / trace trc_0001 / snapshot_available=True）
ffx adi trace-show trc_0001
  → 4 层因果链：interaction → command → render → error
    causality: valid=True / rootSpanId=span_1 / failureSpanId=span_4
ffx adi replay sess_2f78
  → not_reproduced（commandsExecuted=1 / hashMatch=True）——修复后状态
```

### 结果

| 链路 | 结果 | 结论 |
|------|------|------|
| latest-error | ✅ RenderOverflow 观察可消费 | 产品失败 → ADI observation 连接成立 |
| trace-show | ✅ 4 层因果链 valid（含 causality 根因/失败 span） | 失败可归因 |
| replay | ✅ not_reproduced（修复后不复现） | Run #006/#007 闭环结果可用 |

### 关键结论

```text
✅ ADI 证据链（latest-error → trace-show → replay）完整可用——
   FFX 能把产品失败连接到 ADI 证据（observation + trace + replay）
⚠️ 缺口登记 D4：capability registry 无 render/formula adapter
   （contracts/ 仅 markdown_parser.json）→ `ffx capability verify formula`
   （RenderOverflow 对应能力）无法直接跑；verify→diagnose→replay 的
   verify 环节需 render adapter 才能自动衔接 ADI
```

## 3. 缺口登记（本轮新增）

```text
D3（④ Consumer）：BUG-WORD-001 完整检测需 word capability contract +
   输入期望模型（docx_qa 单产物检测无法覆盖「docx 内部公式消失」）
   —— 对应 ROADMAP 3.10.3 consumer adapter
D4（④ ADI）：render/formula capability contract + adapter 缺失——
   verify formula 无法衔接 ADI 证据链 —— 对应 ROADMAP 3.10.3
D1（已登记）：Matrix ↔ contract 一致性未机器强制（3.10.2 contract sync）
```

## 4. 结论与下一步

```text
④ ADI/Consumer 联合部分验证：
  ✅ Consumer：docx_qa 公式保真检测已修复（误报 → 正常产物 ok=true）
  ✅ ADI：latest-error → trace-show → replay 链路完整可用
  ⚠️ word/render/formula capability 契约缺失（D3/D4）——verify 环节
     需 adapter 才能对 BUG-WORD-001 / RenderOverflow 自动 verify

下一步（ROADMAP 3.10.1D）：
  ⑤ Real Agent Repair：Known Bug → verify FAIL → diagnose → Agent patch
     → repair-verify → before=fail / after=pass / regression=pass
  前置：建 word/render contract + adapter（D3/D4）后 verify 才可用
  （或先用 markdown 跑 ⑤ 验证 repair-verify 链路）
```
