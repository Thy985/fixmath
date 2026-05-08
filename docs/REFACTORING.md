# FormulaFix 重构开发文档

## 1. 重构概述

### 1.1 重构背景

原项目为基于 React + Vite 的 Web 应用，存在以下问题：
- 移动端体验不佳，需要 PWA 才能安装
- 离线能力有限
- 依赖外部字体渲染，公式显示不稳定

### 1.2 重构目标

| 目标 | 说明 |
|------|------|
| 移动原生 | 真正的原生 Android 应用 |
| 100% 离线 | 无网络依赖，数据不出设备 |
| 高性能 | 流畅的公式渲染体验 |
| 可维护 | 清晰的架构设计 |

### 1.3 技术栈变更

| 维度 | 原项目 (React) | 新项目 (Flutter) |
|------|---------------|-----------------|
| 框架 | React 18 | Flutter 3.x |
| 语言 | JavaScript | Dart |
| 公式渲染 | KaTeX | flutter_math_fork |
| Markdown | marked | flutter_markdown |
| PDF | html2pdf.js | pdf + printing |
| Word | docx (Node.js) | docx (Dart) |
| 图表 | - | flutter_inappwebview |

---

## 2. 可复用资产

### 2.1 核心算法（高价值）

原项目 `converter.js` 中的以下算法可以直接移植到 Dart：

#### 2.1.1 公式提取器

```javascript
// converter.js 中的核心逻辑
const formulaDelimiters = [
  { regex: /\\\[(.*?)\\\]/gs, displayMode: true },  // \[...\]
  { regex: /\$\$(.*?)\$\$/gs, displayMode: true },  // $$...$$
  { regex: /\\\((.*?)\\\)/gs, displayMode: false }, // \(...\)
  { regex: /\$(.*?)\$/g, displayMode: false },       // $...$
];
```

**移植为 Dart:**

```dart
class FormulaExtractor {
  static final List<_FormulaDelimiter> _delimiters = [
    _FormulaDelimiter(r'\\\[\s*(.*?)\s*\\\]', true),   // \[...\]
    _FormulaDelimiter(r'\$\$\s*(.*?)\s*\$\$', true),   // $$...$$
    _FormulaDelimiter(r'\\\((.*?)\\\)', false),        // \(...\)
    _FormulaDelimiter(r'\$(.*?)\$', false),            // $...$
  ];

  /// 提取所有公式
  static List<FormulaMatch> extractFormulas(String text) {
    // 实现...
  }
}
```

#### 2.1.2 LaTeX 规范化

```javascript
// converter.js 中的 normalizeLatex 函数
function normalizeLatex(content) {
  // 处理希腊字母
  const GREEK_LETTERS = {
    'Δ': '\\Delta', 'δ': '\\delta', 'π': '\\pi', ...
  };
  // 处理导数符号
  processed = processed.replace(/dy\/dx/g, '\\frac{dy}{dx}');
  // 处理极限
  processed = processed.replace(/\\blim\\b/g, '\\lim');
  ...
}
```

**移植为 Dart:**

```dart
class LatexNormalizer {
  static const Map<String, String> _greekLetters = {
    'Δ': r'\Delta', 'δ': r'\delta', 'π': r'\pi',
  };

  static String normalize(String input) {
    String result = input;
    // 希腊字母转换
    _greekLetters.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    // 导数符号
    result = result.replaceAll(RegExp(r'dy/dx'), r'\frac{dy}{dx}');
    // 极限
    result = result.replaceAll(RegExp(r'\blim\b'), r'\lim');
    return result;
  }
}
```

### 2.2 测试用例（直接复用）

以下测试用例可以直接用于 Flutter 项目验证：

| 类别 | 测试用例 | 预期结果 |
|------|----------|----------|
| 行内公式 | `$E=mc^2$` | 正常渲染 |
| 块级公式 | `$$\int_0^1 x^2 dx$$` | 居中渲染 |
| 复杂公式 | `$$\begin{matrix} a & b \\ c & d \end{matrix}$$` | 矩阵渲染 |
| 极限 | `$\lim_{x \to \infty} f(x)$` | 极限渲染 |
| 求和 | `$\sum_{i=1}^{n} i$` | 求和渲染 |
| 积分 | `$\int_a^b f(x)dx$` | 积分渲染 |

### 2.3 产品设计（参考复用）

| 元素 | 原项目 | 复用建议 |
|------|--------|----------|
| 三栏布局 | 左侧设置/中间输入/右侧预览 | 简化为上下布局 |
| 深色模式 | CSS 变量切换 | Flutter Theme 切换 |
| 模板选择器 | TemplateSelector 组件 | 复用交互逻辑 |
| 实时预览 | 防抖渲染 | 复用防抖策略 |

---

## 3. 移植指南

### 3.1 依赖映射表

| 原 React 依赖 | Flutter 替代方案 | 迁移难度 |
|--------------|----------------|----------|
| react | flutter | ⭐⭐⭐⭐⭐ 直接替换 |
| marked | flutter_markdown | ⭐⭐⭐⭐ 语法类似 |
| katex | flutter_math_fork | ⭐⭐⭐ API 不同 |
| docx | docx | ⭐⭐⭐ 语法相似 |
| html2pdf.js | pdf + printing | ⭐⭐⭐ 完全不同 |
| mathquill | (不需要) | ⭐⭐⭐⭐⭐ 已移除 |
| marked | flutter_markdown | ⭐⭐⭐⭐ 成熟稳定 |

### 3.2 pubspec.yaml 依赖配置

