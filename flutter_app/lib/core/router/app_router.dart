import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/editor_screen.dart';
import '../../presentation/screens/file_manager_screen.dart';
import '../../core/constants/app_constants.dart';

final appRouter = GoRouter(
  initialLocation: '/editor',
  errorBuilder: (context, state) => _ErrorScreen(error: state.error?.toString()),
  routes: [
    GoRoute(
      path: '/editor',
      builder: (context, state) {
        final openPath = state.extra as String?;
        return EditorScreen(initialPath: openPath);
      },
    ),
    GoRoute(
      path: '/files',
      builder: (context, state) => const FileManagerScreen(),
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
              Text(
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
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.darkTextSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => context.go('/editor'),
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
