import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/services/formula_svg_service.dart';
import '../../core/services/mermaid_service.dart';

class MermaidRendererHost extends StatefulWidget {
  const MermaidRendererHost({super.key});

  @override
  State<MermaidRendererHost> createState() => _MermaidRendererHostState();
}

class _MermaidRendererHostState extends State<MermaidRendererHost> {
  @override
  Widget build(BuildContext context) {
    if (!MermaidService.isReady || MermaidService.html.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 800,
      height: 400,
      // 加载本地资产目录下的 HTML 模板 (assets/mermaid_renderer.html)。
      // 该文件内的 `<script src="js/tex-svg.js">` / `<script src="js/mermaid.min.js">`
      // 会以 HTML 所在目录为基准解析为 Flutter 打包的 `assets/js/...`，
      // 不再依赖任何 CDN / 平台硬编码路径。
      // 平台映射 (由 flutter_inappwebview 内部解析):
      //   - Android: 打包到 APK assets 目录，WebView 通过 file:// 协议加载
      //   - Windows: 提取到 <exeDir>/data/flutter_assets/ 后用 file:// 加载
      //   - Web:     由 flutter_inappwebview_web 通过 iframe 资源服务代理
      child: InAppWebView(
        key: const ValueKey('mermaid-renderer-webview'),
        initialFile: MermaidService.rendererAssetPath,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: true,
          verticalScrollBarEnabled: false,
          horizontalScrollBarEnabled: false,
        ),
        onWebViewCreated: (controller) {
          MermaidService.attachController(controller);
        },
        onConsoleMessage: (controller, consoleMessage) {
          final msg = consoleMessage.message;
          MermaidService.handleConsoleMessage(msg);
          FormulaSvgService.handleConsoleMessage(msg);
        },
      ),
    );
  }
}
