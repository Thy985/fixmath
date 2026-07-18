import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/storage_migration.dart';
import 'core/services/formula_pdf_renderer.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/mermaid_host.dart';
import 'providers/editor_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启动时执行一次性存储迁移（JSON 文档库 → .md 单一真相源）。
  // 失败不阻塞启动，仅记录日志，旧数据保留为 .bak。
  try {
    await StorageMigration.migrateIfNeeded();
  } catch (e) {
    debugPrint('Storage migration skipped: $e');
  }
  runApp(
    ProviderScope(
      child: FormulaFixApp(),
    ),
  );
}

class FormulaFixApp extends ConsumerWidget {
  const FormulaFixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);

    return MaterialApp.router(
      title: 'FormulaFix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
      builder: (context, child) {
        return FormulaRenderHost(
          child: Stack(
            children: [
              if (child != null) child,
              const Positioned(
                left: -10000,
                top: -10000,
                child: MermaidRendererHost(),
              ),
            ],
          ),
        );
      },
    );
  }
}
