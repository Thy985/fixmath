# ADL Loop Run #005 — Real Production Code Repair Proof

**日期**: 2026-08-17
**前置**: Run #001-004 已验证 ADI 架构和 fault injection 闭环
**状态**: 方案设计（Run #004 遇到 widget test 根本限制，本计划修正闭环定义）

---

## 核心修正：闭环需要三个独立证明层

Run #004 证明了故障注入闭环协议。但缺少最关键的一环：**Agent 修改了真实生产代码 + 重新构建后真实产品行为恢复**。

> **定位声明（2026-08-17 修订）**：本计划与 Run #005 执行证明的是
> **Production Code Repair Verifiability Proof**（真实生产代码修复的**可验证性**），
> **不是** Agent Autonomous Repair。修复动作由确定性脚本 `run005_apply_fix.dart`
> 执行，P2 只能证明「生产源码确实被修改」，不能证明「Agent 从 Observation
> 推理出修改并自主执行」——后者是 Run #006 的职责（见「Run #005 vs Run #006 边界」）。

定义三个独立证明层：

| 层 | 验证什么 | 方法 | 对应谓词 |
|----|---------|------|---------|
| **B: Patch Authenticity** | Agent 真的改了生产代码吗？ | git diff 审计 | P2 |
| **A: Runtime E2E** | 改完代码后产品行为真的恢复了吗？ | 真机/flutter drive | P3, P5 |
| **C: Pipeline/Protocol** | ADI/Replay/Validation 管道没坏吗？ | 现有测试 | P1, P4, P6 |

三者缺一不可，不是替代方案。

---

## Run #005 成功标准（6 条谓词，全部必须为 true）

```json
{
  "P1_before_reproduced": true,
  "P2_agent_patch_authenticity": true,
  "P3_real_runtime_after_fix": true,
  "P4_invariants_pass": true,
  "P5_replay_not_reproduced": true,
  "P6_capability_regression_pass": true
}

PASS = P1 ∧ P2 ∧ P3 ∧ P4 ∧ P5 ∧ P6
```

### 各谓词精确定义

| 谓词 | 定义 | 验证方法 | 来源 |
|------|------|---------|------|
| **P1** | 修复前 replay 复现 bug | `adi replay → status: reproduced` | C 层 |
| **P2** | Agent 修改了生产代码（非测试代码） | `git diff` 包含生产源码修改，排除测试文件 | B 层 |
| **P3** | 修复后真实产品行为恢复 | 真机/integration test 验证无 overflow | A 层 |
| **P4** | 系统不变量通过 | `invariants.allPassed == true` | C 层 |
| **P5** | 修复后 replay 不复现 | `adi validate → after: not_reproduced` | C 层 |
| **P6** | 产品能力未退化 | 原有 CLI 命令仍正常执行 | C 层 |

**关键区分**：
- P2 证明「Agent 做了什么」
- P3 证明「做对了」
- 两者缺一不可

---

## Phase 0: 建立已知坏状态

```bash
# 在 code_block.dart 中引入真实 bug（永久 commit）
# 这不是测试代码，是生产代码的 intentional regression

# 修改 flutter_app/lib/presentation/blocks/code/code_block.dart:
# 在 Column children 末尾添加：
const SizedBox(height: 100000),  // BUG: unbounded height

# Commit 此修改
git add flutter_app/lib/presentation/blocks/code/code_block.dart
git commit -m "test(run005): introduce known RenderOverflow bug in CodeBlock"

# 记录 commit hash
BAD_COMMIT=$(git rev-parse HEAD)
```

这样「Agent 修改源码」变成 Git 可审计的事实，不是测试内模拟。

---

## Phase 1: 真实产品触发 bug（A 层）

```bash
# 启动模拟器，安装 bug 版本 APK
flutter build apk --debug
adb install app-debug.apk

# 运行真实设备测试（flutter drive 或 Patrol）
# 注意：不使用 widget test，使用真实 Flutter runtime
flutter drive \
  --target=test/integration_test/run005_bug_repro_test.dart \
  --device-id=emulator-5554

# ADI 捕获真实 crash
ffx --json adi latest-error
# 期望: {"status":"error","error_type":"RenderOverflow",
#         "session_id":"sess_xxx","trace_id":"trc_xxx"}

ffx --json adi replay sess_xxx
# 期望: {"status":"reproduced","failedAt":"step 0:..."}

# P1 验证
assert replay_status == "reproduced"  → P1 = true
```

