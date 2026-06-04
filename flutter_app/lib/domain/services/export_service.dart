/// Markdown 导出 facade：PDF / Word / TXT 三个 Exporter 的统一入口。
///
/// public API（与重构前完全一致）：
///   - [MarkdownExporter.exportToPdf] / [exportToWord] / [exportToTxt]
///   - [MarkdownExporter.collectAllFormulas]
///   - [ExportService.exportAndShare]（写临时文件 + 调起分享）
///   - [ExportFormat] / [ExportException]（保持旧位置兼容）
///   - [ExportFailure] / [ExportFailureInfo] / [ExportFailureException]（新增）
///
/// 实现层：
///   - [exporters/PdfExporter] / [exporters/WordExporter] / [exporters/TextExporter]
///   - [exporters/WordOoxmlBuilder]
///   - [WordOoxmlTemplates]
///
/// 错误处理：[classifyError] 把任意异常映射到 [ExportFailure] 枚举；调用方
/// 通过 [ExportFailure.kind] 决定给用户看的本地化消息。导出过程抛出的错误
/// 都会被 [ExportService.exportAndShare] 包装为 [ExportFailureException]，
/// 不会泄漏 raw stack 给 UI。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/document.dart';
import 'exporters/pdf_exporter.dart';
import 'exporters/text_exporter.dart';
import 'exporters/word_exporter.dart';

// ============================================================================
// Public facade：MarkdownExporter
// ============================================================================

/// Markdown 文档导出 facade。
///
/// 所有方法都是 static，保持与重构前完全一致的 import 路径和调用方式。
/// 内部按格式委托给对应的 Exporter 类。
class MarkdownExporter {
  MarkdownExporter._();

  /// 递归收集文档中所有唯一的 LaTeX 公式字符串（去重）。
  /// 覆盖 ParagraphElement / ListElement / TableElement（headers + 每个 cell）。
  ///
  /// 注意：MermaidElement / CodeElement 中的内容不是 LaTeX 公式，跳过。
  static Set<String> collectAllFormulas(List<DocumentElement> elements) {
    return PdfExporter.collectAllFormulas(elements);
  }

  /// 把 Markdown 文本导出为 PDF 字节流。
  static Future<Uint8List> exportToPdf(
    String markdown, {
    String? title,
    String? author,
    bool isDark = false,
  }) {
    return PdfExporter.export(
      markdown,
      title: title,
      author: author,
      isDark: isDark,
    );
  }

  /// 把 Markdown 文本导出为 Word (.docx) 字节流。
  static Future<Uint8List> exportToWord(
    String markdown, {
    String? title,
    bool isDark = false,
  }) {
    return WordExporter.export(markdown, title: title, isDark: isDark);
  }

  /// 把 Markdown 文本导出为 UTF-8 编码的纯文本字节流。
  static Future<Uint8List> exportToTxt(String markdown) {
    return TextExporter.export(markdown);
  }
}

// ============================================================================
// 错误分类：ExportFailure / ExportFailureInfo / ExportFailureException
// ============================================================================

/// 导出失败分类。
///
/// UI 层根据 [kind] 决定给用户看的本地化消息；
/// 同一类错误在不同语境下文案可能不同（例如 parseError 既可能源自 Markdown
/// 解析也可能源自 LaTeX 渲染），具体文案在 UI 层拼接。
enum ExportFailure {
  /// 网络不可达（SocketException / NetworkException / HttpException 等）。
  offline,

  /// 文档中有无法识别的公式 / 格式（FormatException / ArgumentError 等）。
  parseError,

  /// 渲染失败：公式 / Mermaid 内部 SVG 解析、字体加载等。
  renderError,

  /// 写临时文件 / 读取 / 删除失败（FileSystemException / PlatformException 等）。
  writeError,

  /// 导出超时（TimeoutException）。
  timeout,

  /// 兜底：未识别的错误类型。
  unknown,
}

/// 分类后的导出错误详情。
///
///   - [kind] 决定 UI 提示类型
///   - [userMessage] 是已经过错误分类的、对用户友好的消息（不含 stack）
///   - [detail] 额外的上下文（如出错的 LaTeX 片段），用于补充 userMessage
///   - [cause] 原始异常，仅在开发模式下打日志，不直接呈现给用户
typedef ExportFailureInfo = ({
  ExportFailure kind,
  String userMessage,
  String? detail,
  Object? cause,
});

/// 抛出后会被 UI 层按 [info.kind] 决定如何呈现。
class ExportFailureException implements Exception {
  final ExportFailureInfo info;
  ExportFailureException(this.info);

  /// 与 [ExportException.message] 行为一致，便于旧 catch (e) 兼容。
  String get message => info.userMessage;

