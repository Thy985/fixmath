# ADL Loop Run #001 — 首个 ADI 诊断闭环证据

> **⚠️ 范围说明**：本次运行证明了 ADI 诊断链（Observation → Diagnostic → Replay → Validation）可以端到端工作。
> 尚未证明「真实产品能力失败 → ADI → Agent 修复 → 产品能力恢复」的完整闭环——这是 Run #002 的目标。
>
> **里程碑定位**：Phase 3.8 中间里程碑，非最终闭环。

**日期**: 2026-08-17
**分支**: `feat/adi-mcp-causality`
**状态**: ✅ ADI 诊断链完整通过 | ❌ Agent 自主修复未验证 | ⚠️ 产品 Capability Layer 仍为静态元数据
**阻塞项**: 真实产品 runtime capability（需 Flutter headless / debug 入口使 ObservabilityService 使用 `full()` 模式）

---

## 执行摘要

本次运行验证了以下链路：

```
CLI Health Check → ADI Latest Error → Trace Show → Replay → Agent Context
           ↓
Fault Injection Test (Flutter unit) → Export Pipeline → Import → Validate
```

共收集 4 条独立证据链，全部通过。

---

## Step 1: CLI Capability Layer — 环境自检

```bash
$ ffx --json diag health
{
  "project_root": "D:\\Projects\\Active\\math2",
  "dart_sdk":  {"available": true,  "path": "C:\\Users\\lenovo\\SDK\\flutter\\bin\\dart.BAT"},
  "flutter_sdk": {"available": true, "path": "C:\\Users\\lenovo\\SDK\\flutter\\bin\\flutter.BAT"},
  "python":    {"available": true,  "path": "C:\\...\\python3.EXE"},
  "adi_cli":   {"available": true},
  "ffx_analyze":{"available": true},
  "pubspec":   true,
  "cli_available": true
}
```

**结论**: 所有依赖就绪，ffx-cli 和 adi.dart 均可访问。

---

## Step 2: Capability Failure — 真实崩溃已捕获

### 2.1 ADI Doctor

```bash
$ ffx --json adi doctor
{
  "status": "healthy",
  "storage": {"exists": true, "path": "D:\\...\\tools\\adi\\.adi"},
  "schema": 1,
  "adi_protocol_version": "0.1",
  "observations": 3
}
```

### 2.2 Latest Error（真实数据）

```bash
$ ffx --json adi latest-error
{
  "status": "error",
  "error_type": "RenderOverflow",
  "error_type_raw": "GlobalError",
  "session_id": "sess_2239",
  "trace_id": "trc_5b98ca4687546592",
  "snapshot_available": true,
  "message": "A RenderFlex overflowed by 99860 pixels on the bottom.",
  "time": "2026-08-16T16:04:07.380633",
  "next_actions": [
    "adi replay sess_2239",
    "adi trace show trc_5b98ca4687546592"
  ]
}
```

**关键发现**: CLI 错误输出中直接包含 `session_id` 和 `trace_id`，Agent 无需猜测去哪找证据。

---

## Step 3: ADI Diagnostic Layer — 完整因果链

### 3.1 Trace Show

```bash
$ ffx --json adi trace-show trc_5b98ca4687546592
{
  "sessionId": "sess_2239",
  "chain": [
    {"layer": "interaction", "description": "UserInput",        "spanId": "interaction_0", "parent": null},
    {"layer": "command",     "description": "InsertTextCommand","spanId": "command_0",     "parent": "interaction_0"},
    {"layer": "transaction", "description": "Transaction",      "spanId": "transaction_0", "parent": "command_0"},
    {"layer": "render",      "description": "CodeBlockThemeRendered",   "spanId": "render_0",  "parent": "transaction_0"},
    {"layer": "render",      "description": "CodeBlockLanguageChipRendered","spanId": "render_1","parent": "render_0"},
    {"layer": "error",       "description": "RenderParagraph overflow","spanId": "error_0",   "parent": "render_1"}
  ],
  "causality": {
    "rootSpanId": "interaction_0",
    "failureSpanId": "error_0",
    "reachable": true,
    "orphanSpanIds": [],
    "valid": true
  }
}
```

