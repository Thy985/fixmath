# PHASE3.11-RUN-015 — E8 真实视觉提取 + FFX Verify 接线

**日期**: 2026-08-22
**阶段**: Phase 3.11 收口验证 / RUN-014 遗留缺口收口（vision_extract 填实 + visual_check 接线 + 模拟机截图）
**范围**: ① e8_vision 视觉提取后端链 ② vision_extract 语义收紧 ③ E6 runner 截图回传块协议（stdout-b64）
④ FormulaAdapter.visual_check 接线 + evaluate checks ⑤ visual_receiver 去 mock ⑥ 模拟机端到端
**结论**: ✅ **E8 视觉语义验证全链路打通——「截图像素 → 真实 OCR 提取 LaTeX → AST Diff → 严格 JSON」
经真实 CLI（`ffx capability verify formula`）在模拟机 emulator-5554 上闭环；
known_latex 代理降级为无截图场景的自洽模式**

---

## 1. 背景

```text
RUN-014 遗留三个缺口（交接说明）：
  ① vision_extract 空壳——known_latex 直接代理，OCR 分支返回 None → OCR_HALLUCINATION
  ② formula.py 未真正调用 e8_evaluator.evaluate()——visual_check 是模拟 result
  ③ E6 只有模拟器渲染证据（virtual_device_runtime），真机 physical_device_runtime ⏳ Release Gate
本轮收口 ①②，并对 ③ 完成模拟机端到端复跑 + 诚实登记。
```

## 2. 实现

### 2.1 e8_vision.py —— 可插拔视觉提取后端链（新文件）

```text
后端优先级（自动探测）：pix2tex → paddleocr → tesseract
  pix2tex     LaTeX-OCR（torch，公式结构感知）——本环境已装且验证可用
  paddleocr   PP-StructureV3 公式管线——本环境未安装，分支按官方 3.x 用法
              编写且标注 UNVERIFIED，异常由链捕获降级（不静默出错结果）
  tesseract   pytesseract + 二值化预处理——线性文本兜底（结构会被拍平，
              AST Diff 会如实报告差异）

选择策略：FFX_E8_VISION_BACKEND=pix2tex|paddleocr|tesseract|none 强制指定
（支持逗号链）；未设置按上表自动探测。全部失败/不可用 → None（不抛异常）。

pix2tex 集成细节（源码 cli.py 实测）：
  - LatexOCR.__init__ 把 root logger 设为 FATAL → 初始化窗口后恢复，
    避免 ffx 进程内 logging 被静音
  - torch>=2.6 torch.load 默认 weights_only=True 可能拒载本地 checkpoint
    → 仅在初始化失败时临时 shim 关闭，加载完即还原
  - temperature 固定 0.01（默认 0.33 采样随机 → 同截图不同判定，
    验证门需可复现；模型单例懒加载）
预处理：白边自动裁剪（纯规范化——E6 截图 RepaintBoundary 可能是大画布，
字形占中间一小块；深色背景自动反转判断），不注入任何信息。
输出归一化：去 $ 包裹、折叠空白；空结果视为提取失败。
日志走 logging（项目规则：禁止 print 调试输出）。
```

### 2.2 e8_evaluator.vision_extract 语义收紧

```text
旧：known_latex 非空直接返回（有截图也走代理）；否则 OCR 空壳 → None
新（RUN-015）：
  screenshot_path 提供时 → 真实视觉提取（像素为真相源）；
    提取失败 → None → OCR_HALLUCINATION——【不回退 known_latex 代理】，
    防止「截图在但没看」被自洽 PASS 掩盖；
  无截图时 → known_latex 代理仍可用（报告 §7 复跑命令路径，行为不变）。
evaluate() 新增可选 observed_latex 直传参数（调用方已自行提取时免二次推理，
如 FormulaAdapter.visual_check 的 provenance 路径）；缺省行为不变。
```

### 2.3 E6 runner 截图回传改造（cap_e6_physical_render_test.dart）

