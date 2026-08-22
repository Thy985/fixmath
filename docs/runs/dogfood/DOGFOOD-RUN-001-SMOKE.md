# Dogfood Run #001 — Smoke（ffx capability verify markdown）

**日期**: 2026-08-19
**阶段**: Phase 3.10.1D Dogfood ① Smoke（ROADMAP 节奏修订后首轮）
**命令**: `ffx capability verify markdown`
**结论**: ✅ **PASS（warn 语义正确）—— real_runtime_path=true 验证通过**

---

## 1. 运行结果

```text
capability: markdown
status: warn                       ← 正确语义（s0_unsupported 非空 → 非阻断 unknown）
coverage:
  roundtrip_convergence: 1.0
  checks: {parse: True, serialize: True, roundtrip: True, no_parse_error: True}
  unknown_max: 3
  blocking_unknown: []
unknown: []                        ← 无证据缺口（s0 声明边界单独在 declared_boundaries）
next_actions:
  - decide S0 scope: ['autolink', 'footnote', 'definition_list']
EXIT=0
```

## 2. real_runtime_path 验证（本轮核心断言）

| 证据 | 内容 | 结论 |
|------|------|------|
| execute 阶段 `tool=dart-runner` | evidence stage=execute, exit_code=0 | ✅ 真实 runner |
| artifact 落盘 | `.ffx/tmp/verify/markdown-*/result.json`（513B） | ✅ 真实产物 |
| metrics 真实性 | files=15 / parse_ok=15 / roundtrip_converged=15 / elements 统计（Heading/EmptyLine/Paragraph/List/Blockquote/Code/Mermaid/Table/TaskListItem/HorizontalRule） | ✅ 生产 parser 真实输出 |
| runtime_bridge 调用链 | `subprocess.run([flutter, test, tool/capability_runner/capability_runner_test.dart])` | ✅ 非 fixture/mock |

**断言 `real_runtime_path=true` 成立**：evidence 来自真实 `flutter test` 执行
生产 `MarkdownParser`/`MarkdownSerializer`，非测试 fixture 或 JSON mock。

## 3. evidence graph（5 阶段链完整）

```text
discover → repo root 定位（ffx）
prepare  → corpus absent → built-in corpus（15 文件）
prepare  → out_dir 创建（.ffx/tmp/verify/markdown-*）
execute  → dart-runner：files=15 roundtrip_conv=1.0（真实 runner 输出）
collect  → policy 读取（unknown_max=3 / blocking_unknown=[] / s0 声明）
```

## 4. 问题与修复

```text
发现问题：无。
status=warn 是正确语义（R3 修复后：s0_unsupported 非空 → 非阻断 unknown → warn），
非 bug——契约要求「declared boundary 不阻断但提示 decide S0 scope」。

本轮验证的 R3/R4/R6/R10/R14 修复全部生效：
  R3  unknown_max/blocking_unknown 被读取（coverage 输出可见）
  R4  serialize check 存在且 True
  R6  unknown=[] 与 declared_boundaries 分离
  R10 parse_ok=15（完整链路成功后计数）
  R14 next_actions 含 "decide S0 scope"
```

## 5. 结论与下一步

```text
Smoke PASS：FFX 正确编排（contract → runtime_bridge → 生产 parser →
evidence graph → completion），且真实调用生产代码（real_runtime_path=true）。

下一步（ROADMAP 3.10.1D）：
  ② Known-Good Dogfood：verify markdown + serializer，与 Feature Capability
     Matrix 对照
  ③ Known-Bad：故意回退 BUG-1，verify 必须 FAIL 不误报
  ④ ADI/Consumer 联合：RenderOverflow / BUG-WORD-001 pdf2txt ❌
  ⑤ Real Agent Repair：before=fail → patch → after=pass → regression=pass
```
