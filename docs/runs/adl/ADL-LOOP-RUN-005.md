# ADL Loop Run #005 — Real Production Code Repair Proof

**日期**: 2026-08-17
**前置**: Run #001-004 已验证 ADI 架构与 FaultInjection 闭环协议
**状态**: ✅ 真实生产代码修复证明通过（三层证明 A + B + C）
**关键边界**: 修正 Run #004 的开关式修复 —— 本次 Agent 修改了**生产源码**（code_block.dart）
**下一步**: Run #006 — 完整 Agent 自主修复 E2E（无人工干预）

---

## 执行摘要

Run #005 回答核心问题：**「真实生产代码修复」的技术链是否可验证？**

> **重要定位**：Run #005 证明的是 **Production Code Repair Verifiability Proof**
> （真实生产代码修复的**可验证性**），**不是** Agent Autonomous Repair（Agent 自主修复）。
>
> 当前修复动作由确定性脚本 `run005_apply_fix.dart` 完成，**不是** Agent 从
> Observation 推理后自主执行。P2 只能证明「生产源码确实发生了修改」，
> 不能证明「Agent 自己推理出这个修改并执行」——后者是 Run #006 的职责。

Run #004 只证明了「FaultInjection.enabled = false」的开关式修复（内存态），未证明源码级修复。Run #005 定义三个独立证明层，缺一不可：

| 层 | 验证什么 | 方法 | 谓词 |
|----|---------|------|------|
| **B: Patch Authenticity** | Agent 真的改了生产代码吗？ | git diff 审计 + 源码断言 | P2 |
| **A: Runtime E2E** | 改完代码后产品行为真的恢复了吗？ | 新进程重编译后运行时验证 | P3, P5 |
| **C: Pipeline/Protocol** | ADI/Replay/Validation 管道没坏吗？ | 既有测试 + 本报告回归 | P1, P4, P6 |

---

## 关键设计修正：双进程证明（解决 Run #004 的根本限制）

Run #004 尝试在**单进程 widget test** 内「改源码 → 重验证」，遇到根本限制：

```
真实 overflow 在生产代码中
  ↓
测试进程启动时 code_block.dart 已被编译
  ↓
测试中途写磁盘源码不会改变已加载的类
  ↓
同一进程内重 pump 仍触发 overflow（P3 伪验证）
```

**解决方案：双进程证明** —— 修复必须在一个**新测试进程**中验证，让新进程重新编译已修复的源码：

```bash
bash tools/adi/run005_proof.sh
# Phase 1: before 测试（bug 存在）→ P1 reproduced
# Phase 2: 应用生产修复（run005_apply_fix.dart apply）→ git diff 可审计
# Phase 3: after 测试（新进程重编译修复后源码）→ P3/P4/P5/P6
# Phase 4: 还原生产源码（cp backup）→ 工作树干净
```

> 说明：计划文档曾要求 integration test（flutter drive）。实施中发现 widget test +
> 双进程方案可达成相同语义（真机不可用场景的替代），且 CI 更稳定、无设备依赖。
> 与计划的偏差已在测试文件 dartdoc 中记录。

---

## 测试结果

### 双进程闭环（驱动脚本）

```
[run005] Phase 1: before test (bug present -> P1 reproduced)
[before] P1 BUG DETECTED: A RenderFlex overflowed by 99858 pixels on the bottom.
         session=sess_43db trace=trc_0001
         chain: 1+1+1+2 spans
[run005] Phase 2: apply agent fix to production source
[run005-fix] apply -> code_block.dart (9262 -> 8857 chars)
[after] P3 VERIFIED: no overflow with fault enabled (fixed source compiled in fresh process)
[after] P4 VERIFIED: invariants intact, no error persisted
[after] P5 VERIFIED: replay not_reproduced
[run005] PASS: code_block.dart restored (working tree clean)
```

### 谓词判定（6 条全部为 true）

