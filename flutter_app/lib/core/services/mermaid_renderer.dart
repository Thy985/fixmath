import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'mermaid_service.dart';

class MermaidSvgWidget extends StatelessWidget {
  final String svg;
  final double? width;
  final double? height;
  final BoxFit fit;

  const MermaidSvgWidget({
    super.key,
    required this.svg,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svg,
      width: width,
      height: height,
      fit: fit,
      placeholderBuilder: (context) => Container(
        width: width,
        height: height,
        color: Colors.transparent,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class MermaidElementWidget extends StatefulWidget {
  final String code;
  final MermaidTheme theme;
  final double? maxWidth;
  final double? maxHeight;

  const MermaidElementWidget({
    super.key,
    required this.code,
    this.theme = MermaidTheme.light,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  State<MermaidElementWidget> createState() => _MermaidElementWidgetState();
}

class _MermaidElementWidgetState extends State<MermaidElementWidget> {
  String? _svg;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(MermaidElementWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.theme != widget.theme) {
      _render();
    }
  }

  Future<void> _render() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svg = await MermaidService.renderToSvg(
        widget.code,
        theme: widget.theme,
      );
      if (mounted) {
        setState(() {
          _svg = svg;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Mermaid 渲染失败',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
            ),
          ],
        ),
      );
    }

    return MermaidSvgWidget(
      svg: _svg!,
      width: widget.maxWidth,
      height: widget.maxHeight,
    );
  }
}
