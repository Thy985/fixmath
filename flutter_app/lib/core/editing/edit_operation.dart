/// EditOperation sealed class + TextOperation + BlockOperation（part）。
///
/// 落地 ADR-0007 §4.2（EditOperation sealed class）+ ADR-0008 §2（apply/revert 幂等纯函数）。
///
/// v1.2 关键约束：
/// - 所有 op 用 [BlockId] 定位（不用 index，因 index 在 insert/delete 后失效）
/// - apply 返回 bool，不抛异常（调用方决定 rollback）
/// - revert 读取 apply 时填充的 revertContext（不依赖外部可变状态）
/// - revertContext 是 immutable snapshot，禁止保存 live mutable reference（[document.dart] 已 @immutable）
///
/// 详见 Phase 2.6 Task Contract §3.2。
///
/// [BlockOperation] 实现在 `block_operation.dart` part 文件中（同 library，
/// 满足 sealed class 子类必须同 library 的约束）。
library;

import 'document_editor.dart';
import 'block_types.dart';
import 'block_serializer.dart';
import '../../data/models/document.dart';

part 'block_operation.dart';

/// 编辑操作联合类型。
///
/// ADR-0007 §4.2 + ADR-0008 §2。
sealed class EditOperation {
  const EditOperation();

  /// 前向应用：修改 [editor] 状态，返回是否成功。
  ///
  /// 幂等纯函数（不依赖外部可变状态），同一 op 对同一 editor 状态多次 apply 结果一致。
  /// 失败返回 false（不抛异常），调用方决定是否 rollback。
  bool apply(DocumentEditor editor);

  /// 反向应用：恢复到 apply 前的状态。
  ///
  /// 幂等纯函数。revert 后 editor 状态应与 apply 前一致。
  void revert(DocumentEditor editor);
}

/// 文本操作：块内文本变化。
///
/// 用户连续输入 "hello" = 5 个 [TextOperation] 或 1 个批量（coalescing 自动合并）。
///
/// **v1.1 评审反馈 1 修订**：用 [BlockId] 而非 blockIndex 作为 identity。
/// 理由：[BlockId] 是稳定 identity（不随 insert/delete 变化），
/// 而 index 在 insert/delete 后会失效（如 delete B 后 index=1 不再指向 B）。
///
/// **v1.2 评审反馈补强 1**：revertContext 是 immutable snapshot，
/// 因 [DocumentElement] 已是 @immutable（[document.dart:30](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart)），
/// 天然满足。
class TextOperation extends EditOperation {
  /// 目标块的 [BlockId]（稳定 identity，不随其他 op 变化）。
  final BlockId blockId;

  /// 块内 offset（UTF-16，对齐 Flutter TextEditingValue）。
  final int offset;

  /// 被删除文本（revert 时恢复）。
  final String deleted;

  /// 插入文本（revert 时删除）。
  final String inserted;

  /// 可选：cached index（性能优化，不作为 identity）。
  ///
  /// apply 时填充，仅用于快速查找。失效时降级到 [DocumentEditor.indexOf]。
  /// 不可作为 revert 定位依据。
  int? cachedIndex;

  TextOperation({
    required this.blockId,
    required this.offset,
    this.deleted = '',
    this.inserted = '',
    this.cachedIndex,
  });

  @override
  bool apply(DocumentEditor editor) {
    // 1. 通过 BlockId 定位（不依赖 cachedIndex）
    final element = editor.getBlock(blockId);
    if (element == null) return false;

    // 2. element → source + type
    final source = fromElement(element);
    final type = BlockType.fromElement(element);

    // 3. 边界检查：offset / deleted.length 在 source 范围内
    if (offset < 0 ||
        offset + deleted.length > source.length) {
      return false;
    }

    // 4. 构造新 source
    final newSource =
        source.substring(0, offset) + inserted + source.substring(offset + deleted.length);

    // 5. source + type → newElement
    final newElement = toElement(newSource, type);

    // 6. 保持 BlockId 不变，仅替换内容
    editor.updateBlockContent(blockId, newElement);

    // 7. 缓存 index（性能优化）
    cachedIndex = editor.indexOf(blockId);

    return true;
  }

  @override
  void revert(DocumentEditor editor) {
    // 逆操作：通过 blockId 定位（不依赖 cachedIndex）
    // 当前 element 已是 apply 后的状态，先序列化拿到当前 source
    final currentElement = editor.getBlock(blockId);
    if (currentElement == null) return;

    final currentSource = fromElement(currentElement);
    final type = BlockType.fromElement(currentElement);

    // 逆操作：先删 inserted，再插 deleted
    // apply 前 source = source[0..offset) + source[offset+deleted.length..)
    // revert: source[0..offset) + deleted + source[offset+inserted.length..)
    if (offset < 0 ||
        offset + inserted.length > currentSource.length) {
      return;  // 边界检查失败，无法 revert（理论上不应发生）
    }

    final revertedSource = currentSource.substring(0, offset) +
        deleted +
        currentSource.substring(offset + inserted.length);

    final revertedElement = toElement(revertedSource, type);
    editor.updateBlockContent(blockId, revertedElement);
  }

  @override
  String toString() =>
      'TextOperation(blockId=$blockId, offset=$offset, deleted="$deleted", inserted="$inserted")';
}
