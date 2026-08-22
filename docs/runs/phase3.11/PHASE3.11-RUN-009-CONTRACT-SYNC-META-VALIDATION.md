# PHASE3.11-RUN-009 — Contract-Sync Meta-Validation（四套 schema 自洽冻结）

**日期**: 2026-08-21
**阶段**: Phase 3.11 收口验证 / 3.11.5 contract-sync（评审 P0 优先级第 1 位）
**范围**: contract_sync 从「Matrix↔契约 s0 对齐」升级为 **Meta-Validation Layer**
（验证系统自身的语义是否自洽）
**结论**: ✅ **contract-sync = PASS——capability contract / failure identity /
evidence policy / repair semantics 四套 schema 彼此自洽，核心 verification
ontology 冻结，不再随 capability 扩展频繁修改**

---

## 1. 背景

```text
评审（Run-007 后）：
  「下一步不是继续扩 capability，而是进入 Phase 3.11 的收口验证阶段。
   先做 3.11.5 contract-sync，冻结验证系统自身。」
  危险场景：Capability verification = PASS + Contract interpretation = WRONG
  ——测试本身通过但结果语义已错，比普通业务 bug 更难发现。

现有 schema（11 contracts）：
  fingerprint v2 / evidence_profile / evidence_strength(+minimum_required) /
  support_policy / s0_unsupported / completion_policy(unknown_max)
corpus 资产：owner_capability / cross_capabilities / required_for /
  defect_attribution（Defect Attribution Contract）
```

## 2. 实现（contract_sync.py 升级）

### 2.1 Contract schema 自洽校验（M1-M4）

```text
M1: s0 声明数 vs unknown_max 自洽
    s0_unsupported(N) > completion_policy.unknown_max → error
    （否则 verify 必然 overflow 误报 fail——3.10 Re-Audit 暴露的真实矛盾）
M2: fingerprint v2 schema
    version==2 + fields 含四层（capability/failing_check/failure_class/
    evidence_signature）——fingerprint_version 保护历史 failure 集
M3: evidence_profile 级别合法
    值 ∈ {required, recommended, conditional, release-gate}
M4: evidence_strength 枚举合法
    achieved / minimum_required ∈ enum
    （policy-defined ordering，非普适全序）
```

### 2.2 Corpus 资产 schema 校验（_check_corpus_assets）

```text
verification_cases/**/*.json：
  - JSON 有效
  - owner_capability 必填（Defect Attribution）
  - cross_capabilities / required_for 为数组
  - required_for 应包含 owner_capability（owned 语义——防反向污染）
  - defect_attribution（Real Defect 资产）：owner / affected_capabilities /
    evidence_owner / repair_target 必填；affected 应含 capability
```

## 3. 验证结果

```text
首跑：contract-sync → status=error，抓到 1 个真实不自洽：
  ✗ bug_pdf_001_sanitize_empty.json required_for=["pdf"] 不含 owner='formula'
    （owned 语义违反——共享 renderer 缺陷的 required_for 必须含 owner formula）

修复：required_for → ["pdf", "formula"]

复跑：contract-sync → status=ok / exit=0 ✅
  11 contracts M1-M4 全部自洽
  2 个 corpus 资产通过（bug_001 / bug_pdf_001，含 defect_attribution）
  剩余 warnings：formula/ime 的 s0 在 Matrix 无独立条目（规则 3 设计内，
  额外能力边界提示，非漂移）
```

### 过程中顺带修复

```text
bug_pdf_001_sanitize_empty.json 有 3 处 JSON 字面换行（note/description/
reproduction_method 字段）→ JSON 无效 → 修复为单行
（正是 corpus 校验要抓的资产健康问题）
```

## 4. 意义

```text
✅ contract-sync 从「Matrix↔s0 对齐」升级为 Meta-Validation Layer：
  Capability verification ↑（被）Contract verification 校验
  ——测试结果语义错误（Capability PASS + Contract WRONG）可被机器发现
✅ 四套 schema 彼此自洽（contract / failure identity / evidence policy /
  repair semantics）——核心 verification ontology 冻结
✅ Defect Attribution Contract 纳入校验（真实缺陷归属：owner/affected/
  evidence_owner/repair_target）——防「哪个 Agent/capability/基础设施层
  真正解决了什么问题」指标污染
✅ corpus 资产健康守门（JSON 有效 + owned 语义 + attribution 完整性）
```

## 5. 结论

```text
3.11.5 Contract-Sync 完成（P0 收口验证第 1 关）：
  contract-sync = PASS（四套 schema 自洽）
  核心 verification ontology 冻结——后续 Word/Undo/Formula 扩展
  不再反复修改核心 contract 语义

下一步（评审冻结顺序）：
  F3 Runtime Real Defect Loop（Formula/Flutter Render——最大证据缺口）
  → Word Full Golden Loop（wpscli 环境）→ E6 Physical Runtime → E8 Visual Fidelity
  → PHASE_3_11_EXIT
```

## 6. 复跑命令

```bash
ffx analyze contract-sync   # → status=ok / exit=0（四套 schema 自洽）
```
