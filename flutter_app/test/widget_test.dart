import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'package:formula_fix/main.dart';

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
    // Stub: 没有真正的 WebView controller 时返回 null 即可。
    // 单元测试不会触达这条路径。
    throw UnimplementedError('NoopPlatformInAppWebViewWidget.controllerFromPlatform');
  }

  @override
  void dispose() {}
}

void main() {
  setUpAll(() {
    InAppWebViewPlatform.instance = _FakeInAppWebViewPlatform();
  });

  testWidgets('App smoke test - verifies app can be built',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FormulaFixApp(),
      ),
    );

    expect(find.text('FormulaFix'), findsOneWidget);
  });
}
