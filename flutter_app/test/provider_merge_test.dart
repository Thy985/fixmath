// 回归测试：验证重复 Provider 已合并到 [providers]。
//
// 防止未来再次在 editor_providers.dart 重复定义同名 Provider
// （Riverpod 中同名 = 两个独立实例，状态不同步）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:formula_fix/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('合并后 editorContentProvider 是唯一实例且状态可用', () {
    final container = ProviderContainer();
    final notifier = container.read(editorContentProvider.notifier);
    expect(notifier, isA<EditorContentNotifier>());

    notifier.state = '# 合并后的草稿';
    expect(container.read(editorContentProvider), '# 合并后的草稿');
  });

  test('合并后 darkModeProvider 解析并可在 notifier 上切换', () {
    final container = ProviderContainer();
    final initial = container.read(darkModeProvider);
    container.read(darkModeProvider.notifier).toggle();
    expect(container.read(darkModeProvider), !initial);
  });

  test('合并后 previewModeProvider / isExportingProvider 默认值一致', () {
    final container = ProviderContainer();
    expect(container.read(previewModeProvider), isFalse);
    expect(container.read(isExportingProvider), isFalse);
  });
}
