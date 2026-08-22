# PHASE3.11-RUN-004 — Failure Identity 四层冻结 + Formula 跨证据层 Golden Loop

**日期**: 2026-08-20
**阶段**: Phase 3.11 Capability Hardening Loop / 3.11.4 Formula + 评审 §2/§3/§4/§6/§7 落地
**范围**: ① Failure Identity 四层冻结 ② regression corpus capability 归属
③ 四层质量闭环 + N=4 families ④ Formula Run-004 跨证据层 Golden Loop
**结论**: ✅ **Formula 进入 Runtime 证据层（ADI 观察消费）——Golden Loop 跨出 Data 层；
Failure Identity 四层冻结；PHASE_3_11_EXIT 明确化（Defined 非 Satisfied）**

> **⚠️ Loop 类型声明（评审 §6，2026-08-20）**：本 Run 为 **Synthetic Failure
> Loop**——Failure A（SVG parse）是**人为注入观察**（err_20260820_svgparse），
> 「修复」= 移除注入，证明的是**系统能识别并清除一个新 failure identity**
> （Evidence → Fingerprint → Diagnose → Repair → Evidence Delta → Regression）。
> **尚不证明 Real Defect Repair Loop**（Agent 修复真实 SVG parser/render pipeline
> 产品缺陷）——后者登记下一阶段（3.11.4 后续：真实渲染缺陷 → reproduce →
> observe → fingerprint → agent diagnose → code fix → rebuild → rerun →
> evidence delta → regression）。

---

## 1. ① Failure Identity 四层冻结（评审 §2）

```text
旧（v1）：fingerprint = capability + failed checks
  风险：同一 check 不同 bug 无法区分（formula render_observable 失败可能来自
  WebView 未挂载/字体缺失/SVG parse 错/布局失败/GPU 失败——都归一个指纹）

新（v2 四层）：fingerprint = capability + failing_check + failure_class + evidence_signature
  例：formula:render_observable:check_failure:adi=err_svgparse
     formula:render_observable:check_failure:adi=err_renderoverflow
  ——同一 check 下不同 bug（evidence_signature 区分）真正分开

contract schema：11 contracts 加 fingerprint {version: 2,
  fields: [capability, failing_check, failure_class, evidence_signature]}
  ——防半年后 check 改名导致历史 failure 集突然全部变「新 Bug」（fingerprint_version 保护）
```

## 2. ② regression corpus capability 归属（评审 §3）

```text
bug_001_hard_break.json 增加：
  owner_capability: "markdown"
  cross_capabilities: ["serializer"]
  required_for: ["markdown", "serializer"]
——防「Serializer 被 Markdown case 扫进去 → verify serializer 变
  Serializer+Markdown 兼容性总测试」污染（owned / cross-capability /
  shared infrastructure 三类可区分）
```

## 3. ③ 四层质量闭环 + N=4 families（评审 §7/§4）

```text
Layer 1 — Data        Parse/Serialize/Round-trip     （Run-002/003 ✅）
Layer 2 — Behavior    Undo/Transaction/IME/Autosave
Layer 3 — Runtime     Flutter Render/WebView/Device   （Run-004 🟡 Formula 进入）
Layer 4 — Consumer/体验 WPS/OfficeCLI/Screenshot/Visual/Human UX

PHASE_3_11_EXIT：N = 4 capability families
  Data ✅（Markdown/Serializer）| Runtime 🟡（Formula/Undo）
  Consumer 🟡（Word/PDF）| Physical/Visual 🟡（E6/E8）
状态：Defined（非 Satisfied）——不提前宣布 Phase 3.11 close
```

## 4. ④ 3.11.4 Formula Run-004（评审 §5/§6 跨证据层 Golden Loop）

### Failure A：逻辑/渲染失败（SVG parse）—— Golden Loop 普通扩展

| 步骤 | 动作 | 结果 |
|------|------|------|
| ① 基线 | `verify formula` | fail（既有 RenderOverflow 观察 err_20260816160407） |
| ② 扩展 | formula adapter 渲染失败关键词加 SvgParse/FormulaSvg/svg（failure_class 区分） | ✅ |
| ③ 注入 | 注入 SVG parse 观察（err_20260820_svgparse）→ verify formula | fail（render_failure_count 1→2，**新指纹**） |
| ④ diagnose | `diagnose art_0028` | ✅ capability=formula，checks failed no_adi_render_failure |
| ⑤ 修复 | 移除注入观察（Agent fix） | ✅ |
| ⑥ repair-verify | `repair-verify art_0028` | ✅ evidence_delta: err_svgparse → err_renderoverflow（SVG 失败消除）、render_failure_count 2→1、regression=pass、new_failures=[] |

**关键**：after=fail 是正确语义——formula 有**既有** RenderOverflow 观察
（persistent，非本次引入）；SVG parse 失败（新指纹）已被修复并 diff 出来。

### Failure B：视觉失败（E6/E8）—— 设计 + Release Gate 登记

```text
设计（评审 §6）：公式结构存在但截图分式/上下标错误
  = Artifact/Runtime PASS + Visual FAIL——不能因「SVG 文件存在」宣布 PASS
证据需求：E6 physical runtime + E8 visual fidelity
当前状态：evidence_profile E6=release-gate；headless 渲染器 s0
→ 登记 Release Gate（formula contract note）：真机/截图环境就绪后执行
  视觉回归（screenshot → 像素/结构比对）
```

## 5. 结论

```text
Run-004 达成：
  ① Failure Identity 四层冻结（capability+check+failure_class+evidence_signature
     + contract fingerprint v2 schema）——防 check 改名致历史 failure 集突变
  ② regression corpus capability 归属（owner/cross/required_for）——防交叉污染
  ③ 四层质量闭环 + N=4 families 明确化（PHASE_3_11_EXIT Defined 非 Satisfied）
  ④ Formula 跨证据层 Golden Loop：Failure A（SVG parse）闭环证明 Golden Loop
     从 Data 层进入 Runtime 层（ADI 观察消费）；Failure B（E6/E8）设计登记

Phase 3.11 体系正式成为四层质量闭环：
  Data（✅）→ Runtime（🟡 本轮进入）→ Consumer（🟡）→ Physical/Visual（🟡）
```

## 6. 下一步

```text
3.11.5 Word/PDF 加固（Consumer 层：WPS/OfficeCLI/pdf2txt/ADI——基础设施最强）
3.11.6 Undo/IME/Autosave/File/Theme/Block（Behavior + Physical/Visual 层）
3.11.7 contract-sync 增强（s0 vs unknown_max 自洽）
```

## 7. 复跑命令

```bash
ffx capability verify formula        # 读 .adi 观察，RenderOverflow/SvgParse 失败类
ffx capability diagnose <id>         # 聚合失败上下文
ffx capability repair-verify <id>    # fingerprint diff（四层）判定回归
```
