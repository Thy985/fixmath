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
    // 关键修复：即使 isReady=false 也必须挂载 WebView，否则永远无法触发
    // onWebViewCreated → attachController → isReady=true。这是典型的"先有鸡还是
    // 先有蛋"死锁——必须无条件下渲染 InAppWebView。
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
          // 立即 attach controller，使 renderToSvg 知道 WebView 已挂载。
          // 即使 JS 还在加载 JS 资源，attachController 已经让请求能排队。
          MermaidService.attachController(controller);
        },
        onConsoleMessage: (controller, consoleMessage) {
          final msg = consoleMessage.message;
          MermaidService.handleConsoleMessage(msg);
          FormulaSvgService.handleConsoleMessage(msg);
        },
        onRenderProcessGone: (controller, gone) {
          // WebView 渲染进程崩溃（GPU worker thread exit 等），
          // 此时 SVG 渲染已不可用，需重置状态让导出回退到 PNG-only 模式。
          MermaidService.resetRenderer();
        },
        onLoadStop: (controller, url) {
          // 关键：页面 + 子资源（tex-svg.js / mermaid.min.js）真正加载完毕
          // 才会触发此回调。在 onWebViewCreated 之后、JS 资源加载完成之前，
          // window.renderMermaid 还不存在，若此时调用 evaluateJavascript
          // 会静默失败 → 30s 后 → MermaidRenderException('render timeout')。
          // 因此必须在 onLoadStop 之后才能把待发请求 dispatch 出去。
          MermaidService.markPageLoaded();
        },
        onReceivedError: (controller, request, error) {
          debugPrint('MermaidRendererHost: load error ${request.url}: ${error.description}');
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('MermaidRendererHost: HTTP error ${request.url}: '
              '${errorResponse.statusCode}');
        },
      ),
    );
  }
}