```text
过程发现两个真实缺陷（均有实测证据）：
  ① compact reporter 对超长 stdout 行在 ~120 列处折行——单行
     `E8_PNG_INFO … latex=\frac{a}{b}` 的 latex 被截成 `\frac{a}{` + 换行
     （首跑实测），单行正则会拿到残缺 latex；
  ② flutter test 结束即卸载 app——应用私有目录截图 host 侧无法事后拉取
     （`run-as com.formulafix.formula_fix` → unknown package 实测，
      pm list packages 无 formula 相关包）。

方案：E8_PNG_BEGIN … E8_PNG_END 块协议——PNG 以 base64 按 76 字符分块
直接走 stdout 回传（短行不触发折行），latex 与截图一一对应：
  E8_PNG_BEGIN / name= / bytes= / w= / h= / latex= / b64_begin … b64_end / E8_PNG_END
host 侧解码落盘 + 完整性校验（解码字节数 == runner 报告 bytes，不一致
→ evidence gap 不喂残缺图）。附带收益：未来真机同样适用（免 root/run-as）。
逐公式独立 RepaintBoundary 截图（避免多公式同图干扰视觉提取）。
```

### 2.4 FormulaAdapter.visual_check 接线（formula.py）

```text
新增 visual_check(expected_latex?, screenshot_path?)：
  E6 截图 + Expected LaTeX → extract_with_provenance()（记录后端名）
  → e8_evaluator.evaluate(observed_latex=…)
  → 逐公式严格 JSON 聚合 {status, error_type, backend, mode, results}
  前置缺失（无截图/无 latex）→ None（evidence gap，不伪造判定）。
execute() 接线：E6 渲染 → 截图落盘 → visual_check → metrics['e8_eval']
→ execute evidence detail['e8_visual_semantic']（严格 JSON 全文入证据链）。
evaluate checks 新增 e8_visual_semantic_pass：
  FAIL → verify fail（公式结构与截图不符 = 产品缺陷信号）；
  ERROR（视觉未判定）→ unknown → warn（ADR-0030 INCONCLUSIVE 语义，
  非产品失败）；PASS/无证据 → 不降级。
顺带修复三处既有隐患（均有实测证据）：
  - stale 正则：dart 已改打印 E8_PNG_INFO 而 adapter 只匹配
    E6_PHYSICAL_PNG → e6_screenshot 恒为 None（现兼容两种标记）；
  - evaluate() coverage 在 latest_observation=None 时 .get('id') 崩溃；
  - **中文 Windows GBK stdout 丢失**：subprocess(text=True) 默认按 GBK
    解码 flutter 的 UTF-8 输出 → 读线程 UnicodeDecodeError → stdout
    整体为空（首跑 verify 实测 stdout len=0：截图捕获为空 + render_tests
    0/0 的「静默盲跑」）→ formula.py / runtime_bridge.py 全部子进程
    显式 encoding='utf-8', errors='replace'。
```

### 2.5 visual_receiver.call_e8_evaluator 去 mock

```text
原：占位函数返回 {'status': 'success', 'message': '视觉检查成功'}（模拟 result）
新：真实调用 e8_evaluator.evaluate(expected_latex, screenshot_path) →
json 解析为严格 JSON dict；handler 契约不变（disabled/缺字段/error 分支保留）。
```

## 3. 验证结果

### 3.1 §7 复跑命令（RUN-014 报告，行为不变）

```text
evaluate(r'\frac{a}{b}', known_latex=r'\frac{a}{b}') → PASS / NONE / diff=[]
evaluate(r'\frac{a}{b}', known_latex=r'\frac{b}{a}') → FAIL / STRUCTURE_INVERSION
evaluate(r'E = mc^2',   known_latex=r'E = mc')      → FAIL / MISSING_ELEMENT
```

### 3.2 单元测试（hermetic，fake 后端注入，不依赖模拟器/模型）

```text
cd tools/ffx-cli && python -m pytest cli_anything/ffx/tests/
→ 114 passed / 1 skipped（新增 test_e8_vision.py 28 用例：
  后端链选择/降级/归一化、vision_extract 语义收紧、visual_receiver 严格 JSON、
  visual_check 聚合判定、evaluate checks 接线、块协议解析、落盘完整性校验）
测试基建修复（环境性失败，非回归）：
  - ffx 未安装 → pip install -e tools/ffx-cli 恢复控制台脚本
  - 中文 Windows GBK 管道编码炸 --help 输出（↔ 字符）→ 根 conftest.py
    统一子进程 UTF-8 + test_full_e2e 显式 encoding="utf-8" 解码
```

### 3.3 模拟机端到端（emulator-5554，真实 CLI 全链路）

```text
flutter analyze integration_test/cap_e6_physical_render_test.dart → No issues
flutter test integration_test/cap_e6_physical_render_test.dart -d emulator-5554
→ All tests passed（结构断言 + 两张逐公式截图 stdout-b64 回传）
ffx --json capability verify formula → diagnostic_id art_0053：

render_tests_passed=46 failed=0（GBK 修复前为 0/0 静默盲跑）
e6_physical_render.ok=true（截图 base64 解码落盘 .ffx/tmp/verify/formula-*/）
e8_visual_semantic（mode=real_vision, backend=pix2tex, temperature=0.01）：
  E = mc^2   observed=E=m c^{2}      → PASS  / diff=[]
  \frac{a}{b} observed=\frac{Q}{\overline{{{\cal J}}}}
             → FAIL / STRUCTURE_INVERSION（numerator/denominator mismatch）

verify 整体 status=fail 由两个独立因子驱动：
  ① no_adi_render_failure=false —— .adi/observations 存在 2026-08-16 的
     遗留观察 err_20260816160407（RenderFlex overflowed 99860px，本轮之前
     的工作区状态），ADI 绑定检查按契约如实判 fail；
  ② e8_visual_semantic_pass=false —— 分式截图 OCR 误读（见 §4 边界）。
E8 视觉语义门本身工作正常：无法确认结构 ≠ 结构确认（不伪造 PASS）。
```

### 3.4 OCR 保真度实验记录（本轮实测，供后续提质参考）

```text
| 实验                                   | emc2 结果     | frac 结果            |
|----------------------------------------|---------------|----------------------|
| pixelRatio 2.0（定稿）                 | E=m c^{2} ✅  | Q/\bar J ❌          |
| 动态高分辨率（目标宽 600px）           | 长串幻觉 ❌   | Q/\bar J ❌          |
| 裁剪后上采样 ×2~×6                     | —             | 仍误读 ❌            |
| temperature 0.01/0.1                   | 不变          | 不变（确定性误读）   |
| matplotlib mathtext 渲染（非 CM 字体） | 接近但 C 大写 | \mathbb{C}/\not\to ❌|

结论：pix2tex 对 flutter_math_fork 小字号分式字形不可靠；结构（\frac{}{}）
可识别但操作数误读。后续提质方向：texify 对照 / 更大渲染字号采集 /
分式上下半图分别提取 / PP-FormulaNet。
```

## 4. 意义

```text
✅ 「截图里的公式结构是否正确」从 known_latex 自洽升级为像素级真相源：
   Observed = OCR(截图像素)，与 Expected 独立——评审建议的完整视觉语义闭环
✅ FFX verify formula 产出真实 E8 JSON（evidence detail.e8_visual_semantic），
   FAIL 可作为产品缺陷信号进入 diagnose/repair 链路
✅ E6↔E8 打通：一次 verify 同时产出 virtual_device_runtime 渲染证据 +
   E8 视觉语义判定（同一截图单一真相源）
⚠️ OCR 保真度是新的诚实边界（§3.4 实验记录）：pix2tex 对 flutter_math_fork
   小字号分式字形不可靠（\frac{a}{b} 稳定误读为 \frac{Q}{\bar J}），
   emc² 级别的行内公式可正确读取——FAIL 判定可能是 OCR 局限而非产品缺陷，
   需人工看 diff_details 复核；E8 门语义是「无法确认结构 ≠ 结构确认」
```

## 5. Phase 3.11 状态更新

```text
E8 Visual   🟡 Pipeline 三层 ✅ + E8 Evaluator ✅ + 真实视觉提取 & FFX 接线 ✅ 本轮
            / 模拟机端到端 ✅ 本轮 / 真机 physical_device_runtime ⏳ Release Gate
E6 Physical 🟡 模拟器渲染 + 截图证据 ✅（本轮块协议化复跑）/ 真机 ⏳
→ PHASE_3_11_EXIT 待 Owner 判定；真机截图仍为 release gate 未满足项
```

## 6. 下一步

```text
真机 physical_device_runtime 截图（USB 连接真机 → FFX_E6_DEVICE_SERIAL=<serial>
跑同一流程 → contracts/formula.json evidence_strength.achieved 才可追加
'physical_device_runtime'——模拟器证据不得语义偷换为真机等级）
→ OCR 提质选项：texify 对照 / 更大渲染字号采集 / 分式上下半图分别提取 /
  PP-FormulaNet（pixelRatio 提高与 temperature 已实测排除，见 §3.4）
→ PHASE_3_11_EXIT 判定 + PR 合并
```

## 7. 复跑命令

```bash
# ① §7 语义用例（RUN-014，行为不变）
cd tools/ffx-cli && python -c "
from cli_anything.ffx.harness.e8_evaluator import evaluate
print(evaluate(r'\frac{a}{b}', known_latex=r'\frac{a}{b}'))  # PASS
print(evaluate(r'\frac{a}{b}', known_latex=r'\frac{b}{a}'))  # FAIL / STRUCTURE_INVERSION
"

# ② 全量单测（114 passed）
cd tools/ffx-cli && python -m pytest cli_anything/ffx/tests/ -v

# ③ 模拟机 E6 渲染 + 截图回传
cd flutter_app && flutter test integration_test/cap_e6_physical_render_test.dart -d emulator-5554

# ④ 端到端（FFX verify → E6 → E8 视觉语义判定）
ffx --json capability verify formula

# 强制指定/禁用视觉后端（可选）
set FFX_E8_VISION_BACKEND=pix2tex   # 或 paddleocr / tesseract / none
```
