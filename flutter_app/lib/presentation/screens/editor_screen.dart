import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/editor_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/template.dart';
import '../../domain/services/export_service.dart';
import '../widgets/preview_content.dart';
import 'file_manager_screen.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _checkClipboard();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    ref.read(editorContentProvider.notifier).state = _controller.text;
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        if (!mounted) return;
        final shouldImport = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('检测到剪贴板内容'),
            content: Text(
              '是否导入剪贴板内容？\n\n'
              '${data.text!.substring(0, data.text!.length > 100 ? 100 : data.text!.length)}'
              '${data.text!.length > 100 ? '...' : ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('导入'),
              ),
            ],
          ),
        );
        if (shouldImport == true) {
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
        _controller.text = await file.readAsString();
        _showSnackBar('文件导入成功');
      }
    } catch (e) {
      _showSnackBar('文件导入失败: $e');
    }
  }

  Future<void> _saveToFile() async {
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) {
      _showSnackBar('请先输入内容');
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/formulafix_${DateTime.now().millisecondsSinceEpoch}.md');
      await file.writeAsString(content);
      _showSnackBar('已保存');
    } catch (e) {
      _showSnackBar('保存失败: $e');
    }
  }

  Future<void> _openFileManager() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const FileManagerScreen()),
    );
    if (path != null && mounted) {
      try {
        _controller.text = await File(path).readAsString();
      } catch (_) {}
    }
  }

  Future<void> _exportToPdf() async {
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) return;
    ref.read(isExportingProvider.notifier).state = true;
    try {
      final bytes = await ExportService.exportToPdf(content);
      final file = File('${(await getTemporaryDirectory()).path}/'
          'formulafix_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'FormulaFix PDF');
    } catch (e) {
      _showSnackBar('PDF导出失败: $e');
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  Future<void> _exportToWord() async {
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) return;
    ref.read(isExportingProvider.notifier).state = true;
    try {
      final bytes = await ExportService.exportToWord(content);
      final file = File('${(await getTemporaryDirectory()).path}/'
          'formulafix_${DateTime.now().millisecondsSinceEpoch}.docx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'FormulaFix Word');
    } catch (e) {
      _showSnackBar('Word导出失败: $e');
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('导出文档', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
              title: const Text('导出为 PDF'),
              subtitle: const Text('标准 PDF 文档'),
              onTap: () { Navigator.pop(ctx); _exportToPdf(); },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: AppColors.wordAccent),
              title: const Text('导出为 Word'),
              subtitle: const Text('.docx 文档'),
              onTap: () { Navigator.pop(ctx); _exportToWord(); },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showTemplateMenu() {
    final byCategory = <String, List<DocumentTemplate>>{};
    for (final t in TemplateData.templates) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('选择模板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...byCategory.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(entry.key,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                ),
              ),
              ...entry.value.map((t) => ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(t.name),
                subtitle: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () { Navigator.pop(ctx); _controller.text = t.content; },
              )),
            ]),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPreview = ref.watch(previewModeProvider);
    final isDark = ref.watch(darkModeProvider);
    final isExporting = ref.watch(isExportingProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final appBarBg = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FormulaFix'),
        backgroundColor: appBarBg,
        foregroundColor: isDark ? Colors.white : Colors.black,
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
            tooltip: '导入',
            onPressed: _importFile,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _saveToFile,
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: '主题',
            onPressed: () => ref.read(darkModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: Container(
        color: bg,
        child: Column(
          children: [
            Expanded(
              child: isPreview
                  ? PreviewContent(content: ref.watch(editorContentProvider), isDark: isDark)
                  : _buildEditor(isDark),
            ),
            _buildBottomBar(isPreview, isExporting),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.pageMargin),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.card(isDark: isDark),
      ),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: AppSpacing.body,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
        decoration: InputDecoration(
          hintText: '开始输入 Markdown...\n\n'
              '• # 标题\n'
              '• \$E=mc^2\$ 行内公式\n'
              '• \$\$...\$\$ 块级公式\n'
              '• - 列表\n'
              '• ``` 代码块',
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppSpacing.cardPadding),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isPreview, bool isExporting) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -2),
        )],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => ref.read(previewModeProvider.notifier).state = !isPreview,
                icon: Icon(isPreview ? Icons.edit : Icons.visibility),
                label: Text(isPreview ? '编辑' : '预览'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isExporting ? null : _showExportMenu,
                icon: isExporting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_download),
                label: Text(isExporting ? '导出中...' : '导出'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
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