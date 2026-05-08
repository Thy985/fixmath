# FormulaFix Flutter App

纯本地 Markdown/LaTeX 编辑器，支持公式渲染与多格式导出。

## 快速开始

```bash
# 1. 安装依赖
cd flutter_app
flutter pub get

# 2. 运行项目
flutter run
```

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── core/                        # 核心层
│   └── parser/                  # 解析器
│       ├── formula_extractor.dart  # 公式提取
│       └── markdown_parser.dart    # Markdown 解析
├── data/                        # 数据层
│   └── models/                  # 数据模型
├── domain/                      # 业务层
│   └── services/                # 服务
│       └── export_service.dart # 导出服务
└── presentation/                # 表现层
    ├── screens/                 # 页面
    │   └── editor_screen.dart   # 编辑器页面
    ├── widgets/                 # 组件
    │   └── preview_content.dart # 预览内容
    └── theme/                  # 主题
        └── app_theme.dart       # 应用主题
```

## 功能

- ✅ Markdown 编辑与预览
- ✅ LaTeX 公式渲染（行内 $...$ 和块级 $$...$$）
- ✅ 实时预览
- ✅ 导出 PDF
- ✅ 导出 Word
- ✅ 深色/浅色模式
- ✅ 系统分享

## 技术栈

- Flutter 3.x
- Riverpod (状态管理)
- flutter_markdown
- flutter_math_fork
- pdf + printing
- docx
