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
///
/// 依赖注入：通过 [register] 注册自定义 exporter 实例，
/// 单元测试可注入 fake exporter 而无需 mock 全局状态。
class MarkdownExporter {
  MarkdownExporter._();

  /// 当前生效的 PDF exporter（默认 = [DefaultPdfExporter]）。
  static PdfExporterInterface _pdfExporter = const DefaultPdfExporter();

  /// 当前生效的 Word exporter（默认 = [DefaultWordExporter]）。
  static WordExporterInterface _wordExporter = const DefaultWordExporter();

  /// 当前生效的 Text exporter（默认 = [DefaultTextExporter]）。
  static TextExporterInterface _textExporter = const DefaultTextExporter();

  /// 注册自定义实现。返回 `dispose` 闭包用于还原。
  ///
  /// 用法:
  /// ```dart
  /// final dispose = MarkdownExporter.register(
  ///   pdf: FakePdfExporter(),
  ///   word: FakeWordExporter(),
  /// );
  /// addTearDown(dispose);
  /// ```
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
    return () {
      _pdfExporter = prevPdf;
      _wordExporter = prevWord;
      _textExporter = prevText;
    };
  }

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
    return _pdfExporter.export(
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
    return _wordExporter.export(markdown, title: title, isDark: isDark);
  }

  /// 把 Markdown 文本导出为 UTF-8 编码的纯文本字节流。
  static Future<Uint8List> exportToTxt(String markdown) {
    return _textExporter.export(markdown);
  }
}

// ============================================================================
// Exporter 接口：依赖注入点
// ============================================================================

/// PDF 导出接口。
abstract interface class PdfExporterInterface {
  Future<Uint8List> export(
    String markdown, {
    String? title,
    String? author,
    bool isDark,
  });
}

/// Word 导出接口。
abstract interface class WordExporterInterface {
  Future<Uint8List> export(
    String markdown, {
    String? title,
    bool isDark,
  });
}

/// 纯文本导出接口。
abstract interface class TextExporterInterface {
  Future<Uint8List> export(String markdown);
}

/// 默认 PDF 实现，代理到 [PdfExporter] 的 static 方法。
class DefaultPdfExporter implements PdfExporterInterface {
  const DefaultPdfExporter();

  @override
  Future<Uint8List> export(
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
}

/// 默认 Word 实现，代理到 [WordExporter] 的 static 方法。
class DefaultWordExporter implements WordExporterInterface {
  const DefaultWordExporter();

  @override
  Future<Uint8List> export(
    String markdown, {
    String? title,
    bool isDark = false,
  }) {
    return WordExporter.export(markdown, title: title, isDark: isDark);
  }
}

/// 默认纯文本实现，代理到 [TextExporter] 的 static 方法。
class DefaultTextExporter implements TextExporterInterface {
  const DefaultTextExporter();

