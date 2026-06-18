# MaohuobanDesignSystem

毛伙伴 iOS 设计系统包，提供跨 Feature 复用的主题、组件和基础视觉能力。

## 平台要求

- Swift 6.4+
- iOS 27+

## 模块结构

### Theme — 主题 Token

统一管理颜色、字体、间距、圆角、图标尺寸等视觉原子。

| 文件 | 职责 |
|---|---|
| `MHBTheme` | 设计系统统一入口和命名空间 |
| `MHBThemeColorToken` | 颜色 Token 定义 |
| `Color+Adaptive` | 自适应颜色（深色模式） |
| `MHBThemeTypography` | 字体排版系统 |
| `MHBThemeSpacing` | 间距系统 |
| `MHBThemeRadius` | 圆角系统 |
| `MHBThemeIconSize` | 图标尺寸规范 |

### Components — 基础组件

跨业务复用的通用 UI 组件。

| 组件 | 职责 |
|---|---|
| `MHBStableTextField` | 稳定文本输入框，防抖和格式化 |
| `MHBStableTextInputStateMachine` | 文本输入状态机，管理输入生命周期 |
| `MHBStableTextInputLimit` | 文本输入限制策略 |
| `MHBTagView` | 标签视图组件 |

### SlotText — 插槽文本动画

声明式文本过渡动画系统，支持字符级插入、删除和替换动画。

| 文件 | 职责 |
|---|---|
| `MHBSlotText` | 插槽文本主入口 |
| `MHBSlotTextConfiguration` | 动画参数配置 |
| `MHBSlotTextTransitionPlan` | 过渡计划生成 |
| `MHBSlotTextCellView` | 单字符动画单元 |
| `MHBSlotTextView` | 文本动画容器视图 |

### Toast — 提示系统

全局 Toast 提示，支持成功/警告/错误/信息四种类型。

| 文件 | 职责 |
|---|---|
| `MHBToast` | Toast 数据模型 |
| `MHBToastType` | 提示类型枚举 |
| `MHBToastAction` | 交互动作定义 |
| `MHBToastView` | 提示条视图渲染 |
| `MHBToastModifier` | SwiftUI View Modifier 入口 |
| `MHBToastManager` | 全局提示管理器 |
| `MHBPassThroughWindow` | 穿透触摸窗口 |
| `MHBCustomHostingView` | 自定义宿主视图 |
| `MHBWindowExtractor` | 窗口提取工具 |

## 使用方式

```swift
import MaohuobanDesignSystem

// 主题 Token
Text("标题").font(MHBTheme.typography.title)
    .foregroundColor(MHBTheme.color.primary)

// Toast
view.mhbToast(isPresented: $showToast, toast: MHBToast(
    type: .success,
    message: "保存成功"
))

// SlotText
MHBSlotText("正在输入...", configuration: .default)

// 稳定输入框
MHBStableTextField(text: $name, placeholder: "宠物名称", limit: .byteLength(32))
```

## 设计原则

1. 主题 Token 是唯一视觉真相源，业务页面不得硬编码颜色、字体、间距
2. 组件只做渲染和基础交互，不持有业务状态
3. 新增视觉能力时，先判断归属：Token / 基础组件 / 页面组件 / 业务私有样式
4. Token 变更必须同步更新测试
