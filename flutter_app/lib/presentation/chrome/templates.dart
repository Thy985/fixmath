/// Templates：Markdown 模板内容常量（Phase 3.3 PR #2C）。
///
/// 落地 Phase 3.3 PR #2 Task Contract v2.1 §2.5 + §6.3.1：
/// - **Hard Rule（§2.5.1）**：禁止业务逻辑用字符串判断模板类型
///   （如 `if (template.contains('mermaid'))`）
/// - 模板内容作为 `static const` 集中管理,Command 构造时传入常量
/// - Phase 3.3 PR #2C 的 8 种模板定义在此
///
/// **演进方向**（Phase 3.4+，ADR-0011 §5）：
/// - 字符串方案演进为 `enum MarkdownTemplate` + domain 层 `TemplateRegistry`
/// - TemplateRegistry 生成结构化内容（如 MermaidTemplate 直接生成 MermaidBlock）
/// - 届时此类被 TemplateRegistry 替代,但 Command 接口（InsertTemplateCommand）
///   保持不变,仅替换 template 字段类型（String → MarkdownTemplate）
///
/// **当前方案为何可接受**：
/// - 业务逻辑不解析字符串（Hard Rule §2.5.1 守门）
/// - 模板内容作为常量,修改不影响调用方
/// - 模板数量有限（8 种）,字符串拼接简单可读
library;

/// Markdown 模板内容常量集合。
///
/// 使用 `abstract final class` 防止实例化与子类化（Dart 3.0+ 特性）。
/// 所有字段为 `static const String`,调用方式：`Templates.tableDefault`。
abstract final class Templates {
  // ============ newBlock 模式（插入新 Block）============

  /// 表格模板（2 列 2 行,含表头 + 分隔行 + 数据行）。
  ///
  /// 插入后由 tryTransform 自动转换为 TableBlock。
  static const String tableDefault = '| 列1 | 列2 |\n|---|---|\n| 内容 | 内容 |';

  /// Mermaid 流程图模板（graph TD,A-->B）。
  ///
  /// 插入后由 tryTransform 自动转换为 MermaidBlock。
  static const String mermaidDefault = '```mermaid\ngraph TD\nA-->B\n```';

  /// 任务列表模板（2 个未勾选任务）。
  ///
  /// 插入后由 tryTransform 自动转换为 TaskListItemElement。
  static const String taskListDefault = '- [ ] 任务1\n- [ ] 任务2';

  // ============ insert 模式（当前块光标位置插入）============

  /// 代码块模板（dart 语言,光标定位到代码区首行）。
  ///
  /// 插入后由 tryTransform 自动转换为 CodeBlock。
  /// 光标位置：`\`\`\`dart\n` 后（offset 9,即代码区第一行）。
  static const String codeBlockDefault = '```dart\n\n```';

  /// 引用块模板（`> ` 前缀）。
  ///
  /// 插入后由 tryTransform 自动转换为 BlockquoteElement。
  static const String quoteDefault = '> 引用内容';

  /// 分隔线模板（`---`）。
  ///
  /// 插入后由 tryTransform 自动转换为 HorizontalRuleElement。
  static const String horizontalRuleDefault = '---';

  /// 图片模板（`![alt](url)` 占位）。
  ///
  /// 保持为 ParagraphElement（图片语法为 inline,不触发 Block 转换）。
  static const String imageDefault = '![alt](url)';

  /// 链接模板（`[文本](url)` 占位）。
  ///
  /// 保持为 ParagraphElement（链接语法为 inline,不触发 Block 转换）。
  static const String linkDefault = '[文本](url)';
}
