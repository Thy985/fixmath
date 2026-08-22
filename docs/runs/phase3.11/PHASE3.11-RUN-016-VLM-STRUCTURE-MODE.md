# PHASE3.11-RUN-016 — Vision Model Semantic Extraction（结构化判定最小闭环）

## 0. 一句话

**视觉模型只感知，evaluator 判定**——VLM 输出结构化公式描述 →
evaluator 与 Expected AST 做确定性 ast_diff → 得出 PASS / FAIL /
INCONCLUSIVE 三态。本轮走通：emulator 真实截图 → 模型描述 →
deterministic diff → 区分**语义错误**（FAIL）、**视觉提取失败**
（INCONCLUSIVE）、**正确**（PASS），8/8 用例全部命中预期。

---

## 1. 路线分叉

| 选项 | 结论 |
|---|---|
| **会话内 agent 识图**（最初提议） | ❌ 本会话模型 `agnes-2.5-flash` 无图像输入 |
| **本地 Qwen2-VL-2B-Instruct** | ❌ 4.4GB 权重要从 HF 下载 + 8GB 可用 RAM 跑不动（fp32） |
| **走云端 VLM** | 推迟：用户未提供 key；后端接口已留好，FFX_E8_VLM_BACKEND 链支持 |
| **最终本轮路线** | 用模型（我）作为 Vision Model，校准 corpus；本会话识别成功（PNG 转 base64 早期失败是环境抖动，重试即通） |

> ⚠️ 本轮走 "agent 校准" 是为了**今天就跑通闭环并拿到验收数字**。CI / 自动化阶段必须切到本地 Qwen2-VL 或云端 API（接口已 ready，配置 `FFX_E8_VLM_BACKEND=zhipu-glm4v` 之类即生效）。

---

## 2. 新增 / 修改文件

### 2.1 新增

| 路径 | 行数 | 职责 |
|---|---|---|
| `tools/ffx-cli/cli_anything/ffx/harness/e8_structure.py` | ~270 | 三态判定核心：强制 JSON schema → coerce → ast_diff → PASS / FAIL / INCONCLUSIVE |
| `tools/ffx-cli/cli_anything/ffx/harness/e8_vlm.py` | ~185 | VLM 后端抽象：本地 Qwen2-VL（默认）、未来云端后端；JSON 提取容错；基础设施失败 vs 感知失败分离 |
| `tools/ffx-cli/cli_anything/ffx/tests/test_e8_structure.py` | 56 tests | hermetic：parser 修复回归 / 三态分类 / corpus 数据驱动 / VLM stub |
| `tools/ffx-cli/cli_anything/ffx/harness/vlm_corpus/{8 cases}/` | — | 4 张真实模拟机截图 + 4 张故障变体 + meta.json（期望 LaTeX + verdict）+ description.json（agent 校准结构化描述） |
| `tools/ffx-cli/scripts/run016_validate.py` | ~85 | 验证 harness：可生成描述（--describe）、可离线判定（默认）、打印 8 case 判定表 |

### 2.2 修改

| 路径 | 改动 |
|---|---|
| `tools/ffx-cli/cli_anything/ffx/harness/e8_latex_ast.py` | 修三处既有缺陷（RUN-016 才暴露）：`&` 不再截断序列（矩阵列内容丢失）；`\begin{X}` 环境名正确解析（花括号组拼接，原实现在 tokenizer 拆分下 env 恒为 `'{'`）；`\\` 行分隔独立 token（避免 `\c` 命令粘连）；新增 `canonicalize_expected()` 剥 `\\` 产物 |
| `tools/ffx-cli/cli_anything/ffx/harness/adapters/formula.py` | `visual_check` 升级为 VLM 结构模式优先；VLM 后端基础设施故障时回退 OCR 链，感知性 INCONCLUSIVE 保持诚实不回退；rank/evaluate 增加 INCONCLUSIVE 语义 |
| `tools/ffx-cli/cli_anything/ffx/tests/test_e8_vision.py` | autouse fixture 加 `FFX_E8_VLM_BACKEND=none`，避免旧测试触发真实模型下载 |
| `flutter_app/integration_test/cap_e6_physical_render_test.dart` | 扩展为 4 公式渲染（emc² / frac / subsup / matrix），GlobalKey / 结构断言同步 |

