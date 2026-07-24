/// TestFixture：integration_test 唯一入口。
///
/// 落地 Phase 3.3 PR #1.5 Task Contract v2.1 §3.3.1（审批 #4）。
///
/// **Hard Rule**（v2.1 §3.3.1）：
/// - 所有 E2E 用例必须通过 [TestFixture] 启动 app
/// - 禁止直接 `pumpWidget(ProviderScope(child: FormulaFixApp()))`（会走真实存储）
/// - 禁止依赖 `path_provider` / `SharedPreferences` 真实存储
///
/// **设计**：
/// Phase 3.0 production 路径中 [EditorPage] 直接在 `initState` 构造
/// [EditorCoordinator]（注入 [InMemoryDocumentEditor] + [EditorHistory]）,
/// **不依赖任何 Provider / Repository**。因此 E2E 直接 `pumpWidget(EditorPage())`
/// 即可跳过路由 `/files`（[FileManagerScreen] 依赖 `path_provider`）与全局
/// [ProviderScope]（`FormulaFixApp` 的 `darkModeProvider` 依赖 `SharedPreferences`）。
///
/// 这样 E2E 测试：
/// - 不触达真实文件系统（满足 v2.1 §3.3.1 Hard Rule）
/// - 直接覆盖 [EditorPage] → [EditorShell] → [BlockRenderer] 路径
/// - 无需 mock SharedPreferencesProvider / DocumentService（EditorPage 不消费这些）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/presentation/editor/editor_page.dart';

/// integration_test 唯一入口：构造 [EditorPage] 并 pump 到 [tester]。
///
/// [seedSelector] 选择种子文档（0 = demo1, 1 = demo2, 2 = demo3）。
/// [locale] 预留：未来国际化时切换 locale（Phase 4+）。
///
/// 返回构造的 [EditorPage] widget 引用（便于高级断言）。
Future<EditorPage> pumpEditorApp(
  WidgetTester tester, {
  int seedSelector = 0,
}) async {
  final app = EditorPage(seedSelector: seedSelector);
  await tester.pumpWidget(
    MaterialApp(
      home: app,
    ),
  );
  await tester.pumpAndSettle();
  return app;
}
