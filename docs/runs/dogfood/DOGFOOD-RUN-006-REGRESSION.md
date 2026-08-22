# Dogfood Run #006 — REGRESSION path 补齐（serializer 第 2 capability）

**日期**: 2026-08-20
**阶段**: Phase 3.10.1D Dogfood ⑤ 补充——REGRESSION path（D5 闭环）
**命令**: `ffx capability verify serializer` + `ffx capability repair-verify art_0005`
**结论**: ✅ **REGRESSION path 真实验证通过（5 条证据链全部完整）**

---

## 1. 背景（D5 登记）

```text
Run #005 时 registry 仅 markdown 单 capability → regression 输出
"only 1 capability in registry (P0.1)"（n/a）——跨能力回归无法验证。
本轮补齐：建第 2 个 capability（serializer）+ 修改 orchestrator regression
逻辑（遍历其他 capability 验证），REGRESSION path 真实验证。
```

## 2. 补齐内容

### 2.1 serializer capability（第 2 个）

```text
contracts/serializer.json（新建）
  id: FEAT-MD-SERIALIZE / capability: serializer / version: 1
  required_checks: [serialize, roundtrip, no_parse_error]（聚焦序列化保真）
  completion_policy: roundtrip_convergence_min 0.99 / parse_error_max 0
  s0_unsupported: [autolink, footnote, definition_list]

tools/ffx-cli/.../harness/adapters/serializer.py（新建，156 行）
  SerializerAdapter：复用 markdown runner（run_markdown）round-trip 指标，
  5 阶段证据链（discover/prepare/execute/collect_evidence/evaluate）
  修复过程：collect_evidence 抽象方法对齐 + run_markdown 接口对齐

tools/ffx-cli/.../harness/adapters/__init__.py（注册）
  _ADAPTERS = {markdown: MarkdownAdapter, serializer: SerializerAdapter}
```

### 2.2 orchestrator regression 逻辑（D5 修复）

```text
orchestrator.py repair_verify：
  regression 从硬编码 n/a → 遍历 available() 中非当前 capability，
  各自 verify：
    - 任一 fail → regression status=fail（修复引入回归）
    - 全非 fail → regression status=pass（未回归）
  输出 checked / results / detail
```

## 3. 验证结果

### 3.1 serializer 独立验证

```text
ffx capability verify serializer → status: warn
  roundtrip_convergence: 1.0（序列化保真达标，s0 声明边界 → warn）
  exit=2（WARN 码）
```

### 3.2 REGRESSION path 真实验证（repair-verify art_0005）

```text
构造：临时回退 BUG-1（markdown_parser.dart:326）→ verify markdown FAIL
     （convergence 0.9333，art_0005 落盘 before=failed）
Agent patch：恢复 BUG-1 修复
repair-verify art_0005：
  before: failed
  after: warn                          ← markdown 修复还原
  regression:
    status: pass                        ← ✅ REGRESSION path 验证
    detail: regression check over ['serializer']: {'serializer': 'warn'}
    checked: ['serializer']
    results: {'serializer': 'warn'}    ← serializer 未回归（warn 非 fail）
  evidence_delta: checks False→True、convergence 0.9333→1.0
```

**关键**：修复 markdown 后，serializer 能力仍 warn（未 fail）→
regression=pass——跨能力回归检测真实生效。

## 4. Dogfood 5 条证据链最终状态

```text
PASS path      ✅（Run #002 Known-Good）
FAIL path      ✅（Run #003 Known-Bad）
DIAGNOSE path  ✅（Run #003/⑤ failure record + diagnose 聚合）
REPAIR path    ✅（Run #005 repair-verify 重新证明）
REGRESSION path ✅（Run #006 本轮补齐：registry ≥2 真实验证 serializer 未回归）

Phase 3.10.1D Dogfood 五轮 + REGRESSION 补齐全部完成 → 退出条件
「Dogfood 5 条证据链全通」达成 ✅
```

## 5. 结论

```text
REGRESSION path 补齐完成：
  - registry 双 capability（markdown + serializer）
  - orchestrator regression 逻辑改为遍历其他 capability 验证
  - repair-verify art_0005 实测：regression status=pass（serializer 未回归）
  - 5 条证据链全部完整（PASS/FAIL/DIAGNOSE/REPAIR/REGRESSION）

Phase 3.10.1D Dogfood 退出条件达成：验证编排器经真实项目能力
（markdown 已知通过/已知破坏 + serializer 跨能力回归）完整闭环。
```
