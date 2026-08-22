# Dogfood Run #002 — Known-Good（verify markdown/serializer vs Feature Matrix）

**日期**: 2026-08-19
**阶段**: Phase 3.10.1D Dogfood ② Known-Good（ROADMAP 节奏修订）
**命令**: `ffx capability verify markdown`（复跑）+ `ffx capability verify serializer`（尝试）
**结论**: ✅ **markdown Known-Good 通过且与 Matrix 一致；serializer 独立契约缺失（登记缺口）**

---

## 1. verify markdown（Known-Good 复跑）

```text
capability: markdown
status: warn                      ← s0 声明边界（autolink/footnote/definition_list）
checks: {parse ✅, serialize ✅, roundtrip ✅, no_parse_error ✅}
roundtrip_convergence: 1.0
files=15 / parse_ok=15 / roundtrip_converged=15 / line_errors=0
```

与 Smoke（Run #001）结果一致——**Known-Good 稳定复现** ✅。

## 2. verify serializer（独立契约缺失）

```text
capability: serializer
status: error
message: no contract found for capability 'serializer' under contracts/
evidence: (0 items)
```

**发现缺口（登记，非 bug）**：`contracts/` 仅 `markdown_parser.json`，
无 serializer 独立契约；`adapters/` 仅 markdown。

**但对照 Matrix 后确认**：serializer 在 Feature Capability Matrix 中**不是独立能力**，
而是 markdown 的 `Fidelity → round-trip S5` 子维度——因此 verify serializer
失败是「契约/矩阵结构差异」，**不是真实缺口**。验证 serializer 的正确方式是
`verify markdown`（其 serialize check 已覆盖）。

## 3. 与 Feature Capability Matrix 对照

| 维度 | Matrix（S0-S5） | FFX verify 实测 | 一致性 |
|------|----------------|----------------|--------|
| round-trip Fidelity | S5（运行时验证） | convergence=1.0 + 4 checks True | ✅ 一致 |
| s0_unsupported | Footnote S0 / Definition List S0 / Autolink S0 | contract s0=['autolink','footnote','definition_list'] | ✅ **完全一致**（人工 contract sync 已对齐） |
| serializer | 非独立能力（Fidelity 子维度） | verify serializer → error（无契约） | ✅ 结构一致（非缺口） |

**关键收获**：Matrix 的 S0 声明与 contract s0_unsupported **人工一致**——这正是
R12（contract sync 防矩阵漂移）要机器化的对齐点；本轮人工对照未发现漂移。

## 4. 缺口登记（本轮发现的真实待办）

```text
D1（R12 相关）：Matrix ↔ contract 一致性当前靠人工对照（本轮一致），
  未机器强制——登记 3.10.2 contract sync（Dogfood 前最小版）
D2（非真实缺口）：serializer 无独立契约——Matrix 定义其为 Fidelity 子维度，
  验证走 verify markdown 的 serialize check（已覆盖）；如未来要独立
  serializer capability 需 Matrix 先定义 S 级
```

## 5. 结论与下一步

```text
Known-Good PASS：
  - verify markdown 稳定 warn（s0 边界）+ 4 checks 全 True + convergence 1.0
  - 与 Feature Matrix 对照一致（round-trip S5 ≈ FFX 实测；s0 声明人工对齐）
  - serializer 无独立契约是结构差异非 bug（Matrix 为 Fidelity 子维度）

下一步（ROADMAP 3.10.1D）：
  ③ Known-Bad：故意回退 BUG-1 → verify 必须 FAIL 不误报
  ④ ADI/Consumer 联合：RenderOverflow / BUG-WORD-001 pdf2txt ❌
  ⑤ Real Agent Repair：before=fail → patch → after=pass → regression=pass
```
