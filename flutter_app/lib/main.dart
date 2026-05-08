import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/editor_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FormulaFixApp(),
    ),
  );
}

class FormulaFixApp extends StatelessWidget {
  const FormulaFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FormulaFix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const EditorScreen(),
    );
  }
}
