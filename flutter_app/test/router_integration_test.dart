import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:formula_fix/main.dart';
import 'package:formula_fix/presentation/screens/document_list_screen.dart';
import 'package:formula_fix/presentation/screens/editor_screen.dart';

/// 测试用 `InAppWebViewPlatform` 桩：返回固定大小的空 Widget，
/// 避免在 `flutter test` 单元测试中尝试初始化平台 WebView。
class _FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return _NoopPlatformInAppWebViewWidget(params);
  }
}

class _NoopPlatformInAppWebViewWidget extends PlatformInAppWebViewWidget {
  _NoopPlatformInAppWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    throw UnimplementedError('NoopPlatformInAppWebViewWidget.controllerFromPlatform');
  }

  @override
  void dispose() {}
}

void main() {
  setUpAll(() {
    InAppWebViewPlatform.instance = _FakeInAppWebViewPlatform();
  });

  /// ROADMAP 1.4：初始路由应为文件列表（/files），首屏显示"文件管理"。
  testWidgets('初始路由为 /files，首屏显示"文件管理"',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FormulaFixApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('文件管理'), findsWidgets);
  });

  /// ROADMAP 1.3：DocumentListScreen 可正常构建（非死代码/非损坏）。
  /// 其 AppBar 标题为 "FormulaFix"，已随 1.3 注册为 /documents 路由。
  testWidgets('DocumentListScreen 可构建，AppBar 显示"FormulaFix"',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DocumentListScreen())),
    );
    // AppBar 标题同步渲染，不依赖 documentsProvider 异步加载结果
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FormulaFix'), findsWidgets);
  });

  /// /editor 路由对应的 EditorScreen 可正常构建（顶栏含"文件管理"入口）。
  testWidgets('EditorScreen 可构建，顶栏含"文件管理"入口',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: EditorScreen())),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('文件管理'), findsWidgets);
  });
}
