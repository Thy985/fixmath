/// 解析 / 生成 .md 文档的 YAML front matter（最小集：id / createdAt / updatedAt）。
///
/// 设计要点（见 ADR-0003 §边界约束 3）：
/// `title` **不**写入 front matter，而由正文首个 `# H1` 推导，
/// 避免 front matter 与正文标题漂移。
class FrontMatterParser {
  static const String _sep = '---';

  /// 解析开头的 `--- ... ---` 块。
  /// 返回 `(meta, body)`：meta 为简单 `key: value` 映射；body 为剩余正文。
  static ({Map<String, String>? meta, String body}) parse(String markdown) {
    final lines = markdown.split('\n');
    if (lines.isEmpty || lines[0].trim() != _sep) {
      return (meta: null, body: markdown);
    }
    final meta = <String, String>{};
    var i = 1;
    for (; i < lines.length; i++) {
      if (lines[i].trim() == _sep) {
        i++;
        break;
      }
      final idx = lines[i].indexOf(':');
      if (idx > 0) {
        final k = lines[i].substring(0, idx).trim();
        final v = lines[i].substring(idx + 1).trim();
        if (k.isNotEmpty) meta[k] = v;
      }
    }
    final body = i < lines.length ? lines.sublist(i).join('\n') : '';
    return (meta: meta, body: body);
  }

  /// 生成带 front matter 的 .md 文本。
  ///
  /// [title] 非空且正文本身没有前导 `# H1` 时，注入首个 `# H1`
  /// （避免与正文已有标题重复）。
  static String build({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String title,
    required String content,
  }) {
    final sb = StringBuffer();
    sb.writeln('---');
    sb.writeln('id: $id');
    sb.writeln('createdAt: ${createdAt.toIso8601String()}');
    sb.writeln('updatedAt: ${updatedAt.toIso8601String()}');
    sb.writeln('---');
    final trimmed = content.replaceFirst(RegExp(r'^\s+'), '');
    final hasLeadingH1 = trimmed.startsWith('# ');
    if (title.isNotEmpty && !hasLeadingH1) {
      sb.writeln('# $title');
      if (content.trim().isNotEmpty) sb.writeln();
    }
    sb.write(content);
    return sb.toString();
  }
}