**因果链验证**: `valid: true` — 从 interaction(根) 到 error(叶) 完全可达，无孤立 span。

### 3.2 Replay（来自 sess_6492 — 有完整 replay.json 数据）

```bash
$ dart run adi.dart replay sess_6492 --json
{
  "status": "reproduced",
  "failedAt": "step 0: InsertTextCommand",
  "commandsExecuted": 1,
  "steps": [{
    "index": 0,
    "commandName": "InsertTextCommand",
    "success": false,
    "hashMatch": true
  }]
}
```

**解读**: 复现成功（`reproduced`），命令 `InsertTextCommand` 在 step 0 失败，语义哈希匹配确认是同一命令。

### 3.3 Validate（诊断修复状态）

```bash
$ dart run adi.dart validate --after-fix sess_6492 --json
{
  "before": "unknown",
  "after": "still_failing",
  "replay": {"status": "reproduced", ...},
  "invariants": {
    "violated": [],
    "checked": ["CursorExists","SelectionValid","BlockTreeAcyclic",
                "ParentChildValid","EditorNotEmpty","HistoryConsistent"],
    "allPassed": true
  }
}
```

**解读**: `after: still_failing` 是正确的——replay 仍然复现了错误，说明 bug 尚未修复。
Invariants 全通过（`allPassed: true`）说明数据结构完整，问题仅在渲染层。

### 3.4 Agent Context（AI Agent 可读格式）

```
# Current Software State

## Last failure
RenderOverflow: A RenderFlex overflowed by 99860 pixels on the bottom.

## Evidence
- trace_id: trc_5b98ca4687546592
- session_id: sess_2239
- snapshot: .adi/observations/err_20260816160407.json

## Suggested next action
- Inspect: `adi trace show trc_5b98ca4687546592`
- Replay: `adi replay sess_2239`
```

---

## Step 4: Fault Injection — Flutter 确定性验证

### 4.1 测试通过

```bash
$ flutter test test/observability/fault_injection_capture_test.dart
00:01 +1: All tests passed!
```

**日志输出**:
```
[OBS] Interaction: UserInput | len=13 nl=false ascii=true
[OBS] Command: InsertTextCommand | txId=tx_001 | ok=true | params={blockId: b1, text: void main(){}\n}
[OBS] Transaction: tx_001 | result=commit | elapsed=0ms
[OBS-Render] CodeBlockThemeRendered | isDark=false | theme=github | lang=dart
[OBS-Render] CodeBlockLanguageChipRendered | lang=dart | shown=true | mode=render
```

### 4.2 断言验证（代码层面）

| 断言 | 结果 |
|------|------|
| `snapshot != null` | ✅ |
| `snapshot.type == 'GlobalError'` | ✅ |
| `snapshot.message contains 'overflow'` | ✅ |
| `classifyErrorType(...) == 'RenderOverflow'` | ✅ |
| `interactions` list not empty | ✅ |
| `commands` list not empty | ✅ |
| `transactions` list not empty | ✅ |
| `renders` list not empty | ✅ |
| `exportDiagnosticZip()` returns non-null zip path | ✅ |

### 4.3 完整因果链

故障注入测试证明了端到端链路：

```
FaultInjection.enabled = true
  ↓
CodeBlock 渲染时插入 SizedBox(height: 100000)
  ↓
Flutter Layout → RenderOverflow
  ↓
FlutterError.onError → ObservabilityService.captureError(GlobalError, "overflowed by 99860px")
  ↓
AdiStorage → .adi/observations/
  ↓
ExportPipeline → formula_fix_debug_*.zip
  ↓
CLI import → 分类为 RenderOverflow
```

---

## Step 5: CLI Capability E2E — 验证产品层

```bash
$ ffx --json project create -o /tmp/doc.json -n "TestDoc"
{"id":"...","name":"TestDoc","content":"","word_count":0,...}

$ ffx --json project inject formula -p /tmp/doc.json --latex 'E=mc^2'
{"status":"ok","injected_type":"formula"}

$ ffx --json project info -p /tmp/doc.json
{"word_count":2,"formula_count":1,"char_count":...,...}

$ ffx --json project inject code -p /tmp/doc.json --lang dart --code 'void main(){}'
{"status":"ok","injected_type":"code"}
```