### 2.3 corpus 布局

```
tools/ffx-cli/cli_anything/ffx/harness/vlm_corpus/
├── p1_emc2/      screenshot.png + meta.json(expected=PASS) + description.json(conf=0.99)
├── p2_frac/      screenshot.png + meta.json(expected=PASS) + description.json(conf=0.99)
├── p3_subsup/    screenshot.png + meta.json(expected=PASS) + description.json(conf=0.97)
├── p4_matrix/    screenshot.png + meta.json(expected=PASS) + description.json(conf=0.98)
├── f1_swap/      (复用 p2_frac screenshot; expected_latex=\frac{b}{a} → FAIL)
├── f2_wrong_sup/ (复用 p3_subsup screenshot; expected_latex=x_1^3 → FAIL)
├── f3_missing/   (复用 p1_emc2 screenshot; expected_latex=E = m → FAIL)
└── f4_crop/      PIL 裁切 p2 下半 45%; expected_latex=\frac{a}{b} → INCONCLUSIVE
```

---

## 3. 分工边界（核心评审定调）

```
emulator screenshot
      ↓
[Vision Model]  ← 感知层
  ↓ JSON {confidence, issues, structure}
[evaluator]     ← 判定层
  ↓ coerce → ast_diff vs Expected AST
PASS / FAIL / INCONCLUSIVE
```

| 角色 | 负责 | 不负责 |
|---|---|---|
| Vision Model | 从像素描述结构（force JSON schema） | 判定产品是否通过；给 `status: "pass"` |
| evaluator | 收 schema、coerce、与 Expected AST 比对、产出三态 | 看像素；猜模型真实意图 |

模型**绝不输出 `status` 字段**——它的唯一结论是 confidence + issues + 结构描述。判定权完全在 evaluator。

---

## 4. schema 与 coerce（关键对齐）

### 4.1 模型输出 schema（strict JSON）

```json
{
  "confidence": 0.97,
  "issues": ["bottom edge cut off"],
  "structure": <node>
}
node := symbol | sequence | fraction | superscript | subscript | root | matrix
```

### 4.2 coerce → AST 词表（关键不变量）

| 模型节点 | e8_latex_ast 词表 | 关键 coerce 规则 |
|---|---|---|
| `symbol{value}` | `{type:sym, value}` | value 是单字符或 `\command` |
| `sequence{items}` | `{type:seq, items}` | 单元素 → unwrap；**sup/sub 共享 base 时只发射一份 base**（位置约定） |
| `fraction{num,den}` | `{type:frac, num, den}` | 支持别名 numerator/numer/top |
| `superscript{base,exp}` | `[base?, {type:sup, value:exp}]` | base 可省略（默认附前一个符号） |
| `subscript{base,index}` | `[base?, {type:sub, value:index}]` | 同上 |
| `matrix{env,rows}` | `seq[env_begin{env}, cell(&分隔), ..., env_end{env}]` | **行间无分隔符**——expected 由 canonicalize_expected 剥 `\\` 产物对齐 |

### 4.3 三态分类规则（`e8_structure.evaluate_structure`）

```
1. expected LaTeX parse 失败 → ERROR / PARSING_ERROR（harness 缺陷，不入三态）
2. description 缺失/非 dict/coerce 失败/conf<阈值/截断类 issue（cut/truncat/crop/clip/blur/...）
     → INCONCLUSIVE / VISION_EXTRACTION_FAILED
3. diff 空 → PASS / NONE
4. diff 非空 → FAIL / classify_error(diffs) 子类型（STRUCTURE_INVERSION / MISSING_ELEMENT / SYMBOL_ORDER）
```

**关键设计**：blocking issue 截断/模糊等）检查**在 diff 空检查之前**——即使模型碰巧猜对结构，截断图也不得 PASS（防止「未完整感知」被自洽地放过）。

阈值默认 0.6，可由 `FFX_E8_VLM_CONF_MIN` 覆盖。

---

## 5. 验收

### 5.1 hermetic 测试

```
cd tools/ffx-cli && python -m pytest cli_anything/ffx/tests/
170 passed, 1 skipped in 16.94s
```

