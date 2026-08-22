# ADL Loop Run #006 — Autonomous Agent Repair E2E (Plan)

**日期**: 2026-08-17
**前置**: Run #001-005 已验证 ADI 诊断链 / 持久化 / 闭环编排 / fault-injection 闭环 / 真实源码修复可验证性
**状态**: 方案设计
**下一步**: 实现 Agent harness + capability 测试 + 全链路验证

---

## 1. 目标与定位

**Run #006 回答：「Agent 能否在无人工干预下完成完整自修复闭环？」**

| | Run #005 | Run #006 |
|--|---------|---------|
| 核心目标 | 真实源码修复**可验证性**（Verifiability） | Agent **自主执行**修复（Autonomy） |
| 修复动作 | `run005_apply_fix.dart` 确定性脚本 | **Agent**（ffx CLI 驱动）推理后执行 |
| 证据来源 | 测试内直接断言 | Agent 仅通过 ADI 观察，不预知 bug 位置 |
| 成功标准 | 6 predicates | 6 predicates + **3 个无人工介入条件** |

Run #005 证明「生产源码修改 + 新进程重编译 + 故障不再复现」技术链成立。
Run #006 把该技术链的**执行者**从确定性脚本换成 Agent，验证三个无人工介入条件。

---

## 2. 三个无人工介入条件（核心验证对象）

### C1: Agent 自己发现问题
- ❌ 不能提前告诉 Agent「bug 在 code_block.dart」
- ✅ Agent 只能看到 `ffx ... failed`，然后自己执行：
  ```bash
  ffx --json adi latest-error
  ffx --json adi trace-show <trace_id>
  ffx --json adi replay <session_id>
  ```
- **断言**：Agent harness 的输入不含 bug 位置；evidence 全部来自 ADI 观察。

### C2: Agent 自己决定修改
- ❌ 不能调用 `run005_apply_fix.dart apply`（预置脚本）
- ✅ Agent 从证据推理出修改内容，产生**真实 git diff**：
  ```bash
  git diff flutter_app/lib/presentation/blocks/code/code_block.dart
  ```
- **断言**：diff 是 Agent 推理后的结果（非脚本调用）；生产源码确实被修改。

### C3: Agent 自己判断修复成功
- ❌ 不能自述「我改好了」
- ✅ Agent 依据 ADI 判定：
  ```bash
  ffx --json adi validate --after-fix <session_id>
  # before=reproduced → after=not_reproduced
  # invariants.allPassed=true
  # capability E2E PASS
  ```
- **断言**：Agent 的 success 判定必须与 ADI validate 输出一致。

---

## 3. 架构：Agent harness（ffx CLI 全链路）

```
FFX capability            # 失败能力（before 测试触发 RenderOverflow）
      ↓
ffx adi latest-error      # C1: 获取 Observation（session/trace/error_type）
      ↓
ffx adi trace-show        # C1: 因果链
      ↓
ffx adi replay            # C1: 确认 reproduced
      ↓
Agent reasoning           # C2: 从证据推理（message/error_type 关键字 → 定位源码）
      ↓
Agent edits code          # C2: 真实 git diff
      ↓
fresh build + after capability   # 新进程重编译修复后源码
      ↓
ffx adi validate --after-fix     # C3: before=reproduced → after=not_reproduced
      ↓
ffx project create/info          # capability E2E 回归
      ↓
证据 JSON（3 条件 + 6 predicates）
```

### 关键设计决策

1. **Agent harness = Python 脚本**（`tools/adi/run006_agent.py`）：
   - 复用 `tools/ffx-cli` 的 adi_wrapper（定位 adi.dart + cwd=tools/adi）
   - 输入仅 capability 测试文件路径，**不含 bug 位置**
   - 每一步记录证据，最终输出结构化 JSON

2. **证据存储契约**：ffx adi 读取 `tools/adi/.adi`（adi_wrapper 固定 cwd=tools/adi → `_adiRoot` = tools/adi/.adi）。因此 Run #006 的 capability 测试必须把 evidence 写入**真实 `.adi`**（通过 `--dart-define=ADL_ADI_ROOT` 覆盖 AdiStorage 路径），而非 Run #005 的 tempDir。

3. **capability 测试**（`fault_injection_run006_test.dart`）：
   - before 模式：FaultInjection.enabled=true → 触发 RenderOverflow → 写入真实 .adi → 断言 captured
   - 由 Agent harness 驱动（`--dart-define=ADL_RUN006_CAPABILITY=true`），CI 默认跳过

4. **驱动脚本**（`tools/adi/run006_proof.sh`）：backup → run agent → restore，与 run005 同构。

---

## 4. 与 Run #005 的复用关系

| 组件 | Run #005 | Run #006 |
|------|---------|---------|
| before/after 双进程验证 | ✅ 核心机制 | ✅ 复用（capability 测试） |
| 修复执行者 | `run005_apply_fix.dart` | Agent harness（推理） |
| 证据写入 | tempDir（测试隔离） | 真实 `tools/adi/.adi`（ffx 可读） |
| 谓词 P1-P6 | ✅ | ✅ 复用 + 3 条件 |

