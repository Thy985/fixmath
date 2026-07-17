# ADR-0003: 存储统一为 .md 文件作为单一真相

- **状态**：Proposed（Phase 1 执行）
- **生效日期**：待 Phase 1 P0 #2 启动时 Accept
- **决策者**：首席架构工程师

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
| `formula_fix_documents.json` | .md 文件 + 文档目录扫描 | 一次性迁移：JSON 内每个 doc 写成 `<title>.md` |
| `SharedPreferences['pref_last_content']` | 自动保存到当前打开的 .md 文件 | 编辑器每次切换文档时记下当前 path，防抖写入该 path |
| `DocumentService` | 新建 `FileRepository`（Phase 2 重命名） | 接口兼容包装 |
| `DocumentListScreen` | 合并到 `FileManagerScreen` 或注册路由（Phase 1 P0 #3 决策） | - |

### 迁移逻辑（幂等）

```dart
class StorageMigration {
  static Future<void> migrateIfNeeded() async {
    final dir = await getApplicationDocumentsDirectory();
    final jsonFile = File('${dir.path}/formula_fix_documents.json');
    if (!await jsonFile.exists()) return;  // 无需迁移
    
    // 备份
    final backup = await jsonFile.copy('${jsonFile.path}.bak');
    debugPrint('Backup created: ${backup.path}');
    
    // 读取 JSON
    final docs = await _readJsonDocuments(jsonFile);
    
    // 写成 .md
    final docsDir = Directory('${dir.path}/documents');
    await docsDir.create(recursive: true);
    for (final doc in docs) {
      final safeTitle = _sanitizeFilename(doc.title);
      final file = File('${docsDir.path}/$safeTitle.md');
      await file.writeAsString(doc.content);
    }
    
    // 保留 JSON 作为 .bak（不删）
    debugPrint('Migrated ${docs.length} documents to .md files');
  }
}
```

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
| 大目录扫描慢 | SharedPreferences 缓存文件列表 + mtime，启动时增量更新 |

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