  @override
  String toString() => 'ExportFailureException(${info.kind}): ${info.userMessage}';
}

/// 把任意异常映射到 [ExportFailureInfo]。
///
/// 优先级（先匹配先返回）：
///   1. [ExportFailureException] → 透传
///   2. [TimeoutException] → timeout
///   3. Socket / IO 网络错误 → offline
///   4. FileSystem / Platform IO → writeError
///   5. Format / Argument / 解析相关 → parseError
///   6. 其它 → unknown（detail 用 e.toString() 截断）
ExportFailureInfo classifyError(Object e) {
  if (e is ExportFailureException) return e.info;

  if (e is TimeoutException) {
    return (
      kind: ExportFailure.timeout,
      userMessage: '导出超时，请重试',
      detail: null,
      cause: e,
    );
  }

  if (e is ExportException) {
    // ExportException 是应用层显式抛出的（空文档 / 编码失败等），按 renderError 处理。
    return (
      kind: ExportFailure.renderError,
      userMessage: '渲染失败，可能含有不支持的语法',
      detail: e.message,
      cause: e,
    );
  }

  if (e is SocketException ||
      e is HttpException ||
      e is HandshakeException) {
    return (
      kind: ExportFailure.offline,
      userMessage: '请检查网络连接',
      detail: e.toString(),
      cause: e,
    );
  }

  if (e is FileSystemException) {
    return (
      kind: ExportFailure.writeError,
      userMessage: '保存失败',
      detail: e.message,
      cause: e,
    );
  }

  if (e is FormatException) {
    return (
      kind: ExportFailure.parseError,
      userMessage: '文档中有无法识别的公式',
      detail: e.message,
      cause: e,
    );
  }

  if (e is ArgumentError || e is StateError) {
    return (
      kind: ExportFailure.parseError,
      userMessage: '文档中有无法识别的公式',
      detail: _truncate(e.toString(), 100),
      cause: e,
    );
  }

  return (
    kind: ExportFailure.unknown,
    userMessage: '导出失败',
    detail: _truncate(e.toString(), 120),
    cause: e,
  );
}

String _truncate(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen)}…';
}

// ============================================================================
// 历史遗留：ExportFormat / ExportException（保持原 API 兼容）
// ============================================================================

/// 导出格式枚举（保持与重构前一致）。
enum ExportFormat { pdf, docx, txt }

/// 旧式导出异常（保持与重构前一致）。
///
/// 内部代码（包括 [MarkdownExporter] / Exporter 实现）抛这个类型；上层
/// [ExportService.exportAndShare] 会通过 [classifyError] 重新分类为
/// [ExportFailureException]。
class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}

// ============================================================================
// 导出 + 分享高层包装：ExportService
// ============================================================================

/// 导出后写临时文件、调起系统分享。
///
/// 失败时：把任意异常通过 [classifyError] 映射为 [ExportFailureInfo]，再
/// 包装为 [ExportFailureException] 抛出。调用方应根据 [ExportFailureException]
/// 的 [ExportFailureInfo.kind] 决定 UI 文案，而不是直接展示堆栈。
class ExportService {
  ExportService._();

  static const _shareTimeout = Duration(seconds: 60);
  static const _exportTimeout = Duration(seconds: 120);

  /// 把 Markdown 导出为目标格式后写临时文件并调起分享。
  ///
  /// [exporter] 是具体的导出函数（通常是一个 MarkdownExporter 静态方法的闭包）。
  /// 任何阶段抛出的异常都会被分类并以 [ExportFailureException] 重新抛出。
  static Future<void> exportAndShare({
    required String markdown,
    required ExportFormat format,
    required Future<Uint8List> Function(String) exporter,
  }) async {
    if (markdown.isEmpty) {
      throw ExportFailureException(
        (
          kind: ExportFailure.renderError,
          userMessage: '无法导出空白文档',
          detail: null,
          cause: null,
        ),
      );
    }

    final Uint8List bytes;
    try {
      bytes = await exporter(markdown).timeout(_exportTimeout);
    } on TimeoutException catch (e) {
      throw ExportFailureException(classifyError(e));
    } catch (e) {
      throw ExportFailureException(classifyError(e));
    }

    final tempDir = await getTemporaryDirectory();
    final extension = format.name;
    final filename = 'formulafix_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File('${tempDir.path}/$filename');

    try {
      await file.writeAsBytes(bytes);

      // 等待分享完成或超时
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'FormulaFix $extension',
        ).timeout(_shareTimeout);
      } on TimeoutException {
        debugPrint('Share timeout, file saved at: ${file.path}');
      }
    } catch (e) {
      throw ExportFailureException(classifyError(e));
    } finally {
      // 分享完成后（或超时后）再删除临时文件
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }
}
