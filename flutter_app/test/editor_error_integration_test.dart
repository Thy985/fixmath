import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:formula_fix/main.dart';
import 'package:formula_fix/core/router/app_router.dart';

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

  /// ROADMAP 1.7 回归：保存空内容时，错误文案应对用户友好，
  /// 且不得向用户透传异常类名 / 内部细节（如 "Exception" / "Cannot save"）。
  testWidgets('保存空内容时错误文案友好，不泄露原始异常',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FormulaFixApp()),
    );
    await tester.pumpAndSettle();

    // 进入编辑器（/editor）。无论首屏是 /files 还是 /editor，
    // 显式导航可保证编辑器已挂载，使本测试不依赖初始路由。
    appRouter.go('/editor');
    await tester.pumpAndSettle();

    // 打开"更多"菜单
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    // 点击"保存"（空内容会触发 saveToFile 抛 FileSaveException）
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 应弹出友好引导文案
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('保存失败，请检查存储空间与文件权限'),
      findsOneWidget,
    );
    // 不得包含原始异常细节
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('Cannot save'), findsNothing);
  });
}
