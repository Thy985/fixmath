import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/template.dart';

class TemplateSelector extends StatelessWidget {
  final void Function(String content) onSelectTemplate;

  const TemplateSelector({
    super.key,
    required this.onSelectTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<DocumentTemplate>>{};
    for (final t in TemplateData.templates) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '选择模板',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: byCategory.entries.expand((entry) {
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ...entry.value.map((t) => ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(t.name),
                        subtitle: Text(
                          t.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onSelectTemplate(t.content);
                        },
                      )),
                ];
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