```yaml
name: formula_fix
description: 纯本地 Markdown/LaTeX 编辑器与导出工具

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # 核心渲染
  flutter_markdown: ^0.6.18
  flutter_math_fork: ^0.6.4
  
  # 导出功能
  pdf: ^3.10.4
  printing: ^5.11.0
  docx: ^8.0.2
  
  # 图表渲染
  flutter_inappwebview: ^6.1.5
  
  # 平台功能
  path_provider: ^2.1.1
  file_picker: ^6.1.1
  share_plus: ^7.0.2
  clipboard: ^0.1.3
  
  # 状态管理
  flutter_riverpod: ^2.4.5
  
  # 工具库
  uuid: ^4.2.1
  intl: ^0.18.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

---

## 4. 开发阶段规划

### 4.1 MVP 阶段（第 1-2 周）

| 周次 | 任务 | 交付物 |
|------|------|--------|
| 第 1 周 | 项目初始化 + Markdown 渲染 | Flutter 项目骨架，能显示 Markdown |
| 第 1 周 | LaTeX 公式渲染集成 | 能渲染 `$...$` 和 `$$...$$` |
| 第 2 周 | 实时预览 + 输入优化 | 编辑器流畅体验 |
| 第 2 周 | 本地保存功能 | 能保存/加载 .md 文件 |

**里程碑：** 可用的 Markdown + LaTeX 编辑器

### 4.2 V1.0 阶段（第 3-4 周）

| 周次 | 任务 | 交付物 |
|------|------|--------|
| 第 3 周 | PDF 导出功能 | 能导出 PDF |
| 第 3 周 | Word 导出功能 | 能导出 Word（公式图片） |
| 第 4 周 | 分享功能 | 支持系统分享 |
| 第 4 周 | 剪贴板监听 | 启动时检测剪贴板 |

**里程碑：** 完整功能的文档导出工具

### 4.3 迭代阶段（第 5 周起）

| 功能 | 优先级 | 预计工作量 |
|------|--------|------------|
| Mermaid 图表 | P2 | 2-3 天 |
| 深色模式 | P2 | 1-2 天 |
| 模板系统 | P2 | 2-3 天 |
| 历史版本 | P3 | 3-5 天 |

---

## 5. 关键实现细节

### 5.1 公式渲染：离屏截图

```dart
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

/// 将公式 Widget 渲染为图片
Future<Uint8List> renderFormulaToImage(
  Widget formulaWidget, {
  double pixelRatio = 3.0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  final renderBox = RenderRepaintBoundary();
  renderBox.paint(canvas, Offset.zero);
  
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    renderBox.size.width.toInt() * pixelRatio,
    renderBox.size.height.toInt() * pixelRatio,
  );
  
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
```

### 5.2 Markdown + LaTeX 混合渲染

```dart
class MarkdownWithLatex extends StatelessWidget {
  final String content;
  
  @override
  Widget build(BuildContext context) {
    final elements = MarkdownParser.parse(content);
    
    return Wrap(
      children: elements.map((element) {
        if (element is FormulaElement) {
          return Math.tex(
            element.latex,
            onErrorFallback: (error) => Text(element.latex),
          );
        } else {
          return MarkdownBody(data: element.text);
        }
      }).toList(),
    );
  }
}
```

### 5.3 Word 导出：公式图片桥接

```dart
Future<Uint8List> exportWordWithFormulas(
  List<DocumentElement> elements,
) async {
  final doc = Document();
  
  for (final element in elements) {
    if (element is TextElement) {
      doc.add(Paragraph(text: element.content));
    } else if (element is FormulaElement) {
      // 1. 离屏渲染公式为图片
      final imageBytes = await renderFormulaToImage(
        Math.tex(element.latex, displayMode: true),
      );
      // 2. 插入图片到 Word
      doc.add(
        Paragraph(
          children: [
            Image.fromBytes(imageBytes, width: 200, height: 50),
          ],
        ),
      );
    }
  }
  
  return await DocxEncoder.encode(doc);
}
```

---

## 6. 测试策略

### 6.1 单元测试

| 测试对象 | 测试内容 |
|----------|----------|
| FormulaExtractor | 公式提取边界情况 |
| LatexNormalizer | 符号转换正确性 |
| MarkdownParser | 解析结果准确性 |

### 6.2 集成测试

| 测试场景 | 验证点 |
|----------|--------|
| 输入 `$E=mc^2$` | 公式正确渲染 |
| 导出 PDF | 文件生成成功 |
| 导出 Word | 公式显示为图片 |

### 6.3 复用原项目测试数据

```dart
// 测试用例 - 直接复用 converter.js 的测试数据
final testCases = [
  r'$E=mc^2$',
  r'$$\int_0^1 x^2 dx$$',
  r'$$\begin{matrix} a & b \\ c & d \end{matrix}$$',
  r'$\lim_{x \to \infty} f(x)$',
  r'$\sum_{i=1}^{n} i$',
];

for (final testCase in testCases) {
  test('公式渲染: $testCase', () {
    final widget = Math.tex(testCase);
    expect(widget, isNotNull);
  });
}
```

---

## 7. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| flutter_math_fork 渲染不一致 | 公式显示效果可能不同 | 用原项目 KaTeX 对比测试 |
| docx 库不支持复杂公式 | Word 导出效果差 | 采用图片桥接法 |
| Mermaid WebView 性能 | 渲染慢、内存占用大 | 缓存已渲染的图片 |
| 长文档卡顿 | 用户体验差 | 使用 ListView.builder 懒加载 |

---

## 8. 版本历史

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| v1.0.0 | 2026-05-06 | 初始重构文档 |