**边界**：Run #006 不新增验证机制，只替换「执行者」角色并增加 C1-C3 条件断言。

---

## 5. 成功标准

```json
{
  "run": "006",
  "status": "autonomous_agent_repair_proven",
  "conditions": {
    "C1_agent_discovers": true,
    "C2_agent_decides_patch": true,
    "C3_agent_judges_success": true
  },
  "predicates": {
    "P1_before_reproduced": true,
    "P2_patch_authenticity": true,
    "P3_fresh_runtime_fixed": true,
    "P4_invariants_pass": true,
    "P5_replay_not_reproduced": true,
    "P6_capability_e2e_pass": true
  }
}

PASS = C1 ∧ C2 ∧ C3 ∧ P1 ∧ P2 ∧ P3 ∧ P4 ∧ P5 ∧ P6
```

---

## 6. 测试计划

1. **Agent harness 单测**（python）：mock adi_wrapper 返回固定 evidence → 断言推理定位 + diff 生成
2. **capability 测试**（flutter）：before 模式捕获 RenderOverflow 写入真实 .adi
3. **端到端**：`bash tools/adi/run006_proof.sh` 全链路 → 输出证据 JSON
4. **静态检查**：flutter analyze 0 warning；TC-ARCH-7 行数 < 400

---

## 7. 风险与边界

- **推理的确定性**：Agent 推理基于 error_type/message 关键字（RenderOverflow + CodeBlock），
  对本次 bug 是确定的；真实环境需 Agent（LLM）介入，本 harness 证明**协议链路**而非 LLM 智能。
- **CI 安全**：capability 测试由 dart-define 门控，默认跳过；驱动脚本写真实 .adi 前先备份。
- **与 Run #007+ 的关系**：本 Run 证明「Agent 可自主完成闭环」的协议层，LLM 推理质量是产品层问题。

---

## 8. 模拟器实测方案（2026-08-17 增补，无 zip 同步）

widget test 双进程已在主机验证闭环；模拟器实测把 capability 换成
**integration_test**（真实 Flutter runtime），证据经**逐文件 base64 透传**
同步回主机 .adi（**省掉 zip 打包/解码/import 三层**）：

```text
Phase 0: 备份 code_block.dart
Phase 1: flutter test integration_test/run006_capability_test.dart -d emulator-5554
         --dart-define=ADL_RUN006_BEFORE=true
         → 真实 runtime 渲染 CodeBlock（FaultInjection gate 存在）→ 真实 RenderOverflow
         → FlutterError.onError 捕获 → AdiStorageImpl 写设备端 .adi
         → 显式补写 traces/<traceId>.json + sessions/<sid>/replay.json(reproduced)
         → RUN006_FILE_BEFORE=<relpath>=<base64> 逐文件透传
Phase 2: 驱动脚本解码直接落盘 tools/adi/.adi/<relpath>（无 zip、无 adi import）
Phase 3: Agent 闭环（run006_agent.py --simulator --reason-only）：
         ffx adi latest-error → trace-show → replay → 推理 → 改码（真实 git diff）
Phase 4: flutter test integration_test/run006_capability_test.dart -d emulator-5554
         --dart-define=ADL_RUN006_AFTER=true --dart-define=ADL_SESSION_ID=<session>
         → 新 APK 重编译修复后源码 → 无 overflow → 直接覆盖目标 session 的
           replay.json(not_reproduced) → RUN006_FILE_AFTER=... 逐文件透传落盘
Phase 5: ffx adi validate --after-fix <session> → after=pass
Phase 6: 还原 code_block.dart
```

### 关键设计决策

1. **capability 复用 FaultInjection gate**（SizedBox(height:100000)，与 widget 版同一 bug）：
   Agent 的 `reason_and_patch` 推理逻辑**零改动**——运行环境从 widget test
   换成模拟器真实 runtime，但 bug 本体与修复动作一致。
2. **逐文件 base64 透传替代 zip**：设备端 `.adi` 由 AdiStorageImpl 直接写入，
   observation 字段与 ffx 期望**完全兼容**（无需 import 转换）。省掉
   exportDiagnosticZip / zip 解码 / `ffx adi import` 三层。
3. **为什么不用 adb pull 目录**：`flutter test integration_test` 结束后卸载应用
   （`pm list packages` 无包），私有目录与 `getExternalFilesDir` 的
   `Android/data/<pkg>` 随卸载清除，公共 /sdcard 无写权限；
   逐文件 base64 透传（测试运行期间打印）是唯一可靠的设备→主机通道。
4. **traces 由 capability 显式补写**：设备端 AdiStorageImpl 不写 traces 目录，
   测试必须写 `traces/<traceId>.json`（含 CodeBlockThemeRendered span），
   否则 Agent 的 trace-show 返回 not_found 导致 C2 推理失败。
