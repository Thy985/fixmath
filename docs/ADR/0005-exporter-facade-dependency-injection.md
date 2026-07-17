# ADR-0005: 导出器 facade + 依赖注入模式

- **状态**：Accepted
- **生效日期**：2026-07-18
- **决策者**：首席架构工程师

## 背景

代码分析显示 [domain/services/export_service.dart](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart) 已采用 facade + 依赖注入模式。证据：

### 现有结构

```dart
class MarkdownExporter {
  MarkdownExporter._();
  
  // 内部持有 exporter 实例（默认指向 Default 实现）
  static PdfExporterInterface _pdfExporter = const DefaultPdfExporter();
  static WordExporterInterface _wordExporter = const DefaultWordExporter();
  static TextExporterInterface _textExporter = const DefaultTextExporter();
  
  // 公开 API：static，调用方不需要 new
  static Future<Uint8List> exportToPdf(String markdown, {...}) {
    return _pdfExporter.export(markdown, ...);
  }
  
  // 依赖注入：测试时注入 fake
  static void Function() register({
    PdfExporterInterface? pdf,
    WordExporterInterface? word,
    TextExporterInterface? text,
  }) {
    final prevPdf = _pdfExporter;
    final prevWord = _wordExporter;
    final prevText = _textExporter;
    if (pdf != null) _pdfExporter = pdf;
    if (word != null) _wordExporter = word;
    if (text != null) _textExporter = text;
    return () {  // dispose 闭包还原
      _pdfExporter = prevPdf;
      _wordExporter = prevWord;
      _textExporter = prevText;
    };
  }
}

// 接口定义
abstract interface class PdfExporterInterface {
  Future<Uint8List> export(String markdown, {String? title, String? author, bool isDark});
}

// 默认实现：代理到具体 Exporter 的 static 方法
class DefaultPdfExporter implements PdfExporterInterface {
  const DefaultPdfExporter();
  @override
  Future<Uint8List> export(String markdown, {...}) {
    return PdfExporter.export(markdown, ...);
  }
}
```

### 已解决的问题

1. **测试可注入**：`MarkdownExporter.register(pdf: FakePdfExporter())` 替换默认实现
2. **API 稳定**：调用方 `MarkdownExporter.exportToPdf(md)` 不需要感知 DI
3. **错误统一**：所有异常经 `classifyError` 映射到 `ExportFailure`
4. **dispose 闭包**：测试 `tearDown` 时还原，避免污染下一个测试

### 仍然存在的问题

1. **静态状态污染测试**：`_pdfExporter` 是 static，跨测试用例共享
   - `register` 返回 dispose 闭包是缓解，但容易忘
   - 建议：测试 `tearDown` 强制调用 dispose
