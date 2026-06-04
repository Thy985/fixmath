/// Markdown → Word (.docx) 导出器。
///
/// 把 Markdown 文档打包为符合 ECMA-376 规范的 .docx 文件：
///   - document.xml（body 内容）由 [WordOoxmlBuilder] 拼装
///   - styles.xml / settings.xml / numbering.xml 取自 [WordOoxmlTemplates]
///   - 公式渲染为 PNG 图片（FormulaPdfRenderer cache）并通过 rIdImageN 引用
///   - Mermaid 图表渲染为 SVG 并通过 rIdMermaidN 引用
///
/// public API：仅 [WordExporter.export] 一个静态方法。
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../../../core/parser/markdown_parser.dart';
import '../../../core/services/formula_pdf_renderer.dart';
import '../../../core/services/mermaid_service.dart';
import '../../../data/models/document.dart';
import '../export_service.dart' show ExportException;
import 'formula_render_plan.dart' show sanitizeSvgString;
import 'pdf_exporter.dart';
import 'word_ooxml_builder.dart';
import '../word_ooxml_templates.dart';

class WordExporter {
  WordExporter._();

  /// 入口：把 Markdown 文本导出为 docx 字节流。
  static Future<Uint8List> export(
    String markdown, {
    String? title,
    bool isDark = false,
  }) async {
    if (markdown.isEmpty) {
      throw ExportException('Cannot export empty content');
    }

    final elements = MarkdownParser.parse(markdown);

    // 收集所有公式（paragraph / list / table cell 走 PdfExporter.collectAllFormulas）
    final allFormulasSet = PdfExporter.collectAllFormulas(elements);

    // 保持 Word 端原有的有序列表（保持生成文件名 / relId 顺序稳定）
    final allFormulas = <String>[];
    // 值类型为 FormulaImageInfo? —— 公式 PNG 渲染失败时设为 null，
    // 让 WordOoxmlBuilder 走 _formulaFallback 文本回退。
    final formulaRels = <String, FormulaImageInfo?>{};
    final allMermaids = <String>[];
    final mermaidRels = <String, MermaidImageInfo>{};

    for (final e in elements) {
      _collectFormulas(e, allFormulas, formulaRels);
      _collectMermaids(e, allMermaids, mermaidRels);
    }
    // 把 set 里多出来的公式（来自 table cell 字符串扫描）也补到有序列表中
    for (final latex in allFormulasSet) {
      if (!formulaRels.containsKey(latex)) {
        final idx = allFormulas.length + 1;
        allFormulas.add(latex);
        formulaRels[latex] = FormulaImageInfo(
          relId: 'rIdImage$idx',
          widthEmu: 0,
          heightEmu: 0,
        );
      }
    }

    if (allFormulas.isNotEmpty) {
      // Word 导出走独立的 cache key 维度，避免与 PDF 像素密度不同导致的互相覆盖
      await FormulaPdfRenderer.preRenderAll(
        allFormulas.toSet(),
        fontSize: 16,
        isDark: isDark,
        format: FormulaPdfRenderer.formatWord,
      );
    }

    // 渲染 Mermaid 为 SVG（并发执行）
    if (allMermaids.isNotEmpty) {
      await Future.wait(
        allMermaids.map((code) async {
          try {
            final svg = await MermaidService.renderToSvg(code);
            final info = mermaidRels[code];
            if (info != null) {
              mermaidRels[code] = MermaidImageInfo(
                relId: info.relId,
                svg: svg,
              );
            }
          } catch (e) {
            debugPrint('Mermaid SVG render failed for Word: $e');
          }
        }),
        eagerError: false,
      );
    }

    // 计算每个公式图片的实际尺寸并更新 formulaRels
    // FormulaPdfRenderer 使用 pixelRatio: 5.0 渲染，PNG 像素是逻辑尺寸的 5 倍
    // 因此需要除以 5 才能得到正确的 EMU 尺寸
    const double formulaPixelRatio = 5.0;
    const int emuPerInchAt96dpi = 914400;
    const double dpi = 96.0;
    // EMU = (pixels / pixelRatio) / dpi * emuPerInch
    // 简化: pixels * (emuPerInch / (pixelRatio * dpi))
    final double emuPerPixel = emuPerInchAt96dpi / (formulaPixelRatio * dpi);
    for (final latex in allFormulas) {
      final bytes = FormulaPdfRenderer.cachedBytes(
        latex,
        fontSize: 16,
        isDark: isDark,
        format: FormulaPdfRenderer.formatWord,
      );
      if (bytes != null) {
        final dims = parsePngDimensions(bytes);
        if (dims != null) {
          final info = formulaRels[latex];
          if (info != null) {
            formulaRels[latex] = FormulaImageInfo(
              relId: info.relId,
              widthEmu: (dims.width * emuPerPixel).round(),
              heightEmu: (dims.height * emuPerPixel).round(),
            );
          }
        }
      }
    }

    final docXml = WordOoxmlBuilder.buildDocumentXml(
      elements, title, formulaRels, mermaidRels);
    final imageRelsXml =
        WordOoxmlBuilder.buildImageRelsXml(formulaRels, mermaidRels);

    // [Content_Types].xml 现在包含 styles/settings/numbering 的 Override，
    // 见 WordOoxmlTemplates.contentTypesXml。
    final contentTypesXml = WordOoxmlTemplates.contentTypesXml;
    final rootRelsXml = WordOoxmlTemplates.rootRelsXml;

    final archive = Archive();

    // 关键：ArchiveFile 接受 String 内容时会调 utf8.encode 写入 zip。
    // document.xml 包含 _esc 转义后的内容，正常应该是合法 UTF-8。
    // 但如果公式或 Mermaid SVG 内有未配对 surrogate 漏到 XML 拼接环节，
    // utf8.encode 会抛 "Unexpected extension byte" 致整份 docx 失败。
    // 统一调用 _safeXml 清洗，保证所有 XML Part 都能通过 utf8.encode。
    _addXml(archive, '[Content_Types].xml', contentTypesXml);
    _addXml(archive, '_rels/.rels', rootRelsXml);
    _addXml(archive, 'word/document.xml', docXml);
    _addXml(
        archive, 'word/_rels/document.xml.rels', imageRelsXml);

    // 补全 OOXML 必需 Part：styles / settings / numbering。
    // 这些文件让导出的 docx 在 Word/WPS/LibreOffice 中能识别 pStyle 和 numId。
    final stylesXml = WordOoxmlTemplates.stylesXml;
    final settingsXml = WordOoxmlTemplates.settingsXml;
    final numberingXml = WordOoxmlTemplates.numberingXml;
    _addXml(archive, 'word/styles.xml', stylesXml);
    _addXml(archive, 'word/settings.xml', settingsXml);
    _addXml(archive, 'word/numbering.xml', numberingXml);

    int i = 0;
    int pngWritten = 0;
    final failedLatex = <String>[];
    for (final latex in allFormulas) {
      i++;
      final bytes = FormulaPdfRenderer.cachedBytes(
        latex,
        fontSize: 16,
        isDark: isDark,
        format: FormulaPdfRenderer.formatWord,
      );
      if (bytes != null) {
        final name = 'word/media/formula_$i.png';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
        pngWritten++;
      } else {
        // 公式渲染失败：把 formulaRels 中的 entry 移除（设为 null），
        // 让 WordOoxmlBuilder 的 _renderInlineCell / _paragraph / _list
        // 走 _formulaFallback 文本回退（显示原始 LaTeX），而不是在
        // 文档里留下一个断链的 rIdImageN。
        // （map 值类型是 FormulaImageInfo?，null 表示未渲染）
        formulaRels[latex] = null;
        failedLatex.add(latex);
      }
    }
    if (pngWritten == 0 && allFormulas.isNotEmpty) {
      debugPrint(
          'WordExporter: all ${allFormulas.length} formulas failed to render PNG, will use text fallback for all');
    } else if (failedLatex.isNotEmpty) {
      debugPrint(
          'WordExporter: ${failedLatex.length}/${allFormulas.length} formulas failed to render, using text fallback for those');
    }

    // 添加 Mermaid SVG 文件
    // 关键：Mermaid SVG 经 WebView 桥接回 Dart 时可能残留未配对 UTF-16
    // 代理对，archive 包的 ArchiveFile 构造函数对 String 内容会调
    // utf8.encode —— 遇到未配对 surrogate 直接抛 "Unexpected extension byte"
    // 致整份 docx 导出失败。必须先 sanitize 清洗。
    i = 0;
    for (final code in allMermaids) {
      i++;
      final info = mermaidRels[code];
      if (info != null && info.svg != null) {
        final name = 'word/media/mermaid_$i.svg';
        // utf8.encode 容错模式：先把孤立 surrogate 替换为 U+FFFD，
        // 让 archive 包的 utf8.encode 不再抛错。
        final svgBytes =
            utf8.encode(sanitizeSvgString(info.svg!));
        archive.addFile(ArchiveFile(name, svgBytes.length, svgBytes));
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw ExportException('Failed to encode Word document');
    }
    // 不在导出末尾清理缓存——重复导出同一文档应能命中缓存。
    // 缓存在 editor_screen 退出 / app pause 时由调用方清理。
    // 但每次导出后清理 WebView DOM payload 元素，减少内存压力。
    await MermaidService.cleanupPayloads();
    return Uint8List.fromList(encoded);
  }

  // --- 公式 / Mermaid 收集 ---

  static void _collectFormulas(
    DocumentElement element,
    List<String> allFormulas,
    Map<String, FormulaImageInfo?> formulaRels,
  ) {
    int register(String latex) {
      if (formulaRels.containsKey(latex)) return 0;
      final idx = allFormulas.length + 1;
      allFormulas.add(latex);
      formulaRels[latex] =
          FormulaImageInfo(relId: 'rIdImage$idx', widthEmu: 0, heightEmu: 0);
      return idx;
    }

    if (element is ParagraphElement) {
      for (final c in element.children) {
        if (c is FormulaElement) register(c.latex);
      }
    } else if (element is ListElement) {
      for (final c in element.children) {
        if (c is FormulaElement) register(c.latex);
      }
    }
  }

  static void _collectMermaids(
    DocumentElement element,
    List<String> allMermaids,
    Map<String, MermaidImageInfo> mermaidRels,
  ) {
    int register(String code) {
      if (mermaidRels.containsKey(code)) return 0;
      final idx = allMermaids.length + 1;
      allMermaids.add(code);
      mermaidRels[code] = MermaidImageInfo(relId: 'rIdMermaid$idx', svg: null);
      return idx;
    }

    if (element is MermaidElement) {
      register(element.code);
    }
  }

  // --- 字符串清洗 / 写入辅助 ---

  /// 清洗任意来源的字符串为可安全 utf8.encode 的 Dart String。
  ///
  /// 复用 [sanitizeSvgString] 的容错策略：先 round-trip 一遍 UTF-8，
  /// 不可编码的字符用 U+FFFD 替换；utf8.encode 本身失败时再降级到
  /// 显式扫 runes 替换未配对 surrogate。覆盖两类历史崩溃：
  ///   - Mermaid SVG 桥接回 Dart 时残留的孤立 surrogate
  ///   - 文档标题/正文中包含的 emoji / 数学符号（U+1D400-U+1D7FF 等）
  static String _safeXml(String s) => sanitizeSvgString(s);

  /// 把字符串形式的 XML Part 写入 archive，自动 sanitize。
  /// 不再用 ArchiveFile(String) 构造（其内部 utf8.encode 在遇到
  /// 未配对 surrogate 时会抛 "Unexpected extension byte"）。
  static void _addXml(Archive archive, String name, String content) {
    final bytes = utf8.encode(_safeXml(content));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
}