**与 Run #004 的关键区别**：
- Run #004: widget test + FaultInjection 模拟 overflow
- Run #005 Phase 1: 真机 + 真实 RenderOverflow（来自生产代码 bug）

---

## Phase 2: 生产代码修改（B 层）

> **执行注记（2026-08-17）**：实际执行中修复动作由确定性脚本
> `run005_apply_fix.dart` 完成，**不是** Agent 从 Observation 推理后自主执行。
> 下面的命令序列描述的是计划中的「Agent 操作」形态，对应 Run #006 的自主修复目标。

Agent 根据 ADI 证据修改生产代码（计划形态）：

```bash
# Agent 读取证据
ffx --json adi trace-show trc_xxx
# → 定位到 code_block.dart 的 RenderParagraph overflow

# Agent 查看源码
cat flutter_app/lib/presentation/blocks/code/code_block.dart
# → 发现 const SizedBox(height: 100000) 在 Column children 中

# Agent 修改生产代码（移除 bug）
sed -i '/const SizedBox(height: 100000)/d' \
  flutter_app/lib/presentation/blocks/code/code_block.dart

# Agent 验证 diff
git diff flutter_app/lib/presentation/blocks/code/code_block.dart
# 期望: 仅修改 code_block.dart，移除 SizedBox(height: 100000)

# Agent 提交修复
git add flutter_app/lib/presentation/blocks/code/code_block.dart
git commit -m "fix(code_block): remove unbounded SizedBox causing RenderOverflow"

# P2 验证（自动化检查）
diff_files=$(git diff --name-only HEAD~1 HEAD)
assert "flutter_app/lib/presentation/blocks/code/code_block.dart" in diff_files
assert diff_contains("SizedBox(height: 100000)") == false
assert no_test_file_modified()  # Agent 不能只改测试
→ P2 = true
```

**与 Run #004 的关键区别**：
- Run #004: 测试代码中设置 `FaultInjection.enabled = false`
- Run #005 Phase 2: Agent 修改 `code_block.dart` 生产源码 + git diff 审计

---

## Phase 3: 重新构建并部署（A 层）

```bash
# 重新编译（确保构建缓存不干扰）
flutter clean
flutter build apk --debug

# 重新安装到模拟器
adb uninstall com.formulafix.formula_fix
adb install app-debug.apk

# 启动 App 验证安装成功
adb shell am start -n com.formulafix.formula_fix/.MainActivity
```

**与 Run #004 的关键区别**：
- Run #004: 没有重新构建，只是内存状态改变
- Run #005 Phase 3: 完整 rebuild + reinstall，证明修复在真实 runtime 中生效

---

## Phase 4: 重新验证故障不再复现（A + C 层）

```bash
# 方法 1: 使用相同 session 的 replay（理想情况）
ffx --json adi replay sess_xxx
# 期望: {"status": "not_reproduced"}

# 方法 2: 如果没有 cached replay，运行新测试
flutter drive \
  --target=test/integration_test/run005_postfix_test.dart \
  --device-id=emulator-5554
# 期望: 无 overflow，CodeBlock 正常渲染

# ADI validate
ffx --json adi validate --after-fix sess_xxx
# 期望: {"after": "not_reproduced", "invariants": {"allPassed": true}}

# P3, P4, P5 验证
assert replay_status == "not_reproduced"  → P3 = true, P5 = true
assert invariants_all_passed == true      → P4 = true
```

---

## Phase 5: CLI Capability 回归验证（C 层）

```bash
# 验证产品能力未退化
ffx --json project create -o /tmp/doc.json -n "TestDoc"
ffx --json project inject code -p /tmp/doc.json --lang dart --code 'void main(){}'
ffx --json project info -p /tmp/doc.json
# 期望: word_count > 0, code_block_count >= 1, status = "ok"

# P6 验证
assert project_info["word_count"] > 0      → P6 = true
assert project_info["code_block_count"] >= 1 → P6 = true
```

---

## Phase 6: 完整证据导出

