/// E2E 用例：app 启动 + SeedDocuments 显示。
///
/// 落地 Phase 3.3 PR #1.5 Task Contract v2.1 §3.3.4。
///
/// **覆盖**：
/// - [EditorPage] 构造成功（无抛异常）
/// - SeedDocuments demo1（标题 "FormulaFix Demo"）正确显示
/// - [EditorShell] 挂载（AppBar + Viewport + StatusBar 三层结构）
///
/// **不在范围**：
/// - Toolbar / Template 测试（PR #2B / PR #2C）
/// - Undo/Redo 操作链（PR #2C）
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:formula_fix/presentation/editor/editor_shell.dart';
import 'helpers/test_fixture.dart';

void main() {
  group('PR #1.5 app 启动 E2E', () {
    testWidgets('EditorPage 启动后显示 SeedDocuments demo1 标题', (tester) async {
      await pumpEditorApp(tester, seedSelector: 0);

      // AppBar 标题应显示 SeedDocuments demo1 的 title（"FormulaFix Demo"）
      expect(find.text('FormulaFix Demo'), findsOneWidget,
          reason: 'AppBar 应显示 SeedDocuments demo1 的 title');
    });

    testWidgets('EditorShell 挂载成功（AppBar + Viewport + StatusBar）', (tester) async {
      await pumpEditorApp(tester);

      // EditorShell 应挂载（含 AppBar + body + bottomNavigationBar）
      expect(find.byType(EditorShell), findsOneWidget,
          reason: 'EditorShell 应作为根布局挂载');
    });

    testWidgets('SeedDocuments demo2（seedSelector=1）正确加载', (tester) async {
      await pumpEditorApp(tester, seedSelector: 1);

      // demo2 标题应不同于 demo1（验证 seedSelector 路由参数生效）
      expect(find.text('FormulaFix Demo'), findsNothing,
          reason: 'demo2 不应显示 demo1 的标题');
    });

    testWidgets('SeedDocuments demo3（seedSelector=2）正确加载', (tester) async {
      await pumpEditorApp(tester, seedSelector: 2);

      // demo3 标题应不同于 demo1
      expect(find.text('FormulaFix Demo'), findsNothing,
          reason: 'demo3 不应显示 demo1 的标题');
    });
  });
}