5. **AFTER 直接覆盖 ADL_SESSION_ID**：`ObservabilityService.sessionId` 是 final
   无法注入，capability 直接把 replay/invariant 写到 Agent 观察到的目标
   session 目录，无 session 合并逻辑。
6. **agent.py 增加 `--simulator` 两阶段模式**（--reason-only / --validate-only，
   validate 阶段从 .adi 重新 observe），保持 C1/C2/C3 与 P1-P6 断言不变。

---

## 9. 最终能力状态与 Run #007 验收预告（2026-08-17 执行后增补）

### 9.1 Run #006 最终能力状态（诚实分级）

| 能力 | 状态 | 说明 |
|------|------|------|
| ADI diagnostic loop | ✅ | latest-error / trace-show / replay 全链路在真实 runtime 可观测 |
| Real Flutter runtime repair | ✅ | Android 模拟器真实 engine：RenderOverflow → 修复 → 新 APK 无 overflow |
| Agent-driven source patch | ✅ | evidence-driven deterministic harness 产生真实 git diff |
| Fresh-build verification | ✅ | 新 APK 重编译修复后源码，非内存态切换 |
| Invariant validation | ✅ | validate 后 invariants.allPassed=true |
| FFX API capability regression | ✅ | `ffx project create/info` 未退化（FFX capability layer 层） |
| **Real product capability E2E** | ⏳ | 待 Run #007：FormulaFix 真实产品能力（parser/export/undo 等真机完整链路） |
| **Real LLM agent** | ⏳ | 执行者为确定性 harness 非 LLM；LLM 接入需专门验证实验 |

**结论声明**：Run #006 验证的是 **Autonomous Harness Loop**（真实 runtime 上的
自主修复协议闭环），**不是** LLM autonomous repair。

### 9.2 已知限制：before=unknown（Run #007 已修复 ✅）

Run #006 执行中 `validate.before=unknown` 的根因：`tools/adi/adi.dart` 的 `_cmdValidate`
硬编码 `'before': 'unknown'`（约 610 行），未把同一 session 的 observation
存在性绑定进结果。`unknown → pass` 弱于 `reproduced → not_reproduced`。

**Run #007 已修复并验收**（2026-08-17）：新增 `_deriveBeforeStatus(sessionId)`
从 `.adi/observations/` 推导 before 状态，模拟器全闭环重测通过：

```text
validate:   before=reproduced  after=pass  replay=not_reproduced  invariants_all_passed=true
```

**Run #007 验收标准（形式化条件，F1-F7 全 true，已通过）**：

```text
F1 = failure observed                   ✅（.adi/observations 存在）
F2 = before replay reproduced           ✅（validate.before=reproduced，Run #007 修复）
F3 = production patch                   ✅（git diff 可审计，非测试文件）
F4 = fresh runtime                      ✅（新 APK 重编译，非内存态）
F5 = after replay not_reproduced        ✅（validate.after=not_reproduced）
F6 = invariants pass                    ✅（validate.invariants.allPassed=true）
F7 = capability regression pass         ✅（FFX API + 真实产品 capability E2E）
```

详见 [ADL-LOOP-RUN-007.md](ADL-LOOP-RUN-007.md)。

### 9.3 Phase 3.9 预告：Product Capability & Behavioral Audit

**方向**：Phase 3.8 技术 Gate 收官后，不再继续堆 ADI 能力，而是用已跑通的
ADL Loop **审计 FormulaFix 本身**。三条线：

```text
               FormulaFix Audit
                      │
        ┌─────────────┼─────────────┐
        ↓             ↓             ↓
   Capability      Behavior       Experience
      Audit          Audit          Audit
        │             │             │
       FFX        E2E + ADI      真机/Golden/
                                  Gesture/IME
```

- **Capability Audit**（先行，可自动化）：Markdown / Parser / Serializer /
  Formula / CodeBlock / List / Export / Autosave / Undo-Redo —— 问「能不能正确做」
- **Behavior Audit**（E2E + ADI）：Enter / Backspace / Undo / Redo / Selection /
  Focus / IME / Block split-merge —— 问「用户这么操作后行为是否正确」
- **Experience Audit**（真机/Golden/手势）：焦点 / 键盘 / 滚动 / 布局 / 小屏 /
  主题 / 输入延迟 —— 问「真的像 Typora/Obsidian/VSCode 那样自然吗」

**执行要点**：
1. Capability Audit 先行（可自动化、可量化），Behavior/Experience 后置
2. 审计项契约：`{capability, 触发方式, 期望行为, ADI 观察点}` —— 发现问题
   才能自动进入 ADL Loop
3. **Regression Asset 是闭环关键**：每个 ADI 发现的 bug 必须产出一个
   regression test，让 Loop 从「修 bug」升级为「积累质量资产」

**反哺链完整形态**：

```text
Product Audit → Capability/UX → Failure → ADI → Agent Repair
→ Fresh Build → Replay + Invariant → Capability E2E → Regression Asset
→ Product Audit again（闭环）
```
