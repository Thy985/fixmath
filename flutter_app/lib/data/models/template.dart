class DocumentTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final String content;

  const DocumentTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.content,
  });
}

class TemplateData {
  static const List<DocumentTemplate> templates = [
    DocumentTemplate(
      id: 'exam_math',
      name: '数学试卷',
      description: '高中数学试卷模板，包含选择题、填空题、解答题',
      category: '试卷',
      content: r'''# 数学试卷

## 一、选择题（每题 5 分，共 50 分）

1. 已知函数 $f(x) = x^2 + 2x + 1$，则 $f(-1)$ 的值为（ ）
2. 若 $\sin\alpha = \frac{3}{5}$，则 $\cos\alpha$ 的值为（ ）
3. 等差数列 $\{a_n\}$ 中，$a_1=2$，$a_3=6$，则公差 $d$ 为（ ）
4. 已知向量 $\vec{a}=(1,2)$，$\vec{b}=(3,4)$，则 $\vec{a}\cdot\vec{b}$ 的值为（ ）
5. 圆 $x^2+y^2=4$ 的半径是（ ）

## 二、填空题（每题 5 分，共 25 分）

6. 方程 $x^2-5x+6=0$ 的解为 _______________
7. 函数 $y=\sqrt{x-1}$ 的定义域为 _______________
8. 若 $\log_2 x = 3$，则 $x=$ _______________

## 三、解答题（共 25 分）

9. （10分）已知函数 $f(x)=x^3-3x$

（1）求 $f'(x)$

（2）求 $f(x)$ 的极值点

10. （15分）已知椭圆 $\frac{x^2}{a^2}+\frac{y^2}{b^2}=1$（$a>b>0$）的离心率为 $\frac{\sqrt{3}}{2}$

（1）求 $\frac{b}{a}$ 的值

（2）若椭圆过点 $(2,\sqrt{3})$，求椭圆方程''',
    ),
    DocumentTemplate(
      id: 'paper_academic',
      name: '学术论文',
      description: '标准学术论文模板，包含摘要、引言、正文、结论',
      category: '论文',
      content: r'''# 论文标题

## 摘要

本文研究了 _______ 的问题。通过 _______ 方法，得出 _______ 的结论。

**关键词：** 关键词1、关键词2、关键词3

## 1 引言

研究背景与意义...

## 2 相关工作

## 3 方法

### 3.1 问题定义

设 $X = \{x_1, x_2, ..., x_n\}$ 为输入数据集，目标函数为：

$$\min_{w} \frac{1}{n}\sum_{i=1}^{n} L(y_i, f(x_i; w)) + \lambda R(w)$$

### 3.2 算法设计

## 4 实验

| 方法 | 准确率 | 召回率 | F1值 |
|------|--------|--------|------|
| 方法A | 0.92 | 0.89 | 0.90 |
| 方法B | 0.94 | 0.91 | 0.92 |

## 5 结论

## 参考文献

[1] Author, A. (2024). Title of the paper. *Journal Name*, 12(3), 100-120.''',
    ),
    DocumentTemplate(
      id: 'report_project',
      name: '项目报告',
      description: '项目/实验报告模板，适用于课程作业和项目总结',
      category: '报告',
      content: r'''# 项目报告

## 一、项目概述

### 1.1 项目名称

### 1.2 项目目标

### 1.3 团队成员

## 二、技术方案

### 2.1 技术选型

| 模块 | 技术 | 说明 |
|------|------|------|
| 前端 | Flutter | 跨平台 UI 框架 |
| 状态管理 | Riverpod | 响应式状态管理 |

### 2.2 架构设计

### 2.3 核心算法

时间复杂度分析：

$$T(n) = O(n\log n)$$

## 三、实现过程

- 第一阶段：需求分析与设计
- 第二阶段：核心功能开发
- 第三阶段：测试与优化
- 第四阶段：部署上线

## 四、测试结果

## 五、总结与展望

### 5.1 项目成果

### 5.2 遇到的问题与解决方案

> 问题描述：...
>
> 解决方案：...

### 5.3 未来改进方向''',
    ),
  ];
}
