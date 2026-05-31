import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  final Function(String)? onOpenFile;

  const FileManagerScreen({super.key, this.onOpenFile});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  List<FileInfo> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dirFiles = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
      dirFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final fileInfos = <FileInfo>[];
      for (final file in dirFiles) {
        final stat = file.statSync();
        final content = await file.readAsString();
        final preview = content.length > 80 ? '${content.substring(0, 80)}...' : content;
        fileInfos.add(FileInfo(
          path: file.path,
          name: file.uri.pathSegments.last,
          modifiedAt: stat.modified,
          size: stat.size,
          preview: preview.replaceAll('\n', ' '),
        ));
      }

      if (mounted) setState(() => _files = fileInfos);
    } catch (_) {}
  }

  Future<void> _deleteFile(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定删除「${_files[index].name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await File(_files[index].path).delete();
        _loadFiles();
      } catch (_) {}
    }
  }

  void _openFile(int index) {
    Navigator.pop(context, _files[index].path);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: _files.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无保存的文档', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('在编辑器中保存文档后将显示在此处', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(file.modifiedAt);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.description, color: Color(0xFF165DFF)),
                    title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '$dateStr  ·  ${_formatSize(file.size)}  ·  ${file.preview}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteFile(index),
                    ),
                    onTap: () => _openFile(index),
                  ),
                );
              },
            ),
    );
  }
}

class FileInfo {
  final String path;
  final String name;
  final DateTime modifiedAt;
  final int size;
  final String preview;

  FileInfo({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.size,
    required this.preview,
  });
}