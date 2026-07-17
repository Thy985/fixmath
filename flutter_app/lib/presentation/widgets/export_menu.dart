import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class ExportMenu extends StatelessWidget {
  final VoidCallback onExportPdf;
  final VoidCallback onExportWord;
  final VoidCallback onExportTxt;

  const ExportMenu({
    super.key,
    required this.onExportPdf,
    required this.onExportWord,
    required this.onExportTxt,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '导出文档',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
            title: const Text('导出为 PDF'),
            subtitle: const Text('标准 PDF 文档，适合打印和分享'),
            onTap: () {
              Navigator.pop(context);
              onExportPdf();
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: AppColors.wordAccent),
            title: const Text('导出为 Word'),
            subtitle: const Text('.docx 文档，方便编辑'),
            onTap: () {
              Navigator.pop(context);
              onExportWord();
            },
          ),
          ListTile(
            leading: Icon(Icons.text_snippet, color: Colors.grey[600]),
            title: const Text('导出为文本'),
            subtitle: const Text('.txt 纯文本文件'),
            onTap: () {
              Navigator.pop(context);
              onExportTxt();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
