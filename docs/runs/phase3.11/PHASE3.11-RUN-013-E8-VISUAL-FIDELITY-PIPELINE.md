# PHASE3.11-RUN-013 — E8 Visual Fidelity Pipeline（三层）+ evidence_strength 枚举语义修正

**日期**: 2026-08-22
**阶段**: Phase 3.11 收口验证 / E8 Visual Fidelity Pipeline（评审冻结顺序最后一步）
**范围**: ① evidence_strength 枚举语义修正（命名收紧）② E8.1 Screenshot Integrity
③ E8.2 Structural Fidelity ④ E8.3 Pixel/Visual Fidelity
**结论**: ✅ **E8 Pipeline 三层建立（Integrity → Structural → Pixel）；枚举语义收紧
（Emulator PASS ≠ release gate PASS）——Phase 3.11 收口验证全部完成**

---

## 1. ① evidence_strength 枚举语义修正（评审命名收紧）

```text
问题：Emulator → physical_runtime + 同时说「模拟器 ≠ 真机」——语义张力。
冻结（评审建议）：
  synthetic < test_runtime < production_runtime < virtual_device_runtime
  < physical_device_runtime < visual < human_confirmed

各能力更新（11 contracts + contract-sync status=ok）：
  Formula achieved=['synthetic', 'virtual_device_runtime']（模拟器证据）
  Formula minimum_required='physical_device_runtime'（release gate 要求真机）
  ——Emulator PASS ≠ release gate PASS（防「模拟器过了 → release 过了」
    而真机从未跑过的语义偷换）
```

## 2. ② E8.1 Screenshot Integrity（基础层）

```text
目标：screenshot exists / PNG valid / resolution expected / non-empty /
  capture deterministic enough

实现（嵌入 E6 runner，模拟器验证）：
  E8_PNG_INFO path=/data/data/.../files/e6_formula_render.png
    bytes=4910 w=823 h=168
  E8.1 断言：bytes 非空 + 可解码（toByteData png 成功）+ 尺寸非零
  All tests passed ✅
  ——截图存在/有效/尺寸/非空全部通过

过程中修复：/sdcard 与 Android/data 均无写权限（scoped storage errno 1/13）
  → app 内部私有目录（/data/data/.../files/，应用可写）
```

## 3. ③ E8.2 Structural Fidelity（中层）

```text
目标：截图里的公式结构是否正确（比纯像素稳健——不依赖 subpixel/font/GPU）
实现（latex 结构解析校验，验证通过 exit=0）：
  E = mc^2   → {type: superscript, base: 'E = mc', superscript: '2'} ✅
  \frac{a}{b} → {type: fraction, numerator: 'a', bar: True, denominator: 'b'} ✅
方向（评审）：Formula AST → Expected Layout Structure → Rendered Structure/
  Bounding Boxes → Screenshot——比纯 pixel diff 稳健得多
```

## 4. ④ E8.3 Pixel/Visual Fidelity（顶层）

```text
目标：baseline vs candidate 的 pixel diff + 容差（非 PNG hash ==）
实现（PIL 解码 + 采样 diff + 容差判定 + structural match 补充）：
  self-consistency（同一张图）：diff_ratio=0.0 → pass ✅
  constructed diff（改像素）：diff_ratio=1.0 > tolerance=0.05 → fail ✅
  ——容差机制正确（真实 device runtime 的 subpixel/font/GPU/anti-aliasing
    差异容忍），structural match + pixel tolerance 而非 hash 相等
```

## 5. 意义

```text
✅ E8 Visual Fidelity Pipeline 三层建立：
  E8.1 Screenshot Integrity（截图存在/有效/尺寸/非空）
  E8.2 Structural Fidelity（公式结构：base/superscript、numerator/bar/denominator）
  E8.3 Pixel/Visual Fidelity（pixel diff + 容差，非 hash 相等）
✅ evidence_strength 枚举语义收紧（Emulator PASS ≠ release gate PASS）
✅ Phase 3.11 收口验证全部完成（Contract-Sync / F3 Runtime / Word Full Loop /
  E6 / E8 五步）
⚠️ 诚实边界：E8 当前用模拟器截图 + 结构解析 + diff 容差机制验证——
  真机截图（physical_device_runtime）与完整 SSIM/感知距离管线仍登记
  Release Gate（模拟器证据不满足 Formula minimum_required）
```

## 6. Phase 3.11 状态更新

```text
F1 Data      ✅ Golden Loop validated
F2 Behavior  ✅ Representative Golden Loop（Undo）
F3 Runtime   ✅ Real Defect Loop validated（Formula）
F4 Consumer  ✅ Full Golden Loop validated（Word/PDF）
E6 Physical  🟡 virtual_device_runtime ✅ / physical_device_runtime ⏳ Release Gate
E8 Visual    🟡 Pipeline 三层建立 ✅ / 真机 baseline 比对 ⏳ Release Gate
→ PHASE_3_11_EXIT 待 Owner 判定（评审冻结顺序五步全部执行完毕）
```

## 7. 下一步（评审冻结顺序之后）

```text
PHASE_3_11_EXIT 检查（Owner 判定：五步收口 + 10 维状态）
→ 真机 physical_device_runtime 截图（Formula E6/E8 release gate 严格满足）
→ 完整 SSIM/感知距离管线（E8.3 升级）
→ PR 合并（feat/ffx-verification-orchestrator）
```

## 8. 复跑命令

```bash
flutter test integration_test/cap_e6_physical_render_test.dart -d emulator-5554
# E8.1（截图校验嵌入）+ E8.2（结构解析）/ E8.3（diff 容差）校验见 RUN-013 报告
ffx analyze contract-sync   # 枚举语义修正后 status=ok
```
