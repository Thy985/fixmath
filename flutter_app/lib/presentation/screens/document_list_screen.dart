import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../data/models/document.dart';
import '../components/loading.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key});

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final isDark = ref.watch(darkModeProvider);

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: docsAsync.when(
        loading: () => const LoadingIndicator(message: '加载中...'),
        error: (e, _) => ErrorDisplay(
          message: '加载失败: $e',
          onRetry: () => ref.refresh(documentsProvider),
        ),
        data: (docs) {
          final query = ref.watch(searchQueryProvider);
          final filtered = query.isEmpty
              ? docs
              : docs.where((d) =>
                  d.title.toLowerCase().contains(query.toLowerCase()) ||
                  d.content.toLowerCase().contains(query.toLowerCase())
                ).toList();

          if (filtered.isEmpty) {
            return _buildEmptyState(query.isNotEmpty);
          }

          return _buildDocList(filtered, isDark);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNew,
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _isSearching = false);
            _searchController.clear();
            ref.read(searchQueryProvider.notifier).state = '';
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索文档...',
            border: InputBorder.none,
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      );
    }

    return AppBar(
      title: const Text('FormulaFix'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _isSearching = true),
        ),
        IconButton(
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => ref.read(darkModeProvider.notifier).toggle(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isFiltered) {
    final isDark = ref.watch(darkModeProvider);
    final iconColor = isDark ? Colors.grey[600] : Colors.grey[400];
    final textColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered ? Icons.search_off : Icons.description_outlined,
            size: 64,
            color: iconColor,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? '未找到匹配的文档' : '还没有文档',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 8),
            Text(
              '点击 + 按钮创建第一个文档',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocList(List<Document> docs, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, i) => _DocCard(
        doc: docs[i],
        isDark: isDark,
        onTap: () => _openDoc(docs[i]),
        onDelete: () => _deleteDoc(docs[i]),
        onRename: () => _renameDoc(docs[i]),
      ),
    );
  }

  void _createNew() {
    ref.read(currentDocumentProvider.notifier).clear();
    ref.read(editorContentProvider.notifier).clear();
    context.push('/editor');
  }

  void _openDoc(Document doc) {
    ref.read(currentDocumentProvider.notifier).setDocument(doc);
    ref.read(editorContentProvider.notifier).setContent(doc.content);
    context.push('/editor');
  }

  Future<void> _renameDoc(Document doc) async {
    final ctrl = TextEditingController(text: doc.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名文档'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '输入新标题'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != doc.title) {
      try {
        await ref.read(documentServiceProvider).updateDocument(
          doc.copyWith(title: newTitle),
        );
        ref.invalidate(documentsProvider);
        _showSnackBar('文档已重命名');
      } catch (e) {
        _showSnackBar('重命名失败: $e');
      }
    }
  }

  Future<void> _deleteDoc(Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文档'),
        content: Text('确定要删除 "${doc.title}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(documentsProvider.notifier).deleteDocument(doc.id);
        _showSnackBar('文档已删除');
      } catch (e) {
        _showSnackBar('删除失败: $e');
      }
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

class _DocCard extends StatelessWidget {
  final Document doc;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _DocCard({
    required this.doc,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final preview = doc.content.isEmpty
        ? '空文档'
        : doc.content.length > 80
            ? '${doc.content.substring(0, 80)}...'
            : doc.content;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      switch (v) {
                        case 'rename': onRename(); break;
                        case 'delete': onDelete(); break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('重命名'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('删除', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _formatDate(doc.updatedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_countChars()} 字',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.month}/${d.day}/${d.year}';
  }

  int _countChars() {
    return doc.content.replaceAll(RegExp(r'\s'), '').length;
  }
}