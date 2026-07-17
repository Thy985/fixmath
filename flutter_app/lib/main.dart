import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/formula_pdf_renderer.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/mermaid_host.dart';
import 'providers/editor_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
