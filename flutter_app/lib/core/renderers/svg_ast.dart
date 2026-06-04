/// SVG AST 模型
///
/// 简化的 SVG 元素树，用于替代 `pw.SvgImage`。`pdf` 包的 `SvgImage` 走
/// `utf8.decode(svgBytes)` + `XmlDocument.parse` 路径，在 SVG 含有未配对
/// UTF-16 代理对时抛 "Unexpected extension byte" 致整份 PDF 导出失败。
///
/// 自写 AST 让我们可以：
/// 1. 完整控制编码：清洗后 SVG 一定可 utf8.encode（防御 utf8 边界 bug）
/// 2. 跳过不支持的元素：显示 `[unsupported: ...]` 占位，绝不阻塞导出
/// 3. 直接用 `pw.CustomPaint` / `pw.Graphics` 画图，无需经过 `pdf` 包的
///    SVG 解析器和 TTF 字体解析器
///
/// 覆盖的 SVG 元素（MathJax SVG 输出基本子集）：
/// - `<svg>` 根节点
/// - `<g>` 容器（支持 `transform`）
/// - `<path>` 矢量路径
/// - `<text>` 文本（支持 `<tspan>`）
/// - `<rect>` 矩形
/// - `<line>` 直线
/// - `<circle>` 圆形
/// - `<ellipse>` 椭圆
/// - `<use>` 引用 `<defs>` 中的元素
library;

/// AST 节点基类。
abstract class SvgNode {
  const SvgNode();

  /// 节点的视觉边界（未变换前）。用于排版估算。
  double get intrinsicWidth;
  double get intrinsicHeight;
}

/// SVG 根节点。
class SvgRoot extends SvgNode {
  final double viewBoxX;
  final double viewBoxY;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double? width;
  final double? height;
  final List<SvgNode> children;

  const SvgRoot({
    required this.viewBoxX,
    required this.viewBoxY,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    this.width,
    this.height,
    required this.children,
  });

  @override
  double get intrinsicWidth => width ?? viewBoxWidth;

  @override
  double get intrinsicHeight => height ?? viewBoxHeight;
}

/// 容器节点，对应 SVG `<g>`。支持简单的 `transform` 平移。
class SvgGroup extends SvgNode {
  final List<SvgNode> children;

  /// 平移变换（x, y），最常用的 transform。
  final double translateX;
  final double translateY;

  const SvgGroup({
    required this.children,
    this.translateX = 0,
    this.translateY = 0,
  });

  @override
  double get intrinsicWidth => 0;

  @override
  double get intrinsicHeight => 0;
}

/// `<rect>` 矩形。
class SvgRect extends SvgNode {
  final double x;
  final double y;
  final double width;
  final double height;
  final String? fill; // "#rrggbb" / "none"
  final String? stroke;
  final double strokeWidth;

  const SvgRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
  });

  @override
  double get intrinsicWidth => width;
  @override
  double get intrinsicHeight => height;
}

/// `<line>` 直线。
class SvgLine extends SvgNode {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String? stroke;
  final double strokeWidth;

  const SvgLine({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.stroke,
    this.strokeWidth = 1,
  });

  @override
  double get intrinsicWidth => (x2 - x1).abs();
  @override
  double get intrinsicHeight => (y2 - y1).abs();
}

/// `<circle>` 圆形。
class SvgCircle extends SvgNode {
  final double cx;
  final double cy;
  final double r;
  final String? fill;
  final String? stroke;
  final double strokeWidth;

  const SvgCircle({
    required this.cx,
    required this.cy,
    required this.r,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
  });

  @override
  double get intrinsicWidth => 2 * r;
  @override
  double get intrinsicHeight => 2 * r;
}

/// `<ellipse>` 椭圆。
class SvgEllipse extends SvgNode {
  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final String? fill;
  final String? stroke;
  final double strokeWidth;

  const SvgEllipse({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
  });

  @override
  double get intrinsicWidth => 2 * rx;
  @override
  double get intrinsicHeight => 2 * ry;
}

/// `<path>` 矢量路径。
///
/// 只支持 MathJax SVG 输出的子集：M, L, H, V, Z, C, S, Q, T, A 命令。
/// 不支持 fill-rule 等高级属性。
class SvgPath extends SvgNode {
  final String d;
  final String? fill;
  final String? stroke;
  final double strokeWidth;
  final double fillOpacity;

  const SvgPath({
    required this.d,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
    this.fillOpacity = 1,
  });

  @override
  double get intrinsicWidth => 0;
  @override
  double get intrinsicHeight => 0;
}

/// `<text>` 文本节点。MathJax 输出的 SVG 大量使用 text + tspan。
class SvgText extends SvgNode {
  final double x;
  final double y;
  final String text;
  final double fontSize;
  final String? fontFamily;
  final String? fill;
  final String? fontWeight; // "normal" / "bold" / "italic"
  final String? fontStyle; // "normal" / "italic"
  final List<SvgTspan> children;

  const SvgText({
    required this.x,
    required this.y,
    required this.text,
    this.fontSize = 16,
    this.fontFamily,
    this.fill,
    this.fontWeight,
    this.fontStyle,
    this.children = const [],
  });

  @override
  double get intrinsicWidth => text.length * fontSize * 0.6;

  @override
  double get intrinsicHeight => fontSize;
}

/// `<tspan>` 文本片段（`<text>` 的子节点）。
class SvgTspan {
  final String text;
  final double? x;
  final double? y;
  final double? fontSize;
  final String? fontFamily;
  final String? fill;
  final String? fontWeight;
  final String? fontStyle;

  const SvgTspan({
    required this.text,
    this.x,
    this.y,
    this.fontSize,
    this.fontFamily,
    this.fill,
    this.fontWeight,
    this.fontStyle,
  });
}

/// `<use>` 引用元素，引用 `<defs>` 中的具名节点。
class SvgUse extends SvgNode {
  final String href;
  final double x;
  final double y;

  const SvgUse({
    required this.href,
    this.x = 0,
    this.y = 0,
  });

  @override
  double get intrinsicWidth => 0;
  @override
  double get intrinsicHeight => 0;
}

/// 解析失败的 SVG 节点占位（用户指定要显示为 [unsupported: ...]）。
class SvgUnsupported extends SvgNode {
  final String reason;
  final String elementName;
  final String originalTag;

  const SvgUnsupported({
    required this.reason,
    required this.elementName,
    required this.originalTag,
  });

  @override
  double get intrinsicWidth => 0;
  @override
  double get intrinsicHeight => 0;
}
