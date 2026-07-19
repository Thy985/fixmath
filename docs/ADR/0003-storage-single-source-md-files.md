# ADR-0003: 存储统一为 .md 文件作为文档内容单一真相

- **状态**：Implemented（2026-07-19 Phase 1 Close Candidate 时点转入）
- **生效日期**：2026-07-18（Phase 1 P0 #2 启动时 Accept）
- **Implemented 日期**：2026-07-19
- **决策者**：首席架构工程师
- **状态流**：`Proposed → Accepted → Implemented → Deprecated`
  - 进入 Phase 1 前：`Accepted`
  - Phase 1 P0 #2 实施完成、CI 全绿、文档迁移验证通过：`Implemented`
  - 未来被新方案（如 SQLite + 全文索引）取代：`Deprecated`

## Implemented 转入依据（2026-07-19）

本 ADR 在 Phase 1 Close Candidate 时点由 `Accepted` 转为 `Implemented`，依据如下：

1. **P0 #2 实施完成**：`FileRepository` / `FrontMatterParser` / `StorageMigration` 三大组件已落地
2. **CI 全绿**：314 tests passed / 9 skipped / 0 regression（[全量测试日志](file:///d:/Projects/Active/math/docs/releases/phase1-verification-report.md)）
3. **文档迁移验证通过**：
   - [test/storage/migration_test.dart](file:///d:/Projects/Active/math/flutter_app/test/storage/migration_test.dart) 覆盖 JSON→.md 迁移幂等性
   - [test/storage/atomic_write_test.dart](file:///d:/Projects/Active/math/flutter_app/test/storage/atomic_write_test.dart) 覆盖原子写不残留 .tmp
   - [test/storage/recovery_test.dart](file:///d:/Projects/Active/math/flutter_app/test/storage/recovery_test.dart) 覆盖数据恢复路径
4. **单一真相源边界守护已建立**：
   - [test/architecture/dependency_rule_test.dart](file:///d:/Projects/Active/math/flutter_app/test/architecture/dependency_rule_test.dart) 禁止业务层直接调用 `File.writeAsString`
   - [test/architecture/file_access_test.dart](file:///d:/Projects/Active/math/flutter_app/test/architecture/file_access_test.dart) 限制 `writeAsString`/`readAsString`/`writeAsBytes` 仅出现在 `lib/data/storage/` 与 `lib/core/services/file_service.dart`

## 背景

代码分析发现项目当前存在**三套互不相通的存储机制**，是 P0 级数据架构问题：

### 现状（三套并存）

| 存储 | 写入方 | 读取方 | 文件位置 | 用途 |
|------|--------|--------|---------|------|
| **SharedPreferences** | [editor_providers.dart:43-54](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L43-54) 500ms 防抖 | [editor_providers.dart:39](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart#L39) 启动恢复 | 系统偏好 | 编辑器内容草稿 |
| **JSON 文档库** | [document_service.dart:68-72](file:///d:/Projects/Active/math/flutter_app/lib/core/services/document_service.dart#L68-72) | [providers/providers.dart:51-59](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart#L51-59) `DocumentsNotifier.loadDocuments` | `getApplicationDocumentsDirectory()/formula_fix_documents.json` | 文档列表 |
| **.md 文件** | [file_service.dart:69-77](file:///d:/Projects/Active/math/flutter_app/lib/core/services/file_service.dart#L69-77) `saveToFile` | [file_manager_screen.dart:24-47](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/file_manager_screen.dart#L24-47) 扫描 `.md` | `getApplicationDocumentsDirectory()/formulafix_<ts>.md` | 用户主动保存的文件 |

### 问题

1. **数据不一致**：用户在编辑器输入 → 存到 SharedPreferences；点"保存" → 写成 .md；但这两个动作**不更新 JSON 文档库**
2. **UI 状态分裂**：
   - `FileManagerScreen` 只扫 `.md`，看不到 JSON 文档
   - `DocumentListScreen` 只读 JSON，看不到 `.md`（且 DocumentListScreen 是死代码）
3. **用户认知割裂**：用户不知道自己的文档到底存哪了
4. **数据丢失风险**：JSON 文件损坏 / SharedPreferences 清空，用户文档可能丢

## 决策

**以 `.md` 文件作为文档单一真相源**。废弃另外两套存储。

### 目标架构

```
┌─────────────────────────────────────────────────────┐
│ UI（EditorScreen / FileListScreen）                 │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ Provider（DocumentProvider / EditorProvider）       │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ FileRepository（单一存储入口，新）                    │
│   - listDocuments()  扫 .md                          │
│   - readDocument(path)  读 .md                       │
│   - writeDocument(path, content)  写 .md             │
│   - deleteDocument(path)  删 .md                     │
│   - renameDocument(oldPath, newPath)  改名           │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ File System                                          │
│   <appDocs>/documents/                               │
│     ├─ 文档1.md                                      │
│     ├─ 文档2.md                                      │
│     └─ ...                                          │
└─────────────────────────────────────────────────────┘

文档元数据（最近打开、收藏、置顶）：
  SharedPreferences 走 kv 缓存，不存内容
```

### 废弃清单

| 废弃项 | 替代方案 | 迁移方式 |
|--------|---------|---------|
| `formula_fix_documents.json` | .md 文件 + 文档目录扫描 | 一次性迁移：JSON 内每个 doc 写成 `<uuid>.md`，并注入最小 front matter（见 §边界约束 3/4） |
| `SharedPreferences['pref_last_content']` | 自动保存到当前打开的 .md 文件 | 编辑器每次切换文档时记下当前 path，防抖写入该 path |
| `DocumentService` | 新建 `FileRepository`（Phase 2 重命名） | 接口兼容包装 |
| `DocumentListScreen` | 合并到 `FileManagerScreen` 或注册路由（Phase 1 P0 #3 决策） | - |

### 迁移逻辑（幂等 + 验证阶段）

迁移遵循严格阶段，任一阶段失败都**不删除源数据**、不标记完成，保证可安全重跑：

```dart
class StorageMigration {
  static const _markerFile = 'documents/.storage_version';
  static const _expectedVersion = '1';

  /// 返回 true 表示已执行（或无需）迁移。
  static Future<bool> migrateIfNeeded() async {
    final dir = await getApplicationDocumentsDirectory();
    final jsonFile = File('${dir.path}/formula_fix_documents.json');
    final marker = File('${dir.path}/$_markerFile');

    // 1. 已完成（marker 命中）或无需迁移（无 JSON）→ 跳过（幂等）
    if (await marker.exists()) {
      if (await _readMarker(marker) == _expectedVersion) return true;
    }
    if (!await jsonFile.exists()) {
      // 没有旧数据，仅写 marker 占位，避免后续重复判断
      await _writeMarker(marker, _expectedVersion);
      return true;
    }

    // 2. Backup：保留 .json.bak，全程不删源
    final backup = await jsonFile.copy('${jsonFile.path}.bak');
    debugPrint('Backup created: ${backup.path}');

    // 3. Parse JSON
    final docs = await _readJsonDocuments(jsonFile);

    // 4. Generate：每个 doc 写成 <uuid>.md，并注入最小 front matter
    final docsDir = Directory('${dir.path}/documents');
    await docsDir.create(recursive: true);
    final written = <String, String>{}; // uuid -> content hash
    for (final doc in docs) {
      final uuid = doc.id ?? _newUuid();
      final file = File('${docsDir.path}/$uuid.md');
      final body = _buildMarkdown(doc, uuid); // 含 front matter
      await _atomicWrite(file, body);
      written[uuid] = _sha256(body);
    }

    // 5. Validate count
    if (written.length != docs.length) {
      debugPrint('Migration validation failed: count mismatch '
          '(${written.length} != ${docs.length})');
      return false; // 保留 .bak，不标记完成
    }

    // 6. Validate hash：重新读回每个 .md，比对内容哈希
    for (final entry in written.entries) {
      final reRead =
          await File('${docsDir.path}/${entry.key}.md').readAsString();
      if (_sha256(reRead) != entry.value) {
        debugPrint('Migration validation failed: hash mismatch for ${entry.key}');
        return false;
      }
    }

    // 7. Mark completed（写 marker，idempotent 守卫）
    await _writeMarker(marker, _expectedVersion);
    debugPrint('Migrated ${docs.length} documents to .md files');
    return true;
  }
}
```

### 边界约束（Accept 时补充）

> 下述 7 条为 Phase 1 P0 #2 正式实施前的硬边界，违反任一条均视为架构回退。

#### 1. Single Source Truth 范围（三层模型）

单一真相源**仅限文档内容**，不涵盖所有数据。明确三层：

| 层 | 内容 | 真相属性 | 可重建？ |
|----|------|---------|---------|
| **内容层** | `.md` 文件（含 front matter 中的 canonical 元数据） | **唯一真相源** | 否 |
| **索引/缓存层** | 运行时目录扫描结果 /（未来）SQLite 索引 / 全文索引 | 派生，非真相 | 是（可随时重建） |
| **偏好/状态层** | 深色模式、最近打开 path、收藏、排序方式 | UI 状态，非内容 | 是（丢失不影响文档） |

索引/缓存层**禁止**反向成为真相源（这正是被废弃的 JSON 文档库之病）。

#### 2. File Write Policy（原子写，禁止业务层直写）

- 业务层（UI / Provider / domain）**不得**直接调用 `File.writeAsString` 或 `FileService.saveToFile` 写文档；所有文档 I/O 必须经过 `FileRepository`。
- `FileRepository` 内部统一使用原子替换：

  ```dart
  // 写 .md：tmp → flush/fsync → rename
  final tmp = File('${path}.tmp');
  await tmp.writeAsString(content);
  await tmp.flush();      // 落盘
  await tmp.rename(path); // 原子替换（POSIX 语义）
  ```

  任何异常都先 `tmp.delete()` 清理半截文件，绝不留下损坏的 `.md`。

#### 3. 最小 front matter 提前到 Phase 1

不再推迟到 Phase 2。每个 `.md` 头部统一：

```
---
id: <uuid>
createdAt: 2026-07-18T17:20:14+08:00
updatedAt: 2026-07-18T17:20:14+08:00
---
```

- `title` **不**写入 front matter（避免与正文/文件名漂移）；展示标题由正文首个 `# H1` 推导，无 H1 时回退为 `<uuid>` 展示名。
- 解析由 `FrontMatterParser` 剥离 `---` 块，返回 `(metadata, body)`。

#### 4. 文件名用 `<uuid>.md` 而非 `<title>.md`

- 标题会冲突、含非法字符、会随编辑改变；以标题作文件名会导致重命名改写 Git 历史、破坏交叉链接。
- `uuid` 稳定、无冲突、无需 sanitize、Git diff 稳定。
- 人类可见的"标题"与文件名解耦（见 §3）。

#### 5. 不建议 SharedPreferences 缓存文件列表

- 原风险表曾建议"SP 缓存文件列表 + mtime 增量更新"，**撤回**：这等于重新引入第二真相源，正是本 ADR 要消灭的 bug。
- 决策：
  - **Phase 1 小规模**（< 数百文件）：加载时直接扫 `documents/`，开销可忽略。
  - **Phase 2+ 中/大规模**：引入 SQLite 索引或全文索引作为**可重建派生缓存**（由 `.md` 重建，非真相），不存内容。

#### 6. FileRepository 扩展 API

在 CRUD（`listDocuments` / `readDocument` / `writeDocument` / `deleteDocument` / `renameDocument`）之外，新增：

| API | 用途 |
|-----|------|
| `Future<DocMetadata> getMetadata(String path)` | 仅读 front matter，不解析正文 |
| `Stream<List<DocMetadata>> watchDocuments()` | 监听目录变化，驱动响应式列表 |
| `Future<List<DocMetadata>> searchDocuments(String query)` | 按标题/正文包含匹配 |
| `Future<bool> exists(String path)` | 廉价存在性检查 |

#### 7. 迁移验证阶段 + `storage_version` marker

- 阶段顺序：**Backup → Parse → Generate → Validate count → Validate hash → Mark completed**。
- `documents/.storage_version`（内容 `"1"`）作为幂等守卫：已标记且源 JSON 已不存在 → 跳过；源 JSON 存在但 marker 命中 → 也跳过（视为已迁移）。
- 任一 Validate 失败：保留 `.bak`、记录 `debugPrint`、友好提示用户、**不标记完成**、不删源。

## 动机

### 选择 .md 文件的理由

1. **用户可访问**：.md 是标准格式，用户可用其他编辑器（含 Typora 本体）打开
2. **可移植**：换设备 / 跨平台同步（iCloud / Dropbox）简单
3. **可调试**：开发者用文件管理器直接看
4. **无锁定**：JSON 文档库是私有格式，用户迁出困难
5. **与 Typora 一致**：Typora 也是以 .md 文件为存储单元

### 否决其他方案的理由

#### 方案 A：保留 JSON + 引入 SQLite 元数据

**否决理由**：
- 双层存储更复杂，未解决"用户可见性"问题
- SQLite 对当前规模过重

#### 方案 B：全部用 SQLite

**否决理由**：
- 用户无法直接访问文档
- 与 Typora 体验不一致
- 增加原生平台依赖

#### 方案 C：保留 SharedPreferences 草稿 + .md 文件保存

**否决理由**：
- 仍然双套，数据不一致风险未消除
- "草稿"概念对用户认知负担重

## 后果

### 正面

- 单一真相源，无数据不一致
- 用户可直接看到 .md 文件
- 跨设备同步简单
- 删除大量存储相关代码

### 负面

- 迁移有丢数据风险（需备份 + 回滚脚本）
- 大量文档（> 1000）时扫描目录慢（需缓存元数据）
- 文件名冲突需处理（同名文档）

### 风险与缓解

| 风险 | 缓解 |
|------|------|
| 迁移丢数据 | 备份 .json → .bak；幂等迁移；保留 .bak 至少 30 天 |
| 文件名冲突 | 自动追加 `_2`、`_3` |
| 元数据丢失（如 createdAt） | 写入 .md front matter（YAML header） |
| 大目录扫描慢 | Phase1 小规模直接扫 `documents/`（< 数百文件开销可忽略）；中/大规模在 Phase 2+ 引入**可重建**的 SQLite 索引或全文索引作为派生缓存，绝不引入第二真相源（见 §边界约束 5） |

## 实施计划

### Phase 1 P0 #2（本 ADR 对应任务）

1. 实现 `StorageMigration.migrateIfNeeded()`（幂等）
2. 实现 `FileRepository` 接口（与现有 `DocumentService` API 对齐）
3. 修改 Provider 从 `DocumentService` 切换到 `FileRepository`
4. 修改 `EditorScreen` 退出时不再清缓存，改为防抖写入当前 path 的 .md
5. 废弃 `formula_fix_documents.json`（保留 .bak）
6. 废弃 `SharedPreferences['pref_last_content']`
7. 添加迁移测试 + 数据一致性测试

### Phase 2（WYSIWYG 重构时）

- 评估是否在 .md front matter 加更多元数据
- 评估是否引入目录结构（按分类 / 标签）

## 替代方案再次评估

如果未来发现 .md 文件方案有不可解决问题：

- **Plan B**：SQLite + 全文索引，导出时合成 .md
- **Plan C**：文档数据库（如 Drift + Moor）+ 自动同步到 .md

## 参考

- [CRITICAL_REVIEW.md §2.1](file:///d:/Projects/Active/math/docs/CRITICAL_REVIEW.md) 三套存储并存
- [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) Phase 1 P0 #2
