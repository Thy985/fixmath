/// SeedDocuments：Phase 3.0 种子数据（3 个示例文档）。
///
/// 落地 Phase 3.0 Task Contract §3.4（数据源接入）。
///
/// **来源**（Phase 2.9 Task Contract §10.4 决议）：
/// 从 Phase 2.9 Prototype Demo 中提取，保证 Phase 3.0 与 Phase 2.9 验证场景一致。
///
/// **用途**：
/// - Phase 3.0 不接入真实 .md 文件（用 InMemoryDocumentEditor + 种子数据）
/// - Phase 3.1+ 接入真实 .md 文件时替换为基于 .md 的实现
library;

import '../../core/editing/block_types.dart';
import 'in_memory_document_editor.dart';

/// Phase 3.0 种子数据工厂（3 个示例文档）。
///
/// 提供 [createDemo1] / [createDemo2] / [createDemo3] 三个工厂方法，
/// 返回填好种子数据的 [InMemoryDocumentEditor] 实例。
class SeedDocuments {
  const SeedDocuments._();

  /// 演示文档 1：基础块组合（paragraph + heading + code）。
  ///
  /// 来源：Phase 2.9 Demo 1（单 Block 双态切换）+ Demo 4（复杂 Block 共存）。
  static InMemoryDocumentEditor createDemo1() {
    final editor = InMemoryDocumentEditor();
    editor.addBlock('# FormulaFix Demo', BlockType.heading);
    editor.addParagraph('Hello, Block Editor!');
    editor.addBlock('```dart\nvoid main() { debugPrint("hi"); }\n```', BlockType.code);
    return editor;
  }

  /// 演示文档 2：标题层级（h1/h2/h3 + paragraph）。
  ///
  /// 来源：Phase 2.9 Demo 4（复杂 Block 共存）。
  static InMemoryDocumentEditor createDemo2() {
    final editor = InMemoryDocumentEditor();
    editor.addBlock('# 标题一', BlockType.heading);
    editor.addBlock('## 标题二', BlockType.heading);
    editor.addBlock('### 标题三', BlockType.heading);
    editor.addParagraph('正文内容');
    return editor;
  }

  /// 演示文档 3：代码示例（paragraph + python code）。
  ///
  /// 来源：Phase 2.9 Demo 4（复杂 Block 共存）。
  static InMemoryDocumentEditor createDemo3() {
    final editor = InMemoryDocumentEditor();
    editor.addParagraph('代码示例：');
    editor.addBlock('```python\ndef greet():\n    return "hi"\n```',
        BlockType.code);
    return editor;
  }
}
