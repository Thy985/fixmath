# ADL Loop Run #002 — Capability Repair Closed Loop

**前置**: Run #001 已证明 ADI 诊断链可行（见 `docs/ADL-LOOP-RUN-001.md`）
**目标**: 完成一次真实的 `Capability Fail → ADI Diagnose → Agent Fix → Capability Pass` 闭环
**状态**: 方案设计（待执行）

---

## 成功标准（必须全部满足）

```json
{
  "diagnostic": {
    "failure_id": "f_001",
    "error_type": "RenderOverflow",
    "causality_valid": true
  },
  "replay": {
    "status": "reproduced",
    "before_fix": true
  },
  "agent_fix": {
    "file_changed": "flutter_app/lib/presentation/blocks/code/code_block.dart",
    "lines_changed": 1,
    "commit_hash": "<sha>"
  },
  "adi_validation": {
    "before": "reproduced",
    "after": "not_reproduced",
    "invariants_pass": true
  },
  "capability_validation": {
    "status": "pass",
    "command": "ffx project inject code --lang dart --code 'void main(){}'",
    "e2e_pass": true
  }
}
```

**任何一项不满足 = Run #002 失败，需分析原因后重试。**

---

## 四层架构与职责边界

```
                 Agent
                   │
          ┌────────┴────────┐
          │                 │
     Capability          Diagnostic
      Surface             Surface
          │                 │
         ffx                adi
          │                 │
          └────────┬────────┘
                   │
                Product
                   │
                   ▼
                Runtime
```

| 层 | 系统 | 职责 | 输出 |
|----|------|------|------|
| **Capability** | `ffx` | 声明产品能力，验证是否可用 | `{"status":"pass/fail"}` |
| **Diagnostic** | `adi` | 捕获失败证据，输出因果链 | `session_id + trace_id + causality` |
| **Replay** | `adi replay` | 确定性问题是否可稳定复现 | `{"status":"reproduced/not_reproduced"}` |
| **Validation** | `adi validate` | 确认故障是否消失（仅检查因果链+invariant） | `{"after":"pass/still_failing"}` |

**关键原则**：`adi validate` 只回答"故障是否消失"，**不跑产品功能测试**。
产品能力恢复由 `ffx` 独立验证。

---

## 选定的 Fault: CodeBlock RenderOverflow

**故障来源**: Run #001 已采集的真实崩溃（3 次复现，2 个不同 stack hash）

**根因定位**（基于 Run #001 trace 数据）:
```
interaction(UserInput "void main(){}\n")
  ↓ command(InsertTextCommand)
  ↓ transaction(commit)
  ↓ render(CodeBlockThemeRendered)
  ↓ render(CodeBlockLanguageChipRendered)   ← overflow 发生在此
  ↓ error(RenderParagraph overflow 99860px)
```

**修复位置**:
```
flutter_app/lib/presentation/blocks/code/code_block.dart:187
```
当前代码:
```dart
if (FaultInjection.renderOverflowEnabled)
  const SizedBox(height: 100000),  // ← 触发 overflow
```

**Agent 应执行的修复**:
1. 找到代码块溢出问题（非 fault injection 场景下的真实溢出）
2. 给 CodeBlock 添加 `SingleChildScrollView` 或限制最大高度
3. 提交 commit

---

## Run #002 执行步骤

### Step 0: 环境准备（Run #001 已完成）
```bash
# 模拟机 Pixel 10 已连接 emulator-5554
# APK 已安装到模拟器
# ffx-cli 已安装，40 测试通过
# .adi/ 有 3 observations，2 failures，完整因果链
```

### Step 1: 注入故障 → 触发 Capability Failure

**采用单元测试路径**（确定性高，可重复）：

```bash
# 扩展 fault_injection_capture_test.dart，使其：
# 1. 启用 FaultInjection.enabled = true
# 2. 运行 CodeBlock 渲染并触发 overflow
# 3. 导出 zip 到 temp 目录
# 4. 通过 ffx import 导入到 .adi/
# 5. 验证 ffx latest-error 返回新的 session_id 和 trace_id

# 同时验证 ffx project inject code 在 overflow 状态下返回 diagnostic_hint
cd flutter_app
flutter test test/observability/fault_injection_capture_test.dart
```

**产出**:
```json
{
  "session_id": "sess_run002_001",
  "trace_id": "trc_run002_xxx",
  "error_type": "RenderOverflow",
  "causality_valid": true
}
```

### Step 2: Agent 读取诊断数据

```bash
# Agent 收到 capability failure 信号后：
ffx --json adi latest-error
# → 得到 session_id, trace_id, next_actions

ffx --json adi trace-show <trace_id>
# → 得到完整因果链，定位到 CodeBlockLanguageChipRendered

ffx --json adi replay <session_id>
# → 确认 reproduced

ffx adi agent-context
# → 得到可读 Markdown
```

### Step 3: Agent 定位并修复源码

**Agent 应执行的诊断流程**:
1. 读取 `ffx adi trace-show` 输出的 causal chain
2. 搜索 `CodeBlockLanguageChipRendered` 在源码中的位置
3. 定位到 `code_block.dart` 渲染逻辑
4. 分析 overflow 根因
5. 实施修复（添加宽度约束或滚动）
6. 提交 commit