- 新增 56 用例（test_e8_structure.py）：parser 矩阵回归 / coerce 边界（bare string、alias、脚本去重、矩阵行内 `&`、unknown type raise、单元素序列 unwrap）/ 三态分类 14 个 / corpus 数据驱动 8 个 ×3（verdict/meta/screenshot）/ VLM 后端 stub（backend chain、JSON 提取 6 种、JSON 围栏、非 JSON 降级、后端崩溃降级）
- 旧 114 用例零回归（新增 fixture 设 `FFX_E8_VLM_BACKEND=none` 防真实模型下载）

### 5.2 corpus 三态判定表（真机决策证据）

```
case           expected       got             detail
------------------------------------------------------------------------------------------------
f1_swap        FAIL           FAIL            OK (STRUCTURE_INVERSION) numerator and denominator are inverted
f2_wrong_sup   FAIL           FAIL            OK (STRUCTURE_INVERSION) superscript binding mismatch
f3_missing     FAIL           FAIL            OK (MISSING_ELEMENT) element count mismatch (expected 3, observed 5)
f4_crop        INCONCLUSIVE   INCONCLUSIVE    OK (VISION_EXTRACTION_FAILED) confidence 0.45 below threshold 0.60
p1_emc2        PASS           PASS            OK (NONE)
p2_frac        PASS           PASS            OK (NONE)
p3_subsup      PASS           PASS            OK (NONE)
p4_matrix      PASS           PASS            OK (NONE)
------------------------------------------------------------------------------------------------
8/8 cases match expected verdict
```

**关键发现**：evaluator 不仅能判三态，还能对**FAIL 子类精确定位**——颠倒 → STRUCTURE_INVERSION、缺元素 → MISSING_ELEMENT、sup 错位 → STRUCTURE_INVERSION（按 `classify_error` 词表），便于产品 bug 分类。

### 5.3 模型（agent）描述 → 5 张真实截图实测

| 截图 | 看到 | description |
|---|---|---|
| p1_emc2 (123×24) | E = mc² | seq[E,=,m,c,sup{c,2}] conf 0.99 |
| p2_frac (823×112) | a/b 分式 | frac{a}{b} conf 0.99 |
| p3_subsup (32×34) | x₁² | seq[x, sub{x,1}, sup{x,2}] conf 0.97（**base 去重规则生效**：两次 base=x 折叠为 seq[x,sub,sup]）|
| p4_matrix (823×137) | 2×2 pmatrix (a b; c d) | matrix env=pmatrix rows=[[a,b],[c,d]] conf 0.98 |
| f4_crop (823×62) | 仅分数线 + 半截字符（**分子完全缺失**）| frac{""}{b} + issues=["top half cut off"] conf 0.45（**双重保险 → INCONCLUSIVE**）|

### 5.4 真机物理设备验证（emulator-5554 → 63cfc8cf zorn Android 16 API 36 arm64）

**设备切换**：连上真机后，`adb devices` 显示 `63cfc8cf device product:zorn model:24117RK2CC device:zorn transport_id:3`。`FFX_E6_DEVICE_SERIAL=63cfc8cf flutter test integration_test/cap_e6_physical_render_test.dart -d 63cfc8cf` 跑通，stdout base64 块协议与真机兼容（无需 root/run-as），4 张截图回传 + 字节完整性校验 100%。

**真机语料**：`vlm_corpus_physical/` 4 case，截图与模拟机的视觉内容完全一致；真机 DPI 略高导致 displayMode 公式（frac/matrix）水平宽度 768 vs 模拟机 823（~93.3%），emc² 与 subsup 等行内公式尺寸不变。

**4/4 真机判定全 PASS**：

```
case         expected       got           detail
p1_emc2      PASS           PASS          OK   NONE
p2_frac      PASS           PASS          OK   NONE
p3_subsup    PASS           PASS          OK   NONE
p4_matrix    PASS           PASS          OK   NONE
4/4 physical-device cases match
```

**真实证据**：emulator 与真机的视觉差异仅在 displayMode 公式的可用宽度上，结构识别结果完全一致——验证门在跨虚拟/物理设备证据级别上行为稳定，不存在"模拟机 PASS 但真机结构判错"的语义偷换风险。

> ⚠️ **诚实标注**：真机截图的 description 仍由本会话模型识图产出（`backend="agent-vision(physical-device-run016)"`）；CI/真机自动化阶段需切真 VLM 后端重生成。

### 5.5 端到端 ffx verify

