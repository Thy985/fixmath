# Task Contract: Phase 2.3 BlockEditor 双向映射 + BlockTypeDetector + 性能基线

> AI Agent 在开始编码前必须填写此契约。复杂任务提交 Human Owner 审批后再开始实现。

---

Task ID: ROADMAP Phase 2.3

---

## 1. Goal（目标）

要解决的问题：**为 BlockEditor 抽象实现 source ↔ DocumentElement 双向映射、BlockType 规则检测器骨架、1000 块性能基线**。

ADR-0007（[docs/ADR/0007-blockeditor-abstraction-design.md](file:///d:/Projects/Active/math/docs/ADR/0007-blockeditor-abstraction-design.md)）已 Accepted。Phase 2.2（PR #27，commit `c94ad4e`）落地了接口骨架与状态机。本任务落地 ADR-0007 §实施计划 Phase 2.3：

> - 实现 `BlockEditor.toElement()` / `fromElement()` 双向映射
> - 实现 `BlockTypeDetector`（Markdown 快捷映射）
> - 性能测试：1000 块 Document 增量解析 < 16ms（ROADMAP 退出条件）

**不实现**：
- BlockTypeDetector 集成到 `onSourceChanged`（Phase 2.7）
- BlockOperations 五原语（Phase 2.6）
- ComposingRegion 接入 UI（Phase 2.5）
- EmptyLineElement 移除 / TableElement 拆分（Phase 2.4 评估）
- AST 字段修改（HeadingElement.text / BlockquoteElement.text 仍为 plain String）

---

## 2. Scope（范围）

### 修改

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `flutter_app/lib/core/editing/block_serializer.dart` | 新增 | toElement / fromElement 顶层函数 + InlineSerializer 递归工具 |
| `flutter_app/lib/core/editing/block_type_detector.dart` | 新增 | detect(source) → BlockType? 纯函数，7 条规则检测 |
| `flutter_app/test/editing/block_serializer_test.dart` | 新增 | 9 类 BlockType round-trip + InlineSerializer 8 类 + 边界 |
| `flutter_app/test/editing/block_type_detector_test.dart` | 新增 | 7 条规则正负样本 |
| `flutter_app/test/performance/block_perf_test.dart` | 新增 | 1000 块单块 toElement < 16ms |
| `flutter_app/test/architecture/editing_layer_test.dart` | 修改 | 守门：block_serializer / block_type_detector 不反向 import |
| [docs/contracts/phase2.3-task-contract.md](file:///d:/Projects/Active/math/docs/contracts/phase2.3-task-contract.md) | 新增 | 本 Task Contract |

### 不修改

- `lib/data/models/document.dart`（AST 严禁改动，保护导出器）
- `lib/core/parser/markdown_parser.dart`（仅复用 `MarkdownParser.parseInline`，不改 parser）
- `lib/core/parser/formula_extractor.dart`（不改）
- `lib/core/editing/block_editor.dart` / `block_editor_state.dart` / `block_types.dart`（Phase 2.2 产物已稳定）
- `lib/core/utils/history_manager.dart`（Phase 2.6 才扩展）
- `lib/presentation/` 下任何 UI 代码（[AGENTS.md §6.5](file:///d:/Projects/Active/math/AGENTS.md) Phase 2 UI 冻结）
- ADR-0001 ~ 0007（不动架构决策）
- AGENTS.md / ROADMAP.md（不动顶层规范）
- pubspec.yaml（不引入新依赖）

---

## 3. Expected Behavior（预期行为）

### Before（当前行为）

- `lib/core/editing/` 仅含 Phase 2.2 接口骨架（3 文件），无任何实现
- BlockEditor 接口的 `source` getter 在 Phase 2.2 是抽象定义，无 toElement / fromElement
- 无 BlockTypeDetector，无性能基线
- MarkdownParser 只支持整篇 `parse(content)` 与 `parseInline(text)`，无单块解析

### After（目标行为）

- `lib/core/editing/block_serializer.dart` 导出两个顶层函数：
  - `DocumentElement toElement(String source, BlockType type)`：单块解析
  - `String fromElement(DocumentElement element)`：单块序列化
  - 私有 `InlineSerializer` 类：递归处理 8 类 InlineElement
- `lib/core/editing/block_type_detector.dart` 导出：
  - `BlockType detectBlockType(String source)`：7 条规则检测，**永不返回 null**，无匹配时返回 `BlockType.paragraph`（减少调用方分支）
- 9 类 BlockType 的 toElement / fromElement round-trip 测试全部通过
- 8 类 InlineElement 序列化测试通过
- BlockTypeDetector 7 条规则正负样本测试通过
- 性能基线：
  - 单块 toElement 典型耗时 < 5ms
  - 单块 toElement 最坏耗时 < 16ms（60fps 帧预算，与 ROADMAP Phase 2 退出条件对齐）
  - 1000 块整篇 `MarkdownParser.parse` 耗时记录（信息性对照，无强制阈值）
- 守门测试通过：block_serializer / block_type_detector 不反向 import
- `flutter analyze` 无 error，`flutter test` 0 regression

### Round-trip 一致性定义：AST equivalence（非字符串等价）

Markdown 不是 canonical 形式（如 `*hello*` 与 `_hello_` 语义等价但字符串不等）。因此 Phase 2.3 round-trip 测试采用 **AST equivalence** 判定，而非字符串等价：

```dart
// 不是：
// expect(fromElement(toElement(source, type)), equals(source));

// 而是：
final element1 = toElement(source, type);
final serialized = fromElement(element1);
final element2 = toElement(serialized, type);
expect(_astDeepEquals(element1, element2), isTrue);
```

`_astDeepEquals` 在 `test/editing/block_serializer_test.dart` 实现为私有 helper，递归比较 9 类 BlockType + 8 类 InlineElement 的所有字段（含 `List<InlineElement>` 嵌套、`List<List<String>>` 表格行）。

### Round-trip 一致性边界（非目标，docstring 标注）

接受"非 bit-perfect round-trip"，以下场景在 docstring 标注限制，不实现转义：

- `TextElement` 含未配对 `*` / `_` / `` ` `` / `[` / `!` / `~` → 重解析时可能误识别
- `TableElement` cell 含 `|` → parser 用 `split('|')` 会误拆
- `CodeElement.code` 含 ``` ``` ``` → fence 冲突
- `CodeElement.language` 大小写不保（` ```MERMAID ``` ` round-trip 后变 `mermaid`）

---

## 4. Validation Plan（验证计划）

### Unit Test

| 测试文件 | 验证点 | 预期结果 |
|----------|--------|---------|
| `test/editing/block_serializer_test.dart` | toElement: 9 类 BlockType 各 1 个正样本 | ✅ |
| 同上 | toElement: 9 类 BlockType 边界（空 source / 极端 offset） | ✅ |
| 同上 | fromElement: 9 类 BlockType 各 1 个正样本 | ✅ |
| 同上 | round-trip: 9 类 BlockType **AST equivalence**（`parse(source) == parse(fromElement(toElement(source, type)))`，用 `_astDeepEquals` 私有 helper） | ✅（除 docstring 标注的非 bit-perfect 场景） |
| 同上 | InlineSerializer: 8 类 InlineElement 序列化 | ✅ |
| 同上 | InlineSerializer: 嵌套 Bold/Italic/Strikethrough | ✅ |
| 同上 | MermaidElement 与 CodeElement(language=mermaid) 互转 | ✅ |
| 同上 | TableElement 含分隔行 `\|---\|---\|` | ✅ |
| 同上 | ListElement ordered/unordered + indent | ✅ |
| 同上 | TaskListItemElement checked/unchecked | ✅ |
| `test/editing/block_type_detector_test.dart` | 7 条规则正样本：`# ` / `- ` / `- [ ] ` / `1. ` / ` ``` ` / `> ` / `---` | ✅ |
| 同上 | 6 条规则负样本：纯文本 / 空字符串 / 不完整语法 → 返回 `BlockType.paragraph`（非 null） | ✅ |
| 同上 | taskListItem 优先于 listItem（避免误判） | ✅ |
| 同上 | horizontalRule 三种形式 `---` / `***` / `___` | ✅ |
| 同上 | detector 返回类型为 `BlockType`（非 `BlockType?`） | ✅ |

### Integration Test

| 测试文件 | 验证流程 | 预期结果 |
|----------|---------|---------|
| - | Phase 2.3 无集成测试（无 UI 接入，纯逻辑） | - |

### Manual Verification

1. `flutter analyze` 无 error
2. `flutter test` 全部通过
3. 9 类 BlockType round-trip AST equivalence 测试 100% 通过
4. 7 条 detector 规则正负样本完整，detector 返回 `BlockType`（非 null）
5. 性能测试：单块典型 < 5ms，单块最坏 < 16ms
6. 守门测试通过（core/editing 不反向 import）
7. 文件均 < 400 行（[AGENTS.md §1.2](file:///d:/Projects/Active/math/AGENTS.md)）
8. 每个文件有 1-3 行 `///` 顶部文档（[AGENTS.md §2.4](file:///d:/Projects/Active/math/AGENTS.md)）

### Architecture Validation

| 检查项 | 验证方式 | 预期结果 |
|--------|---------|---------|
| 分层依赖方向 | [test/architecture/editing_layer_test.dart](file:///d:/Projects/Active/math/flutter_app/test/architecture/editing_layer_test.dart) 扩展 | block_serializer / block_type_detector 不 import presentation / domain / providers |
| AST 不修改 | git diff lib/data/models/document.dart | 无变更 |
| Parser 不修改 | git diff lib/core/parser/ | 无变更（仅复用 parseInline） |
| HistoryManager 不修改 | git diff lib/core/utils/history_manager.dart | 无变更 |
| Phase 2.2 产物不修改 | git diff lib/core/editing/block_editor.dart lib/core/editing/block_editor_state.dart lib/core/editing/block_types.dart | 无变更 |
| 不引入新依赖 | git diff pubspec.yaml | 无变更 |
| 文件大小 | wc -l flutter_app/lib/core/editing/*.dart | 每个 < 400 行 |

### Performance Validation

| 测试文件 | 验证点 | 预期结果 |
|----------|--------|---------|
| `test/performance/block_perf_test.dart` | 单块 toElement 典型耗时（1000 块循环取平均） | < 5ms |
| 同上 | 单块 toElement 最坏耗时（极端长 paragraph / 复杂 inline 嵌套） | < 16ms（60fps 帧预算） |
| 同上 | 1000 块整篇 `MarkdownParser.parse` 耗时（信息性对照，与 Phase 2.3 工作无直接关系） | 记录但不强制阈值 |

**性能指标语义说明**：
- **5ms**：单块 latency 严格预算。增量解析场景下（用户编辑触发单块重解析），5ms 保证输入响应不卡顿
- **16ms**：单块 latency 极端预算。对应 ROADMAP Phase 2 退出条件"1000 块增量解析 < 16ms"——"增量解析"语义为单次 toElement 调用，不是 1000 块整体
- **16ms 不是 1000 块整体预算**：1000 块整体 throughput 不在 Phase 2.3 验收范围（属 Phase 2.4 性能优化评估项）

---

## 5. Success Criteria（完成标准）

任务完成必须满足：

- [ ] `flutter_app/lib/core/editing/block_serializer.dart` 已创建
- [ ] `flutter_app/lib/core/editing/block_type_detector.dart` 已创建
- [ ] `toElement(source, type)` 顶层函数已实现（9 类 BlockType 全覆盖）
- [ ] `fromElement(element)` 顶层函数已实现（9 类 BlockType 全覆盖）
- [ ] `InlineSerializer` 私有类已实现（8 类 InlineElement 递归序列化）
- [ ] `detectBlockType(source)` 纯函数已实现（7 条规则，返回 `BlockType` 非 `BlockType?`）
- [ ] round-trip AST equivalence 测试覆盖 9 类 BlockType（用 `_astDeepEquals` helper）
- [ ] InlineSerializer 测试覆盖 8 类 InlineElement + 嵌套
- [ ] detector 测试覆盖 7 条规则正负样本（负样本断言返回 `BlockType.paragraph`）
- [ ] 性能测试：单块典型 < 5ms 通过
- [ ] 性能测试：单块最坏 < 16ms 通过
- [ ] 守门测试通过（block_serializer / block_type_detector 不反向 import）
- [ ] Task Contract 已填写完整
- [ ] `flutter analyze` 无 error
- [ ] `flutter test` 全部通过（Phase 2.2 基线 370 + Phase 2.3 新增 N，0 regression）
- [ ] **未修改** AST / parser / history_manager / Phase 2.2 产物 / UI 代码
- [ ] **未引入** 新依赖
- [ ] PR 已创建

---

## 6. Rollback Plan（回滚方案）

如果出现问题：

回滚方式：

1. **Task Contract 未通过 Human Owner 审批**：直接 close PR，分支保留。重新修订 Task Contract 后再提交。
2. **round-trip 测试发现重大丢字**：在 docstring 标注限制场景，不实现转义（属 Phase 2.4+ 评估）。若丢字超出可接受范围，需重新评估 ADR-0007 §1.3 wrapping 策略。
3. **性能测试 ≥ 16ms**：分析瓶颈（预计在 inline 解析）。Phase 2.3 接受失败，标记为已知问题，留到 Phase 2.4 性能优化。
4. **toElement / fromElement API 设计缺陷**：Phase 2.3 产物尚未被任何业务代码使用，可直接修改 API 不影响其他模块。
5. **整体回滚**：删除 `lib/core/editing/block_serializer.dart` + `block_type_detector.dart` + 3 测试文件，对 Phase 2.2 已合并代码零副作用（独立文件 + 0 业务接入）。

回滚不影响 Phase 1 / Phase 2.2 已稳定的代码与测试，因为 Phase 2.3 新建独立文件，不改业务代码。

---

## 7. Feedback Signals（反馈信号）

### 成功信号

- ✅ Human Owner 在 PR review 中明确 Approve Task Contract + 代码
- ✅ `flutter analyze` 无 error
- ✅ `flutter test` 全部通过，0 regression
- ✅ 9 类 BlockType round-trip 测试 100% 通过
- ✅ 7 条 detector 规则正负样本完整
- ✅ 性能测试 < 16ms
- ✅ Phase 2.4 启动时，开发者能直接基于 `toElement` / `fromElement` 评估 AST 重构需求

### 失败信号

- ❌ Human Owner 在 PR review 中 Request Changes，指出映射策略有重大缺陷
- ❌ `flutter analyze` 报 error
- ❌ `flutter test` 出现 regression（Phase 2.2 基线 370 测试有失败）
- ❌ round-trip 测试发现超出 docstring 标注范围的丢字
- ❌ 性能测试 ≥ 16ms 且无法在 Phase 2.3 范围内优化
- ❌ 守门测试失败（block_serializer / block_type_detector 反向 import）

---

## 8. Risk Assessment（风险评估）

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| Round-trip 丢字超出可接受范围 | 高 | 中 | docstring 明确标注非 bit-perfect 场景；Phase 2.4 评估转义策略 |
| MermaidElement 与 CodeElement(language=mermaid) 互转边界 | 中 | 中 | toElement 内部统一判定：`language.toLowerCase() == 'mermaid'` 返回 MermaidElement；fromElement 硬编码 `mermaid` 小写 |
| ListElement 多行合并 parser buggy 行为 | 中 | 低 | Phase 2.3 round-trip 测试不构造嵌套列表场景；toElement 按"单 ListElement = 单 `- item` 行"实现 |
| 性能测试 ≥ 16ms | 中 | 中 | 预计瓶颈在 inline 解析；Phase 2.3 接受失败标记为已知问题，留 Phase 2.4 优化 |
| TableElement cell 含 `\|` 误拆 | 中 | 低 | docstring 标注限制，测试用例规避此场景 |
| 守门测试规则与现有 layer_dependency_test.dart 冲突 | 低 | 低 | 扩展现有 editing_layer_test.dart，不修改 layer_dependency_test.dart |
| 文件超 400 行 | 低 | 低 | block_serializer 预计 ~300 行（含 InlineSerializer），block_type_detector 预计 ~80 行 |

Risk Level: **Medium**

理由：本任务实现新逻辑（双向映射 + detector），但不修改业务代码、不接入 UI、不引入新依赖、不改 AST / parser。Round-trip 非 bit-perfect 是已知风险，docstring 标注限制即可。回滚成本可控（独立文件 + 0 业务接入）。

### Future ADR 候选（Phase 2.3 不实施，但需记录以避免 Phase 2.5~2.6 返工）

Phase 2.1 评审反馈识别出三个未来架构压力点。本 Task Contract 不实施，但记录在此供后续 Phase 启动时优先评估：

| ADR 候选 | 触发 Phase | 待决问题 |
|---------|----------|---------|
| **ADR-0008: Canonical Markdown Serialization** | Phase 2.4 | Round-trip bit-perfect 需求触发。当前 Phase 2.3 接受非 bit-perfect，若未来导出 / 同步场景要求 canonical 形式（如 `*hello*` 与 `_hello_` 统一），需引入 normalize 规则。当前 Phase 2.3 用 AST equivalence 规避字符串等价问题 |
| **ADR-0009: Editor Transaction Model** | Phase 2.6 | Undo/Redo 双层架构。**注：ADR-0007 v1.1 §4.2 已落地"BlockOperation + TextOperation 共存"决策**，本 ADR 候选用于细化 TextOperation 的字符级 / 词级粒度、transaction 边界（beginBatch/endBatch）、与 VS Code TextEdit 模型的对齐度 |
| **ADR-0010: IME State Extension** | Phase 2.5 | ComposingRegion 生命周期扩展。当前 Phase 2.2 ComposingRegion 仅含 start/end，未来 Phase 2.5 可能需增加 `composingText` / `committedSnapshot` 字段以支持 cancel rollback；状态机可能需增加 `composing` 态（介于 focused 与 blurring 之间）。本 Phase 2.3 不动 ComposingRegion 数据类（Phase 2.2 产物已稳定） |

**澄清说明（Undo 双层）**：评审反馈 §6 建议"Undo 改为双层 BlockOperation + TextOperation 共存"。此建议在 ADR-0007 v1.1 修订（PR #25）中已落地为 §4.2 双层 Undo 决策：

> BlockOperation 管理结构变化（insert/delete/merge/split/move），TextOperation 管理块内文本变化。两层共用同一 HistoryManager，但记录类型不同。

Phase 2.3 不实施 Undo（Phase 2.6 范围），无需修订 Task Contract。

---

## 9. Approval（审批）

复杂任务（Risk Medium+ / 涉及架构变更）需 Human Owner 审批。

- [ ] 无需审批（风险低，AI 可自主执行）
- [x] 待审批（Human Owner 确认后开始 Phase 2.3 实现）

Human Owner:

- [ ] Approve Task Contract（授权按本契约执行 Phase 2.3 实现）
- [ ] Approve 代码实现（PR merge 后进入 Phase 2.4）
- [ ] Request Changes（指出需修订点）
- [ ] Reject（设计方向错误，需重新设计或修订 ADR-0007）

---

## 10. AI Self Review

| 检查项 | 状态 | 说明 |
|-------|------|------|
| ADR 合规 | ✅ | 实现严格遵循 ADR-0007 §1.3（wrapping）+ §4.3（detector 规则）+ §Phase 2.3 三项交付 |
| 范围漂移 | ✅ | Phase 2.3 仅实现 toElement/fromElement + detector + 性能测试，不集成到 onSourceChanged（Phase 2.7） |
| 技术债务 | ✅ | 未引入新依赖 / 新存储 / 新静态状态；纯 Dart 函数，可独立测试 |
| 测试覆盖 | ✅ | 9 类 BlockType round-trip AST equivalence + 8 类 InlineElement 序列化 + 7 条 detector 规则 + 2 个 perf 断言（典型 5ms + 最坏 16ms）+ 守门测试 |
| §6.4 禁区授权 | ✅ | Task Contract 走 PR 流程，ADR-0007 不动（Phase 2.1 已 Accepted） |
| §6.5 当前阶段禁区 | ✅ | Phase 2.3 不修改 UI 行为、不新增 Phase 3 功能、不引入派生缓存、不修改 AST |
| 与 ADR-0003 兼容 | ✅ | 不引入派生缓存，BlockSerializer 是无状态纯函数 |
| 与 ADR-0004 兼容 | ✅ | 不修改 parser，仅复用 `MarkdownParser.parseInline` |
| Task Contract 完整性 | ✅ | 10 节齐全，Risk Level = Medium |
| AI commit message | ✅ | 将包含 `Task scope: ROADMAP Phase 2.3` |

### 修订记录（v1.1，基于 Phase 2.1 评审反馈）

应用 Human Owner 评审反馈的三项修订：

1. **性能指标分层**（原：单块 < 16ms；修订：单块典型 < 5ms + 单块最坏 < 16ms）。理由：16ms 是 frame budget，含 build/layout/paint/input，单块 latency 应远低于此
2. **Round-trip 改为 AST equivalence**（原：`source == output`；修订：`parse(source) == parse(output)`，用 `_astDeepEquals` helper）。理由：Markdown 非 canonical（`*hello*` ≠ `_hello_` 字符串但 AST 等价）
3. **BlockTypeDetector 不返回 null**（原：`BlockType? detect()`；修订：`BlockType detect()` 永远返回值，默认 paragraph）。理由：减少调用方分支

### 未应用的反馈（明确不实施，避免范围漂移）

以下反馈属于 Phase 2.4+ 范围，本 Phase 2.3 不实施，已记录在 §Future ADR 候选：

- **EditorBuffer 替代 source**：Phase 2.4 评估（不阻塞 Phase 2.3，source 仍是 String）
- **状态机增加 composing 态**：Phase 2.5 评估（ADR-0010 候选）
- **ComposingRegion 增加 composingText / committedSnapshot**：Phase 2.5 评估（ADR-0010 候选）
- **Undo 双层架构细化**：已在 ADR-0007 v1.1 §4.2 落地，Phase 2.6 实施时无需返工

---

**Agent**：TRAE (GLM-5.2)
**日期**：2026-07-19
**版本**：v1.0
