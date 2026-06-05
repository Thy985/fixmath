# FormulaFix

一款纯本地运行的 Markdown/LaTeX 编辑器，支持数学公式渲染与多格式导出。

## 特性

- **纯本地运行** - 100% 离线工作，无需网络连接
- **数学公式支持** - 支持 LaTeX 语法，包括行内公式 `$...$` 和块级公式 `$$...$$`
- **实时预览** - 编辑内容实时渲染，所见即所得
- **多格式导出** - 支持 PDF、Word(.docx)、纯文本导出
- **深色模式** - 支持深色/浅色主题切换
- **模板系统** - 提供多种文档模板

## 支持的 Markdown 语法

### 标题

```markdown
# 一级标题
## 二级标题
### 三级标题
```

### 列表

```markdown
- 无序列表项
- 另一个项

1. 有序列表
2. 第二项

- 嵌套列表
  - 子项
```

### 数学公式

```markdown
行内公式: $E = mc^2$

块级公式:
$$
\int_0^1 x^2 dx = \frac{1}{3}
$$
```

### 表格

```markdown
| 列1 | 列2 | 列3 |
|-----|-----|-----|
| A   | B   | C   |
| D   | E   | F   |
```

### 代码块

````markdown
```python
def hello():
    print("Hello, World!")
```
````

### 引用

```markdown
> 这是一段引用文本
```

## 项目结构

```
lib/
├── core/                    # 核心层
│   ├── parser/             # Markdown 解析器
│   ├── constants/          # 常量定义
│   └── services/           # 核心服务
├── data/                   # 数据层
│   └── models/            # 数据模型
├── domain/                 # 业务层
│   ├── providers/          # 状态管理
│   └── services/          # 业务服务
└── presentation/           # 表现层
    ├── screens/            # 页面
    ├── widgets/            # 组件
    └── theme/              # 主题
```

## 开始使用

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### 安装依赖

```bash
cd flutter_app
flutter pub get
```

### 运行应用

```bash
# Android
flutter run

# Web
flutter run -d chrome

# Windows
flutter run -d windows
```

### 运行测试

```bash
flutter test
```

## 技术栈

| 模块 | 技术 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 | Riverpod |
| 公式渲染 | flutter_math_fork |
| PDF 生成 | pdf + printing |
| Word 生成 | archive (手写 OOXML) |

## 版本历史

- **v2.0.0** (2026-06-02) - 代码重构，修复解析器bug，改进导出服务
- **v1.0.0** (2026-05-06) - 初始版本

## 许可证

本项目基于 MIT 许可证开源，详见 [LICENSE](LICENSE) 文件。