2. **`PdfExporter` / `WordExporter` 内部状态也是 static**：
   - [pdf_exporter.dart:27-30](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/exporters/pdf_exporter.dart#L27-30) `_cjkFont` / `_cjkFontLoadAttempted` 等跨用例共享
   - Phase 2 评估是否改为 instance + DI

## 决策

**保留现有 facade + 依赖注入模式，作为后续导出器扩展的标准。**

### 规则

1. **新增导出格式**必须按以下结构实现：
   - 在 `domain/services/exporters/` 新增 `xxx_exporter.dart`
   - 定义 `XxxExporterInterface`（abstract interface）
   - 实现 `DefaultXxxExporter` 代理到 `XxxExporter` static 方法
   - 在 `MarkdownExporter` 添加 `exportToXxx` + `register` 参数
   - 在 `ExportFormat` 枚举添加 `xxx`

2. **调用方**必须通过 `MarkdownExporter.exportToXxx(...)`，不直接 new 具体类

3. **错误处理**必须经 `classifyError` 映射到 `ExportFailure`，再抛 `ExportFailureException`

4. **测试**必须用 `MarkdownExporter.register({...})` 注入 fake，避免依赖 WebView / 字体 / 网络

### 实现模板（新增格式的标准模板）

```dart
// 1. domain/services/exporters/xxx_exporter.dart

class XxxExporter {
  XxxExporter._();
  
  static Future<Uint8List> export(String markdown, {...}) async {
    // 解析 + 渲染 + 拼装
  }
}

// 2. domain/services/export_service.dart 新增

abstract interface class XxxExporterInterface {
  Future<Uint8List> export(String markdown, {...});
}

class DefaultXxxExporter implements XxxExporterInterface {
  const DefaultXxxExporter();
  @override
  Future<Uint8List> export(String markdown, {...}) {
    return XxxExporter.export(markdown, ...);
  }
}

class MarkdownExporter {
  static XxxExporterInterface _xxxExporter = const DefaultXxxExporter();
  
  static Future<Uint8List> exportToXxx(String markdown, {...}) {
    return _xxxExporter.export(markdown, ...);
  }
  
  static void Function() register({
    XxxExporterInterface? xxx,
    ...  // 现有参数
  }) {
    final prevXxx = _xxxExporter;
    if (xxx != null) _xxxExporter = xxx;
    return () {
      _xxxExporter = prevXxx;
    };
  }
}

// 3. ExportFormat 枚举
enum ExportFormat { pdf, docx, txt, xxx }

// 4. UI 调用方（presentation/widgets/export_menu.dart）
onExportXxx: _exportToXxx,
```

## 动机

### 选择 facade + DI 的理由

1. **调用方简单**：`MarkdownExporter.exportToPdf(md)` 一行调用，不感知 DI
2. **测试可注入**：`register({pdf: FakePdfExporter()})` 替换实现
3. **API 稳定**：现有调用方 import 路径不变（保持 [export_service.dart:4-7](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart#L4-7) 注释"保持与重构前完全一致"）
4. **新增格式低摩擦**：按模板复制粘贴即可

### 否决其他方案的理由

#### 方案 A：直接用 Service Locator（如 `get_it`）

**否决理由**：
- 增加第三方依赖
- `get_it` 是全局单例，反 Riverpod DI 哲学
- 现有 `register` 闭包已足够

#### 方案 B：改用 Riverpod Provider 注入

```dart
final pdfExporterProvider = Provider<PdfExporterInterface>((ref) {
  return DefaultPdfExporter();
});
```

**否决理由**：
- 现有 `MarkdownExporter` 是 static，调用方不持有 `ref`
- 改造为 Provider 注入需要重构所有调用点
- 收益不明显（仅 UI 调用，无需跨树传递）

#### 方案 C：完全重写为 instance 类 + Riverpod Provider

**否决理由**：
- 重构成本高
- Phase 1/2 期间不希望触碰导出器

## 后果

### 正面

- 新增格式按模板实现，无架构决策开销
- 测试隔离（通过 `register` + dispose）
- 错误处理统一

### 负面

- 静态状态跨测试用例共享（需 `tearDown` 强制还原）
- 长期看 `MarkdownExporter` 会越来越胖（每加格式加 3-4 个字段）

### 风险与缓解

| 风险 | 缓解 |
|------|------|
| 测试忘调用 dispose 闭包 | 测试 base class 强制 `tearDown` 调用 `MarkdownExporter.register({})` 还原 |
| `MarkdownExporter` 文件膨胀 | 超过 600 行时拆分为 `MarkdownExporter` + `ExporterRegistry` |
| 内部 Exporter 静态状态污染 | Phase 2 评估改为 instance + DI |

## 实施计划

### Phase 0（已完成）

- 现有 facade + DI 已落地，本 ADR 只是确认模式

### Phase 1

- 修复 [editor_screen.dart:221-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L221-253) 把 `detail` 透传给用户的问题
- 测试补齐：每个 exporter 至少一个集成测试 + 错误分类测试

### Phase 2

- 评估是否把内部 Exporter 的静态状态改为 instance + DI
- 评估是否把 `MarkdownExporter` 拆为 `ExporterRegistry`

### Phase 3

- 新增 HTML 导出格式（按本 ADR 模板）

## 替代方案再次评估

如果未来发现静态 facade 难以维护：

- **Plan B**：改为 `class ExporterRegistry` 实例 + Riverpod Provider
- **Plan C**：用 `dart_mappable` 或 `freezed` 自动生成接口

## 参考

- [export_service.dart](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart)
- [AGENTS.md §1.3](file:///d:/Projects/Active/math/AGENTS.md) 显式依赖原则
- [CODING_RULES.md §6](file:///d:/Projects/Active/math/docs/CODING_RULES.md) 数据访问规范
