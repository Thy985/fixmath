# FormulaFix 编码规范

> 本文是 [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) 第 2-4 章的展开版。  
> 所有规则基于现有代码分析，不凭空设计。

---

## 1. 文件与目录

### 1.1 文件命名

- `snake_case.dart`
- 一个文件 = 一个核心 class / 一个 Provider 簇 / 一个主题
- 测试文件与源文件同名，放 `test/` 镜像目录

### 1.2 文件头文档

每个 `.dart` 文件必须有 1-3 行 `///` 顶部文档：

```dart
/// Markdown → PDF 导出器。
///
/// 把 Markdown 文档解析为 PDF：标题 / 段落 / 列表 / 表格 / 代码块 /
/// 引用 / 公式（含 SVG 矢量 + PNG 位图回退） / Mermaid 图表。
library;

import 'package:flutter/foundation.dart';
```

参考 [pdf_exporter.dart:1-9](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/exporters/pdf_exporter.dart#L1-9) 的写法。

### 1.3 文件长度

- 单文件 ≤ 400 行：理想
- 400-600 行：可接受，需评估是否拆分
- \> 600 行：必须拆分

例外：自动生成的代码（OOXML 模板等）可放宽。

### 1.4 import 顺序

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:io';

// 2. Flutter / 第三方
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 3. 项目内（相对路径，不混用 package:）
import '../../core/constants/app_constants.dart';
import '../../data/models/document.dart';
```

每组之间空一行。**禁止** `package:formulafix/...`，统一用相对路径。

---

## 2. 命名

### 2.1 总规则

| 类型 | 规则 | 示例 |
|------|------|------|
| 类 / 枚举 / typedef | UpperCamelCase | `DocumentElement`、`ExportFailure` |
| 文件 | snake_case.dart | `markdown_parser.dart` |
| 方法 / 变量 | lowerCamelCase | `parseInline`、`isDarkMode` |
| 私有 | `_` 前缀 | `_PendingLatex`、`_dispatchWaiting` |
| 常量（static const） | lowerCamelCase 或 UPPER_SNAKE | `maxHistorySize`、`_kHtml` |
| Provider | `xxxProvider` 后缀 | `documentsProvider`、`darkModeProvider` |
| 异常类 | `XxxException` 后缀 | `ExportException`、`FormulaSvgException` |

### 2.2 布尔变量

- 用 `is` / `has` / `can` 前缀：`isDark`、`hasContent`、`canUndo`
- 不用 `not`：❌ `notEmpty`，✅ `isNotEmpty`

### 2.3 避免缩写

- ❌ `btn` / `ctx` / `doc`
- ✅ `button` / `context` / `document`
- 例外：行业通用缩写 `URL` / `PDF` / `SVG` / `API`

---

## 3. Dart 语言特性

### 3.1 鼓励使用

- **sealed class**：用于 AST / 状态联合（参考 [document.dart:12-14](file:///d:/Projects/Active/math/flutter_app/lib/data/models/document.dart#L12-14)）
- **records**：用于多值返回（参考 `ExportFailureInfo`）
- **switch 表达式 + 模式匹配**：替代 if-else 链（参考 [preview_content.dart:80-102](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L80-102)）
- **空安全**：优先 `?` / `??` / `?.`，禁止 `!` 强解包（除非同行已 null 检查）

### 3.2 禁止使用

- `dynamic`：除非与 JS 桥接（如 [formula_svg_service.dart:241](file:///d:/Projects/Active/math/flutter_app/lib/core/services/formula_svg_service.dart#L241) 的 `raw`）
- `late`：除非有明确的初始化保证，且不可在 final 字段上用
- 全局可变状态
- `print()`：必须 `debugPrint()`

### 3.3 类型注解

- public API 必须**显式类型**：`Future<Uint8List> export(String markdown)`
- 局部变量可省略（`final` / `var`）让类型推断工作
- 集合字面量优先 `<>`：`final List<Document> docs = []`

---

## 4. Flutter 与 Widget

### 4.1 Widget 拆分原则

- 单个 `build` 方法 ≤ 80 行
- 复杂 UI 拆为 `Widget` 类（参考 `_DocCard` in [document_list_screen.dart:241-346](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/document_list_screen.dart#L241-346)）
- 内联闭包：≤ 30 行；超出就抽 Widget

### 4.2 状态管理

- 无状态：`StatelessWidget`
- 局部状态：`StatefulWidget` + `setState`
- 跨 Widget 共享：Riverpod Provider（见第 5 章）
- 禁止 `StatefulWidget` 内用 `InheritedWidget` 手动传递状态

### 4.3 性能

- 长列表用 `ListView.builder`，禁止 `ListView(children: [...])`
- 图片 / 字体加载用缓存（`precacheImage`）
- 避免在 `build` 内做重计算，移到 Provider / `useMemoized`

### 4.4 主题

- 颜色 / 间距 / 字号**必须**从 [app_constants.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/constants/app_constants.dart) 取
- 禁止硬编码 `Color(0xFFxxxxxx)`、`fontSize: 16`、`EdgeInsets.all(8)`
- **已知问题**：当前 [app_theme.dart](file:///d:/Projects/Active/math/flutter_app/lib/presentation/theme/app_theme.dart) 也定义了一组颜色常量，与 `AppColors` 冲突，待 Phase 1 合并

---

## 5. 状态管理（Riverpod）

### 5.1 Provider 选择决策树

```
需要异步数据？
  ├─ 是 → FutureProvider / AsyncNotifierProvider
  └─ 否 → 需要修改状态？
          ├─ 是 → StateNotifierProvider（业务状态）
          │      / StateProvider（UI 简单状态）
          └─ 否 → Provider（依赖注入）
```

### 5.2 命名

- Provider 名：`xxxProvider`
- Notifier 名：`XxxNotifier`
- 状态类型：不可变 class 或 record，配 `copyWith`

### 5.3 归属

- 业务级 Provider：`domain/providers/`
- UI 全局状态：`providers/`
- 单个屏幕私有 Provider：放该屏幕文件内或 `presentation/providers/`

### 5.4 不可变性

```dart
// ❌ 错误：直接修改 state 内的集合
state.list.add(doc);

// ✅ 正确：创建新对象
state = state.copyWith(list: [...state.list, doc]);
```

### 5.5 dispose

- 资源型 Provider（WebView / Stream / Timer）：用 `autoDispose` 或在 Notifier 的 dispose 中清理
- 当前静态状态（`MermaidService._cache`）是历史遗留，Phase 2 重构

### 5.6 已知违规

- [providers/providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart) 与 [providers/editor_providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart) 重复定义 `sharedPreferencesProvider` / `darkModeProvider`  
  → Phase 1 P0 #1 修复

---

## 6. 数据访问

### 6.1 分层

```
UI  →  Provider  →  Service  →  File / SharedPreferences / WebView
```

- UI **不直接** 调 `DocumentService` / `FileService`
- Provider 持有 Service 实例，UI 通过 `ref.watch(xxxProvider)` 读、`ref.read(xxxProvider.notifier).method()` 写

### 6.2 单一真相源（目标，未达成）

详见 [ADR-0003](file:///d:/Projects/Active/math/docs/ADR/0003-storage-single-source-md-files.md)。

- 当前：三套并存
- 目标：`.md` 文件为唯一真相
- 过渡期：禁止新增第四套

### 6.3 编码兜底

```dart
// ❌ 错误：直接 utf8.decode
final content = utf8.decode(await file.readAsBytes());

// ✅ 正确：用 decodeBytesAuto
final content = decodeBytesAuto(await file.readAsBytes());
```

详见 [file_service.dart:13-41](file:///d:/Projects/Active/math/flutter_app/lib/core/services/file_service.dart#L13-41)。

### 6.4 错误传播

- Service 抛业务异常（`ExportException` / `FileImportException`）
- Provider catch 后转换为业务态（`AsyncValue.error` 或 `ExportFailure`）
- UI 通过 `ExportFailure.kind` 决定文案，**不直接展示 detail**

```dart
// ❌ 错误：UI 直接展示 detail
return '文档中有无法识别的内容: ${_clip(detail, 60)}';

// ✅ 正确：UI 按 kind 给本地化文案
return '文档中有无法识别的内容，请检查公式语法';
```

已知违规：[editor_screen.dart:230-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L230-253)，Phase 1 P1 #7 修复。

---

## 7. 错误处理

### 7.1 异常分类

参考 [export_service.dart:201-260](file:///d:/Projects/Active/math/flutter_app/lib/domain/services/export_service.dart#L201-260)：

- `ExportFailure`：业务分类枚举
- `ExportFailureInfo`：record，含 kind / userMessage / detail / cause
- `ExportFailureException`：包装后抛出

### 7.2 catch 顺序

```dart
try {
  await exportAndShare(...);
} on ExportFailureException catch (e) {
  // 业务异常 → 本地化提示
  _showSnackBar(_userMessageFor(e.info));
} catch (e) {
  // 未分类异常 → 兜底
  debugPrint('Unexpected: $e');
  _showSnackBar('操作失败，请重试');
}
```

### 7.3 禁止静默吞

```dart
// ❌ 错误：完全静默
try { ... } catch (_) {}

// ✅ 正确：至少 debugPrint
try { ... } catch (e) {
  debugPrint('xxx failed: $e');
}
```

已知违规：[file_manager_screen.dart:46](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/file_manager_screen.dart#L46)，Phase 1 修复。

---

## 8. 测试

### 8.1 覆盖率要求

- 新增 public API：必须配单元测试
- Bug 修复：必须配回归测试
- 复杂 Widget：建议配 Widget 测试
- 集成测试：关键流程必须有（导出 / 文档流转）

### 8.2 命名

```
test/<source_name>_test.dart
```

示例：`markdown_parser_test.dart` 对应 `markdown_parser.dart`。

### 8.3 结构

```dart
void main() {
  group('MarkdownParser.parse', () {
    test('应识别一级标题', () { ... });
    test('应识别块级公式', () { ... });
    
    group('表格', () {
      test('应识别单行列分隔符', () { ... });
      test('应识别多行数据', () { ... });
    });
  });
}
```

### 8.4 测试隔离

- 静态状态（CJK 字体、缓存）必须在 `setUp` / `tearDown` 清理
- 用 `MarkdownExporter.register({...})` 注入 fake 避开 WebView

```dart
setUp(() {
  FormulaSvgService.clearCache();
  MermaidService.clearCache();
});

tearDown(() {
  FormulaSvgService.clearCache();
  MermaidService.clearCache();
});
```

### 8.5 已知测试缺口

- 无 `editor_screen_test.dart`
- 无 `document_list_screen_test.dart`
- 无 `file_manager_screen_test.dart`
- 无路由测试
- 无 Provider 集成测试
- 无存储一致性测试

Phase 1 P1 #8 补齐。

---

## 9. 性能

### 9.1 列表

- `ListView.builder` / `GridView.builder`
- 禁止 `Column` 内嵌超长 `ListView`（用 `Expanded`）

### 9.2 重绘

- `const` Widget 优先
- `RepaintBoundary` 包裹独立动画区域

### 9.3 异步

- IO 操作（文件 / 网络 / WebView）必须 `async`
- 主线程不阻塞：长计算用 `compute`（isolate）

### 9.4 已知性能问题

- [editor_screen.dart:67-69](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L67-69)：每次按键全量解析
- WebView 冷启动 2-3 秒
- 单条公式 30s 超时

Phase 2 修复。

---

## 10. 注释

### 10.1 dartdoc（`///`）

- 用于 public API
- 第一行简短摘要
- 空行后展开细节
- 用 `[Symbol]` 引用其他 API

```dart
/// 把 Markdown 文本导出为 PDF 字节流。
///
/// 内部委托给 [_pdfExporter]，可通过 [register] 替换为 fake。
static Future<Uint8List> exportToPdf(String markdown, {...}) { ... }
```

### 10.2 普通注释（`//`）

- 用于实现细节、调试信息、TODO
- TODO 格式：`// TODO(<name>): <desc> —— <ticket/url>`

```dart
// TODO(architect): Phase 1 替换为 .md 文件存储 —— ROADMAP 1.2
```

### 10.3 禁止

- 无意义注释（`// constructor`）
- 改动历史注释（`// 修改 by xxx`）—— 用 git
- 大段注释掉的代码 —— 删除，用 git 找回

---

## 11. 已知违规清单（不视为本次新增违规，按 Phase 修复）

| 违规 | 位置 | 修复 Phase |
|------|------|---------|
| Provider 重复定义 | [providers/providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/providers.dart) + [providers/editor_providers.dart](file:///d:/Projects/Active/math/flutter_app/lib/providers/editor_providers.dart) | 1.1 |
| UI 层直接展示 detail | [editor_screen.dart:221-253](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart#L221-253) | 1.7 |
| 异常静默吞 | [file_manager_screen.dart:46](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/file_manager_screen.dart#L46) | 1.7 |
| 颜色常量两套 | [app_constants.dart](file:///d:/Projects/Active/math/flutter_app/lib/core/constants/app_constants.dart) + [app_theme.dart](file:///d:/Projects/Active/math/flutter_app/lib/presentation/theme/app_theme.dart) | 1 |
| `main()` 多余 async | [main.dart:9](file:///d:/Projects/Active/math/flutter_app/lib/main.dart#L9) | 1 |
| 静态状态污染测试 | `MermaidService._cache` 等 | 2 |
| 编辑/预览分离 | [editor_screen.dart](file:///d:/Projects/Active/math/flutter_app/lib/presentation/screens/editor_screen.dart) | 2 |
| 每次按键全量解析 | [preview_content.dart:30](file:///d:/Projects/Active/math/flutter_app/lib/presentation/widgets/preview_content.dart#L30) | 2 |

新增代码不得延续以上违规模式。

---

## 12. Android 构建配置

### 12.1 工具链版本（锁定，不可随意升级）

| 组件 | 版本 | 说明 |
|------|------|------|
| AGP (Android Gradle Plugin) | **8.7.3** | AGP 9.0+ 不支持 `proguard-android.txt`，与 `flutter_inappwebview_android 1.1.3` 不兼容 |
| Gradle | **8.12.1** | AGP 8.7.x 要求 Gradle 8.9-8.12 |
| Kotlin | **2.1.0** | 与 AGP 8.7.3 兼容 |
| Java | **17** | CI 中使用 `temurin-17` |

升级任一组件前必须验证：`flutter_inappwebview_android`、`file_picker`、`flutter_plugin_android_lifecycle` 三个插件的 `build.gradle` 全部能通过编译。

### 12.2 compileSdk 策略

Flutter 3.44.6 的 `flutter.compileSdkVersion` = **36**。

但第三方插件可能硬编码旧版 compileSdk：

| 插件 | 原始 compileSdk | 问题 |
|------|----------------|------|
| `file_picker` 8.x | 33 | `flutter_plugin_android_lifecycle` 要求 ≥36 |
| `flutter_inappwebview_android` 1.1.3 | 34 | 同上 |

**正确修复方式**：在根 `build.gradle.kts` 中用 `gradle.afterProject` 统一覆盖：

```kotlin
// android/build.gradle.kts
gradle.afterProject {
    if (project != rootProject) {
        extensions.findByType<com.android.build.api.dsl.LibraryExtension>()?.let {
            it.compileSdk = 36
        }
        extensions.findByType<com.android.build.api.dsl.ApplicationExtension>()?.let {
            it.compileSdk = 36
        }
    }
}
```

**禁止的做法**：
- ❌ 用 `afterEvaluate`（会与 `evaluationDependsOn(":app")` 冲突）
- ❌ 用多个 `subprojects {}` 块（时序不可控）
- ❌ 直接修改 pub cache 中插件的 `build.gradle`（污染全局）
- ❌ 用 `sed` 在 CI 中修补（脆弱、难维护）

### 12.3 inappwebview 依赖锁定

`flutter_inappwebview` 的 pub.dev 存在稳定版与 beta 版混合发布的问题。pub 解析器会自动选择 beta 版（如 `1.4.0-beta.3`、`1.2.0-beta.3`），导致 API 不兼容。

**必须通过 `dependency_overrides` 锁定到稳定版**：

```yaml
# pubspec.yaml
dependency_overrides:
  flutter_inappwebview_platform_interface: 1.3.0+1
  flutter_inappwebview_ios: 1.1.2
  flutter_inappwebview_macos: 1.1.2
  flutter_inappwebview_web: 1.1.2
```

升级 `flutter_inappwebview` 时必须同步验证所有子包版本一致性，避免 beta 混入。

### 12.4 android/ 目录已纳入版本控制

`flutter_app/android/` 目录已提交到仓库（AGP 8.7.3 + Gradle 8.12.1 + compileSdk 36 override）。

CI 不再需要 `flutter create --platforms=android .` 动态生成，也不需要 `sed` 修补 compileSdk。

修改 `android/` 下的 Gradle 文件后，必须本地验证：
```bash
flutter build apk --debug --target-platform android-arm64
```

---

## 13. 开发环境约束

### 13.1 Flutter CLI 执行环境

**禁止在 PowerShell 中直接调用 `flutter.bat`**。PowerShell 读取 `.bat` 子进程 stdout 时存在缓冲死锁问题，表现为进程卡死无输出。

**正确方式**：使用 Git Bash 执行所有 Flutter CLI 命令：

```bash
# Git Bash 中
export PATH="/c/Users/lenovo/SDK/flutter/bin:$PATH"
cd /d/Projects/Active/math/flutter_app
flutter pub get
flutter build apk --debug
```

PowerShell 中调用 Git Bash 的方式：
```powershell
bash -c 'export PATH="/c/Users/lenovo/SDK/flutter/bin:$PATH"; cd /d/Projects/Active/math/flutter_app && flutter pub get 2>&1'
```

### 13.2 Flutter 进程锁管理

Flutter 使用文件锁（`cache/flutter.bat.lock`、`cache/lockfile`）防止并发。以下情况会导致锁残留：

- 后台化的 Flutter 进程被 kill
- `flutter precache` 中途取消
- 多个终端同时执行 Flutter 命令

**症状**：`Waiting for another flutter command to release the startup lock...`

**修复**：
```powershell
# 1. 杀掉所有残留进程
taskkill /F /IM flutter.bat; taskkill /F /IM dart.exe; taskkill /F /IM java.exe

# 2. 清理锁文件
Remove-Item "$env:USERPROFILE\SDK\flutter\bin\cache\flutter.bat.lock" -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\SDK\flutter\bin\cache\lockfile" -ErrorAction SilentlyContinue
```

### 13.3 一次性文件清理

以下类型的文件用完必须立即删除，**禁止提交到仓库、禁止长期留存**：

| 类型 | 示例 | 处置 |
|------|------|------|
| CI/调试日志 | `ci_logs/`、`logs.zip`、`pub_get.log` | 用完即删 |
| 临时压缩包 | `logs2.zip` ~ `logs6.zip` | 分析后删除 |
| 包管理器残留 | `node_modules/` | Flutter 项目不需要，删除 |
| 构建产物 | `build/`、`.dart_tool/` | 已在 `.gitignore` 中排除 |

**原则**：根目录只保留 `AGENTS.md`、`README.md`、`LICENSE`、`docs/`、`flutter_app/`、`design-system/`、`.github/`。出现其他目录/文件时先问"这是永久的还是临时的"，临时的用完即删。

### 13.4 首次环境搭建

新机器或清空 cache 后，必须先完成 `flutter precache`：

```bash
export PATH="/c/Users/lenovo/SDK/flutter/bin:$PATH"
flutter precache
```

`precache` 会下载 `cache/artifacts/` 和 `cache/pkg/sky_engine/`。缺失时 `flutter pub get` 会报 `sky_engine not found`。

`precache` 首次运行耗时较长（10-20 分钟），中途不可 kill，否则需重新开始。

---

## 14. 相关文档

- [AGENTS.md](file:///d:/Projects/Active/math/AGENTS.md) — 总体规范
- [GIT_WORKFLOW.md](file:///d:/Projects/Active/math/docs/GIT_WORKFLOW.md) — Git 流程
- [ARCHITECTURE.md](file:///d:/Projects/Active/math/docs/ARCHITECTURE.md) — 架构总览
- [ROADMAP.md](file:///d:/Projects/Active/math/docs/ROADMAP.md) — 路线图
- [ADR/](file:///d:/Projects/Active/math/docs/ADR) — 架构决策记录