**预期修复方向**（由 Agent 自行决定具体实现）:
- 给 CodeBlock 的 Row 添加 `mainAxisSize: MainAxisSize.min` 或 `flex` 权重
- 给 CodeBlockLanguageChip 添加 `maxWidth` 约束 + overflow 截断
- 或在 CodeBlock 外层包裹 `SingleChildScrollView`

### Step 4: ADI Validate

```bash
# Agent 修复后，重新注入相同故障，验证不再复现：
ffx --json adi validate --after-fix <new_session_id>
# 期望输出:
# {"before": "reproduced", "after": "not_reproduced",
#  "invariants": {"allPassed": true}}
```

**关键要求**: `before` 必须是 `"reproduced"`（不能是 `"unknown"`），
否则无法证明 Agent 确实修复了问题。

### Step 5: Capability E2E 回归验证

```bash
# 修复后重新验证产品能力未被破坏：
ffx --json project inject code -p /tmp/doc.json --lang dart --code 'void main(){}'
ffx --json project info -p /tmp/doc.json
# 期望: word_count > 0, code_block_count >= 1, 无异常

# 如果已有真实 Flutter headless 能力命令（Run #003 目标）：
# ffx capability render-code-block --input doc.json --output /tmp/rendered.png
# 期望: 文件存在且非空
```

---

## 所需代码变更

### 变更 1 (P0): `ffx project inject` 返回 diagnostic hint

当 inject 操作因产品能力失败时，输出应包含 `diagnostic_hint` 字段：

```json
{
  "status": "error",
  "error": "RenderOverflow",
  "diagnostic_hint": {
    "available": true,
    "session_id": "sess_xxx",
    "trace_id": "trc_xxx",
    "next_action": "ffx adi replay sess_xxx"
  }
}
```

预计改动：`cli_anything/ffx/core/project.py` + `ffx_cli.py`，约 20 行。

### 变更 2 (P1): 扩展 fault injection test 支持新 session 导入

在 `fault_injection_capture_test.dart` 中增加：
- 导出 zip 后立即调用 `import_zip` 逻辑（复用 `import_zip.dart`）
- 验证新的 `.adi/` 数据产生正确的 session_id / trace_id
- 为 Run #002 提供可复现的注入点

预计改动：`flutter_app/test/observability/fault_injection_capture_test.dart`，约 40 行。

### 变更 3 (P2): App debug toggle for full observability

在 App 中添加一个 debug flag，使 `ObservabilityService` 使用 `full()` 而非 `light()` 模式。
这样真机运行时也能产生完整的 `.adi/` 数据，为 Run #003（真机闭环）做准备。

预计改动：`main.dart` + 一个 debug options screen，约 50 行。

---

## 时间估计

| 步骤 | 预估时间 | 说明 |
|------|---------|------|
| Step 1: 注入故障 + 导出 | 2 min | 运行扩展后的 fault injection test |
| Step 2: 读取诊断 | 30s | 4 个 ffx 命令串行 |
| Step 3: Agent 修复 | 5 min | Agent 分析 trace → 定位 → 修复 → 提交 |
| Step 4: ADI Validate | 30s | 1 个 ffx 命令 |
| Step 5: Capability E2E | 1 min | 2-3 个 ffx 命令 |
| **总计** | **~10 min** | 不含变更 1-3 的代码开发时间 |

---

## 执行决策点

在执行 Run #002 之前，需要确认：

1. **是否先做变更 1（diagnostic hint）？**
   - 是：Agent 可以自动获取 session_id，闭环更完整
   - 否：Agent 需要手动从 latest-error 输出中复制 session_id
   - **建议**: 先做变更 1，这是 P0 阻塞项

2. **Run #002 的 Agent 是谁？**
   - Claude Code 自身（本次会话）→ 最快，但可能有视角盲区
   - 其他 Agent（TRAE/Cursor）→ 更真实的自主性验证，但需要额外配置

3. **是否同步做变更 3（debug toggle）？**
   - 是：Run #002 和 Run #003 可以共用同一套数据
   - 否：保持专注，Run #002 用单元测试路径，Run #003 再做真机
   - **建议**: 先不做，保持 Run #002 范围最小

---

## 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Agent 修复方案错误 | step 4 validate 仍 `still_failing` | 允许 Agent 迭代修复，最多 3 次；每次失败后重新读取 trace |
| Fault injection 数据无法在真实场景中复现 | replay 结果不一致 | 以单元测试 fixture 为 ground truth，真机路径作为后续 |
| `ffx project inject` 不产生真实 overflow | 无法触发真实失败 | 改用 fault injection test 路径（确定性高），这是预期设计 |
| App 使用 `light()` 模式 | 真机不写入 `.adi/` | Run #002 用单元测试路径，绕开此限制 |

---

## 成功标志

Run #002 完成后，应该有以下产出：

1. `docs/ADL-LOOP-RUN-002.md` — 完整运行报告（类比 Run #001）
2. 至少 1 个 commit 修改了 `code_block.dart` 或相关文件
3. `ffx --json adi validate --after-fix <session_id>` 输出 `after: pass`
4. `ffx --json project info` 验证产品能力未退化
5. Git 历史记录包含完整的 Agent 修复过程
