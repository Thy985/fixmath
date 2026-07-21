import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/editor_screen.dart';
import '../../presentation/screens/file_manager_screen.dart';
import '../../presentation/screens/document_list_screen.dart';
import '../../presentation/editor/editor_page.dart';
import '../../core/constants/app_constants.dart';

/// 应用路由表。
///
/// **Phase 3.1-A PR #2 起**：
/// - `/editor` 默认指向新 [EditorPage]（Phase 3.0 production 路径）
/// - `/editor-legacy` 指向旧 [EditorScreen]（fallback，迁移期保留）
/// - `/editor3` 已移除（合并到 `/editor`）
///
/// 旧 UI 代码保留一个 release 周期，收集用户反馈后再决定是否完全删除
/// （按 [phase3.1-task-contract.md v2.0 §3.4](../../docs/contracts/phase3.1-task-contract.md)）。
final appRouter = GoRouter(
  initialLocation: '/files',
  errorBuilder: (context, state) => _ErrorScreen(error: state.error?.toString()),
  routes: [
    GoRoute(
      path: '/files',
      builder: (context, state) => const FileManagerScreen(),
    ),
    GoRoute(
      path: '/documents',
      builder: (context, state) => const DocumentListScreen(),
    ),
    // Phase 3.1-A PR #2：默认入口指向新 EditorPage（production 路径）
    GoRoute(
      path: '/editor',
      builder: (context, state) {
        final seedSelector = state.extra as int?;
        return EditorPage(seedSelector: seedSelector ?? 0);
      },
    ),
    // Phase 3.1-A PR #2：旧 EditorScreen 作为 fallback 路由（迁移期保留）
    // 入口隐藏在 EditorAppBar 设置中，普通用户不会发现。
    // Phase 3.17 完成后移除此路由 + editor_screen.dart 文件。
    GoRoute(
      path: '/editor-legacy',
      builder: (context, state) {
        final openPath = state.extra as String?;
        return EditorScreen(initialPath: openPath);
      },
    ),
  ],
);

class _ErrorScreen extends StatelessWidget {
  final String? error;

  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '页面加载失败',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.darkTextSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => context.go('/files'),
                icon: const Icon(Icons.home),
                label: const Text('返回首页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
