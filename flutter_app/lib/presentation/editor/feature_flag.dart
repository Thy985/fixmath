/// Feature Flag：Phase 3.0 新旧 UI 并存切换开关。
///
/// 落地 Phase 3.0 Task Contract §2.5（旧 UI 并存）+ Phase 3.1-A §3.4 Default Editor
/// Migration。
///
/// **生命周期**：
/// - Phase 3.0：默认 `false`（旧 UI 为 `main` 入口，新 UI 经 `/editor3` 路由访问）
/// - Phase 3.1-A PR #2：改为 `true`（新 UI 成为主入口，旧 UI 降级为 `/editor-legacy`）
/// - Phase 3.17 完成：删除旧 UI 代码 + 移除 feature flag
///
/// **理由**：避免 Phase 3.0 期间 UI 完全不可用；为 Phase 3.1 移除 `previewModeProvider`
/// 提供过渡期。
library;

/// 是否启用新 Editor（Phase 3.0 production 路径）。
///
/// Phase 3.1-A PR #2 起默认 `true`，新 `EditorPage` 为 `/editor` 主入口。
/// 旧 `EditorScreen` 经 `/editor-legacy` 路由访问（fallback，迁移期保留）。
///
/// **注意**：此 flag 在 Phase 3.1-A PR #2 后已失去"切换"意义（新 UI 已默认），仅作为
/// "旧 UI 代码是否已删除"的标记。Phase 3.17 删除旧 UI 代码时同步移除本 flag。
const bool kEnableNewEditor = true;
