import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/parser/markdown_parser.dart';
import '../../data/models/template.dart';
import '../../domain/services/export_service.dart';
import '../widgets/preview_content.dart';
import 'file_manager_screen.dart';

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
    _checkClipboard();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final shouldImport = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('检测到剪贴板内容'),
            content: Text(
              '是否导入剪贴板内容？\n\n${data.text!.substring(0, data.text!.length > 100 ? 100 : data.text!.length)}${data.text!.length > 100 ? '...' : ''}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导入')),
            ],
          ),
        );
        if (shouldImport == true && mounted) {
          _controller.text = data.text!;
        }
      }
    } catch (_) {}
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'tex'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        _controller.text = content;
        _showSnackBar('文件导入成功');
      }
    } catch (e) {
      _showSnackBar('文件导入失败: $e');
    }
  }

  Future<void> _saveToFile() async {
    final content = ref.read(editorProvider);
    if (content.isEmpty) {
      _showSnackBar('请先输入内容');
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/formulafix_$timestamp.md');
      await file.writeAsString(content);
      _showSnackBar('已保存');
    } catch (e) {
      _showSnackBar('保存失败: $e');
    }
  }

  Future<void> _openFileManager() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FileManagerScreen(onOpenFile: null),
      ),
    );
    if (path != null) {
      try {
        final file = File(path);
        final content = await file.readAsString();
        _controller.text = content;
      } catch (_) {}
    }
  }

  Future<void> _exportToPdf() async {
    final content = ref.read(editorProvider);
    if (content.isEmpty) {
      _showSnackBar('请先输入内容');
      return;
    }

    ref.read(isExportingProvider.notifier).state = true;
    try {
      final pdfBytes = await ExportService.exportToPdf(content);
      final dir = await getTemporaryDirectory();
      final filename = 'formulafix_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'FormulaFix PDF 导出');
    } catch (e) {
      _showSnackBar('PDF导出失败: $e');
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  Future<void> _exportToWord() async {
    final content = ref.read(editorProvider);
    if (content.isEmpty) {
      _showSnackBar('请先输入内容');
      return;
    }

    ref.read(isExportingProvider.notifier).state = true;
    try {
      final wordBytes = await ExportService.exportToWord(content);
      final dir = await getTemporaryDirectory();
      final filename = 'formulafix_${DateTime.now().millisecondsSinceEpoch}.docx';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(wordBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'FormulaFix Word 导出');
    } catch (e) {
      _showSnackBar('Word导出失败: $e');
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
              child: Text('导出文档', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('导出为 PDF'),
              subtitle: const Text('生成标准 PDF 文档，公式以文本形式呈现'),
              onTap: () {
                Navigator.pop(context);
                _exportToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('导出为 Word'),
              subtitle: const Text('生成 .docx 文档，公式以 Cambria Math 字体呈现'),
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

  void _showTemplateMenu() {
    final templatesByCategory = <String, List<DocumentTemplate>>{};
    for (final t in TemplateData.templates) {
      templatesByCategory.putIfAbsent(t.category, () => []).add(t);
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择模板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...templatesByCategory.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(entry.key, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              ),
              ...entry.value.map((template) => ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(template.name),
                subtitle: Text(template.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(context);
                  _controller.text = template.content;
                },
              )),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPreviewMode = ref.watch(previewModeProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final isExporting = ref.watch(isExportingProvider);

    final bgColor = isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF2F3F5);
    final appBarBg = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final appBarFg = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FormulaFix'),
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '文件管理',
            onPressed: _openFileManager,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: '模板',
            onPressed: _showTemplateMenu,
          ),
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: '导入文件',
            onPressed: _importFile,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存到本地',
            onPressed: _saveToFile,
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: '切换主题',
            onPressed: () {
              ref.read(isDarkModeProvider.notifier).state = !isDarkMode;
            },
          ),
        ],
      ),
      body: Container(
        color: bgColor,
        child: Column(
          children: [
            Expanded(
              child: isPreviewMode
                  ? PreviewContent(content: ref.watch(editorProvider), isDarkMode: isDarkMode)
                  : _buildEditor(isDarkMode),
            ),
            _buildBottomBar(isPreviewMode, isExporting),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(bool isDarkMode) {
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
          hintText: '开始输入 Markdown...\n\n支持：\n• # 标题\n• \$E=mc^2\$ 行内公式\n• \$\$...\$\$ 块级公式\n• - 列表\n• ``` 代码块',
          hintStyle: TextStyle(color: Colors.grey[400]),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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