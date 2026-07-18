import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/file_service.dart';
import '../../domain/services/export_service.dart';
import '../../core/services/formula_pdf_renderer.dart';
import '../../core/services/formula_svg_service.dart';
import '../../core/services/mermaid_service.dart';
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
    _clearExportCaches();
    super.dispose();
  }

  /// 退出编辑器时清理所有公式 / Mermaid 缓存。
  /// 防止应用长期挂起时 WebView isolate 持有大量内存。
  /// 同次会话内的多次导出会复用缓存。
  void _clearExportCaches() {
    FormulaPdfRenderer.clearCache();
    FormulaSvgService.clearCache();
    MermaidService.clearCache();
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
      debugPrint('文件导入失败: $e');
      _showSnackBar('文件导入失败，请确认文件存在且为文本或 Markdown 格式');
    }
  }

  Future<void> _saveToFile() async {
    try {
      await FileService.saveToFile(_controller.text);
      _showSnackBar('已保存');
    } catch (e) {
      debugPrint('文件保存失败: $e');
      _showSnackBar('保存失败，请检查存储空间与文件权限');
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
      debugPrint('文件加载失败: $e');
      _showSnackBar('文件加载失败，请确认文件未被其他程序占用');
    }
  }

  /// 从 Markdown 内容中提取第一个标题行作为导出文件名
  String? _extractTitle(String markdown) {
    final lines = markdown.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      }
    }
    return null;
  }

  Future<void> _exportToPdf() async {
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) return;
    final isDark = ref.read(darkModeProvider);
    final title = _extractTitle(content);

    ref.read(isExportingProvider.notifier).state = true;
    try {
      await ExportService.exportAndShare(
        markdown: content,
        format: ExportFormat.pdf,
        exporter: (markdown) => MarkdownExporter.exportToPdf(markdown, isDark: isDark),
        title: title,
      );
    } on ExportFailureException catch (e) {
      _showSnackBar(_userMessageFor('PDF', e.info));
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  Future<void> _exportToWord() async {
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) return;
    final isDark = ref.read(darkModeProvider);
    final title = _extractTitle(content);

    ref.read(isExportingProvider.notifier).state = true;
    try {
      await ExportService.exportAndShare(
        markdown: content,
        format: ExportFormat.docx,
        exporter: (markdown) => MarkdownExporter.exportToWord(markdown, isDark: isDark),
        title: title,
      );
    } on ExportFailureException catch (e) {
      _showSnackBar(_userMessageFor('Word', e.info));
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  Future<void> _exportToTxt() async {
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) return;
    final title = _extractTitle(content);

    ref.read(isExportingProvider.notifier).state = true;
    try {
      await ExportService.exportAndShare(
        markdown: content,
        format: ExportFormat.txt,
        exporter: MarkdownExporter.exportToTxt,
        title: title,
      );
    } on ExportFailureException catch (e) {
      _showSnackBar(_userMessageFor('文本', e.info));
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  /// 把 [ExportFailureInfo] 翻译成给用户看的本地化消息。
  ///
  /// 绝不暴露底层异常类名或堆栈——只用 [userMessage] 和 [detail]，
  /// 而 [detail] 也经过脱敏（短字符串 + 局部截断）。
  ///
  /// 失败时不仅告诉用户"超时/失败",还要引导用户自助排查(检查文档大小、
  /// 检查是否含未支持语法等)。Snippet 类型的 detail 在合法范围内透传。
  String _userMessageFor(String formatLabel, ExportFailureInfo info) {
    final kind = info.kind;
    final detail = info.detail;
    switch (kind) {
      case ExportFailure.emptyDocument:
        return '无法导出空白文档';
      case ExportFailure.offline:
        return '请检查网络连接';
      case ExportFailure.parseError:
        if (detail != null && detail.isNotEmpty) {
          return '文档中有无法识别的内容: ${_clip(detail, 60)}';
        }
        return '文档中有无法识别的内容';
      case ExportFailure.renderError:
        if (detail != null && detail.isNotEmpty) {
          return '$formatLabel 渲染失败: ${_clip(detail, 60)}';
        }
        return '$formatLabel 渲染失败，可能含有不支持的语法';
      case ExportFailure.writeError:
        if (detail != null && detail.isNotEmpty) {
          return '保存失败: ${_clip(detail, 60)}';
        }
        return '保存失败';
      case ExportFailure.timeout:
        return '$formatLabel 导出超时（超过 120s）。'
            '可能原因：文档过大、公式/图表太多、或 WebView 渲染卡死。'
            '请尝试：减少公式/图表数量后重试，或简化文档内容。';
      case ExportFailure.unknown:
        if (detail != null && detail.isNotEmpty) {
          return '$formatLabel 导出失败: ${_clip(detail, 80)}';
        }
        return '$formatLabel 导出失败';
    }
  }

  /// 截断 detail 以避免 SnackBar 文案过长。
  String _clip(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ExportMenu(
        onExportPdf: _exportToPdf,
        onExportWord: _exportToWord,
        onExportTxt: _exportToTxt,
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
      title: const Text(
        'FormulaFix',
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: appBarBg,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: 0,
      titleSpacing: 8,
      actions: [
        IconButton(
          icon: const Icon(Icons.folder_open_outlined),
          tooltip: '文件管理',
          visualDensity: VisualDensity.compact,
          onPressed: _openFileManager,
        ),
        IconButton(
          icon: const Icon(Icons.auto_awesome_outlined),
          tooltip: '模板',
          visualDensity: VisualDensity.compact,
          onPressed: _showTemplateMenu,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多',
          onSelected: (value) {
            switch (value) {
              case 'import':
                _importFile();
                break;
              case 'save':
                _saveToFile();
                break;
              case 'theme':
                ref.read(darkModeProvider.notifier).toggle();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.file_open_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('导入'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'save',
              child: Row(
                children: [
                  Icon(Icons.save_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('保存'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'theme',
              child: Row(
                children: [
                  Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(isDark ? '浅色模式' : '深色模式'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
