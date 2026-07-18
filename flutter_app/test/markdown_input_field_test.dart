import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formula_fix/presentation/widgets/markdown_input_field.dart';

/// ROADMAP 1.6 回归测试：工具栏按钮必须与解析器能力对齐。
///
/// 解析器已支持（markdown_parser.dart）：
///   图片 / 任务列表 / 水平线 / 代码块 / 表格
/// 工具栏必须提供对应按钮，否则用户无法通过 UI 触发这些语法。
void main() {
  testWidgets('MarkdownInputField toolbar exposes all parser-aligned buttons',
      (WidgetTester tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: const [],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MarkdownInputField(
                controller: controller,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      ),
    );

    // 原有按钮（防止意外移除）
    expect(find.byTooltip('加粗 **'), findsOneWidget);
    expect(find.byTooltip('斜体 *'), findsOneWidget);
    expect(find.byTooltip('删除线 ~~'), findsOneWidget);
    expect(find.byTooltip('行内代码 `'), findsOneWidget);
    expect(find.byTooltip('标题 #'), findsOneWidget);
    expect(find.byTooltip('无序列表 -'), findsOneWidget);
    expect(find.byTooltip('有序列表 1.'), findsOneWidget);
    expect(find.byTooltip('引用 >'), findsOneWidget);
    expect(find.byTooltip('链接 []()'), findsOneWidget);

    // 新增按钮：与解析器能力对齐
    expect(find.byTooltip('图片 ![]()'), findsOneWidget,
        reason: 'parser 已支持 ImageElement');
    expect(find.byTooltip('任务列表 - [ ]'), findsOneWidget,
        reason: 'parser 已支持 TaskListItemElement');
    expect(find.byTooltip('水平分割线 ---'), findsOneWidget,
        reason: 'parser 已支持 HorizontalRuleElement');
    expect(find.byTooltip('代码块 ```'), findsOneWidget,
        reason: 'parser 已支持 CodeElement');
    expect(find.byTooltip('表格 |...|'), findsOneWidget,
        reason: 'parser 已支持 TableElement');

    controller.dispose();
  });

  testWidgets('Tapping image button inserts image markdown at cursor',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: '');

    await tester.pumpWidget(
      ProviderScope(
        overrides: const [],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MarkdownInputField(
                controller: controller,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('图片 ![]()'));
    await tester.pump();

    expect(controller.text, contains('![alt](url)'));

    controller.dispose();
  });

  testWidgets('Tapping task list button inserts - [ ] prefix',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: '');

    await tester.pumpWidget(
      ProviderScope(
        overrides: const [],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MarkdownInputField(
                controller: controller,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('任务列表 - [ ]'));
    await tester.pump();

    expect(controller.text, contains('- [ ] '));

    controller.dispose();
  });

  testWidgets('Tapping code block button inserts fenced code block',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: '');

    await tester.pumpWidget(
      ProviderScope(
        overrides: const [],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MarkdownInputField(
                controller: controller,
                isDarkMode: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('代码块 ```'));
    await tester.pump();

    // 必须是成对的 ``` 围栏，不能只有一个
    expect(controller.text.split('```').length - 1, 2,
        reason: '代码块插入必须成对围栏');

    controller.dispose();
  });
}
