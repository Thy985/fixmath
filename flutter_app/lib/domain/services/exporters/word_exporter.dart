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

import 'dart:convert' show utf8;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../../../core/parser/markdown_parser.dart';
import '../../../core/services/formula_pdf_renderer.dart';
import '../../../core/services/mermaid_service.dart';
import '../../../data/models/document.dart';
import '../export_service.dart' show ExportException;
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
    final formulaRels = <String, FormulaImageInfo>{};
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

    // 渲染 Mermaid 为 SVG
    if (allMermaids.isNotEmpty) {
      for (int i = 0; i < allMermaids.length; i++) {
        final code = allMermaids[i];
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
      }
    }

    // 计算每个公式图片的实际尺寸并更新 formulaRels
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
              widthEmu: dims.width * 9525,
              heightEmu: dims.height * 9525,
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

    // 注意：ArchiveFile 写入 String content 时实际产生的是 utf8 字节流，
    // 但 `size` 字段如果传 `String.length`（UTF-16 code units），非 ASCII 字符
    // （中文/特殊符号）越多，header 里 uncompSize 与实际字节数偏差越大
    // （差值 = 多字节字符数 × 2）。严格 zip 读取器（Python zipfile 等）会因此
    // 报 `Bad CRC-32` 拒绝打开。下面统一用 `utf8.encode(...)` 把 String 转
    // 成 Uint8List，让 size 与 content 走同一份字节数，避免该规范违例。
    final contentTypesBytes = utf8.encode(contentTypesXml);
    final rootRelsBytes = utf8.encode(rootRelsXml);
    final docBytes = utf8.encode(docXml);
    final imageRelsBytes = utf8.encode(imageRelsXml);

    archive.addFile(ArchiveFile(
        '[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));
    archive.addFile(
        ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));
    archive.addFile(ArchiveFile(
        'word/document.xml', docBytes.length, docBytes));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels',
        imageRelsBytes.length, imageRelsBytes));

    // 补全 OOXML 必需 Part：styles / settings / numbering。
    // 这些文件让导出的 docx 在 Word/WPS/LibreOffice 中能识别 pStyle 和 numId。
    final stylesXml = WordOoxmlTemplates.stylesXml;
    final settingsXml = WordOoxmlTemplates.settingsXml;
    final numberingXml = WordOoxmlTemplates.numberingXml;
    final stylesBytes = utf8.encode(stylesXml);
    final settingsBytes = utf8.encode(settingsXml);
    final numberingBytes = utf8.encode(numberingXml);
    archive.addFile(ArchiveFile(
        'word/styles.xml', stylesBytes.length, stylesBytes));
    archive.addFile(ArchiveFile(
        'word/settings.xml', settingsBytes.length, settingsBytes));
    archive.addFile(ArchiveFile(
        'word/numbering.xml', numberingBytes.length, numberingBytes));

    int i = 0;
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
      }
    }

    // 添加 Mermaid SVG 文件
    i = 0;
    for (final code in allMermaids) {
      i++;
      final info = mermaidRels[code];
      if (info != null && info.svg != null) {
        final name = 'word/media/mermaid_$i.svg';
        // 同样要 utf8.encode，避免 SVG 里的非 ASCII 字符引发 zip header
        // uncompSize 偏差。
        final svgBytes = utf8.encode(info.svg!);
        archive.addFile(ArchiveFile(name, svgBytes.length, svgBytes));
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw ExportException('Failed to encode Word document');
    }
    // 不在导出末尾清理缓存——重复导出同一文档应能命中缓存。
    // 缓存在 editor_screen 退出 / app pause 时由调用方清理。
    return Uint8List.fromList(encoded);
  }

  // --- 公式 / Mermaid 收集 ---

  static void _collectFormulas(
    DocumentElement element,
    List<String> allFormulas,
    Map<String, FormulaImageInfo> formulaRels,
  ) {
    int register(String latex) {
      if (formulaRels.containsKey(latex)) return 0;
      final idx = allFormulas.length + 1;
      allFormulas.add(latex);
      formulaRels[latex] = FormulaImageInfo(relId: 'rIdImage$idx', widthEmu: 0, heightEmu: 0);
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
}