| 谓词 | 定义 | 验证结果 | 证据 |
|------|------|---------|------|
| **P1** | 修复前 bug 被 ADI 捕获 | ✅ | before 测试：RenderOverflow captured, session=sess_43db |
| **P2** | 生产源码确实被修改（非测试代码） | ✅ | after 测试断言：`SizedBox(height: 100000)` 与 fault gate 均从 code_block.dart 移除（由 `run005_apply_fix.dart` 确定性脚本执行，非 Agent 推理） |
| **P3** | 修复后真实运行时不再溢出 | ✅ | after 测试：新进程 + FaultInjection.enabled=true 仍无 overflow |
| **P4** | 系统不变量通过 | ✅ | after 测试：无错误记录持久化，editor 非空 |
| **P5** | 修复后 replay 不复现 | ✅ | after 测试：status = not_reproduced |
| **P6** | 产品能力未退化 | ✅ | after 测试：命令管道仍工作，renders 事件仍记录 |

```
PASS = P1 ∧ P2 ∧ P3 ∧ P4 ∧ P5 ∧ P6 = true
```

### 静态检查

```
flutter analyze --no-fatal-infos --fatal-warnings 新增两个测试文件
→ 0 error / 0 warning

TC-ARCH-7 行数门禁：before 184 行 / after 241 行（均 < 400，无需豁免）
```

---

## 与 Run #004 的关键区别

| | Run #004 | Run #005 |
|--|---------|---------|
| **修复对象** | 测试标志 `FaultInjection.enabled = false` | 生产源码 `code_block.dart`（移除 bug 块 + import） |
| **验证方式** | 单进程内存态切换 | 双进程：新进程重编译修复后源码 |
| **P2 证明** | 无（无源码 diff） | 源码断言 + 可 git diff 审计 |
| **P3 证明** | 内存态（伪） | 新进程真实运行时（真） |
| **CI 安全** | — | after 测试以 `ADL_RUN005_AFTER` define 门控，CI 默认跳过 |

---

## 交付物

| 文件 | 职责 |
|------|------|
| `tools/adi/run005_proof.sh` | 双进程证明驱动脚本（before → apply fix → after → restore） |
| `tools/adi/run005_apply_fix.dart` | 生产修复应用/回退助手（apply/revert，git diff 可审计） |
| `flutter_app/test/observability/fault_injection_run005_before_test.dart` | P1/P2-pre 验证（bug 存在态） |
| `flutter_app/test/observability/fault_injection_run005_after_test.dart` | P2-P6 验证（修复后新进程） |

---

## 遗留与下一步

1. **Run #006（Autonomous Repair E2E）**: Run #005 已证明「修复过程可验证」，Run #006 才证明「Agent 能自主执行修复过程」。职责边界：
   - Run #005: 修复动作由 `run005_apply_fix.dart` 确定性脚本执行 → **Verifiability Proof**
   - Run #006: 把脚本角色换成 Agent（ffx CLI）→ 满足三个「无人工介入」条件：① Agent 自己发现问题（只能看到 `ffx ... failed`，不能预知 bug 位置）；② Agent 自己决定修改（产生真实 git diff，而非调用预置脚本）；③ Agent 自己判断修复成功（依据 ADI before=reproduced → after=not_reproduced + invariants + capability，而非自述"我改好了"）。
2. **双进程验证 → 通用 Validation Contract**: `before 进程 → patch → fresh runtime → replay → compare` 机制可上升为 ADI 的通用验证契约：**验证修复时不信赖当前进程状态，必须在 fresh runtime 中验证**（对 Flutter/Dart、Python、Node、C++、配置、generated files 等一切可能缓存旧代码的运行时都适用）。
3. **P6 升级**: 当前 P6 偏 Infrastructure regression（命令管道 + renders 事件）。更严格定义应为 **Capability E2E**：patch 后原始 capability E2E + 相关 capability smoke test 仍 PASS（防止「overflow 修好了但 export 坏了」——该升级已在本报告配套的 after 测试中落实，见 `fault_injection_run005_after_test.dart`）。
4. **CI 集成**: 可将 `run005_proof.sh` 接入 GitHub Actions 的 schedule job（当前 after 测试由 define 门控，CI 默认安全跳过）。
5. **真实 bug 验证**: 双进程证明已消除「同进程伪验证」，但 fault-injection 仍是确定性触发；真机环境可进一步用真实 RenderOverflow（非注入）走同一协议。
