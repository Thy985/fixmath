/// Feature Flag：Phase 3.0 新旧 UI 并存切换开关。
///
/// 落地 Phase 3.0 Task Contract §2.5（旧 UI 并存）+ §7.4 风险 4。
///
/// **生命周期**：
/// - Phase 3.0：默认 `false`（旧 UI 为 `main` 入口，新 UI 经 `/editor3` 路由访问）
/// - Phase 3.1 完成：改为 `true`（新 UI 成为主入口）
/// - Phase 3.17 完成：删除旧 UI 代码 + 移除 feature flag
///
/// **理由**：避免 Phase 3.0 期间 UI 完全不可用；为 Phase 3.1 移除 `previewModeProvider`
/// 提供过渡期。
library;

/// 是否启用新 Editor（Phase 3.0 production 路径）。
///
/// Phase 3.0 期间默认 `false`，旧 `EditorScreen` 为主入口。
/// 调试 Phase 3.0 新 UI 时通过 `/editor3` 路由访问。
const bool kEnableNewEditor = false;
