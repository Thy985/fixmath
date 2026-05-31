import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/editor_screen.dart';
import '../../presentation/screens/file_manager_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/editor',
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