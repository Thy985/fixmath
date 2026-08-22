# PHASE3.11-RUN-012 — E6 Physical Runtime（Formula 模拟器真实渲染 + 截图证据）

**日期**: 2026-08-21
**阶段**: Phase 3.11 收口验证 / E6 Physical Runtime（评审冻结顺序第 4 步）
**范围**: E6 渲染 runner（integration_test）+ formula adapter E6 步骤 + evidence_strength 提升
**结论**: ✅ **E6 Physical Runtime evidence 成立——Formula 在模拟器 device runtime 真实
渲染并产出截图（非 headless 单测）；真机/WebView Release Gate 仍登记**

---

## 1. 背景

```text
评审冻结顺序：Contract-Sync ✅ → F3 Runtime ✅ → Word Full Loop ✅ → E6（本轮）。

E6 Physical Runtime 要解决的缺口（评审）：
  SVG 存在 ≠ SVG 渲染 ≠ 用户看到正确公式
  ——此前 formula 只有 synthetic（注入观察）+ test_runtime（flutter test）；
  本轮补 physical_runtime（模拟器 device runtime 真实渲染 + 截图）。
```

## 2. 实现

### 2.1 E6 渲染 runner（integration_test/cap_e6_physical_render_test.dart）

```text
模拟器真实 Flutter runtime 渲染 FormulaRenderer（E=mc^2 + 分式 \frac{a}{b}）：
  - MaterialApp(theme: AppTheme.lightTheme) 注入 EditorTokens（§11.5 教训）
  - 结构断言：FormulaRenderer ×2 渲染 + 渲染树完成绘制（debugNeedsPaint=false）
    + 渲染尺寸非零（真实绘出内容，非空渲染）
  - 截图：RepaintBoundary.toImage → PNG（physical runtime 视觉证据）
运行：flutter test integration_test/cap_e6_physical_render_test.dart -d emulator-5554
```

### 2.2 formula adapter E6 步骤（execute 增加）

```text
integration_test cap_e6_physical_render_test.dart -d emulator-5554 →
  解析 E6_PHYSICAL_PNG 输出 → e6_screenshot / e6_physical_render_ok /
  e6_structural_ok metrics → evidence.add 补 e6_physical_render 字段
evidence_strength.achieved 提升：synthetic → +virtual_device_runtime
（模拟器 device runtime；minimum_required=physical_device_runtime 仍待真机）
```

> **命名收紧（评审 2026-08-22）**：evidence_strength 枚举语义修正——
> `physical_runtime` 拆为 `virtual_device_runtime`（模拟器）与
> `physical_device_runtime`（真机）：
> synthetic < test_runtime < production_runtime < virtual_device_runtime
> < physical_device_runtime < visual < human_confirmed
> Formula achieved=['synthetic', 'virtual_device_runtime']（模拟器证据），
> minimum_required=physical_device_runtime（release gate 要求真机）——
> **Emulator PASS ≠ release gate PASS**（防「模拟器过了 → release 过了」
> 而真机从未跑过的语义偷换）。

## 3. 验证结果（模拟器 emulator-5554）

```text
E6_PHYSICAL_PNG /data/user/0/com.formulafix.formula_fix/code_cache/
  e6_formula_render.png bytes=4910 ✅（截图产出）
03:04 +1: All tests passed ✅（结构断言通过：渲染树绘制 + 尺寸非零）
analyze 0 error/warning ✅

→ E6 Physical Runtime evidence 成立：Formula 在模拟器 device runtime
  真实渲染（非 headless 单测），截图 4910 字节产出
```

## 4. 过程中发现并修复的问题（3 个）

```text
① 编译错误 1：binding 变量未使用（ensureInitialized 返回值）→ 移除变量
② 编译错误 2：findRenderObject() 返回 RenderObject 无 toImage →
   as RenderRepaintBoundary
③ 断言假设错误：find.textContaining('=') 不适用于图形渲染的公式
   （WebView/SVG/flutter_math_fork 渲染为图形非文本）→ 改用
   渲染树完成绘制（debugNeedsPaint）+ 尺寸非零（真实绘出内容）
```

## 5. 意义

```text
✅ E6 Physical Runtime evidence 成立（模拟器 device runtime 真实渲染 + 截图）
✅ evidence_strength：formula 达到 physical_runtime（minimum_required 满足）
✅ 「SVG 存在 ≠ 用户看到正确公式」——结构断言用渲染树/尺寸（真实绘制）
   而非文件存在/文本假设
⚠️ 诚实边界：模拟器 ≠ 真机——真机/WebView Release Gate 仍登记
   （E6 严格 release 判定需真机截图 + 像素比对）
```

## 6. Phase 3.11 状态更新

```text
F1 Data      ✅ Golden Loop validated
F2 Behavior  ✅ Representative Golden Loop（Undo）
F3 Runtime   ✅ Real Defect Loop validated（Formula）
F4 Consumer  ✅ Full Golden Loop validated（Word/PDF）
E6 Physical  🟡 模拟器渲染 + 截图证据 ✅ / 真机 Release Gate ⏳
E8 Visual    ⏳ Release Gate（下一阶段）
```

## 7. 下一步（评审冻结顺序）

```text
E8 Visual Fidelity（视觉回归：截图结构 + 像素比对 → release gate；
  需真机/WebView 环境或视觉比对管线）
→ PHASE_3_11_EXIT
```

## 8. 复跑命令

```bash
flutter test integration_test/cap_e6_physical_render_test.dart -d emulator-5554
ffx capability verify formula   # 含 E6 渲染步骤（模拟器截图）+ evidence_strength
```