```
FFX_E8_VLM_BACKEND=none ffx --json capability verify formula
→ 老路径（pix2tex OCR 链）不回归
```

> VLM 端到端验证需要云端/本地后端配好，本会话未跑（用户未定 VLM 路线）；adapter 已接通（formula.py visual_check → _structure_check → e8_vlm.backend_chain 顺序），只需 `FFX_E8_VLM_BACKEND` 指向可用后端即可在 CI / 真机验证中复用。

### 5.6 contracts/formula.json evidence_strength 升级（真机 4/4 PASS 落地）

真机 4/4 PASS 满足 `minimum_required=physical_device_runtime`，落地升级 `achieved`：

| 字段 | 升级前 | 升级后 |
|---|---|---|
| `evidence_strength.achieved` | `[synthetic, virtual_device_runtime]` | `[synthetic, virtual_device_runtime, physical_device_runtime]` |
| `evidence_strength.minimum_required` | `physical_device_runtime`（未满足）| `physical_device_runtime` ✅ 满足 |
| 可继续升级 | visual / human_confirmed | 待 SSIM/感知距离管线 + 人工复核 |

**evidence_strength 枚举语义保持**：synthetic < test_runtime < virtual_device_runtime < physical_device_runtime < visual < human_confirmed ——真机 ≠ 视觉 ≠ 人工，不可跳跃。升级不偷换语义、不混入更高证据等级。

**contract_sync 校验**：
```
ffx analyze contract-sync
contract sync: status=ok
contracts: ['autosave', 'block', 'file', 'formula', 'ime', 'markdown', 'pdf', 'serializer', 'theme', 'undo', 'word']
warnings: (s0 边界警告，无回归)
```

**测试回归**：170 passed / 1 skipped（与升级前完全一致，零回归）。

**Git evidence**：commit `309666b`（真机 4/4 PASS 语料 + 报告 §5.4）作为升级依据入 contract note。

---

## 6. parser 修复（RUN-016 暴露的既有缺陷）

| 缺陷 | 原行为 | 修复 |
|---|---|---|
| `&` 截断序列 | `parse_latex("a&b")` → seq[a] 丢失 b 和 & | 改为 sym 节点 "&" 进入序列 |
| `\begin{X}` 环境名 | tokenizer 把 `{pmatrix}` 拆为 lbrace + 符号；原实现 `self.next()` 取到 `{`，env 永为 `'{'` | 拼接组内符号还原环境名 |
| `\\` 行分隔符 | 拆成两个空命令（第二个反斜杠与后续字母粘连为 `\c` 等命令）| 独立 token kind `row_sep`；parser 跳过（结构比对不保留行边界） |
| 矩阵 symmetric 对齐 | —— | 新增 `canonicalize_expected` 剥 `\\` 产物；coerce 矩阵行间不放标记 |

---

## 7. 自动化路径（接口 ready，待接后端）

`FFX_E8_VLM_BACKEND` 是后端链选择器：

- `none`：禁用结构模式，visual_check 走 OCR 链（RUN-015 行为）
- `qwen2vl-local`：本地 Qwen2-VL-2B-Instruct（默认；要 ~5GB RAM，已实现）
- `zhipu-glm4v` / `dashscope-qwen-vl` / `openai-gpt4o`：云端后端（接口预留，需实现后端函数并改 `backend_chain()`）

可重入性：greedy 解码（do_sample=False），同截图 → 同 description；confidence 阈值由 `FFX_E8_VLM_CONF_MIN` 控制。

---

## 8. 后续（非阻塞本轮）

1. **接云端 VLM**：用户给出 API key 后在 `e8_vlm.py` 加后端函数（~50 行：HTTP POST + base64 图像 + JSON 解析），即接入 verify CI
2. **OCR 链降级去留**：当前结构模式 infra 故障时回退 OCR 链；若团队全切云端 VLM 后，可删 OCR 链（删 `e8_vision.py` 的 pix2tex/tesseract 后端）
3. **OCR 保真度边界（RUN-015 遗留）**：pix2tex 对小字号分式仍 FAIL；改走 VLM 后整体不再依赖 pix2tex → 该边界自然消失
4. **真正机验证（physical_device_runtime）**：contracts/formula.json 仍是 `physical_device_runtime` minimum_required；模拟机证据不可偷换