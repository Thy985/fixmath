import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
      child: InAppWebView(
        key: const ValueKey('mermaid-renderer-webview'),
        initialData: InAppWebViewInitialData(
          data: MermaidService.html,
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
            transparentBackground: true,
            verticalScrollBarEnabled: false,
            horizontalScrollBarEnabled: false,
          ),
        ),
        onWebViewCreated: (controller) {
          MermaidService.attachController(controller);
        },
        onConsoleMessage: (controller, consoleMessage) {
          MermaidService.handleConsoleMessage(consoleMessage.message);
        },
      ),
    );
  }
}
