# PHASE3.11-RUN-001 — 3.11.1 独立 runner 化（资产引用 → 真实执行）

**日期**: 2026-08-20
**阶段**: Phase 3.11 FormulaFix Capability Hardening Loop / 3.11.1（P0）
**范围**: 7 个资产引用型能力（undo/pdf/autosave/file/ime/theme/block）从
「测试资产存在」验证 → 真实 runner 执行验证
**结论**: ✅ **3.11.1 完成——5 个能力的测试证据已从「资产存在」升级为「测试真实执行」
（Evidence Execution Level 升级；undo/block 实测 41/151 passed），
2 个能力因证据层依赖（模拟器/golden）标记 Evidence Gap。本轮不改变
功能 Completion Status，仅升级 Evidence Execution Level。**

---

## 1. 背景

```text
Phase 3.10 时 7 个能力（undo/pdf/autosave/file/ime/theme/block）为
「测试资产存在」验证（资产扫描 → status=pass 表示文件存在，非实时执行）——
诚实边界已声明，3.11.1 将其提升为真实 runner 执行。
```

## 2. 实现

### 2.1 通用真实 runner 机制（runtime_bridge.run_flutter_tests）

```text
runtime_bridge.py 新增 run_flutter_tests(test_globs, out_dir)：
  解析 globs → 实际测试文件 → `flutter test <files> --reporter compact`
  → 真实 passed/failed/skipped metrics（从输出解析汇总行）
  空匹配（无 test/ 可跑文件）→ 返回 files=0（由 adapter 判 warn，不抛异常）
```

### 2.2 7 个 adapter 真实执行（assets.py）

```text
execute：assets-scan（文件存在计数）→ flutter-test（真实执行 + 真实 metrics）
evaluate：checks 改为 {tests_executed: files>=min, no_failures: failed==0}
  - 有测试但 failed>0 → fail（真实失败）
  - 空 globs（无 test/ 可跑）→ warn（证据缺口，需模拟器/golden 环境）
  - declared s0 只记录不降级（沿用 G3 语义）
```

### 2.3 各能力测试文件映射

| 能力 | 测试文件（真实执行） | 说明 |
|------|---------------------|------|
| undo | test/editing/*undo* + cap_beh_audit_test.dart | ✅ test/ 可跑 |
| block | test/editing/block_operation* + block_editor_state_test.dart | ✅ test/ 可跑 |
| file | test/file_service_import + decode_test.dart | ✅ test/ 可跑 |
| pdf | test/export_integration + formula_render_plan_test.dart | ✅ test/ 可跑 |
| ime | test/editing/*composing* + *ime* | ✅ test/ 可跑 |
| autosave | （空）仅 integration_test 需模拟器 | ⚠️ 登记 |
| theme | （空）仅 golden（预存失败 §13.2）+ integration_test | ⚠️ 登记 |

## 3. 验证结果

### 3.1 真实执行生效（修复 2 个问题后）

```text
verify undo  → status=pass / passed=41 / failed=0 / files=6   ✅ 真实结果
verify block → status=pass / passed=151 / failed=0 / files=9  ✅ 真实结果
verify autosave → status=warn（evidence gap：需模拟器）        ✅ 诚实登记
verify theme   → status=warn（evidence gap：需 golden 环境）   ✅ 诚实登记
```

### 3.2 过程中修复的 2 个问题

```text
① metrics 解析 bug：原 re.search 取第一个 '+N' 可能命中中间状态/非汇总行
   → passed=0；修复为 findall 取最后一个（多文件汇总行）
   → undo passed 0→41、block 0→151
② 空 globs 误判 fail：run_flutter_tests 空匹配抛异常 → execute 记 runner_error
   → fail；修复为返回 files=0（adapter 判 warn 证据缺口）
   → autosave/theme fail → warn
```

## 4. 剩余能力登记（3.11 后续任务）

```text
⏳ autosave：真实 runner 需模拟器（integration_test/phase34_autosave*）
   → 模拟器可用时接线（3.11.6）
⏳ theme：真实 runner 需 golden 基线修复（预存环境失败 §13.2 后）
   → golden baseline 修复后接线（3.11.6）
⏳ ime/pdf/file：真实 runner 已接线，待 3.11.3-3.11.6 加固循环逐个跑
```

## 5. 结论

```text
3.11.1 完成：7 个能力证据从「测试资产存在」→「测试真实执行」
（Evidence Execution Level 升级——不改变功能 Completion Status）
  - 5 个能力真实 flutter test runner 接线（undo/block/file/pdf/ime）
  - 2 个能力标记 Evidence Gap（autosave 需模拟器 / theme 需 golden 基线）
  - 验证：undo 41 passed / block 151 passed（真实测试 metrics）
```

### 7 能力状态（Runner 状态 ≠ 功能完成度）

| 能力 | Runner 状态 | 当前证据意义 | 功能完成度（不因本轮改变） |
|------|------------|-------------|--------------------------|
| Undo | ✅ real `flutter test` | 测试层证据（E2/E3） | conditional（未变） |
| Block | ✅ real `flutter test` | 测试层证据（E2/E3） | incomplete（未变） |
| File | ✅ real `flutter test` | 文件服务/逻辑证据 | conditional（未变） |
| PDF | ✅ real `flutter test` | 导出逻辑证据 | conditional（未变） |
| IME | ✅ real `flutter test`（TestTextInput） | composing 模型证据 | unproven（真机软键盘未验） |
| Autosave | ⚠️ no runnable unit layer | 需 runtime E2E（模拟器） | unproven（未变） |
| Theme | ⚠️ golden/environment blocked | 需视觉基线 | unproven（未变） |

> ⚠️ 关键术语边界：`flutter test` 真实执行 ≠ 产品功能真实运行。
> IME 的 TestTextInput 与 Android 物理键盘 composing 是不同证据等级；
> undo 的 41 passed 证明「测试所覆盖场景通过」，不证明
> 真实 App → EditorShell → 用户操作 → Command → Transaction → History
> → UI 全链路正确。这正是 Feature Completion Matrix E2/E3/E5/E6 分层的原因。

### execution 证据字段（防证据层级偷换）

```json
{
  "execution": {
    "runner": "flutter_test",
    "real_execution": true,
    "production_runtime": false
  }
}
```

### 三正交维度（Implementation Status / Evidence Level / Completion Status）

```text
Undo    ：Implementation=implemented / Evidence=E2/E3 verified / Completion=conditional
Autosave：Implementation=implemented / Evidence=E2/E3 partial, E5/E6 missing / Completion=unproven
Block   ：Implementation=incomplete   / Evidence=E2/E3 pass / Completion=incomplete
——「151 tests passed」≠「Block 已完成」：Completion 需 Evidence Profile 全维度（见 3.11 Evidence Profile 落地）
```

下一步（Phase 3.11）：
  3.11.2 Markdown 加固闭环（Golden Loop 首轮：verify → FAIL → diagnose → 修复
  → repair-verify → regression asset）——最成熟、最能完整跑通闭环的能力
  / 3.11.3-3.11.6 复制同一模式（Undo/File/PDF/IME/Autosave/Theme/Block）
  / 3.11.7 contract-sync 增强
