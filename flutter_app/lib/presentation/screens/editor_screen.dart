import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/parser/formula_extractor.dart';
import '../../core/parser/markdown_parser.dart';
import '../../domain/services/export_service.dart';
import '../widgets/preview_content.dart';

final editorProvider = StateProvider<String>((ref) => '');

final previewModeProvider = StateProvider<bool>((ref) => false);

final isDarkModeProvider = StateProvider<bool>((ref) => false);

final isExportingProvider = StateProvider<bool>((ref) => false);

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      ref.read(editorProvider.notifier).state = _controller.text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _exportToPdf() async {
    final content = ref.read(editorProvider);
    if (content.isEmpty) {
      _showSnackBar('请先输入内容');
      return;
    }

    ref.read(isExportingProvider.notifier).state = true;
    try {
      final pdfBytes = await ExportService.exportToPdf(content);
      await ExportService.sharePdf(pdfBytes, 'formula_fix_${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e) {
      _showSnackBar('PDF导出失败: $e');
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  void _exportToWord() async {
    final content = ref.read(editorProvider);
    if (content.isEmpty) {
      _showSnackBar('请先输入内容');
      return;
    }

    ref.read(isExportingProvider.notifier).state = true;
    try {
      final wordBytes = await ExportService.exportToWord(content);
      await ExportService.sharePdf(wordBytes, 'formula_fix_${DateTime.now().millisecondsSinceEpoch}.docx');
    } catch (e) {
      _showSnackBar('Word导出失败: $e');
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '导出文档',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('导出为 PDF'),
              subtitle: const Text('生成标准 PDF 文档'),
              onTap: () {
                Navigator.pop(context);
                _exportToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('导出为 Word'),
              subtitle: const Text('生成 .docx 文档'),
              onTap: () {
                Navigator.pop(context);
                _exportToWord();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(editorProvider);
    final isPreviewMode = ref.watch(previewModeProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final isExporting = ref.watch(isExportingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FormulaFix'),
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              ref.read(isDarkModeProvider.notifier).state = !isDarkMode;
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        color: isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF2F3F5),
        child: Column(
          children: [
            Expanded(
              child: isPreviewMode
                  ? PreviewContent(content: content, isDarkMode: isDarkMode)
                  : _buildEditor(content, isDarkMode),
            ),
            _buildBottomBar(isPreviewMode, isExporting),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(String content, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: '开始输入 Markdown...\n\n支持语法：\n• # 标题\n• \$E=mc^2\$ 行内公式\n• \$\$...\$\$ 块级公式\n• - 列表\n• ``` 代码块',
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isPreviewMode, bool isExporting) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(previewModeProvider.notifier).state = !isPreviewMode;
                },
                icon: Icon(isPreviewMode ? Icons.edit : Icons.visibility),
                label: Text(isPreviewMode ? '编辑' : '预览'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF165DFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isExporting ? null : _showExportMenu,
                icon: isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download),
                label: Text(isExporting ? '导出中...' : '导出'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B42A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