  @override
  Future<Uint8List> export(String markdown) {
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
  /// 文档为空或无效。
  emptyDocument,

  /// 网络不可达（SocketException / NetworkException / HttpException 等）。
  offline,

  /// 文档中有无法识别的公式 / 格式（FormatException / ArgumentError 等）。
  parseError,

  /// 渲染失败：公式 / Mermaid 内部 SVG 解析、字体加载等。
  renderError,

  /// 写临时文件 / 读取 / 归档编码失败（FileSystemException / PlatformException 等）。
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
    // ExportException 根据消息内容分类
    final msg = e.message.toLowerCase();
    if (msg.contains('empty') || msg.contains('空白') || msg.isEmpty) {
      return (
        kind: ExportFailure.emptyDocument,
        userMessage: '无法导出空白文档',
        detail: null,
        cause: e,
      );
    }
    if (msg.contains('encode') || msg.contains('zip') || msg.contains('archive')) {
      return (
        kind: ExportFailure.writeError,
        userMessage: '文档打包失败，请重试',
        detail: e.message,
        cause: e,
      );
    }
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
    // DEBUG-DIAG: 把 stack trace 也带进 detail，定位 Unexpected extension byte 真因
    debugPrint('[FORMAT-EXC] ${e.message}');
    debugPrint('[FORMAT-EXC] source: ${e.source}');
    debugPrint('[FORMAT-EXC] offset: ${e.offset}');
    return (
      kind: ExportFailure.parseError,
      userMessage: '文档中有无法识别的公式',
      detail: '${e.message} | source: ${_truncate(e.source.toString(), 80)} | offset: ${e.offset}',
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
  if (s.isEmpty || maxLen <= 0) return '';
  return safeClip(s, maxLen);
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

/// 公开的工具函数：UTF-16 安全的字符串截断。
///
/// 使用 [String.runes] 迭代字符，避免 surrogate pair 被 [String.substring]
/// 切到中间产生乱码。`maxLen` 是 rune (Unicode code point) 数量，不是 UTF-16
/// 单元数。截断后追加 `…`。
String safeClip(String s, int maxLen) {
  if (s.isEmpty || maxLen <= 0) return '';
  final chars = s.runes.toList();
  if (chars.length <= maxLen) return s;
  return '${String.fromCharCodes(chars.take(maxLen))}…';
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
  ///
  /// 阶段：解析/收集公式 → 预渲染公式 → 拼装文档 → 写临时文件 → 调起系统分享。
  /// 每个阶段都打 debugPrint 日志，便于线上排查卡在哪个阶段。
  static Future<void> exportAndShare({
    required String markdown,
    required ExportFormat format,
    required Future<Uint8List> Function(String) exporter,
    String? title,
  }) async {
    final formatLabel = switch (format) {
      ExportFormat.pdf => 'PDF',
      ExportFormat.docx => 'Word',
      ExportFormat.txt => 'TXT',
    };
    final sw = Stopwatch()..start();
    debugPrint('[Export:${formatLabel}] start, markdown length=${markdown.length}');

    if (markdown.trim().isEmpty) {
      throw ExportFailureException(
        (
          kind: ExportFailure.emptyDocument,
          userMessage: '无法导出空白文档',
          detail: null,
          cause: null,
        ),
      );
    }

    // 阶段 1: 渲染
    final Uint8List bytes;
    try {
      bytes = await exporter(markdown).timeout(_exportTimeout);
      debugPrint('[Export:${formatLabel}] render done, bytes=${bytes.length}');
    } on TimeoutException {
      debugPrint(
        '[Export:${formatLabel}] TIMEOUT after ${sw.elapsedMilliseconds}ms in render stage. '
        '常见原因：(1) 公式/Mermaid 预渲染挂死 (FormulaRenderHost 未挂载或 WebView 卡死); '
        '(2) 文档过大, 拼装 PDF/Word 耗时超过 120s。',
      );
      throw ExportFailureException(classifyError(TimeoutException(
        '导出在渲染阶段超时（${_exportTimeout.inSeconds}s）',
      )));
    } catch (e) {
      debugPrint('[Export:${formatLabel}] render failed: $e');
      throw ExportFailureException(classifyError(e));
    }

    // 阶段 2: 写临时文件 + 调起分享
    final tempDir = await getTemporaryDirectory();
    final extension = format.name;
    final rawTitle = (title == null || title.trim().isEmpty) ? 'formulafix' : title;
    final sanitizedTitle = rawTitle
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final safeTitle = _truncate(sanitizedTitle, 30);
    final filename = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File('${tempDir.path}/$filename');

    try {
      await file.writeAsBytes(bytes);
      debugPrint('[Export:${formatLabel}] file written: ${file.path}');

      // 等待分享完成或超时
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'FormulaFix $extension',
        ).timeout(_shareTimeout);
        debugPrint('[Export:${formatLabel}] share completed in ${sw.elapsedMilliseconds}ms');
      } on TimeoutException {
        debugPrint(
          '[Export:${formatLabel}] share UI timeout after ${_shareTimeout.inSeconds}s, '
          'file still saved at: ${file.path}',
        );
      }
    } catch (e) {
      debugPrint('[Export:${formatLabel}] write/share failed: $e');
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
