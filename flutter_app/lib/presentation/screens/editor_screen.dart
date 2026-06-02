import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/export_service.dart';
import '../../core/services/file_service.dart';
import '../../domain/services/export_service.dart' as domain;
import '../../providers/editor_providers.dart';
import '../widgets/markdown_input_field.dart';
import '../widgets/editor_bottom_bar.dart';
import '../widgets/export_menu.dart';
import '../widgets/template_selector.dart';
import '../widgets/preview_content.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String? initialPath;

  const EditorScreen({super.key, this.initialPath});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _controller = TextEditingController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _controller.text = ref.read(editorContentProvider);
    if (widget.initialPath != null) {
      await _loadPath(widget.initialPath!);
    }
    await _checkClipboard();
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
      if (data?.text != null && data!.text!.isNotEmpty && mounted) {
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
    } catch (e) {
      debugPrint('Clipboard check failed: $e');
    }
  }

  Future<void> _importFile() async {
    try {
      final content = await FileService.importFile();
      _controller.text = content;
      _showSnackBar('文件导入成功');
    } catch (e) {
      _showSnackBar('文件导入失败: $e');
    }
  }

  Future<void> _saveToFile() async {
    try {
      await FileService.saveToFile(_controller.text);
      _showSnackBar('已保存');
    } catch (e) {
      _showSnackBar('保存失败: $e');
    }
  }

  Future<void> _openFileManager() async {
    final path = await context.push<String>('/files');
    if (path != null && mounted) {
      await _loadPath(path);
    }
  }

  Future<void> _loadPath(String path) async {
    try {
      final content = await FileService.loadFromPath(path);
      _controller.text = content;
    } catch (e) {
      _showSnackBar('加载失败: $e');
    }
  }

  Future<void> _exportToPdf() async {
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) return;
    
    ref.read(isExportingProvider.notifier).state = true;
    try {
      await ExportService.exportAndShare(
        markdown: content,
        format: ExportFormat.pdf,
        exporter: domain.ExportService.exportToPdf,
      );
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
      await ExportService.exportAndShare(
        markdown: content,
        format: ExportFormat.docx,
        exporter: domain.ExportService.exportToWord,
      );
    } catch (e) {
      _showSnackBar('Word导出失败: $e');
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ExportMenu(
        onExportPdf: _exportToPdf,
        onExportWord: _exportToWord,
      ),
    );
  }

  void _showTemplateMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => TemplateSelector(
          onSelectTemplate: (content) {
            _controller.text = content;
          },
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
      appBar: _buildAppBar(appBarBg, isDark),
      body: Container(
        color: bg,
        child: Column(
          children: [
            Expanded(
              child: isPreview
                  ? PreviewContent(
                      content: ref.watch(editorContentProvider),
                      isDark: isDark)
                  : MarkdownInputField(
                      controller: _controller,
                      isDarkMode: isDark,
                    ),
            ),
            EditorBottomBar(
              isPreview: isPreview,
              isExporting: isExporting,
              onTogglePreview: () =>
                  ref.read(previewModeProvider.notifier).state = !isPreview,
              onExport: _showExportMenu,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(Color appBarBg, bool isDark) {
    return AppBar(
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
    );
  }
}
