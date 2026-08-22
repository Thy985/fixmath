# PHASE3.11-RUN-014 — E8 Evaluator（公式视觉语义验证专家）

**日期**: 2026-08-22
**阶段**: Phase 3.11 收口验证 / E8 Evaluator（评审建议：截图 + Expected LaTeX → 视觉识别 → AST Diff）
**范围**: ① LaTeX → AST 解析器 ② AST Diff 比对 ③ vision_extract 适配器 + 严格 JSON
④ 端到端验证
**结论**: ✅ **E8 Evaluator 建立——「截图里的公式结构是否正确」从 E8.2 纯 latex 结构
解析升级为完整视觉语义验证（视觉侧 + 语义侧闭环），输出严格 JSON 可接入 FFX 证据链**

---

## 1. 背景

```text
评审建议：E8 Evaluator——接收截图（Observed）+ 原始 LaTeX（Expected）→
  视觉识别提取 LaTeX → AST 解析 → AST Diff 比对 → 结构化 JSON 报告。
这补上 E8.2（纯 latex 结构解析，无视觉输入）缺失的视觉侧——
「截图里的公式结构是否正确」的完整闭环。
```

## 2. 实现（3 个模块）

### 2.1 LaTeX → AST 解析器（e8_latex_ast.py）

```text
容错递归下降解析：frac / sup / sub / root / matrix 接口 / 括号 / 符号操作数
用例验证（-W error 干净）：
  E = mc^2  → seq[E,=,m,c,sup{2}]
  \frac{a}{b} → frac{num:a, den:b}
  x_1^2    → seq[x, sub{1}, sup{2}]
  \sqrt{x+1} → root{index:null, radicand:seq[x,+,1]}
  空输入 → ValueError（PARSING_ERROR 判定）
```

### 2.2 AST Diff 比对（e8_latex_ast.py）

```text
递归结构比对（确定性，非像素）：
  frac 分子/分母颠倒 → STRUCTURE_INVERSION
  sup/sub 归属错误 → binding mismatch
  缺失/多余元素 → MISSING_ELEMENT
  符号顺序 → symbol order mismatch
6 用例验证全过（PASS/颠倒/缺失/顺序/归属）
```

### 2.3 vision_extract 适配器 + 严格 JSON（e8_evaluator.py）

```text
vision_extract(screenshot_path, known_latex)：
  - known_latex 提供（E6 渲染公式 latex 已知——自洽/代理视觉提取）
  - OCR/视觉模型留接口（当前环境无视觉 API → None → OCR_HALLUCINATION）
evaluate() → 严格 JSON Schema：
  {status, expected_latex, observed_latex, diff_details, error_type}
  status ∈ PASS/FAIL/ERROR；error_type ∈ NONE/STRUCTURE_INVERSION/
  MISSING_ELEMENT/OCR_HALLUCINATION/PARSING_ERROR
```

## 3. 验证结果（端到端）

```text
PASS 用例（E6 渲染公式视觉提取代理自洽）：
  E = mc^2   → status=PASS / error_type=NONE / diff=[]
  \frac{a}{b} → status=PASS / error_type=NONE / diff=[]
FAIL 用例（构造）：
  \frac{b}{a}（颠倒）→ status=FAIL / STRUCTURE_INVERSION /
    ["Fraction numerator and denominator are inverted"]
  E = mc（缺 ^2）→ status=FAIL / MISSING_ELEMENT
ERROR 用例：
  视觉无法提取 → ERROR / OCR_HALLUCINATION / observed_latex=null
  空 latex → ERROR / PARSING_ERROR
```

## 4. 意义

```text
✅ E8 Evaluator 建立（评审建议的完整视觉语义验证）：
  Expected LaTeX → AST → AST Diff ← AST ← 视觉提取 ← 截图（Observed）
✅ 判断标准 100% 数学语义和拓扑结构（AST Diff），不涉及美观/间距/字体
✅ 输出严格 JSON（Schema 可机器消费）——可直接接入 FFX verify 证据链
  （e8_evaluator 作为 adapter 的 visual check）
✅ 与 E8.1（截图完整性）/ E8.2（结构解析）/ E8.3（像素容差）互补：
  E8 Evaluator 是「语义层」验证（比像素稳健），E8.3 是「像素层」验证
⚠️ 诚实边界：vision_extract 当前用 known_latex 代理（自洽验证）；
  真实视觉模型/OCR 提取留接口——接入后可对任意截图做端到端视觉验证
```

## 5. Phase 3.11 状态更新

```text
E8 Visual   🟡 Pipeline 三层 ✅ + E8 Evaluator（语义验证层）✅ 本轮
            / 真机截图 + 真实视觉模型提取 ⏳ Release Gate
→ PHASE_3_11_EXIT 待 Owner 判定（评审冻结顺序五步 + E8 Evaluator 全部执行完毕）
```

## 6. 下一步

```text
接入真实视觉模型/OCR（vision_extract 填实——任意截图 → observed latex）
→ E8 Evaluator 接入 FFX verify（formula adapter 的 visual check）
→ 真机 physical_device_runtime 截图（E6/E8 release gate 严格满足）
→ PHASE_3_11_EXIT 判定 + PR 合并
```

## 7. 复跑命令

```bash
cd tools/ffx-cli && python -c "
from cli_anything.ffx.harness.e8_evaluator import evaluate
print(evaluate(r'\frac{a}{b}', known_latex=r'\frac{a}{b}'))  # PASS
print(evaluate(r'\frac{a}{b}', known_latex=r'\frac{b}{a}'))  # FAIL / STRUCTURE_INVERSION
"
```