**注意**: 当前 `project inject` 操作的是 JSON 元数据文件，不是真实 Flutter 渲染。这是 CLI-Anything 对 FormulaFix 的正确定位——它暴露的是产品已有的静态分析能力，而非模拟渲染引擎。

---

## 数据完整性证明

### ADI 存储状态

```
D:/Projects/Active/math2/tools/adi/.adi/
├── schema_version.json       ✓ v1, protocol 0.1
├── observations/
│   ├── err_20260816101511.json  ✓ RenderOverflow (sess_2bf0)
│   ├── err_20260816110418.json  ✓ RenderOverflow (sess_6492)
│   └── err_20260816160407.json  ✓ RenderOverflow (sess_2239)
├── sessions/
│   ├── sess_2239/   metadata + invariant_report
│   ├── sess_2bf0/   commands.jsonl + replay + invariant_report
│   ├── sess_6492/   commands.jsonl + replay + invariant_report
│   └── sess_7167/   commands.jsonl + replay + invariant_report
└── traces/
    ├── trc_5b98ca4687546592.json  ✓ causality valid=true
    ├── trc_6cbb709012a1593b.json
    └── trc_e919c684fce382c3.json
```

### 真实设备导出

```
D:/Projects/Active/math2/tools/adi/realdevice/
├── formula_fix_debug_20260816_110419.zip
├── formula_fix_debug_20260816_112457.zip
└── formula_fix_debug_20260816_160407.zip   ← 已导入，产生 err_20260816160407
```

---

## 测试结果汇总

| 测试套件 | 通过 | 跳过 | 失败 |
|----------|------|------|------|
| `test_core.py` (unit) | 26 | 1 | 0 |
| `test_full_e2e.py` (subprocess) | 13 | 1 | 0 |
| `fault_injection_capture_test.dart` | 1 | 0 | 0 |
| **总计** | **40** | **2** | **0** |

---

## 已知限制

| 限制 | 原因 | 解决方向 |
|------|------|----------|
| 真机未触发新崩溃 | App 使用 `light()` 模式，ADI 不写入 | 需支持 `full()` 模式或添加 debug 入口 |
| `project inject` 写 JSON 非 `.md` | CLI 设计为轻量元数据操作层 | 增加 `export-md` 命令导出回 `.md` |
| Replay `sess_2239` 无缓存结果 | 该 session 没有 replay.json | 需要 App 内运行 replay 或使用有数据的 sess_6492 |
| `after: still_failing` 待验证 | bug 尚未修复 | Phase 3.8 实施后修复 RenderOverflow 可验证 `pass` |

---

## 闭环可行性结论

### 已验证 ✅

```
✅ CLI Health Check        → ffx --json diag health
✅ Capability Failure Capture → ffx --json adi latest-error (含 session_id / trace_id)
✅ Diagnostic ID           → 自动附带，Agent 无需猜测
✅ ADI Latest Error        → RenderOverflow + message
✅ ADI Trace Show          → 6 span 因果链，causality valid=true
✅ ADI Replay              → reproduced (sess_6492)
✅ ADI Agent Context       → Markdown + 建议下一步
✅ Flutter Fault Injection → 确定性捕获 + 分类 + 导出 zip
✅ CLI Subprocess Tests    → 40 passed, 0 failed
```

### 尚未验证 ❌

```
❌ Agent 自主修复          → 无 Agent 修改源码记录
❌ ADI Validate after fix → before=unknown (非 reproduced)，after=still_failing
❌ 产品 Capability E2E     → ffx project inject 操作 JSON 元数据，非真实 Flutter runtime
```

### 架构边界声明

**ADI 的职责边界**：`ffx adi validate` 只验证「故障是否消失」，不跑产品功能测试。
产品能力恢复由 `ffx` 独立验证。联合验证需要两个系统分别输出 PASS。

**Run #002 的目标**：用真实 Flutter runtime（或 headless 集成测试），完成一次完整的
`Capability Fail → ADI Diagnose → Agent Fix → ADI Validate → Capability E2E Pass` 链路。