```bash
# 汇总所有证据
git log --oneline -3                    # 记录 bug commit + fix commit
git diff HEAD~1 HEAD                    # 记录生产代码修改
ffx --json adi doctor                   # 系统健康
ffx --json adi latest-error --json      # 原始错误证据
ffx --json adi validate --after-fix sess_xxx  # 修复验证

# 结构化输出
{
  "run": "005",
  "status": "real_production_code_repair_proven",
  "predicates": {
    "P1_before_reproduced": true,
    "P2_agent_patch_authenticity": true,
    "P3_real_runtime_after_fix": true,
    "P4_invariants_pass": true,
    "P5_replay_not_reproduced": true,
    "P6_capability_regression_pass": true
  },
  "bug_commit": "<bad_commit_sha>",
  "fix_commit": "<good_commit_sha>",
  "evidence_path": ".adi/..."
}
```

---

## 当前环境的可行性评估

### 问题

Run #004 尝试直接修改生产代码并在 widget test 中验证，遇到了 **Flutter widget test 的根本限制**：

```
真实 overflow 在生产代码中
  ↓
每次 pump() 触发新的 RenderOverflow
  ↓
FlutterError.onError 恢复时序问题
  ↓
binding._pendingExceptionDetails assertion 失败
  ↓
测试超时
```

这是因为 widget test 的 `FakeAsync` zone 中，widget tree 的每个 rebuild 都会重新触发 layout overflow。

### 解决方案

**Run #005 必须使用 integration test（flutter drive）而非 widget test**：

```bash
# 正确的测试方式
flutter drive \
  --target=test/integration_test/run005_test.dart \
  --device-id=emulator-5554
```

Integration test 在真实 Flutter runtime 上运行，不受 FakeAsync zone 限制。overflow error 由真实 Flutter framework 处理，不会触发 binding 超时。

---

## Run #005 vs Run #006 边界

| | Run #005 | Run #006 |
|--|---------|---------|
| **核心目标** | 真实源码修复证明（Verifiability） | 完整 Agent 自主修复 E2E（Autonomy） |
| **修改方式** | 确定性脚本 `run005_apply_fix.dart` 修改 | Agent 全程自主（诊断→修复→验证） |
| **Runtime** | 真机/flutter drive（实际：双进程 widget test） | 真机 + 可能 headless |
| **Capability** | CLI API regression | 真实 Flutter runtime E2E |
| **成功标准** | 6 predicates | 6 predicates + autonomous replay |

**Run #005** 回答：「真实生产代码修复的**技术链是否可验证**？」——证明「生产源码修改 + 新进程重编译 + 故障不再复现」成立，但**不宣称 Agent 自主推理修复**（修复动作由确定性脚本执行）。
**Run #006** 回答：「Agent 能否在无人工干预下完成完整自修复闭环？」——满足三个无人工介入条件：Agent 自己发现问题（仅见 `ffx ... failed`）、自己决定修改（产生真实 git diff）、自己判断修复成功（依据 ADI before/after + invariants + capability）。

---

## 当前状态：Phase 3.8 里程碑总结

```text
3.7 Observability System
  ✅ 证据采集层（ObservabilityService, AdiStorage, RingBuffer）

3.8 Agent Diagnostic Interface
  ✅ Run #001: ADI 诊断链（doctor → latest-error → trace → replay）
  ✅ Run #002: Fault → AdiStorage 持久化
  ✅ Run #003: 闭环编排架构（5 phases）
  ✅ Run #004: Fault injection 闭环协议（before=reproduced → after=pass）
  ✅ Run #005: 真实生产代码修复（双进程证明，见 ADL-LOOP-RUN-005.md）
  ⏳ Run #006: 完整 Agent 自主修复 E2E

架构 Gate: PASSED（Run #004）
真实修复 Gate: PASSED（Run #005，2026-08-17）
```

> **执行注记（2026-08-17）**：Run #005 实际采用 widget test + 双进程方案
> （`tools/adi/run005_proof.sh`）而非 integration test（flutter drive）——
> 计划文档原要求真机/flutter drive，实施中发现双进程 widget test 可达成
> 相同「重编译后真实运行时验证」语义，且 CI 更稳定、无设备依赖。
> 详细证据见 [ADL-LOOP-RUN-005.md](ADL-LOOP-RUN-005.md)。

---

## 下一步行动

1. **立即**: 添加 `flutter drive` 配置到 `.github/workflows/ci.yml`
2. **短期**: 创建 `test/integration_test/run005_bug_repro_test.dart`
3. **中期**: 实现 Run #005（引入真实 bug → ADI 捕获 → Agent 修复 → 重新构建 → 验证）
4. **长期**: Run #006 完整 Agent 自主修复闭环
