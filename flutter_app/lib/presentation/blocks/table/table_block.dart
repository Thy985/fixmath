/// TableBlock：表格块（render + edit 双态）。
///
/// 落地 Phase 3.2 Task Contract §3.5（任务 3.2.4）+ ADR-0009 §3.3。
///
/// **双态切换**：
/// - [RenderMode.rendered]：Table widget（headers + rows + 对齐分隔线）
/// - [RenderMode.editing]：由基类 `buildEditField` 提供 [TextField]
///   （source 为 Markdown 表格源码）
///
/// **视觉规范**（[ui-spec.md §2.5](../../design/ui-spec.md)）：
/// - 表头加粗 + 浅灰背景
/// - 单元格 padding 8-12
/// - 列宽均分（Phase 3.2 不实现可视化拖拽编辑,留 Phase 3.5）
///
/// **AST 类型**：[TableElement]（含 headers / rows,无对齐信息,Phase 3.2 不实现 col-align）
///
/// **依赖方向**（Hard Rule 8）：blocks/ → editor/ → core/editing/。
library;

import 'package:flutter/material.dart';

import '../../../core/editing/block_types.dart';
import '../../../data/models/document.dart';
import '../../editor/editor_coordinator.dart';
import '../../states/block_view_state.dart';
import '../base_block_state.dart';

/// 表格块 Widget（StatefulWidget,依赖 BaseBlockState 共享样板）。
class TableBlock extends StatefulWidget {
  /// 当前块的 UI 视图状态。
  final BlockViewState state;

  /// 当前块的 AST 数据（[TableElement]）。
  final TableElement element;

  /// 当前页面绑定的 [EditorCoordinator]。
  final EditorCoordinator coordinator;

  const TableBlock({
    super.key,
    required this.state,
    required this.element,
    required this.coordinator,
  });

  @override
  State<TableBlock> createState() => _TableBlockState();
}

/// 表格块 State：extends [BaseBlockState] 共享 controller / focus / commit 样板。
///
/// **Phase 3.2 §3.0 方案 A**：仅保留 buildRenderContent + edit 态配置,
/// 不重写 build()（基类统一调度）。
class _TableBlockState extends BaseBlockState<TableBlock> {
  @override
  BlockId get blockId => widget.state.id;

  @override
  RenderMode get currentMode => widget.state.mode;

  @override
  RenderMode previousMode(TableBlock oldWidget) => oldWidget.state.mode;

  /// edit 态多行（表格源码多行）。
  @override
  int? get editFieldMaxLines => null;

  /// edit 态 monospace 字体（与 CodeBlock 一致,Markdown 表格源码对齐可读）。
  @override
  TextStyle? get editFieldStyle => const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
      );

  @override
  Widget buildRenderContent(BuildContext context) {
    final headers = widget.element.headers;
    final rows = widget.element.rows;

    if (headers.isEmpty && rows.isEmpty) {
      return GestureDetector(
        onTap: onBlockTap,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('（空表格）'),
        ),
      );
    }

    return GestureDetector(
      onTap: onBlockTap,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            columnWidths: const {},
            children: [
              // 表头行
              if (headers.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                  ),
                  children: headers
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            h,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              // 数据行
              ...rows.map(
                (row) => TableRow(
                  children: row
                      .map(
                        (cell) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            cell,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
