/// Phase 3.2 PR #3 架构守门测试（BlockRenderer case 分发 + WebViewPool 复用）。
///
/// 落地 Phase 3.2 Task Contract v1.2 §3.3 + §3.2.8：
/// - TC-BLOCK-CASE-DISPATCH：BlockRenderer 的 Mermaid case 分发
/// - TC-PERF-WEBVIEW-1：WebView 复用（MermaidBlock 不自建 WebView 实例）
/// - TC-PERF-CACHE-1：渲染缓存复用（MermaidService._cache LRU）
///
/// 测试方式：源码静态扫描（与架构守门测试风格一致）
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ============ TC-BLOCK-CASE-DISPATCH Mermaid case 分发 ============

  group('TC-BLOCK-CASE-DISPATCH BlockRenderer Mermaid case 分发', () {
    test('BlockRenderer 包含 MermaidElement me => MermaidBlock 分支', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('MermaidElement me => MermaidBlock'),
        isTrue,
        reason: 'BlockRenderer 必须有 MermaidElement → MermaidBlock 的 case 分发',
      );
    });

    test('BlockRenderer import mermaid_block.dart', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains("import 'mermaid/mermaid_block.dart'"),
        isTrue,
        reason: 'BlockRenderer 必须 import mermaid/mermaid_block.dart',
      );
    });

    test('BlockRenderer 不再将 MermaidElement 放入 UnimplementedError 分支', () {
      final file = File('lib/presentation/blocks/block_renderer.dart');
      final content = file.readAsStringSync();

      // MermaidElement 不应在 UnimplementedError 分支（已移出）
      // 检查 ListElement / TaskListItemElement / HorizontalRuleElement 仍在 fallback
      expect(
        content.contains('ListElement()') &&
            content.contains('TaskListItemElement()') &&
            content.contains('HorizontalRuleElement()'),
        isTrue,
        reason: 'BlockRenderer 仍需对 ListElement / TaskListItemElement / '
            'HorizontalRuleElement 抛 UnimplementedError（Phase 3.5+ 实现）',
      );
    });
  });

  // ============ TC-PERF-WEBVIEW-1 WebView 复用 ============

  group('TC-PERF-WEBVIEW-1 WebView 复用（MermaidBlock 不自建 WebView）', () {
    test('MermaidBlock 不直接 import flutter_inappwebview', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains("import 'package:flutter_inappwebview"),
        isFalse,
        reason: 'MermaidBlock 不应直接 import flutter_inappwebview'
            '（必须通过 MermaidService 共享 WebView,Hard Rule + Task Contract §3.2.8）',
      );
    });

    test('MermaidBlock 通过 MermaidService 获取渲染能力', () {
      final file = File('lib/presentation/blocks/mermaid/mermaid_block.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains("import 'mermaid_service.dart'") ||
            content.contains("import '../../../core/services/mermaid_service.dart'"),
        isTrue,
        reason: 'MermaidBlock 必须 import MermaidService（共享 WebView 实例）',
      );
      expect(
        content.contains('MermaidService.isReady'),
        isTrue,
        reason: 'MermaidBlock 必须通过 MermaidService.isReady 检测 WebView 状态',
      );
    });
  });

  // ============ TC-PERF-CACHE-1 渲染缓存复用 ============

  group('TC-PERF-CACHE-1 渲染缓存复用（MermaidService._cache LRU）', () {
    test('MermaidService 有 LRU 缓存（已存在,Phase 3.2 PR #3 复用）', () {
      final file = File('lib/core/services/mermaid_service.dart');
      expect(file.existsSync(), isTrue, reason: 'mermaid_service.dart 必须存在');
      final content = file.readAsStringSync();

      // 缓存 key 是 (code, theme) 的 hash
      expect(
        content.contains('_cache'),
        isTrue,
        reason: 'MermaidService 必须有 _cache 缓存字段',
      );
      // LRU 策略（LinkedHashMap）
      expect(
        content.contains('LinkedHashMap'),
        isTrue,
        reason: 'MermaidService 缓存必须用 LinkedHashMap 实现 LRU',
      );
      // 缓存上限
      expect(
        content.contains('_maxCacheEntries'),
        isTrue,
        reason: 'MermaidService 必须有 _maxCacheEntries 缓存上限',
      );
    });

    test('MermaidService renderToSvg 命中缓存时不重新渲染', () {
      final file = File('lib/core/services/mermaid_service.dart');
      final content = file.readAsStringSync();

      // renderToSvg 开头必须检查缓存命中
      expect(
        content.contains('final hit = _cache.remove(key)'),
        isTrue,
        reason: 'MermaidService.renderToSvg 必须检查缓存命中（LRU remove + reinsert）',
      );
      expect(
        content.contains('if (hit != null)'),
        isTrue,
        reason: 'MermaidService.renderToSvg 命中缓存时必须直接返回（不重新渲染）',
      );
    });
  });
}
