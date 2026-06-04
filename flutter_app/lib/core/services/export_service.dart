/// Re-export shim：把 domain 层的导出 facade 透传到 core 层。
///
/// 重构前 lib/core/services/export_service.dart 持有 ExportService / ExportFormat
/// / ExportException；lib/domain/services/export_service.dart 持有 1000+ 行
/// MarkdownExporter。两个同名文件分散在不同职责层，调用方需要分别 import。
///
/// 重构后把 ExportService / ExportFormat / ExportException 全部迁到
/// `domain/services/export_service.dart`（作为顶层 helper），core 层只保留
/// 这一个 re-export 入口。EditorScreen 等老代码的 import 路径不变，
/// 内部直接看到的就是 domain 的统一实现。
library;

export '../../domain/services/export_service.dart'
    show
        ExportFormat,
        ExportService,
        ExportException,
        ExportFailure,
        ExportFailureInfo,
        ExportFailureException,
        classifyError,
        MarkdownExporter;
