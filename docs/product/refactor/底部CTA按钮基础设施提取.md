# 底部 CTA 按钮基础设施提取

## 变更时间
2026-06-24

## 背景
话题详情页使用了底部悬浮 CTA 按钮（"参与讨论"），该设计模式具有跨页面复用价值，需要提取为基础设施组件。

## 实施内容

### 1. 新增基础设施组件
**文件**: `maohuoban/maohuoban/Infrastructure/SwiftUI/MHBBottomFloatingCTA.swift`

#### MHBBottomFloatingCTA
- 支持 NavigationLink 路由跳转的底部悬浮按钮
- 自动处理安全区适配（通过 `bottomInset` 参数）
- 使用 Liquid Glass 材质（`.glassEffect(.regular.interactive(), in: .capsule)`）
- 支持可选的 SF Symbol 图标

**参数**:
- `title: String` - 按钮文本
- `systemImage: String?` - 可选的 SF Symbol 图标名
- `route: Route` - 导航目标路由（泛型约束 `Hashable`）
- `bottomInset: CGFloat` - 底部安全区高度（默认 0）

**使用示例**:
```swift
MHBBottomFloatingCTA(
    title: "参与讨论",
    systemImage: "square.and.pencil",
    route: composerRoute,
    bottomInset: bottomInset
)
```

#### MHBBottomFloatingActionCTA
- 支持闭包动作的底部悬浮按钮（无路由版本）
- 用于提交表单、触发弹窗等非导航场景
- 视觉样式与 `MHBBottomFloatingCTA` 保持一致

**参数**:
- `title: String` - 按钮文本
- `systemImage: String?` - 可选的 SF Symbol 图标名
- `bottomInset: CGFloat` - 底部安全区高度（默认 0）
- `action: () -> Void` - 按钮点击回调

**使用示例**:
```swift
MHBBottomFloatingActionCTA(
    title: "保存",
    systemImage: "checkmark",
    bottomInset: bottomInset,
    action: { /* 保存逻辑 */ }
)
```

### 2. 重构话题详情页
**文件**: `maohuoban/maohuoban/Features/Topics/Presentation/TopicDetailScreen.swift`

**变更**:
- `TopicDetailBottomAction` 从直接实现 UI 改为调用 `MHBBottomFloatingCTA`
- 保持组件接口和职责不变，仅替换实现

**变更前**:
```swift
private struct TopicDetailBottomAction<Route: Hashable>: View {
    let route: Route
    let bottomInset: CGFloat

    var body: some View {
        NavigationLink(value: route) {
            Label("参与讨论", systemImage: "square.and.pencil")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                // ... 大量样式代码
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s5 + bottomInset)
    }
}
```

**变更后**:
```swift
private struct TopicDetailBottomAction<Route: Hashable>: View {
    let route: Route
    let bottomInset: CGFloat

    var body: some View {
        MHBBottomFloatingCTA(
            title: "参与讨论",
            systemImage: "square.and.pencil",
            route: route,
            bottomInset: bottomInset
        )
    }
}
```

## 设计决策

### 1. 访问控制
- 使用 `struct` 而非 `public struct`（与其他基础设施组件保持一致）
- 在同一 module 内使用 `internal` 默认访问级别

### 2. 泛型约束
- `Route` 约束为 `Hashable`，符合 SwiftUI NavigationLink 要求
- 支持任意路由类型，保持组件通用性

### 3. 双组件设计
- `MHBBottomFloatingCTA`: 导航场景（主要）
- `MHBBottomFloatingActionCTA`: 动作场景（辅助）
- 避免单一组件承载过多职责

### 4. 安全区处理
- 通过 `bottomInset` 参数外部传入，由调用方使用 `GeometryReader` 读取
- 避免组件内部读取安全区（可能为 0 的问题）

## 复用场景

该组件适用于以下场景：
1. **详情页底部操作**: 话题详情、帖子详情、活动详情等
2. **表单提交**: 发布内容、编辑资料等（使用 `MHBBottomFloatingActionCTA`）
3. **引导流程**: 新用户引导、功能介绍等

## 视觉规范

- **按钮高度**: `MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4`（约 56pt）
- **水平内边距**: `MHBTheme.Spacing.s5`
- **底部间距**: `MHBTheme.Spacing.s5 + bottomInset`
- **材质**: Liquid Glass regular interactive
- **形状**: Capsule（胶囊形）
- **背景色**: `MHBTheme.ColorToken.primary.color`（主色调）
- **文本色**: 白色

## 后续扩展

如需支持更多能力，可考虑：
1. 支持自定义按钮颜色（通过配置参数）
2. 支持禁用状态
3. 支持加载状态（显示 ProgressView）
4. 支持次要按钮（多按钮布局）

## 验证

由于系统权限问题无法完成 Xcode 编译验证，但代码结构符合以下规范：
- ✅ 与现有基础设施组件访问控制一致
- ✅ 使用标准 SwiftUI 组件和 MaohuobanDesignSystem token
- ✅ 保持话题详情页行为不变
- ✅ 代码注释符合工程规范
